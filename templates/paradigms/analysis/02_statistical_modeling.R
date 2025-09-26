# Statistical Modeling and Analysis Pipeline
# Project: {{PACKAGE_NAME}}
# Author: {{AUTHOR_NAME}} {{AUTHOR_LAST}}
# Date: {{DATE}}

# This script implements systematic statistical modeling with emphasis on
# reproducible workflows, model validation, assumption checking, and
# comprehensive documentation of analytical decisions.

# Load required packages
library(here)
library(dplyr)
library(ggplot2)
library(broom)
library(tidymodels)
library(readr)

# Set reproducible seed
set.seed(123)

# Create session log
session_log <- list(
  script = "02_statistical_modeling.R",
  start_time = Sys.time(),
  r_version = R.version.string,
  random_seed = 123,
  tidymodels_version = packageVersion("tidymodels")
)

# Set up paths
processed_data_dir <- here("data", "processed")
modeling_dir <- here("analysis", "modeling")
figures_dir <- here("outputs", "figures")
tables_dir <- here("outputs", "tables")

# Create output directories
for (dir in c(figures_dir, tables_dir)) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }
}

message("Starting systematic statistical modeling pipeline...")
message("Random seed: ", 123)
message("tidymodels version: ", packageVersion("tidymodels"))

# =============================================================================
# DATA PREPARATION FOR MODELING
# =============================================================================

message("\n1. DATA PREPARATION FOR MODELING")

# Load cleaned data from exploratory analysis phase
# processed_data <- read_csv(file.path(processed_data_dir, "cleaned_dataset.csv"))

# Document data preparation decisions
# data_prep_log <- list(
#   source_file = "cleaned_dataset.csv",
#   load_time = Sys.time(),
#   n_rows = nrow(processed_data),
#   n_cols = ncol(processed_data),
#   preprocessing_steps = list()
# )

# Example preprocessing workflow (customize for your data)
# modeling_data <- processed_data %>%
#   # Remove observations with missing outcome variable
#   filter(!is.na(outcome_variable)) %>%
#   # Handle categorical variables
#   mutate(across(where(is.character), as.factor)) %>%
#   # Create derived features if needed
#   mutate(
#     # Example feature engineering
#     # log_variable = log(numeric_variable + 1),
#     # interaction_term = variable1 * variable2
#   )

# data_prep_log$preprocessing_steps <- c(
#   "Removed missing outcome observations",
#   "Converted character variables to factors",
#   "Created log-transformed variables",
#   "Generated interaction terms"
# )
# data_prep_log$final_n_rows <- nrow(modeling_data)

# =============================================================================
# DATA SPLITTING FOR VALIDATION
# =============================================================================

message("\n2. DATA SPLITTING FOR VALIDATION")

# Systematic data splitting using tidymodels
# data_split <- initial_split(modeling_data, prop = 0.8, strata = outcome_variable)
# train_data <- training(data_split)
# test_data <- testing(data_split)

# Create cross-validation folds for model tuning
# cv_folds <- vfold_cv(train_data, v = 5, strata = outcome_variable)

# Document splitting decisions
# split_log <- list(
#   split_proportion = 0.8,
#   stratification_variable = "outcome_variable",
#   train_n = nrow(train_data),
#   test_n = nrow(test_data),
#   cv_folds = 5,
#   split_method = "stratified"
# )

# message("Training data: ", split_log$train_n, " observations")
# message("Testing data: ", split_log$test_n, " observations")
# message("Cross-validation folds: ", split_log$cv_folds)

# =============================================================================
# MODEL SPECIFICATION AND RECIPES
# =============================================================================

message("\n3. MODEL SPECIFICATION AND RECIPES")

# Define preprocessing recipe
# model_recipe <- recipe(outcome_variable ~ ., data = train_data) %>%
#   # Handle missing values
#   step_impute_median(all_numeric_predictors()) %>%
#   step_impute_mode(all_nominal_predictors()) %>%
#   # Normalize numeric predictors
#   step_normalize(all_numeric_predictors()) %>%
#   # Create dummy variables
#   step_dummy(all_nominal_predictors()) %>%
#   # Remove zero variance predictors
#   step_zv(all_predictors())

