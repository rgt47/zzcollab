# Data Development Workflow Guide

## Overview

This guide outlines the complete workflow for data receipt, preparation, validation, and testing in a zzcollab project. Follow this process to ensure reproducible, well-tested data pipelines that meet research standards.

## 🎯 Workflow Phases

1. **Data Receipt & Initial Setup**
2. **Data Exploration & Validation**  
3. **Data Preparation Development**
4. **Unit Testing & Validation**
5. **Integration Testing & Documentation**
6. **Final Validation & Deployment**

---

## Phase 1: Data Receipt & Initial Setup

> **💻 HOST SYSTEM OPERATIONS** - All Phase 1 tasks are performed on your host system, outside of Docker containers.

### 📥 Data Receipt Checklist

- [ ] **Create project structure (HOST)**
  ```bash
  # If new project - run on host system
  zzcollab -p your-project-name
  cd your-project-name
  ```

- [ ] **Receive and document data source (HOST)**
  - [ ] Obtain data files from collaborator/source
  - [ ] Document data origin, collection method, date received
  - [ ] Note any known issues or preprocessing by source
  - [ ] Save email/communication about data context

- [ ] **Place raw data in proper location (HOST)**
  ```bash
  # Copy data to raw_data directory - NEVER modify these files
  # This creates persistent storage on host filesystem
  cp /path/to/received/data.csv data/raw_data/
  ```

- [ ] **Update data README with source information (HOST)**
  ```bash
  # Edit on host system using your preferred editor
  vim data/README.md    # or nano, code, etc.
  ```
  - [ ] Edit `data/README.md` with actual data source details
  - [ ] Document expected vs. actual column names and types
  - [ ] Note file size, number of records received
  - [ ] Document any known data quality issues from source

- [ ] **Enter Docker container for data analysis**
  ```bash
  # NOW enter container - data files are automatically mounted and available
  make docker-zsh     # or make docker-rstudio for RStudio interface
  ```

- [ ] **Initial data inspection (CONTAINER)**
  ```r
  # Inside container - quick look at data structure
  raw_data <- read.csv("data/raw_data/your_data.csv")
  head(raw_data)
  str(raw_data)
  summary(raw_data)
  
  # Exit container when done with initial inspection
  # Type 'exit' to return to host system
  ```

### 📋 Initial Assessment Questions

- [ ] Does data match expectations from collaborator description?
- [ ] Are column names and types as expected?
- [ ] Are there obvious data quality issues (negative values, extreme outliers)?
- [ ] Is the data complete or are there systematic missing patterns?

---

## Phase 2: Data Exploration & Validation

> **🐳 CONTAINER OPERATIONS** - All Phase 2+ tasks are performed inside Docker containers with your R environment.

### 🔍 Data Quality Assessment Checklist

- [ ] **Enter container if not already inside**
  ```bash
  # On host system
  make docker-zsh     # or make docker-rstudio
  ```

- [ ] **Run basic data validation (CONTAINER)**
  ```r
  # Inside container
  library(here)
  source(here("R", "data_prep.R"))
  
  # Load raw data
  raw_data <- read.csv(here("data", "raw_data", "your_data.csv"))
  
  # Run validation
  is_valid <- validate_penguin_data(raw_data)  # Adapt function for your data
  if (!is_valid) {
    cat("Validation errors:\n")
    cat(paste(attr(raw_data, "validation_errors"), collapse = "\n"))
  }
  ```

- [ ] **Generate data quality report**
  ```r
  # Check missing data patterns
  missing_summary <- sapply(raw_data, function(x) sum(is.na(x)))
  print(missing_summary)
  
  # Check for duplicates
  duplicate_count <- nrow(raw_data) - nrow(unique(raw_data))
  cat("Duplicate rows:", duplicate_count, "\n")
  
  # Check value ranges for numeric columns
  numeric_cols <- sapply(raw_data, is.numeric)
  summary(raw_data[numeric_cols])
  ```

- [ ] **Document data quality findings (HOST/CONTAINER)**
  ```bash
  # Exit container to edit documentation on host
  exit
  
  # Edit on host system
  vim data/README.md    # Add quality assessment results
  
  # Re-enter container to continue analysis
  make docker-zsh
  ```
  - [ ] Update `data/README.md` with quality assessment results
  - [ ] Note any data cleaning needs identified
  - [ ] Document decisions about handling missing values, outliers

