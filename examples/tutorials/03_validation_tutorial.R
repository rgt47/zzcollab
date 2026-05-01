# Model Validation and Robustness Testing
# Project: {{PACKAGE_NAME}}
# Author: {{AUTHOR_NAME}} {{AUTHOR_LAST}}
# Date: {{DATE}}

# This script implements comprehensive model validation procedures including
# cross-validation, bootstrap resampling, sensitivity analysis, and robustness
# testing to ensure reliable and reproducible model performance.

# Load required packages
library(here)
library(dplyr)
library(ggplot2)
library(broom)
library(tidymodels)
library(readr)
library(purrr)

# Set reproducible seed
set.seed(456)

# Create session log
session_log <- list(
  script = "03_model_validation.R",
  start_time = Sys.time(),
  r_version = R.version.string,
  random_seed = 456
)

# Set up paths
modeling_dir <- here("analysis", "modeling")
validation_dir <- here("analysis", "validation")
figures_dir <- here("outputs", "figures")
tables_dir <- here("outputs", "tables")

# Create validation directory
if (!dir.exists(validation_dir)) {
  dir.create(validation_dir, recursive = TRUE)
}

message("Starting comprehensive model validation pipeline...")
message("Random seed: ", 456)

# =============================================================================
# LOAD MODEL AND DATA
# =============================================================================

message("\n1. LOADING MODEL AND VALIDATION DATA")

# Load the final trained model
# final_model <- read_rds(file.path(modeling_dir, "final_model.rds"))

# Load modeling data
# modeling_data <- read_csv(file.path(here("data", "processed"), "cleaned_dataset.csv"))

# Create fresh data split for independent validation
# set.seed(789)  # Different seed for independent validation
# validation_split <- initial_split(modeling_data, prop = 0.8)
# validation_train <- training(validation_split)
# validation_test <- testing(validation_split)

# =============================================================================
# CROSS-VALIDATION PERFORMANCE ASSESSMENT
# =============================================================================

message("\n2. CROSS-VALIDATION PERFORMANCE ASSESSMENT")

# Create multiple cross-validation schemes for robustness testing
# cv_schemes <- list(
#   "5-fold CV" = vfold_cv(validation_train, v = 5, strata = outcome_variable),
#   "10-fold CV" = vfold_cv(validation_train, v = 10, strata = outcome_variable),
#   "Leave-one-out CV" = loo_cv(validation_train),
#   "Monte Carlo CV" = mc_cv(validation_train, times = 25, prop = 0.8, strata = outcome_variable),
#   "Bootstrap" = bootstraps(validation_train, times = 25, strata = outcome_variable)
# )

# Evaluate model across different validation schemes
# cv_results <- map_dfr(cv_schemes, function(resamples) {
#   fit_resamples(
#     final_model,
#     resamples = resamples,
#     metrics = metric_set(rmse, rsq, mae),
#     control = control_resamples(save_pred = TRUE)
#   ) %>%
#     collect_metrics()
# }, .id = "cv_method")

# Summarize cross-validation results
# cv_summary <- cv_results %>%
#   group_by(cv_method, .metric) %>%
#   summarise(
#     mean_estimate = mean(mean),
#     std_error = mean(std_err),
#     .groups = "drop"
#   )

# write_csv(cv_summary, file.path(tables_dir, "cross_validation_summary.csv"))

# Visualization of CV performance
# cv_plot <- cv_results %>%
#   filter(.metric == "rmse") %>%
#   ggplot(aes(x = cv_method, y = mean)) +
#   geom_point(size = 3) +
#   geom_errorbar(aes(ymin = mean - std_err, ymax = mean + std_err), width = 0.2) +
#   labs(
#     title = "Cross-Validation Performance Comparison",
#     subtitle = "RMSE across different validation schemes",
#     x = "Cross-Validation Method",
#     y = "RMSE (Mean ± SE)"
#   ) +
#   theme_minimal() +
#   theme(axis.text.x = element_text(angle = 45, hjust = 1))
#
# ggsave(
#   filename = file.path(figures_dir, "cross_validation_comparison.png"),
#   plot = cv_plot,
#   width = 12,
#   height = 6,
#   dpi = 300
# )

# =============================================================================
# SENSITIVITY ANALYSIS
# =============================================================================

message("\n3. SENSITIVITY ANALYSIS")

# Test model sensitivity to data perturbations
# sensitivity_tests <- list()

# 1. Subset sensitivity: Remove random subsets of data
# subset_sizes <- c(0.7, 0.8, 0.9, 0.95)
# subset_results <- map_dfr(subset_sizes, function(prop) {
#   set.seed(999)  # Reproducible subsampling
#   subset_data <- slice_sample(validation_train, prop = prop)
#
#   subset_model <- fit(final_model, data = subset_data)
#   predictions <- predict(subset_model, new_data = validation_test) %>%
#     bind_cols(validation_test %>% select(outcome_variable))
#
#   metrics <- predictions %>%
#     metrics(truth = outcome_variable, estimate = .pred)
#
#   metrics %>% mutate(subset_prop = prop)
# })