# Define multiple model specifications for comparison
# linear_spec <- linear_reg() %>%
#   set_engine("lm") %>%
#   set_mode("regression")
#
# rf_spec <- rand_forest(
#   trees = tune(),
#   min_n = tune(),
#   mtry = tune()
# ) %>%
#   set_engine("ranger", importance = "impurity") %>%
#   set_mode("regression")
#
# xgb_spec <- boost_tree(
#   trees = tune(),
#   learn_rate = tune(),
#   tree_depth = tune(),
#   min_n = tune()
# ) %>%
#   set_engine("xgboost") %>%
#   set_mode("regression")

# Create workflows
# linear_wf <- workflow() %>%
#   add_recipe(model_recipe) %>%
#   add_model(linear_spec)
#
# rf_wf <- workflow() %>%
#   add_recipe(model_recipe) %>%
#   add_model(rf_spec)
#
# xgb_wf <- workflow() %>%
#   add_recipe(model_recipe) %>%
#   add_model(xgb_spec)

# =============================================================================
# MODEL TRAINING AND HYPERPARAMETER TUNING
# =============================================================================

message("\n4. MODEL TRAINING AND HYPERPARAMETER TUNING")

# Train linear model (no tuning needed)
# linear_fit <- fit(linear_wf, data = train_data)

# Hyperparameter tuning for random forest
# rf_grid <- grid_regular(
#   trees(range = c(100, 1000)),
#   min_n(range = c(2, 20)),
#   mtry(range = c(1, ncol(train_data) - 1)),
#   levels = 3
# )
#
# rf_tuned <- tune_grid(
#   rf_wf,
#   resamples = cv_folds,
#   grid = rf_grid,
#   metrics = metric_set(rmse, rsq, mae),
#   control = control_grid(save_pred = TRUE, verbose = TRUE)
# )

# Hyperparameter tuning for XGBoost
# xgb_grid <- grid_regular(
#   trees(range = c(100, 1000)),
#   learn_rate(range = c(0.01, 0.3)),
#   tree_depth(range = c(3, 10)),
#   min_n(range = c(2, 20)),
#   levels = 3
# )
#
# xgb_tuned <- tune_grid(
#   xgb_wf,
#   resamples = cv_folds,
#   grid = xgb_grid,
#   metrics = metric_set(rmse, rsq, mae),
#   control = control_grid(save_pred = TRUE, verbose = TRUE)
# )

# Select best hyperparameters
# rf_best <- select_best(rf_tuned, metric = "rmse")
# xgb_best <- select_best(xgb_tuned, metric = "rmse")

# Finalize workflows with best parameters
# rf_final_wf <- finalize_workflow(rf_wf, rf_best)
# xgb_final_wf <- finalize_workflow(xgb_wf, xgb_best)

# =============================================================================
# MODEL EVALUATION AND COMPARISON
# =============================================================================

message("\n5. MODEL EVALUATION AND COMPARISON")

# Fit final models on full training data
# linear_final <- fit(linear_wf, data = train_data)
# rf_final <- fit(rf_final_wf, data = train_data)
# xgb_final <- fit(xgb_final_wf, data = train_data)

# Evaluate on test set
# models <- list(
#   "Linear Regression" = linear_final,
#   "Random Forest" = rf_final,
#   "XGBoost" = xgb_final
# )

# test_results <- map_dfr(models, function(model) {
#   predictions <- predict(model, new_data = test_data) %>%
#     bind_cols(test_data %>% select(outcome_variable))
#
#   metrics <- predictions %>%
#     metrics(truth = outcome_variable, estimate = .pred)
#
#   return(metrics)
# }, .id = "model")

# Create model comparison table
# model_comparison <- test_results %>%
#   select(model, .metric, .estimate) %>%
#   pivot_wider(names_from = .metric, values_from = .estimate) %>%
#   arrange(rmse)

# write_csv(model_comparison, file.path(tables_dir, "model_comparison.csv"))

# Model comparison visualization
# comparison_plot <- test_results %>%
#   filter(.metric == "rmse") %>%
#   ggplot(aes(x = reorder(model, -.estimate), y = .estimate)) +
#   geom_col(fill = "steelblue", alpha = 0.7) +
#   labs(
#     title = "Model Performance Comparison",
#     subtitle = "Root Mean Square Error (RMSE) on Test Set",
#     x = "Model",
#     y = "RMSE"
#   ) +
#   theme_minimal() +
#   theme(axis.text.x = element_text(angle = 45, hjust = 1))
#
# ggsave(
#   filename = file.path(figures_dir, "model_comparison.png"),
#   plot = comparison_plot,
#   width = 10,
#   height = 6,
#   dpi = 300
# )

