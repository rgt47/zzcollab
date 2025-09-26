# Exploratory Data Analysis Workflow
# Project: {{PACKAGE_NAME}}
# Author: {{AUTHOR_NAME}} {{AUTHOR_LAST}}
# Date: {{DATE}}

# This script performs systematic exploratory data analysis with emphasis on
# reproducibility, documentation, and methodical investigation of data structure,
# quality, and patterns.

# Load required packages
library(here)
library(dplyr)
library(ggplot2)
library(skimr)
library(janitor)
library(readr)

# Set reproducible seed for any random operations
set.seed(42)

# Create session log for reproducibility
session_log <- list(
  script = "01_exploratory_analysis.R",
  start_time = Sys.time(),
  r_version = R.version.string,
  loaded_packages = search(),
  working_directory = getwd(),
  random_seed = 42
)

# Set up data paths
raw_data_dir <- here("data", "raw")
processed_data_dir <- here("data", "processed")
analysis_dir <- here("analysis", "exploratory")
figures_dir <- here("outputs", "figures")

# Create output directories if they don't exist
for (dir in c(processed_data_dir, figures_dir)) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }
}

message("Starting systematic exploratory data analysis...")
message("Working directory: ", getwd())
message("R version: ", R.version.string)

# =============================================================================
# DATA IMPORT AND INITIAL INSPECTION
# =============================================================================

message("\n1. DATA IMPORT AND INITIAL INSPECTION")

# List available raw data files
raw_files <- list.files(raw_data_dir, pattern = "\\.(csv|xlsx|rds)$", full.names = TRUE)
message("Available raw data files: ", length(raw_files))
if (length(raw_files) > 0) {
  message("Files: ", paste(basename(raw_files), collapse = ", "))
}

# Example data loading (customize for your specific data sources)
# Replace this section with your actual data import
#
# Primary dataset
# data_raw <- read_csv(file.path(raw_data_dir, "primary_dataset.csv"))
#
# Log data import
# import_log <- list(
#   file = "primary_dataset.csv",
#   import_time = Sys.time(),
#   file_size = file.size(file.path(raw_data_dir, "primary_dataset.csv")),
#   n_rows = nrow(data_raw),
#   n_cols = ncol(data_raw)
# )

# =============================================================================
# DATA STRUCTURE AND QUALITY ASSESSMENT
# =============================================================================

message("\n2. DATA STRUCTURE AND QUALITY ASSESSMENT")

# Systematic data structure inspection
# dim(data_raw)
# str(data_raw)
# glimpse(data_raw)

# Comprehensive data summary using skimr
# skim_summary <- skim(data_raw)
# print(skim_summary)

# Data quality assessment
# quality_report <- list(
#   total_rows = nrow(data_raw),
#   total_cols = ncol(data_raw),
#   missing_data = sapply(data_raw, function(x) sum(is.na(x))),
#   duplicate_rows = sum(duplicated(data_raw)),
#   unique_values = sapply(data_raw, function(x) length(unique(x))),
#   data_types = sapply(data_raw, class)
# )

# Save quality report for documentation
# write_rds(quality_report, file.path(analysis_dir, "data_quality_report.rds"))
# message("Data quality report saved to: analysis/exploratory/data_quality_report.rds")

# =============================================================================
# UNIVARIATE ANALYSIS
# =============================================================================

message("\n3. UNIVARIATE ANALYSIS")

# Systematic analysis of each variable
# numeric_vars <- select_if(data_raw, is.numeric)
# categorical_vars <- select_if(data_raw, function(x) is.factor(x) | is.character(x))

# Distribution plots for numeric variables
# if (ncol(numeric_vars) > 0) {
#   for (var in names(numeric_vars)) {
#     p <- ggplot(data_raw, aes_string(x = var)) +
#       geom_histogram(bins = 30, alpha = 0.7, fill = "steelblue") +
#       geom_density(aes(y = after_stat(count)), color = "red", linewidth = 1) +
#       labs(
#         title = paste("Distribution of", var),
#         subtitle = paste("n =", sum(!is.na(data_raw[[var]]))),
#         x = var,
#         y = "Frequency"
#       ) +
#       theme_minimal()
#
#     ggsave(
#       filename = file.path(figures_dir, paste0("dist_", var, ".png")),
#       plot = p,
#       width = 8,
#       height = 6,
#       dpi = 300
#     )
#   }
#   message("Distribution plots saved for ", ncol(numeric_vars), " numeric variables")
# }