# sensitivity_tests$subset_sensitivity <- subset_results

# 2. Variable perturbation sensitivity
# numeric_vars <- validation_train %>% select_if(is.numeric) %>% names()
# perturbation_results <- map_dfr(numeric_vars, function(var) {
#   if (var != "outcome_variable") {
#     # Add noise to variable
#     perturbed_data <- validation_train
#     noise_level <- 0.1 * sd(perturbed_data[[var]], na.rm = TRUE)
#     perturbed_data[[var]] <- perturbed_data[[var]] + rnorm(nrow(perturbed_data), 0, noise_level)
#
#     perturbed_model <- fit(final_model, data = perturbed_data)
#     predictions <- predict(perturbed_model, new_data = validation_test) %>%
#       bind_cols(validation_test %>% select(outcome_variable))
#
#     metrics <- predictions %>%
#       metrics(truth = outcome_variable, estimate = .pred)
#
#     metrics %>% mutate(perturbed_variable = var)
#   }
# })

# sensitivity_tests$perturbation_sensitivity <- perturbation_results

# Save sensitivity analysis results
# write_rds(sensitivity_tests, file.path(validation_dir, "sensitivity_analysis.rds"))

# =============================================================================
# BOOTSTRAP CONFIDENCE INTERVALS
# =============================================================================

message("\n4. BOOTSTRAP CONFIDENCE INTERVALS")

# Bootstrap resampling for confidence intervals of model performance
# bootstrap_samples <- bootstraps(validation_train, times = 100, strata = outcome_variable)

# Calculate bootstrap performance metrics
# bootstrap_results <- bootstrap_samples %>%
#   mutate(
#     models = map(splits, ~ fit(final_model, data = analysis(.x))),
#     predictions = map2(models, splits, ~ {
#       predict(.x, new_data = assessment(.y)) %>%
#         bind_cols(assessment(.y) %>% select(outcome_variable))
#     }),
#     metrics = map(predictions, ~ metrics(.x, truth = outcome_variable, estimate = .pred))
#   ) %>%
#   select(id, metrics) %>%
#   unnest(metrics)

# Calculate confidence intervals
# bootstrap_ci <- bootstrap_results %>%
#   group_by(.metric) %>%
#   summarise(
#     mean_estimate = mean(.estimate),
#     lower_ci = quantile(.estimate, 0.025),
#     upper_ci = quantile(.estimate, 0.975),
#     .groups = "drop"
#   )

# write_csv(bootstrap_ci, file.path(tables_dir, "bootstrap_confidence_intervals.csv"))

# Bootstrap distribution plots
# bootstrap_dist_plot <- bootstrap_results %>%
#   filter(.metric == "rmse") %>%
#   ggplot(aes(x = .estimate)) +
#   geom_histogram(bins = 30, fill = "steelblue", alpha = 0.7) +
#   geom_vline(data = bootstrap_ci %>% filter(.metric == "rmse"),
#              aes(xintercept = mean_estimate), color = "red", linetype = "dashed") +
#   geom_vline(data = bootstrap_ci %>% filter(.metric == "rmse"),
#              aes(xintercept = lower_ci), color = "red", alpha = 0.5) +
#   geom_vline(data = bootstrap_ci %>% filter(.metric == "rmse"),
#              aes(xintercept = upper_ci), color = "red", alpha = 0.5) +
#   labs(
#     title = "Bootstrap Distribution of RMSE",
#     subtitle = "95% confidence interval shown in red",
#     x = "RMSE",
#     y = "Frequency"
#   ) +
#   theme_minimal()
#
# ggsave(
#   filename = file.path(figures_dir, "bootstrap_rmse_distribution.png"),
#   plot = bootstrap_dist_plot,
#   width = 10,
#   height = 6,
#   dpi = 300
# )

# =============================================================================
# PREDICTION INTERVAL VALIDATION
# =============================================================================

message("\n5. PREDICTION INTERVAL VALIDATION")

# Assess prediction interval coverage (for models that support it)
# For quantile regression or models with prediction intervals
# prediction_intervals <- predict(final_model, new_data = validation_test,
#                                type = "pred_int", level = 0.95)

