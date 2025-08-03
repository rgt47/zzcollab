#!/bin/bash
##############################################################################
# ZZCOLLAB ANALYSIS MODULE
##############################################################################
# 
# PURPOSE: Research analysis framework and academic report templates
#          - Research report template (R Markdown)
#          - Bibliography and citation management
#          - Analysis templates and examples
#          - Academic workflow support
#
# DEPENDENCIES: core.sh (logging), templates.sh (file creation)
#
# TRACKING: All created analysis files are tracked for uninstall capability
##############################################################################

# Validate required modules are loaded
require_module "core" "templates"

#=============================================================================
# ANALYSIS FILES CREATION (extracted from lines 525-536)
#=============================================================================

# Function: create_analysis_files
# Purpose: Creates research report templates and analysis framework
# Creates:
#   - analysis/report/report.Rmd (main research report template)
#   - analysis/report/references.bib (bibliography file)
#   - Citation style files for academic publishing
#
# Template Features:
#   - Complete R Markdown paper structure
#   - Author and institution placeholders
#   - Bibliography integration with references.bib
#   - Standard academic sections (Introduction, Methods, Results, Discussion)
#   - Knitr chunk options for reproducible figures
#   - Package loading and setup configurations
#
# Academic Standards:
#   - Follows academic report conventions
#   - Supports multiple citation styles
#   - Integrated with R package workflow
#   - Reproducible research practices
#
# Tracking: All created files are tracked in manifest for uninstall
create_analysis_files() {
    log_info "Creating analysis and paper files..."
    
    # Create research report template from R Markdown template
    # Template includes: YAML header, author info, bibliography setup, standard sections
    if ! install_template "report.Rmd" "analysis/report/report.Rmd" "Research report template" "Created research report template with academic structure"; then
        log_error "Failed to create research report template"
        return 1
    fi
    
    # Create bibliography file for citations and references
    # BibTeX format for academic reference management
    if ! install_template "references.bib" "analysis/report/references.bib" "references.bib file" "Created bibliography file for citation management"; then
        log_error "Failed to create bibliography file"
        return 1
    fi
    
    # Create citation style file for academic journals
    # CSL (Citation Style Language) file for formatting citations
    if ! install_template "statistics-in-medicine.csl" "analysis/report/statistics-in-medicine.csl" "citation style file" "Created citation style file for academic formatting"; then
        log_warn "Citation style file not found - citations will use default format"
    fi
    
    log_success "Analysis files created successfully"
}

#=============================================================================
# ANALYSIS FRAMEWORK UTILITIES
#=============================================================================

