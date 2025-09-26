# Statistical Analysis Pipeline
# Research Compendium: {{PACKAGE_NAME}}
# Author: {{AUTHOR_NAME}} {{AUTHOR_LAST}}
# Date: {{DATE}}

# This script performs the main statistical analyses for the research project.
# All analysis functions are implemented as documented R package functions
# with comprehensive unit tests for computational reproducibility.

# Load required packages
library({{PACKAGE_NAME}})
library(here)
library(dplyr)
library(broom)
library(readr)

# Load package functions
devtools::load_all()

# Set up data and results paths
derived_data_dir <- here("data", "derived_data")
results_dir <- here("analysis", "results")

# Create results directory if it doesn't exist
if (!dir.exists(results_dir)) {
  dir.create(results_dir, recursive = TRUE)
}

message("Starting statistical analysis pipeline...")

# Load processed data
# processed_data <- read_csv(file.path(derived_data_dir, "processed_dataset.csv"))

# Perform statistical analyses using package functions
# Example analysis framework (customize for your research questions)

# 1. Descriptive statistics
message("Generating descriptive statistics...")
# descriptive_stats <- compute_descriptive_statistics(processed_data)
# write_csv(descriptive_stats, file.path(results_dir, "descriptive_statistics.csv"))

# 2. Primary statistical models
message("Fitting primary statistical models...")
# primary_model <- fit_primary_model(processed_data)
# model_summary <- tidy(primary_model)
# write_csv(model_summary, file.path(results_dir, "primary_model_results.csv"))

# 3. Secondary analyses
message("Performing secondary analyses...")
# secondary_results <- perform_secondary_analyses(processed_data)
# write_csv(secondary_results, file.path(results_dir, "secondary_analysis_results.csv"))

# 4. Sensitivity analyses
message("Running sensitivity analyses...")
# sensitivity_results <- run_sensitivity_analyses(processed_data)
# write_csv(sensitivity_results, file.path(results_dir, "sensitivity_analysis_results.csv"))

# 5. Model diagnostics
message("Generating model diagnostics...")
# diagnostic_results <- generate_model_diagnostics(primary_model)
# saveRDS(diagnostic_results, file.path(results_dir, "model_diagnostics.rds"))

message("Statistical analysis pipeline completed successfully.")

# Create analysis log
analysis_log <- list(
  script = "02_statistical_analysis.R",
  timestamp = Sys.time(),
  r_version = R.version.string,
  package_version = packageVersion("{{PACKAGE_NAME}}"),
  session_info = sessionInfo(),
  data_files_used = list.files(derived_data_dir),
  results_generated = list.files(results_dir)
)

# Save analysis log
saveRDS(analysis_log, file.path(results_dir, "statistical_analysis_log.rds"))

message("Analysis log saved to: analysis/results/statistical_analysis_log.rds")