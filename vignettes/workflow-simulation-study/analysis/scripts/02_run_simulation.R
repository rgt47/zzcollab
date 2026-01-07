# 02_run_simulation.R
# Run the complete simulation study
#
# This script executes the full simulation comparing GEE, GLMM, and
# conditional logistic regression for longitudinal binary data.
#
# Expected runtime: ~30 minutes with parallel processing
# Output: analysis/data/derived_data/simulation_results_raw.rds

library(furrr)
library(progressr)
library(tictoc)

source("R/simulate_data.R")
source("R/fit_models.R")
source("R/performance_metrics.R")

# Configuration --------------------------------------------------------------

N_SIMS <- 1000
N_CORES <- parallel::detectCores() - 1

cat("=== Simulation Configuration ===\n")
cat("Simulations per scenario:", N_SIMS, "\n")
cat("Parallel workers:", N_CORES, "\n")
cat("================================\n\n")

# Configure parallel processing
plan(multisession, workers = N_CORES)

# Create simulation grid -----------------------------------------------------

sim_grid <- create_simulation_grid(
  n_subjects = c(50, 100, 200),
  beta_interaction = c(0, 0.3, 0.5),
  sigma_b = c(0.5, 1.0),
  n_sims = N_SIMS
)

n_scenarios <- length(unique(sim_grid$scenario_id))
n_total <- nrow(sim_grid)

cat("Total simulations:", n_total, "\n")
cat("Unique scenarios:", n_scenarios, "\n")
cat("Methods per simulation: 5\n")
cat("Total model fits:", n_total * 5, "\n\n")

# Define single simulation function ------------------------------------------

run_single_simulation <- function(row) {
  beta <- c(-1, 0, 0.2, row$beta_interaction)

  data <- simulate_longitudinal_binary(
    n_subjects = row$n_subjects,
    n_timepoints = 4,
    beta = beta,
    sigma_b = row$sigma_b,
    seed = row$seed
  )

  results <- fit_all_models(data)

  results$scenario_id <- row$scenario_id
  results$sim_id <- row$sim_id
  results$n_subjects <- row$n_subjects
  results$beta_interaction <- row$beta_interaction
  results$sigma_b <- row$sigma_b
  results$seed <- row$seed

  results
}

# Run simulation with progress -----------------------------------------------

cat("Starting simulation...\n\n")
tic("Full simulation")

handlers(global = TRUE)
handlers("progress")

with_progress({
  p <- progressor(steps = n_total)

  results_list <- future_map(
    seq_len(n_total),
    function(i) {
      p()
      run_single_simulation(sim_grid[i, ])
    },
    .options = furrr_options(seed = TRUE)
  )
})

elapsed <- toc()

# Combine and save results ---------------------------------------------------

results <- do.call(rbind, results_list)

output_dir <- "analysis/data/derived_data"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

output_file <- file.path(output_dir, "simulation_results_raw.rds")
saveRDS(results, output_file)

# Summary statistics ---------------------------------------------------------

cat("\n=== Simulation Complete ===\n")
cat("Total rows:", nrow(results), "\n")
cat("Unique scenarios:", length(unique(results$scenario_id)), "\n")
cat("Methods:", paste(unique(results$method), collapse = ", "), "\n")

convergence_rate <- results |>
  dplyr::group_by(method) |>
  dplyr::summarise(
    converged = mean(converged),
    n = dplyr::n()
  )

cat("\nConvergence rates by method:\n")
print(convergence_rate)

cat("\nResults saved to:", output_file, "\n")