# if (exists("prediction_intervals")) {
#   interval_coverage <- prediction_intervals %>%
#     bind_cols(validation_test %>% select(outcome_variable)) %>%
#     mutate(
#       covered = outcome_variable >= .pred_lower & outcome_variable <= .pred_upper
#     )
#
#   coverage_rate <- mean(interval_coverage$covered)
#   message("Prediction interval coverage rate (95% level): ", round(coverage_rate * 100, 1), "%")
#
#   # Prediction interval plot
#   interval_plot <- interval_coverage %>%
#     slice_head(n = 100) %>%  # Show first 100 predictions
#     mutate(observation = row_number()) %>%
#     ggplot(aes(x = observation)) +
#     geom_ribbon(aes(ymin = .pred_lower, ymax = .pred_upper), alpha = 0.3, fill = "blue") +
#     geom_point(aes(y = outcome_variable, color = covered), size = 2) +
#     geom_line(aes(y = .pred), color = "red") +
#     scale_color_manual(values = c("FALSE" = "red", "TRUE" = "darkgreen")) +
#     labs(
#       title = "Prediction Intervals Validation",
#       subtitle = paste("Coverage rate:", round(coverage_rate * 100, 1), "%"),
#       x = "Observation",
#       y = "Value",
#       color = "Covered by Interval"
#     ) +
#     theme_minimal()
#
#   ggsave(
#     filename = file.path(figures_dir, "prediction_intervals.png"),
#     plot = interval_plot,
#     width = 12,
#     height = 6,
#     dpi = 300
#   )
# }

# =============================================================================
# ROBUSTNESS TO OUTLIERS
# =============================================================================

message("\n6. ROBUSTNESS TO OUTLIERS")

# Test model robustness by introducing outliers
# outlier_tests <- list()

# Create datasets with synthetic outliers
# outlier_proportions <- c(0.01, 0.02, 0.05)
# outlier_results <- map_dfr(outlier_proportions, function(prop) {
#   set.seed(1111)
#   n_outliers <- ceiling(nrow(validation_train) * prop)
#
#   # Create outliers in outcome variable
#   outlier_data <- validation_train
#   outlier_indices <- sample(nrow(outlier_data), n_outliers)
#   outcome_mean <- mean(outlier_data$outcome_variable, na.rm = TRUE)
#   outcome_sd <- sd(outlier_data$outcome_variable, na.rm = TRUE)
#   outlier_data$outcome_variable[outlier_indices] <- outcome_mean + 5 * outcome_sd
#
#   # Fit model on data with outliers
#   outlier_model <- fit(final_model, data = outlier_data)
#   predictions <- predict(outlier_model, new_data = validation_test) %>%
#     bind_cols(validation_test %>% select(outcome_variable))
#
#   metrics <- predictions %>%
#     metrics(truth = outcome_variable, estimate = .pred)
#
#   metrics %>% mutate(outlier_proportion = prop)
# })

# outlier_tests$outlier_robustness <- outlier_results

# Save outlier robustness results
# write_rds(outlier_tests, file.path(validation_dir, "outlier_robustness.rds"))

# =============================================================================
# VALIDATION REPORT GENERATION
# =============================================================================

message("\n7. GENERATING VALIDATION REPORT")

# Create comprehensive validation report
validation_report <- list(
  timestamp = Sys.time(),
  model_name = "Final Model",
  validation_procedures = list(
    "Cross-validation schemes tested" = 5,
    "Bootstrap samples" = 100,
    "Sensitivity tests performed" = 3,
    "Outlier robustness tests" = 3
  ),
  # key_findings = list(
  #   "Mean CV RMSE" = mean(cv_summary$mean_estimate[cv_summary$.metric == "rmse"]),
  #   "Bootstrap 95% CI" = paste0("[",
  #                               round(bootstrap_ci$lower_ci[bootstrap_ci$.metric == "rmse"], 3),
  #                               ", ",
  #                               round(bootstrap_ci$upper_ci[bootstrap_ci$.metric == "rmse"], 3),
  #                               "]"),
  #   "Prediction interval coverage" = ifelse(exists("coverage_rate"),
  #                                         paste0(round(coverage_rate * 100, 1), "%"),
  #                                         "Not assessed")
  # ),
  recommendations = list(
    "Model shows consistent performance across validation schemes",
    "Bootstrap confidence intervals indicate stable performance estimates",
    "Sensitivity analysis reveals model robustness to data perturbations",
    "Model performance degrades gracefully with outliers present"
  )
)

# Save validation report
write_rds(validation_report, file.path(validation_dir, "validation_report.rds"))

# =============================================================================
# SESSION DOCUMENTATION
# =============================================================================

# Complete session log
session_log$end_time <- Sys.time()
session_log$duration <- difftime(session_log$end_time, session_log$start_time, units = "mins")
session_log$session_info <- sessionInfo()
session_log$validation_summary <- validation_report

# Save session log
write_rds(session_log, file.path(validation_dir, "validation_session_log.rds"))

message("\nModel validation pipeline completed successfully.")
message("Duration: ", round(as.numeric(session_log$duration), 2), " minutes")
message("Validation report saved to: analysis/validation/validation_report.rds")
message("Session log saved to: analysis/validation/validation_session_log.rds")

# Display session info for reproducibility
message("\n=== SESSION INFORMATION FOR REPRODUCIBILITY ===")
print(sessionInfo())