# 03_analyze_results.R
# Analyze simulation results and generate performance summaries
#
# Input: analysis/data/derived_data/simulation_results_raw.rds
# Output: analysis/data/derived_data/simulation_performance.rds
#         analysis/data/derived_data/simulation_performance.csv

library(tidyverse)

source("R/performance_metrics.R")

# Load results ---------------------------------------------------------------

results_file <- "analysis/data/derived_data/simulation_results_raw.rds"

if (!file.exists(results_file)) {
  stop("Results file not found. Run 02_run_simulation.R first.")
}

results <- readRDS(results_file)

cat("Loaded", nrow(results), "rows from", results_file, "\n\n")

# Create true values mapping -------------------------------------------------

true_values <- results |>
  select(scenario_id, n_subjects, beta_interaction, sigma_b) |>
  distinct()

cat("Scenarios:\n")
print(true_values)
cat("\n")

# Calculate performance metrics ----------------------------------------------

cat("Calculating performance metrics...\n")

performance <- summarize_simulation(results, true_values)

# Display summary ------------------------------------------------------------

cat("\n=== Performance Summary (beta = 0.3, sigma = 0.5) ===\n\n")

performance |>
  filter(beta_interaction == 0.3, sigma_b == 0.5) |>
  select(n_subjects, method, bias, coverage, power) |>
  arrange(n_subjects, method) |>
  print(n = 50)

# Type I error (null effect) -------------------------------------------------

cat("\n=== Type I Error Rate (beta = 0) ===\n\n")

performance |>
  filter(beta_interaction == 0) |>
  select(n_subjects, sigma_b, method, power) |>
  pivot_wider(names_from = method, values_from = power) |>
  arrange(n_subjects, sigma_b) |>
  print()

# Coverage analysis ----------------------------------------------------------

cat("\n=== Coverage Probability (Non-null Effects) ===\n\n")

performance |>
  filter(beta_interaction != 0) |>
  select(n_subjects, beta_interaction, sigma_b, method, coverage) |>
  pivot_wider(names_from = method, values_from = coverage) |>
  arrange(beta_interaction, n_subjects, sigma_b) |>
  print()

# Power analysis -------------------------------------------------------------

cat("\n=== Power Analysis (80% Threshold) ===\n\n")

performance |>
  filter(beta_interaction != 0) |>
  select(n_subjects, beta_interaction, sigma_b, method, power) |>
  mutate(power = round(power, 3)) |>
  pivot_wider(names_from = method, values_from = power) |>
  arrange(beta_interaction, sigma_b, n_subjects) |>
  print()

# Best method by scenario ----------------------------------------------------

cat("\n=== Best Coverage by Scenario ===\n\n")

best_coverage <- performance |>
  filter(beta_interaction != 0) |>
  group_by(scenario_id) |>
  slice_min(abs(coverage - 0.95), n = 1) |>
  ungroup() |>
  select(n_subjects, beta_interaction, sigma_b, method, coverage, power)

print(best_coverage)

# SE calibration -------------------------------------------------------------

cat("\n=== SE Calibration (Model SE / Empirical SE) ===\n\n")

performance |>
  filter(beta_interaction == 0.3) |>
  select(n_subjects, sigma_b, method, se_ratio) |>
  mutate(se_ratio = round(se_ratio, 3)) |>
  pivot_wider(names_from = method, values_from = se_ratio) |>
  arrange(n_subjects, sigma_b) |>
  print()

# Recommendations ------------------------------------------------------------

cat("\n=== Summary Recommendations ===\n\n")

adequate_power <- performance |>
  filter(beta_interaction == 0.3, power >= 0.80) |>
  group_by(method) |>
  summarise(min_n = min(n_subjects)) |>
  arrange(min_n)

cat("Minimum sample size for 80% power (beta = 0.3):\n")
print(adequate_power)

cat("\nMethods with coverage closest to 95% across scenarios:\n")
avg_coverage_diff <- performance |>
  filter(beta_interaction != 0) |>
  group_by(method) |>
  summarise(
    mean_coverage = mean(coverage),
    mean_abs_diff = mean(abs(coverage - 0.95))
  ) |>
  arrange(mean_abs_diff)

print(avg_coverage_diff)

# Save results ---------------------------------------------------------------

output_dir <- "analysis/data/derived_data"

saveRDS(performance,
        file.path(output_dir, "simulation_performance.rds"))

write_csv(performance,
          file.path(output_dir, "simulation_performance.csv"))

cat("\n=== Output Files ===\n")
cat("- simulation_performance.rds\n")
cat("- simulation_performance.csv\n")
cat("\nAnalysis complete.\n")
