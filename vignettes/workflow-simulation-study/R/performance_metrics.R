#' Calculate performance metrics for simulation results
#'
#' Computes bias, empirical SE, average model SE, coverage, and power
#' from a vector of estimates and standard errors across simulation
#' replicates.
#'
#' @param estimates Vector of point estimates across simulations
#' @param ses Vector of standard errors across simulations
#' @param true_value True parameter value used in data generation
#' @param alpha Significance level for coverage and power (default 0.05)
#'
#' @return Named vector with performance metrics:
#'
#' - n_valid: Number of non-missing estimates
#' - bias: Mean estimate minus true value
#' - relative_bias: Bias as percentage of true value (NA if true_value = 0)
#' - empirical_se: Standard deviation of estimates
#' - average_model_se: Mean of model-based standard errors
#' - se_ratio: Ratio of average model SE to empirical SE
#' - mse: Mean squared error
#' - coverage: Proportion of CIs containing true value
#' - power: Proportion of tests rejecting null (type I error if true_value = 0)
#'
#' @export
#'
#' @examples
#' set.seed(42)
#' estimates <- rnorm(1000, mean = 0.5, sd = 0.1)
#' ses <- rep(0.1, 1000)
#' calculate_performance(estimates, ses, true_value = 0.5)
calculate_performance <- function(estimates, ses, true_value, alpha = 0.05) {
  if (length(estimates) != length(ses)) {
    stop("estimates and ses must have the same length")
  }

  if (alpha <= 0 || alpha >= 1) {
    stop("alpha must be between 0 and 1")
  }

  valid <- !is.na(estimates) & !is.na(ses)
  estimates <- estimates[valid]
  ses <- ses[valid]

  if (length(estimates) < 10) {
    return(c(
      n_valid = length(estimates),
      bias = NA_real_,
      relative_bias = NA_real_,
      empirical_se = NA_real_,
      average_model_se = NA_real_,
      se_ratio = NA_real_,
      mse = NA_real_,
      coverage = NA_real_,
      power = NA_real_
    ))
  }

  z_crit <- qnorm(1 - alpha / 2)

  bias <- mean(estimates) - true_value

  if (true_value != 0) {
    relative_bias <- bias / true_value * 100
  } else {
    relative_bias <- NA_real_
  }

  empirical_se <- sd(estimates)

  average_model_se <- mean(ses)

  se_ratio <- average_model_se / empirical_se

  mse <- mean((estimates - true_value)^2)

  lower <- estimates - z_crit * ses
  upper <- estimates + z_crit * ses
  coverage <- mean(lower <= true_value & upper >= true_value)

  if (true_value == 0) {
    power <- mean(abs(estimates / ses) > z_crit)
  } else {
    power <- mean((estimates / ses) > z_crit |
                    (estimates / ses) < -z_crit)
  }

  c(
    n_valid = length(estimates),
    bias = bias,
    relative_bias = relative_bias,
    empirical_se = empirical_se,
    average_model_se = average_model_se,
    se_ratio = se_ratio,
    mse = mse,
    coverage = coverage,
    power = power
  )
}


#' Summarize simulation results by scenario and method
#'
#' Aggregates raw simulation results into performance metrics for each
#' combination of scenario parameters and analytic method.
#'
#' @param results Data frame of simulation results with columns:
#'   scenario_id, method, estimate, se
#' @param true_values Data frame mapping scenario_id to true parameter values
#'   with columns: scenario_id, beta_interaction (and optionally n_subjects,
#'   sigma_b)
#'
#' @return Data frame with performance metrics per scenario and method
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # After running simulation
#' results <- readRDS("simulation_results.rds")
#' true_values <- data.frame(
#'   scenario_id = 1:6,
#'   beta_interaction = rep(c(0, 0.3), each = 3),
#'   n_subjects = rep(c(50, 100, 200), 2),
#'   sigma_b = 0.5
#' )
#' performance <- summarize_simulation(results, true_values)
#' }
summarize_simulation <- function(results, true_values) {
  required_results <- c("scenario_id", "method", "estimate", "se")
  if (!all(required_results %in% names(results))) {
    stop("results must contain columns: ",
         paste(required_results, collapse = ", "))
  }

  required_true <- c("scenario_id", "beta_interaction")
  if (!all(required_true %in% names(true_values))) {
    stop("true_values must contain columns: ",
         paste(required_true, collapse = ", "))
  }

  results <- merge(results, true_values, by = "scenario_id")

  param_cols <- intersect(
    c("scenario_id", "n_subjects", "beta_interaction", "sigma_b"),
    names(results)
  )
  scenarios <- unique(results[, param_cols, drop = FALSE])

  methods <- unique(results$method)

  output <- do.call(rbind, lapply(seq_len(nrow(scenarios)), function(i) {
    scenario <- scenarios[i, ]

    do.call(rbind, lapply(methods, function(m) {
      subset_data <- results[results$scenario_id == scenario$scenario_id &
                               results$method == m, ]

      perf <- calculate_performance(
        estimates = subset_data$estimate,
        ses = subset_data$se,
        true_value = scenario$beta_interaction
      )

      row_data <- data.frame(
        method = m,
        t(perf),
        stringsAsFactors = FALSE
      )

      cbind(scenario, row_data)
    }))
  }))

  rownames(output) <- NULL
  output
}


#' Calculate Monte Carlo standard error
#'
#' Computes the Monte Carlo standard error for a performance metric,
#' which quantifies uncertainty due to finite simulation size.
#'
#' @param metric_value Value of the performance metric
#' @param n_sims Number of simulation replicates
#' @param metric_type Type of metric: "proportion" (coverage, power),
#'   "mean" (bias), or "variance" (empirical_se)
#'
#' @return Monte Carlo standard error
#'
#' @export
#'
#' @examples
#' # MCSE for coverage of 0.95 with 1000 simulations
#' mcse_proportion(0.95, 1000)
#'
#' # MCSE for bias of 0.02 with empirical SE 0.10 and 1000 simulations
#' mcse_mean(0.10, 1000)
mcse_proportion <- function(p, n_sims) {
  sqrt(p * (1 - p) / n_sims)
}

mcse_mean <- function(empirical_se, n_sims) {
  empirical_se / sqrt(n_sims)
}

mcse_variance <- function(empirical_se, n_sims) {
  empirical_se * sqrt(2 / (n_sims - 1))
}


#' Format performance table for publication
#'
#' Creates a formatted table of performance metrics suitable for
#' manuscript inclusion.
#'
#' @param performance Data frame from summarize_simulation
#' @param metrics Character vector of metrics to include
#' @param digits Number of decimal places
#'
#' @return Formatted data frame
#'
#' @export
format_performance_table <- function(performance,
                                     metrics = c("bias", "coverage", "power"),
                                     digits = 3) {
  keep_cols <- c("n_subjects", "beta_interaction", "sigma_b", "method", metrics)
  keep_cols <- intersect(keep_cols, names(performance))

  result <- performance[, keep_cols, drop = FALSE]

  for (col in metrics) {
    if (col %in% names(result)) {
      result[[col]] <- round(result[[col]], digits)
    }
  }

  result
}