- [ ] **Create initial data visualization**
  ```r
  # Basic plots to understand data distribution
  if (require(ggplot2)) {
    # Adapt to your specific data columns
    ggplot(raw_data, aes(x = your_numeric_column)) + 
      geom_histogram(bins = 30) + 
      labs(title = "Distribution of [Column Name]")
  }
  ```

### ❓ Quality Assessment Questions

- [ ] What percentage of data is missing overall?
- [ ] Are missing values random or systematic?
- [ ] Do numeric values fall in expected ranges?
- [ ] Are categorical variables using expected values?
- [ ] Do relationships between variables make sense?

---

## Phase 3: Data Preparation Development

> **🐳 CONTAINER OPERATIONS** - Development work happens inside containers, with documentation updates on host.

### 🛠 Data Processing Development Checklist

- [ ] **Design data processing pipeline**
  - [ ] Define transformation requirements (subset, aggregation, derivation)
  - [ ] Identify which columns need processing
  - [ ] Plan handling of missing values and outliers
  - [ ] Document expected output structure

- [ ] **Develop data preparation functions (CONTAINER)** 
  ```r
  # Inside container - edit R/data_prep.R to add your specific functions
  # Example structure:
  prepare_your_data <- function(data, param1 = default_value) {
    # Input validation
    if (!is.data.frame(data)) {
      stop("Input must be a data frame")
    }
    
    # Required columns check
    required_cols <- c("col1", "col2", "col3")
    missing_cols <- setdiff(required_cols, names(data))
    if (length(missing_cols) > 0) {
      stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
    }
    
    # Data processing steps
    result <- data %>%
      # Your transformations here
      filter(!is.na(important_column)) %>%
      mutate(new_column = log(numeric_column))
    
    return(result)
  }
  ```

- [ ] **Create data processing script (CONTAINER)**
  ```r
  # Inside container - create scripts/01_data_preparation.R
  library(here)
  library(dplyr)  # or other required packages
  
  source(here("R", "data_prep.R"))
  
  # Load raw data
  raw_data <- read.csv(here("data", "raw_data", "your_data.csv"))
  
  # Apply processing
  processed_data <- prepare_your_data(raw_data, param1 = your_value)
  
  # Save processed data
  write.csv(processed_data, 
           here("data", "derived_data", "processed_data.csv"),
           row.names = FALSE)
  
  # Generate processing summary
  cat("Processing completed:\n")
  cat("Input rows:", nrow(raw_data), "\n")
  cat("Output rows:", nrow(processed_data), "\n")
  cat("Columns added:", setdiff(names(processed_data), names(raw_data)), "\n")
  ```

- [ ] **Test data processing interactively (CONTAINER)**
  - [ ] Run processing on small sample first
  - [ ] Verify transformations produce expected results
  - [ ] Check edge cases (empty data, single row, all missing)

### 🎨 Development Best Practices

- [ ] Write functions that do one thing well
- [ ] Include comprehensive input validation
- [ ] Use meaningful parameter names and defaults  
- [ ] Add informative error messages
- [ ] Document function parameters and return values

---

## Phase 4: Unit Testing & Validation

> **🐳 CONTAINER OPERATIONS** - Test development and execution happens inside containers.

### 🧪 Test Development Checklist

- [ ] **Create unit tests for data functions (CONTAINER)**
  ```r
  # Inside container - edit tests/testthat/test-data_prep.R
  test_that("prepare_your_data works with valid input", {
    # Create test data
    test_data <- data.frame(
      col1 = c("A", "B", "C"),
      col2 = c(1, 2, 3),
      col3 = c(10, 20, 30)
    )
    
    # Test function
    result <- prepare_your_data(test_data)
    
    # Assertions
    expect_s3_class(result, "data.frame")
    expect_equal(nrow(result), 3)
    expect_true("new_column" %in% names(result))
  })
  ```

- [ ] **Test input validation**
  ```r
  test_that("prepare_your_data validates inputs correctly", {
    # Test invalid input types
    expect_error(
      prepare_your_data("not a dataframe"),
      "Input must be a data frame"
    )
    
    # Test missing required columns
    incomplete_data <- data.frame(col1 = "A")
    expect_error(
      prepare_your_data(incomplete_data),
      "Missing required columns"
    )
  })
  ```

