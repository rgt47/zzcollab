# Generate Manuscript Figures and Tables
# Research Compendium: {{PACKAGE_NAME}}
# Author: {{AUTHOR_NAME}} {{AUTHOR_LAST}}
# Date: {{DATE}}

# This script generates all figures and tables for the manuscript using
# standardized, documented functions from the R package component.

# Load required packages
library({{PACKAGE_NAME}})
library(here)
library(ggplot2)
library(dplyr)
library(readr)
library(knitr)

# Load package functions
devtools::load_all()

# Set up paths
results_dir <- here("analysis", "results")
figures_dir <- here("submission", "figures")
tables_dir <- here("submission", "tables")

# Create output directories
for (dir in c(figures_dir, tables_dir)) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }
}

message("Generating manuscript figures and tables...")

# Load analysis results
# analysis_results <- read_csv(file.path(results_dir, "primary_model_results.csv"))
# descriptive_stats <- read_csv(file.path(results_dir, "descriptive_statistics.csv"))

# Generate publication-ready figures
message("Creating figures...")

# Figure 1: Study overview/descriptive plots
# fig1 <- create_descriptive_figure(descriptive_stats)
# ggsave(file.path(figures_dir, "figure_01_descriptive.png"),
#        fig1, width = 10, height = 8, dpi = 300)
# ggsave(file.path(figures_dir, "figure_01_descriptive.pdf"),
#        fig1, width = 10, height = 8, device = "pdf")

# Figure 2: Main results visualization
# fig2 <- create_results_figure(analysis_results)
# ggsave(file.path(figures_dir, "figure_02_main_results.png"),
#        fig2, width = 12, height = 10, dpi = 300)
# ggsave(file.path(figures_dir, "figure_02_main_results.pdf"),
#        fig2, width = 12, height = 10, device = "pdf")

# Figure 3: Model diagnostics (supplementary)
# model_diagnostics <- readRDS(file.path(results_dir, "model_diagnostics.rds"))
# fig3 <- create_diagnostics_figure(model_diagnostics)
# ggsave(file.path(figures_dir, "figure_03_diagnostics.png"),
#        fig3, width = 12, height = 8, dpi = 300)
# ggsave(file.path(figures_dir, "figure_03_diagnostics.pdf"),
#        fig3, width = 12, height = 8, device = "pdf")

# Generate publication-ready tables
message("Creating tables...")

# Table 1: Sample characteristics
# table1 <- create_sample_characteristics_table(descriptive_stats)
# write_csv(table1, file.path(tables_dir, "table_01_sample_characteristics.csv"))
# kable(table1, format = "html") %>%
#   writeLines(file.path(tables_dir, "table_01_sample_characteristics.html"))

# Table 2: Main statistical results
# table2 <- create_main_results_table(analysis_results)
# write_csv(table2, file.path(tables_dir, "table_02_main_results.csv"))
# kable(table2, format = "html") %>%
#   writeLines(file.path(tables_dir, "table_02_main_results.html"))

# Table 3: Sensitivity analysis results (supplementary)
# sensitivity_results <- read_csv(file.path(results_dir, "sensitivity_analysis_results.csv"))
# table3 <- create_sensitivity_results_table(sensitivity_results)
# write_csv(table3, file.path(tables_dir, "table_03_sensitivity_analysis.csv"))
# kable(table3, format = "html") %>%
#   writeLines(file.path(tables_dir, "table_03_sensitivity_analysis.html"))

message("All figures and tables generated successfully.")

# Create figure/table generation log
figure_table_log <- list(
  script = "03_figures_tables.R",
  timestamp = Sys.time(),
  r_version = R.version.string,
  package_version = packageVersion("{{PACKAGE_NAME}}"),
  figures_generated = list.files(figures_dir, pattern = "\\.(png|pdf)$"),
  tables_generated = list.files(tables_dir, pattern = "\\.(csv|html)$"),
  figure_specs = list(
    dpi = 300,
    formats = c("PNG", "PDF"),
    color_space = "sRGB"
  )
)

# Save generation log
saveRDS(figure_table_log, file.path(here("analysis"), "figure_table_generation_log.rds"))

message("Figure and table generation log saved.")