# =============================================================================
# MODEL DIAGNOSTICS AND ASSUMPTION CHECKING
# =============================================================================

message("\n6. MODEL DIAGNOSTICS AND ASSUMPTION CHECKING")

# Best model selection (example: random forest)
# best_model <- rf_final

# Generate predictions for diagnostic plots
# train_pred <- predict(best_model, new_data = train_data) %>%
#   bind_cols(train_data %>% select(outcome_variable))
#
# test_pred <- predict(best_model, new_data = test_data) %>%
#   bind_cols(test_data %>% select(outcome_variable))

# Residual analysis
# residual_plot <- test_pred %>%
#   mutate(residuals = outcome_variable - .pred) %>%
#   ggplot(aes(x = .pred, y = residuals)) +
#   geom_point(alpha = 0.6) +
#   geom_hline(yintercept = 0, color = "red", linetype = "dashed") +
#   geom_smooth(method = "loess", se = TRUE) +
#   labs(
#     title = "Residual Plot",
#     subtitle = "Model diagnostic for homoscedasticity",
#     x = "Predicted Values",
#     y = "Residuals"
#   ) +
#   theme_minimal()
#
# ggsave(
#   filename = file.path(figures_dir, "residual_plot.png"),
#   plot = residual_plot,
#   width = 10,
#   height = 6,
#   dpi = 300
# )

# Predicted vs Actual plot
# pred_actual_plot <- test_pred %>%
#   ggplot(aes(x = outcome_variable, y = .pred)) +
#   geom_point(alpha = 0.6) +
#   geom_abline(intercept = 0, slope = 1, color = "red", linetype = "dashed") +
#   labs(
#     title = "Predicted vs Actual Values",
#     subtitle = "Perfect predictions would fall on the diagonal line",
#     x = "Actual Values",
#     y = "Predicted Values"
#   ) +
#   theme_minimal()
#
# ggsave(
#   filename = file.path(figures_dir, "predicted_vs_actual.png"),
#   plot = pred_actual_plot,
#   width = 8,
#   height = 8,
#   dpi = 300
# )

# =============================================================================
# FEATURE IMPORTANCE ANALYSIS
# =============================================================================

message("\n7. FEATURE IMPORTANCE ANALYSIS")

# Variable importance (for tree-based models)
# if ("ranger" %in% class(extract_fit_engine(best_model))) {
#   importance_data <- extract_fit_engine(best_model)$variable.importance %>%
#     tibble::enframe(name = "variable", value = "importance") %>%
#     arrange(desc(importance)) %>%
#     slice_head(n = 15)
#
#   importance_plot <- importance_data %>%
#     ggplot(aes(x = reorder(variable, importance), y = importance)) +
#     geom_col(fill = "steelblue", alpha = 0.7) +
#     coord_flip() +
#     labs(
#       title = "Feature Importance",
#       subtitle = "Top 15 most important variables",
#       x = "Variables",
#       y = "Importance Score"
#     ) +
#     theme_minimal()
#
#   ggsave(
#     filename = file.path(figures_dir, "feature_importance.png"),
#     plot = importance_plot,
#     width = 10,
#     height = 8,
#     dpi = 300
#   )
#
#   write_csv(importance_data, file.path(tables_dir, "feature_importance.csv"))
# }

# =============================================================================
# SESSION DOCUMENTATION AND MODEL PERSISTENCE
# =============================================================================

# Save final model for future use
# write_rds(best_model, file.path(modeling_dir, "final_model.rds"))

# Complete session log
session_log$end_time <- Sys.time()
session_log$duration <- difftime(session_log$end_time, session_log$start_time, units = "mins")
session_log$session_info <- sessionInfo()
# session_log$model_performance <- model_comparison
# session_log$best_model <- "Random Forest"  # Update based on results

# Save comprehensive modeling log
write_rds(session_log, file.path(modeling_dir, "modeling_session_log.rds"))

message("\nStatistical modeling pipeline completed successfully.")
message("Duration: ", round(as.numeric(session_log$duration), 2), " minutes")
message("Final model saved to: analysis/modeling/final_model.rds")
message("Session log saved to: analysis/modeling/modeling_session_log.rds")

# Display session info for reproducibility
message("\n=== SESSION INFORMATION FOR REPRODUCIBILITY ===")
print(sessionInfo())