- [ ] **Test edge cases**
  ```r
  test_that("prepare_your_data handles edge cases", {
    # Empty data
    empty_data <- data.frame(col1 = character(0), col2 = numeric(0), col3 = numeric(0))
    result <- prepare_your_data(empty_data)
    expect_equal(nrow(result), 0)
    
    # Single row
    single_row <- data.frame(col1 = "A", col2 = 1, col3 = 10)
    result <- prepare_your_data(single_row)
    expect_equal(nrow(result), 1)
    
    # Missing values
    data_with_na <- data.frame(col1 = c("A", NA), col2 = c(1, 2), col3 = c(10, NA))
    result <- prepare_your_data(data_with_na)
    # Add appropriate expectations based on your missing value handling
  })
  ```

- [ ] **Create data file validation tests**
  ```r
  # Edit tests/testthat/test-data_files.R
  test_that("raw data file has expected structure", {
    data_file <- here("data", "raw_data", "your_data.csv")
    skip_if_not(file.exists(data_file), "Raw data file not found")
    
    raw_data <- read.csv(data_file, stringsAsFactors = FALSE)
    
    # Test structure
    expect_s3_class(raw_data, "data.frame")
    expect_gt(nrow(raw_data), 0)
    
    # Test expected columns
    expected_cols <- c("col1", "col2", "col3")
    expect_true(all(expected_cols %in% names(raw_data)))
  })
  ```

- [ ] **Run unit tests (CONTAINER or HOST)**
  ```bash
  # Option 1: Inside container
  make test
  R -e "testthat::test_file('tests/testthat/test-data_prep.R')"
  
  # Option 2: From host system (runs in clean container)
  exit  # Exit current container first
  make docker-test  # Run tests in clean environment
  ```

### ✅ Unit Testing Standards

- [ ] Test happy path (valid inputs, expected outputs)
- [ ] Test input validation (invalid types, missing columns)
- [ ] Test edge cases (empty data, single row, extreme values)
- [ ] Test error handling (meaningful error messages)
- [ ] Achieve >90% code coverage for data functions

---

## Phase 5: Integration Testing & Documentation

> **🐳 CONTAINER + HOST OPERATIONS** - Testing in containers, documentation updates on host.

### 🔄 Integration Testing Checklist

- [ ] **Create full pipeline tests (CONTAINER)**
  ```r
  # Inside container - edit tests/integration/test-data_pipeline.R
  test_that("complete data pipeline runs successfully", {
    # Load raw data
    raw_data_file <- here("data", "raw_data", "your_data.csv")
    skip_if_not(file.exists(raw_data_file), "Raw data not available")
    
    raw_data <- read.csv(raw_data_file, stringsAsFactors = FALSE)
    
    # Run full pipeline
    processed_data <- prepare_your_data(raw_data)
    
    # Test pipeline results
    expect_s3_class(processed_data, "data.frame")
    expect_gt(nrow(processed_data), 0)
    # Add specific expectations for your transformations
  })
  ```

- [ ] **Test file consistency**
  ```r
  test_that("derived data file matches pipeline output", {
    raw_file <- here("data", "raw_data", "your_data.csv")
    derived_file <- here("data", "derived_data", "processed_data.csv")
    
    skip_if_not(file.exists(raw_file) && file.exists(derived_file))
    
    # Load both datasets
    raw_data <- read.csv(raw_file, stringsAsFactors = FALSE)
    derived_data_file <- read.csv(derived_file, stringsAsFactors = FALSE)
    
    # Recreate derived data using pipeline
    derived_data_pipeline <- prepare_your_data(raw_data)
    
    # Compare key characteristics
    expect_equal(nrow(derived_data_file), nrow(derived_data_pipeline))
    expect_equal(sort(names(derived_data_file)), sort(names(derived_data_pipeline)))
  })
  ```

- [ ] **Run integration tests (CONTAINER)**
  ```bash
  # Inside container
  R -e "testthat::test_file('tests/integration/test-data_pipeline.R')"
  ```

- [ ] **Update documentation (HOST)**
  ```bash
  # Exit container to edit documentation
  exit
  
  # Edit comprehensive documentation on host
  vim data/README.md
  
  # Re-enter container if needed for more testing
  make docker-zsh
  ```
  - [ ] Complete `data/README.md` with final processing details
  - [ ] Document all derived variables and their creation
  - [ ] Include data quality assessment results
  - [ ] Add reproduction instructions