# Function: validate_analysis_structure
# Purpose: Verify that all required analysis files were created successfully
# Checks: report.Rmd, references.bib, analysis directories
# Returns: 0 if all files exist, 1 if any are missing
validate_analysis_structure() {
    log_info "Validating analysis structure..."
    
    local -r required_files=(
        "analysis/report/report.Rmd"
        "analysis/report/references.bib"
    )
    
    local -r required_dirs=(
        "analysis/report"
        "analysis/figures"
        "analysis/tables"
        "analysis/templates"
    )
    
    local missing_items=()
    
    # Check required files
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_items+=("file: $file")
        fi
    done
    
    # Check required directories
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            missing_items+=("directory: $dir")
        fi
    done
    
    if [[ ${#missing_items[@]} -eq 0 ]]; then
        log_success "All required analysis files and directories exist"
        return 0
    else
        log_error "Missing analysis items: ${missing_items[*]}"
        return 1
    fi
}

# Function: show_analysis_summary
# Purpose: Display analysis framework summary and usage instructions
show_analysis_summary() {
    log_info "Analysis framework summary:"
    cat << 'EOF'
📝 ANALYSIS FRAMEWORK CREATED:

├── analysis/
│   ├── report/
│   │   ├── report.Rmd            # Main research report template
│   │   ├── references.bib       # Bibliography for citations
│   │   └── *.csl               # Citation style files (optional)
│   ├── figures/                # Generated plots and visualizations
│   ├── tables/                 # Generated statistical tables
│   └── templates/              # Analysis templates and snippets

📊 RESEARCH WORKFLOW:
1. Edit analysis/report/report.Rmd for your research report
2. Add references to analysis/report/references.bib
3. Generate figures and save to analysis/figures/
4. Create tables and save to analysis/tables/
5. Use knitr to render report.Rmd to PDF

📚 KEY FEATURES:
- R Markdown integration with package functions
- Automatic bibliography generation
- Reproducible figure and table creation
- Standard academic report structure
- Citation management with BibTeX

🔧 RENDERING COMMANDS:
- rmarkdown::render("analysis/report/report.Rmd")     # Render to PDF
- make docker-render                                 # Render in container
- knitr::knit("analysis/report/report.Rmd")           # Process R chunks

📝 EDITING WORKFLOW:
1. Write analysis code in R chunks within report.Rmd
2. Reference package functions with PKG_NAME::function_name
3. Include figures with knitr chunk options
4. Cite references with [@citation_key] syntax
5. Use cross-references for figures and tables

🎯 ACADEMIC STANDARDS:
- Follows reproducible research practices
- Integrates with R package development
- Supports multiple citation styles
- Version controlled with git
- Container-ready for collaboration
EOF
}

# Function: create_analysis_examples
# Purpose: Create example analysis scripts and templates
# Optional: Provides examples for common analysis patterns
create_analysis_examples() {
    log_info "Creating analysis examples and templates..."
    
    # Create example data analysis script
    local example_analysis='# Example Data Analysis Script
# This script demonstrates common analysis patterns

# Load required packages
library(here)
library(dplyr)
library(ggplot2)
library(knitr)

# Load package functions
# Replace PKG_NAME with your actual package name
# library(PKG_NAME)

# Example: Load and explore data
# data <- read.csv(here("data", "raw_data", "your_data.csv"))
# summary(data)

# Example: Create a figure
# p <- ggplot(data, aes(x = variable1, y = variable2)) +
#   geom_point() +
#   theme_minimal() +
#   labs(title = "Example Plot",
#        x = "Variable 1",
#        y = "Variable 2")
# 
# ggsave(here("analysis", "figures", "example_plot.png"), p)

# Example: Create a table
# result_table <- data %>%
#   group_by(group_variable) %>%
#   summarise(
#     mean_value = mean(numeric_variable, na.rm = TRUE),
#     sd_value = sd(numeric_variable, na.rm = TRUE),
#     n = n()
#   )
# 
# write.csv(result_table, 
#           here("analysis", "tables", "summary_table.csv"),
#           row.names = FALSE)

cat("Analysis example template created\\n")
cat("Edit this file to implement your specific analysis\\n")'
    
    if create_file_if_missing "analysis/templates/example_analysis.R" "$example_analysis" "example analysis script"; then
        track_file "analysis/templates/example_analysis.R"
        log_info "Created example analysis script"
    else
        log_warn "Failed to create example analysis script"
    fi
    
    # Create figure template script
    local figure_template='# Figure Creation Template
# Template for creating publication-ready figures

library(ggplot2)
library(here)

# Function to create publication-ready theme
pub_theme <- function() {
  theme_minimal() +
  theme(
    text = element_text(size = 12),
    plot.title = element_text(size = 14, face = "bold"),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 10),
    legend.title = element_text(size = 12),
    legend.text = element_text(size = 10),
    panel.grid.minor = element_blank()
  )
}

# Example figure creation function
create_example_figure <- function(data) {
  p <- ggplot(data, aes(x = x_var, y = y_var)) +
    geom_point(alpha = 0.7) +
    geom_smooth(method = "lm", se = TRUE) +
    pub_theme() +
    labs(
      title = "Example Figure Title",
      subtitle = "Descriptive subtitle",
      x = "X Variable Label",
      y = "Y Variable Label",
      caption = "Source: Your data source"
    )
  
  return(p)
}

# Save figure with consistent settings
save_figure <- function(plot, filename, width = 8, height = 6, dpi = 300) {
  ggsave(
    filename = here("analysis", "figures", filename),
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    device = "png"
  )
}

cat("Figure template functions loaded\\n")
cat("Use create_example_figure() and save_figure() in your analysis\\n")'
    
    if create_file_if_missing "analysis/templates/figure_template.R" "$figure_template" "figure creation template"; then
        track_file "analysis/templates/figure_template.R"
        log_info "Created figure creation template"
    else
        log_warn "Failed to create figure template"
    fi
    
    log_success "Analysis examples and templates created"
}

# Function: create_scripts_directory
# Purpose: Create essential research scripts in the scripts/ directory
# Creates data validation, parallel computing, database setup, and reproducibility scripts
create_scripts_directory() {
    log_info "Creating essential research scripts..."
    
    # Ensure scripts directory exists
    safe_mkdir "scripts" "research scripts directory"
    
    # 1. Data validation script
    local data_validation_script='# Data Validation Script
# This script performs comprehensive data quality checks

# Load required packages
library(here)
library(dplyr)
library(visdat)
library(naniar)
library(skimr)
library(janitor)
library(palmerpenguins)

# Source utility functions
source(here("R", "utils.R"))

# Load data - use Palmer penguins dataset as example
# Replace with your actual data loading logic
if (file.exists(here("data", "raw_data", "dataset1.csv"))) {
  raw_data <- readr::read_csv(here("data", "raw_data", "dataset1.csv"))
  cat("Loaded custom dataset from data/raw_data/dataset1.csv\\n")
} else {
  # Use Palmer penguins as example dataset
  data(penguins, package = "palmerpenguins")
  raw_data <- penguins
  cat("Using Palmer penguins dataset for validation example\\n")
}

# 1. BASIC DATA STRUCTURE CHECKS ====
cat("=== BASIC DATA STRUCTURE ===\\n")
cat("Dimensions:", dim(raw_data), "\\n")
cat("Variable names:\\n")
print(names(raw_data))

# 2. MISSING DATA ANALYSIS ====
cat("\\n=== MISSING DATA ANALYSIS ===\\n")
# Overall missingness
miss_var_summary(raw_data)

# Missing data patterns
vis_miss(raw_data)

# Missing data heatmap
gg_miss_upset(raw_data)

# 3. DATA TYPE VALIDATION ====
cat("\\n=== DATA TYPE VALIDATION ===\\n")
# Check data types
glimpse(raw_data)

# 4. OUTLIER DETECTION ====
cat("\\n=== OUTLIER DETECTION ===\\n")
# Statistical summary
skim(raw_data)

# 5. CONSISTENCY CHECKS ====
cat("\\n=== CONSISTENCY CHECKS ===\\n")
# Check for duplicate rows
n_duplicates <- nrow(raw_data) - nrow(distinct(raw_data))
cat("Duplicate rows:", n_duplicates, "\\n")

# 6. RANGE VALIDATION ====
cat("\\n=== RANGE VALIDATION ===\\n")
# Penguin-specific range checks
if ("bill_length_mm" %in% names(raw_data)) {
  bill_length_issues <- raw_data$bill_length_mm < 25 | raw_data$bill_length_mm > 70
  cat("Bill length values outside 25-70mm range:", sum(bill_length_issues, na.rm = TRUE), "\\n")
}

if ("body_mass_g" %in% names(raw_data)) {
  mass_issues <- raw_data$body_mass_g < 2000 | raw_data$body_mass_g > 7000
  cat("Body mass values outside 2000-7000g range:", sum(mass_issues, na.rm = TRUE), "\\n")
}

# Species validation
if ("species" %in% names(raw_data)) {
  expected_species <- c("Adelie", "Chinstrap", "Gentoo")
  unexpected_species <- !raw_data$species %in% expected_species
  cat("Unexpected species values:", sum(unexpected_species, na.rm = TRUE), "\\n")
  if (any(unexpected_species, na.rm = TRUE)) {
    cat("Found species:", unique(raw_data$species[unexpected_species]), "\\n")
  }
}

cat("\\n=== DATA VALIDATION COMPLETE ===\\n")
cat("Review the output above for any data quality issues\\n")'
    
    if create_file_if_missing "scripts/02_data_validation.R" "$data_validation_script" "data validation script"; then
        track_file "scripts/02_data_validation.R"
        log_info "Created data validation script"
    else
        log_warn "Failed to create data validation script"
    fi
    
    # 2. Parallel computing setup script
    local parallel_setup_script='# High-Performance Computing Setup
# Configure parallel processing for computationally intensive tasks

# Load required packages
library(parallel)
library(doParallel)
library(foreach)
library(future)
library(furrr)

# Detect available cores
n_cores <- parallel::detectCores()
cat("Detected", n_cores, "CPU cores\\n")

# Set up parallel backend (choose one)

# 1. Using doParallel (for foreach loops)
cl <- makeCluster(max(1, n_cores - 1))  # Leave one core free
registerDoParallel(cl)

# 2. Using future (for purrr-style functions)
plan(multisession, workers = max(1, n_cores - 1))

# Configuration for different computing environments

# Local development (conservative)
if (Sys.getenv("COMPUTING_ENV") == "local" || Sys.getenv("COMPUTING_ENV") == "") {
  n_workers <- min(4, max(1, n_cores - 1))
  options(mc.cores = n_workers)
  cat("Local environment: Using", n_workers, "cores\\n")
}

# High-performance cluster
if (Sys.getenv("COMPUTING_ENV") == "cluster") {
  # Read from SLURM environment variables or config
  n_workers <- as.numeric(Sys.getenv("SLURM_CPUS_PER_TASK", n_cores))
  options(mc.cores = n_workers)
  cat("Cluster environment: Using", n_workers, "cores\\n")
}

# Cloud computing (AWS, GCP, Azure)
if (Sys.getenv("COMPUTING_ENV") == "cloud") {
  # Configure based on instance type
  n_workers <- n_cores  # Use all available cores in cloud
  options(mc.cores = n_workers)
  cat("Cloud environment: Using", n_workers, "cores\\n")
}

# Memory management for large datasets
if (Sys.getenv("LARGE_DATA") == "true") {
  # Increase memory limits
  if (.Platform$OS.type == "unix") {
    system("ulimit -v unlimited", ignore.stderr = TRUE)
  }
  
  # Configure garbage collection
  options(expressions = 500000)  # Increase expression limit
  
  # Use memory-efficient data structures
  options(datatable.fwrite.sep = ",")
  options(datatable.optimize = 2)
  
  cat("Large data mode: Optimized for memory efficiency\\n")
}

# Progress reporting setup
options(future.progress = TRUE)

# Cleanup function
cleanup_parallel <- function() {
  if (exists("cl")) {
    stopCluster(cl)
  }
  plan(sequential)  # Reset future plan
}

# Register cleanup on exit
on.exit(cleanup_parallel(), add = TRUE)

cat("Parallel computing setup complete\\n")'
    
    if create_file_if_missing "scripts/00_setup_parallel.R" "$parallel_setup_script" "parallel computing setup script"; then
        track_file "scripts/00_setup_parallel.R"
        log_info "Created parallel computing setup script"
    else
        log_warn "Failed to create parallel computing setup script"
    fi
    
    # 3. Database setup script
    local database_setup_script='# Database Connection Setup
# Template for connecting to various database systems

# Load database packages
suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(RPostgres)  # For PostgreSQL
  library(RMySQL)     # For MySQL
  library(odbc)       # For ODBC connections
  library(here)
})

# 1. SQLite Database (local file-based) ====
setup_sqlite <- function(db_path = here("analysis", "data", "project.db")) {
  con <- dbConnect(RSQLite::SQLite(), db_path)
  cat("Connected to SQLite database at:", db_path, "\\n")
  return(con)
}

# 2. PostgreSQL Database ====
setup_postgresql <- function() {
  con <- dbConnect(RPostgres::Postgres(),
    dbname = Sys.getenv("POSTGRES_DB", "research_db"),
    host = Sys.getenv("POSTGRES_HOST", "localhost"),
    port = as.numeric(Sys.getenv("POSTGRES_PORT", "5432")),
    user = Sys.getenv("POSTGRES_USER"),
    password = Sys.getenv("POSTGRES_PASSWORD")
  )
  cat("Connected to PostgreSQL database\\n")
  return(con)
}

# 3. MySQL Database ====
setup_mysql <- function() {
  con <- dbConnect(RMySQL::MySQL(),
    dbname = Sys.getenv("MYSQL_DB", "research_db"),
    host = Sys.getenv("MYSQL_HOST", "localhost"),
    port = as.numeric(Sys.getenv("MYSQL_PORT", "3306")),
    user = Sys.getenv("MYSQL_USER"),
    password = Sys.getenv("MYSQL_PASSWORD")
  )
  cat("Connected to MySQL database\\n")
  return(con)
}

# 4. ODBC Connection (for various databases) ====
setup_odbc <- function(dsn_name) {
  con <- dbConnect(odbc::odbc(), dsn = dsn_name)
  cat("Connected via ODBC to:", dsn_name, "\\n")
  return(con)
}

# Example usage:
# con <- setup_sqlite()  # For local SQLite database
# con <- setup_postgresql()  # For PostgreSQL (requires environment variables)
# dbDisconnect(con)  # Always disconnect when done

cat("Database connection functions loaded\\n")
cat("Set environment variables for database credentials\\n")
cat("Use setup_sqlite(), setup_postgresql(), setup_mysql(), or setup_odbc()\\n")'
    
    if create_file_if_missing "scripts/00_database_setup.R" "$database_setup_script" "database setup script"; then
        track_file "scripts/00_database_setup.R"
        log_info "Created database setup script"
    else
        log_warn "Failed to create database setup script"
    fi
    
    # 4. Reproducibility check script
    local reproducibility_script='# Reproducibility Check Script
# Run this script to verify that the analysis can be fully reproduced

# Load required packages
library(here)
library(sessioninfo)
library(renv)
library(digest)

# 1. Environment Check ====
cat("=== REPRODUCIBILITY CHECK ===\\n")
cat("Date:", as.character(Sys.Date()), "\\n")
cat("Time:", as.character(Sys.time()), "\\n\\n")

# Check R version
cat("R Version:", R.version.string, "\\n")

# Check package versions
cat("\\n=== PACKAGE ENVIRONMENT ===\\n")
if (file.exists("renv.lock")) {
  cat("renv.lock found - checking package versions\\n")
  renv::status()
} else {
  cat("WARNING: No renv.lock found - package versions not locked\\n")
}

# 2. File Integrity Check ====
cat("\\n=== FILE INTEGRITY CHECK ===\\n")

# Check for required files
required_files <- c(
  "DESCRIPTION",
  "analysis/report/report.Rmd",
  "R/utils.R",
  "scripts"
)

missing_files <- c()
for (file in required_files) {
  if (file.exists(here(file))) {
    cat("✓", file, "exists\\n")
  } else {
    cat("✗", file, "MISSING\\n")
    missing_files <- c(missing_files, file)
  }
}

if (length(missing_files) > 0) {
  cat("\\nERROR: Missing required files:\\n")
  cat(paste("-", missing_files, collapse = "\\n"), "\\n")
  stop("Cannot proceed with missing files")
}

# 3. Data Integrity Check ====
cat("\\n=== DATA INTEGRITY CHECK ===\\n")

# Check for data files
data_dir <- here("data", "raw_data")
if (dir.exists(data_dir)) {
  data_files <- list.files(data_dir, recursive = TRUE)
  cat("Found", length(data_files), "data files\\n")
  
  # Calculate checksums for data files
  if (length(data_files) > 0) {
    cat("\\nData file checksums:\\n")
    for (file in data_files) {
      if (file.size(file.path(data_dir, file)) > 0) {
        checksum <- digest::digest(file.path(data_dir, file), file = TRUE)
        cat("-", file, ":", checksum, "\\n")
      }
    }
  }
} else {
  cat("No raw data directory found\\n")
}

# 4. Script Execution Check ====
cat("\\n=== SCRIPT EXECUTION CHECK ===\\n")

# Test that key scripts can be sourced without error
test_scripts <- list.files(here("scripts"), pattern = "\\\\.R$", full.names = TRUE)

if (length(test_scripts) > 0) {
  for (script in test_scripts) {
    script_name <- basename(script)
    cat("Testing", script_name, "... ")
    
    tryCatch({
      # Test syntax without executing
      parse(script)
      cat("✓ Syntax OK\\n")
    }, error = function(e) {
      cat("✗ Syntax Error:", e$message, "\\n")
    })
  }
} else {
  cat("No R scripts found in scripts directory\\n")
}

# 5. Session Information ====
cat("\\n=== SESSION INFORMATION ===\\n")
session_info()

cat("\\n=== REPRODUCIBILITY CHECK COMPLETE ===\\n")'
    
    if create_file_if_missing "scripts/99_reproducibility_check.R" "$reproducibility_script" "reproducibility check script"; then
        track_file "scripts/99_reproducibility_check.R"
        log_info "Created reproducibility check script"
    else
        log_warn "Failed to create reproducibility check script"
    fi
    
    # 5. Testing guide script
    local testing_guide_script='# Testing Guide for Research Projects
# This script provides examples and templates for adding tests to your research repository

cat("=== RESEARCH PROJECT TESTING GUIDE ===\\n")
cat("This guide covers testing at multiple levels:\\n")
cat("1. Unit tests for R package functions\\n")
cat("2. Integration tests for analysis scripts\\n") 
cat("3. Data validation tests\\n")
cat("4. Reproducibility tests\\n\\n")

# Load required packages for testing
library(testthat)
library(here)

# 1. UNIT TESTS FOR PACKAGE FUNCTIONS ====
cat("=== 1. UNIT TESTS FOR PACKAGE FUNCTIONS ===\\n")
cat("Location: tests/testthat/\\n")
cat("Framework: testthat package\\n\\n")

cat("Example test file structure:\\n")
cat("tests/testthat/test-my-function.R:\\n")
cat("\\n")
cat("test_that(\\"my_function works correctly\\", {\\n")
cat("  # Test basic functionality\\n")
cat("  result <- my_function(input_data)\\n")
cat("  expect_equal(nrow(result), expected_rows)\\n")
cat("  expect_true(all(result$column > 0))\\n")
cat("})\\n\\n")

cat("test_that(\\"my_function handles edge cases\\", {\\n")
cat("  # Test with empty input\\n")
cat("  expect_error(my_function(data.frame()))\\n")
cat("  \\n")
cat("  # Test with NA values\\n")
cat("  data_with_na <- data.frame(x = c(1, NA, 3))\\n")
cat("  result <- my_function(data_with_na)\\n")
cat("  expect_false(any(is.na(result)))\\n")
cat("})\\n\\n")

cat("To run package tests:\\n")
cat("- devtools::test()     # Run all tests\\n")
cat("- testthat::test_file(\\"tests/testthat/test-my-function.R\\")  # Run specific test\\n")
cat("- make test           # Using Makefile\\n\\n")

# 2. INTEGRATION TESTS FOR ANALYSIS SCRIPTS ====
cat("=== 2. INTEGRATION TESTS FOR ANALYSIS SCRIPTS ===\\n")
cat("Location: tests/integration/\\n")
cat("Purpose: Test that analysis scripts run without errors\\n\\n")

# Create integration test directory and example
dir.create(here("tests", "integration"), recursive = TRUE, showWarnings = FALSE)

integration_test_example <- "# Integration Test Example
# tests/integration/test-analysis-pipeline.R

# Test that main analysis scripts can run without errors
test_that(\\"data validation script runs without errors\\", {
  expect_no_error({
    source(here(\\"scripts\\", \\"02_data_validation.R\\"))
  })
})

test_that(\\"parallel setup configures correctly\\", {
  expect_no_error({
    source(here(\\"scripts\\", \\"00_setup_parallel.R\\"))
  })
})

# Test with mock data
test_that(\\"analysis works with test data\\", {
  # Create mock dataset
  test_data <- data.frame(
    id = 1:100,
    treatment = sample(c(\\"A\\", \\"B\\"), 100, replace = TRUE),
    outcome = rnorm(100, mean = 50, sd = 10)
  )
  
  # Save test data
  temp_file <- tempfile(fileext = \\".csv\\")
  write.csv(test_data, temp_file, row.names = FALSE)
  
  # Test analysis functions
  # Add your specific analysis tests here
  expect_true(nrow(test_data) == 100)
  
  # Cleanup
  unlink(temp_file)
})"

cat("\\nExample integration test:\\n")
cat(integration_test_example)
cat("\\n\\n")

# 3. DATA VALIDATION TESTS ====
cat("=== 3. DATA VALIDATION TESTS ===\\n")
cat("Location: tests/data/\\n")
cat("Purpose: Ensure data quality and consistency\\n\\n")

data_test_example <- "# Data Validation Test Example
# tests/data/test-data-quality.R

test_that(\\"raw data meets quality standards\\", {
  # Skip if no data files exist
  data_dir <- here(\\"data\\", \\"raw_data\\")
  skip_if_not(dir.exists(data_dir), \\"No raw data directory found\\")
  
  data_files <- list.files(data_dir, pattern = \\"\\\\.csv$\\", full.names = TRUE)
  skip_if(length(data_files) == 0, \\"No CSV files found in raw data\\")
  
  for (file in data_files) {
    data <- read.csv(file)
    
    # Test basic properties
    expect_true(nrow(data) > 0, info = paste(\\"Empty data file:\\", basename(file)))
    expect_true(ncol(data) > 0, info = paste(\\"No columns in:\\", basename(file)))
    
    # Test for required columns (customize for your data)
    # expect_true(\\"id\\" %in% names(data), info = \\"Missing id column\\")
    
    # Test data types and ranges (customize for your data)
    # if(\\"age\\" %in% names(data)) {
    #   expect_true(all(data$age >= 0 & data$age <= 120, na.rm = TRUE))
    # }
  }
})"

cat("Example data validation test:\\n")
cat(data_test_example)
cat("\\n\\n")

# 4. REPRODUCIBILITY TESTS ====
cat("=== 4. REPRODUCIBILITY TESTS ===\\n")
cat("Location: tests/reproducibility/\\n")
cat("Purpose: Ensure analysis can be reproduced\\n\\n")

repro_test_example <- "# Reproducibility Test Example
# tests/reproducibility/test-reproducibility.R

test_that(\\"analysis environment is reproducible\\", {
  # Test renv lockfile exists
  expect_true(file.exists(\\"renv.lock\\"), \\"renv.lock file missing\\")
  
  # Test package versions are locked
  if (require(\\"renv\\", quietly = TRUE)) {
    status <- renv::status()
    expect_true(length(status) == 0, \\"Package environment not synchronized\\")
  }
})

test_that(\\"analysis scripts have consistent output\\", {
  # Test that scripts produce consistent results
  # This is especially important for analyses with random components
  
  set.seed(12345)  # Set seed for reproducibility
  
  # Run analysis script
  # result1 <- source(here(\\"scripts\\", \\"my_analysis.R\\"))
  
  set.seed(12345)  # Reset seed
  
  # Run again
  # result2 <- source(here(\\"scripts\\", \\"my_analysis.R\\"))
  
  # Compare results
  # expect_equal(result1, result2, info = \\"Analysis results not reproducible\\")
})"

cat("Example reproducibility test:\\n")
cat(repro_test_example)
cat("\\n\\n")

# 5. TESTING WORKFLOW ====
cat("=== 5. TESTING WORKFLOW ===\\n")
cat("Recommended testing workflow:\\n\\n")

cat("1. DEVELOPMENT CYCLE:\\n")
cat("   - Write function in R/\\n")
cat("   - Write test in tests/testthat/\\n")
cat("   - Run devtools::test() to verify\\n")
cat("   - Iterate until tests pass\\n\\n")

cat("2. ANALYSIS TESTING:\\n")
cat("   - Create integration tests for scripts\\n")
cat("   - Test with sample/mock data\\n")
cat("   - Validate data quality regularly\\n")
cat("   - Check reproducibility periodically\\n\\n")

cat("3. CI/CD TESTING:\\n")
cat("   - GitHub Actions runs tests automatically\\n")
cat("   - Tests run on multiple R versions\\n")
cat("   - Tests run in clean environment\\n")
cat("   - Failures block merges to main branch\\n\\n")

cat("4. USEFUL TESTING COMMANDS:\\n")
cat("   devtools::test()                    # Run all package tests\\n")
cat("   devtools::check()                   # Full package check\\n")
cat("   testthat::test_dir(\\"tests/data\\")    # Run data tests\\n")
cat("   source(\\"scripts/99_reproducibility_check.R\\")  # Check reproducibility\\n")
cat("   make test                          # Run via Makefile\\n\\n")

cat("5. TEST COVERAGE:\\n")
cat("   # Install covr package for coverage analysis\\n")
cat("   library(covr)\\n")
cat("   coverage <- package_coverage()\\n")
cat("   report(coverage)  # Generate HTML coverage report\\n\\n")

cat("=== TESTING SETUP COMPLETE ===\\n")
cat("Next steps:\\n")
cat("1. Add specific tests for your functions in tests/testthat/\\n")
cat("2. Create integration tests for your analysis scripts\\n")
cat("3. Set up data validation tests for your datasets\\n")
cat("4. Run tests regularly during development\\n")
cat("5. Check test coverage with covr package\\n")'

    if create_file_if_missing "scripts/00_testing_guide.R" "$testing_guide_script" "testing guide script"; then
        track_file "scripts/00_testing_guide.R"
        log_info "Created comprehensive testing guide script"
    else
        log_warn "Failed to create testing guide script"
    fi

    log_success "Essential research scripts created in scripts/ directory"
}

#=============================================================================
# ANALYSIS MODULE VALIDATION
#=============================================================================

# Validate that required directories exist for analysis files
# These should be created by the structure module
if [[ ! -d "analysis/report" ]]; then
    log_warn "analysis/report directory not found - may need to run structure module first"
fi

if [[ ! -d "analysis/figures" ]]; then
    log_warn "analysis/figures directory not found - may need to run structure module first"
fi