# Frequency tables for categorical variables
# if (ncol(categorical_vars) > 0) {
#   categorical_summaries <- list()
#   for (var in names(categorical_vars)) {
#     freq_table <- table(data_raw[[var]], useNA = "ifany")
#     prop_table <- prop.table(freq_table)
#
#     categorical_summaries[[var]] <- list(
#       frequencies = freq_table,
#       proportions = prop_table
#     )
#
#     # Bar plot for categorical variables
#     p <- ggplot(data_raw, aes_string(x = var)) +
#       geom_bar(fill = "steelblue", alpha = 0.7) +
#       labs(
#         title = paste("Frequency of", var),
#         x = var,
#         y = "Count"
#       ) +
#       theme_minimal() +
#       theme(axis.text.x = element_text(angle = 45, hjust = 1))
#
#     ggsave(
#       filename = file.path(figures_dir, paste0("freq_", var, ".png")),
#       plot = p,
#       width = 8,
#       height = 6,
#       dpi = 300
#     )
#   }
#
#   write_rds(categorical_summaries, file.path(analysis_dir, "categorical_summaries.rds"))
#   message("Frequency analysis completed for ", ncol(categorical_vars), " categorical variables")
# }

# =============================================================================
# BIVARIATE ANALYSIS
# =============================================================================

message("\n4. BIVARIATE ANALYSIS")

# Correlation analysis for numeric variables
# if (ncol(numeric_vars) > 1) {
#   correlation_matrix <- cor(numeric_vars, use = "complete.obs")
#
#   # Correlation heatmap
#   cor_data <- correlation_matrix %>%
#     as.data.frame() %>%
#     tibble::rownames_to_column("var1") %>%
#     tidyr::pivot_longer(-var1, names_to = "var2", values_to = "correlation")
#
#   p_cor <- ggplot(cor_data, aes(x = var1, y = var2, fill = correlation)) +
#     geom_tile() +
#     scale_fill_gradient2(low = "red", mid = "white", high = "blue", midpoint = 0) +
#     labs(
#       title = "Correlation Matrix",
#       subtitle = "Pearson correlation coefficients"
#     ) +
#     theme_minimal() +
#     theme(axis.text.x = element_text(angle = 45, hjust = 1))
#
#   ggsave(
#     filename = file.path(figures_dir, "correlation_matrix.png"),
#     plot = p_cor,
#     width = 10,
#     height = 8,
#     dpi = 300
#   )
#
#   write_csv(cor_data, file.path(analysis_dir, "correlation_matrix.csv"))
#   message("Correlation analysis completed and saved")
# }

# =============================================================================
# DATA CLEANING RECOMMENDATIONS
# =============================================================================

message("\n5. GENERATING DATA CLEANING RECOMMENDATIONS")

# Document systematic observations and cleaning recommendations
# cleaning_recommendations <- list(
#   timestamp = Sys.time(),
#   missing_data_issues = "Document specific missing data patterns identified",
#   outliers_identified = "Document outlier detection results",
#   data_type_corrections = "Document any data type inconsistencies",
#   duplicate_handling = "Document duplicate row handling decisions",
#   variable_transformations = "Document recommended transformations",
#   quality_flags = "Document data quality concerns"
# )

# write_rds(cleaning_recommendations, file.path(analysis_dir, "cleaning_recommendations.rds"))

# =============================================================================
# SESSION DOCUMENTATION
# =============================================================================

# Complete session log
session_log$end_time <- Sys.time()
session_log$duration <- difftime(session_log$end_time, session_log$start_time, units = "mins")
session_log$session_info <- sessionInfo()
session_log$files_created <- list.files(figures_dir, pattern = "\\.png$")

# Save session log for complete reproducibility
write_rds(session_log, file.path(analysis_dir, "eda_session_log.rds"))

message("\nExploratory Data Analysis completed successfully.")
message("Duration: ", round(as.numeric(session_log$duration), 2), " minutes")
message("Figures created: ", length(session_log$files_created))
message("Session log saved to: analysis/exploratory/eda_session_log.rds")

# Display session info for reproducibility
message("\n=== SESSION INFORMATION FOR REPRODUCIBILITY ===")
print(sessionInfo())