### 📊 Integration Requirements

- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Derived data files match pipeline output
- [ ] Documentation is complete and accurate
- [ ] Processing is reproducible

---

## Phase 6: Final Validation & Deployment

### 🚀 Final Validation Checklist

- [ ] **Run complete test suite**
  ```bash
  # Run all tests in clean environment
  make docker-test
  
  # Check test coverage
  R -e "covr::package_coverage()"
  ```

- [ ] **Validate reproducibility**
  ```bash
  # Delete derived data and recreate
  rm data/derived_data/*
  source("scripts/01_data_preparation.R")
  
  # Run tests again to ensure consistency
  make test
  ```

- [ ] **Generate final data quality report**
  ```r
  source(here("R", "data_prep.R"))
  
  # Load final processed data
  final_data <- read.csv(here("data", "derived_data", "processed_data.csv"))
  
  # Generate comprehensive summary
  summary_stats <- summarize_your_data(final_data)  # Use your summary function
  print(summary_stats)
  
  # Save quality report
  write.csv(summary_stats, here("data", "derived_data", "quality_report.csv"))
  ```

- [ ] **Create data processing log**
  ```r
  # Document processing metadata
  processing_log <- data.frame(
    step = c("data_received", "quality_check", "processing", "validation"),
    date = Sys.Date(),
    status = c("complete", "complete", "complete", "complete"),
    notes = c("Data from collaborator X", "See quality_report.csv", "Applied transformations", "All tests pass")
  )
  
  write.csv(processing_log, here("data", "processing_log.csv"), row.names = FALSE)
  ```

- [ ] **Final checklist review**
  - [ ] All tests pass (unit + integration)
  - [ ] Documentation complete
  - [ ] Code follows project style standards  
  - [ ] Data quality acceptable for analysis
  - [ ] Processing is reproducible
  - [ ] Files are properly organized

### 📋 Deployment Standards

- [ ] Test coverage >90%
- [ ] No failing tests
- [ ] Documentation complete
- [ ] Code review completed (if team project)
- [ ] Data quality meets research standards

---

## 🎯 Quick Start Checklist Summary

### For New Data Receipt:
1. [ ] Place raw data in `data/raw_data/`
2. [ ] Run initial inspection (`str()`, `summary()`)
3. [ ] Update `data/README.md` with source info
4. [ ] Run data validation functions
5. [ ] Document quality issues

### For Data Processing:
1. [ ] Design processing pipeline
2. [ ] Develop functions in `R/data_prep.R` 
3. [ ] Create processing script `scripts/01_data_preparation.R`
4. [ ] Test interactively with sample data
5. [ ] Save processed data to `data/derived_data/`

### For Testing:
1. [ ] Write unit tests in `tests/testthat/test-data_prep.R`
2. [ ] Write data validation tests in `tests/testthat/test-data_files.R`
3. [ ] Write integration tests in `tests/integration/test-data_pipeline.R`
4. [ ] Run all tests: `make test`
5. [ ] Achieve >90% test coverage

### For Final Validation:
1. [ ] All tests pass
2. [ ] Documentation complete in `data/README.md`
3. [ ] Processing reproducible
4. [ ] Data quality acceptable
5. [ ] Code ready for analysis phase

---

## 🛠 Useful Commands

```bash
# Run all tests
make test
make docker-test  # In clean container

# Run specific test files
R -e "testthat::test_file('tests/testthat/test-data_prep.R')"
R -e "testthat::test_file('tests/integration/test-data_pipeline.R')"

# Check test coverage
R -e "covr::package_coverage()"

# Generate documentation
make document

# Run data processing script
Rscript scripts/01_data_preparation.R
```

## 📞 Troubleshooting

**Tests failing?**
- Check that raw data file exists in `data/raw_data/`
- Verify column names match expectations
- Check for missing required packages

**Data validation errors?**
- Review data quality report
- Check for unexpected values or missing data
- Verify data types match expectations

**Pipeline not reproducible?**
- Ensure all random seeds are set
- Check file paths use `here::here()`
- Verify no hard-coded absolute paths

---

*Follow this workflow to ensure robust, tested, and reproducible data processing in your zzcollab projects!*