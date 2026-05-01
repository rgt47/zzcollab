# Testing Guide

## Overview

ZZCOLLAB implements a comprehensive testing framework that ensures
research code reliability, reproducibility, and maintainability. This
guide documents testing strategies, implementation patterns, and best
practices for the unified research compendium architecture.

## Testing Philosophy

### Scientific Rationale

Testing in research software addresses three critical concerns:

1. **Research Integrity**: Preventing silent data processing errors
   that compromise scientific conclusions
2. **Reproducibility**: Ensuring consistent behavior across
   environments and time
3. **Collaboration**: Enabling confident code modifications without
   breaking existing functionality

### Testing Coverage Requirements

ZZCOLLAB establishes systematic testing standards:

- **Unit Tests**: >90% code coverage for all R functions
- **Integration Tests**: Complete workflow validation
- **Data Validation**: Input/output quality checks
- **Regression Tests**: Prevention of reintroduced bugs
- **Edge Case Tests**: Boundary condition handling

## Testing Architecture

### Three-Layer Testing Strategy

ZZCOLLAB implements testing at three distinct layers:

**Layer 1: Unit Tests** (`tests/testthat/`)

- Individual function behavior validation
- Isolated component testing
- Fast execution (milliseconds per test)
- No external dependencies
- Comprehensive edge case coverage

**Layer 2: Integration Tests** (`tests/integration/`)

- Complete workflow validation
- Multi-function interaction testing
- File I/O and data pipeline validation
- Moderate execution time (seconds to minutes)
- External dependency management

**Layer 3: System Tests** (GitHub Actions)

- Full environment reproducibility validation
- Cross-platform compatibility testing
- Dependency synchronization verification
- Package build and check processes
- Extended execution time (minutes to hours)

### Testing Framework Components

ZZCOLLAB testing infrastructure consists of:

```
tests/
├── testthat/
│   ├── test-<function>.R       # Unit tests (one per R file)
│   ├── test-helpers.R          # Testing utilities
│   └── helper-functions.R      # Shared test functions
├── integration/
│   ├── test-workflow.R         # End-to-end workflow tests
│   ├── test-data-pipeline.R   # Data processing validation
│   └── test-reproducibility.R # Reproducibility checks
└── data/
    ├── test-data.rds           # Small test datasets
    └── expected-output.rds     # Expected results
```

## Unit Testing

### testthat Framework

ZZCOLLAB uses testthat for unit testing due to:

- Industry standard in R community
- Excellent RStudio integration
- Comprehensive assertion library
- Clear test output formatting
- Integration with R CMD check

### Unit Test Structure

Standard unit test file structure:

```r
# tests/testthat/test-data-functions.R

# Test context
context("Data preparation functions")

# Setup (run once per file)
setup({
  # Create test data
  test_data <- data.frame(
    x = 1:10,
    y = rnorm(10),
    group = rep(c("A", "B"), 5)
  )
})

# Teardown (run once per file)
teardown({
  # Clean up test artifacts
  if (exists("test_data")) rm(test_data)
})

# Individual test
test_that("prepare_data handles missing values correctly", {
  # Arrange: Create test input
  data_with_na <- test_data
  data_with_na$y[3] <- NA

  # Act: Execute function
  result <- prepare_data(data_with_na, remove_na = TRUE)

  # Assert: Verify expectations
  expect_equal(nrow(result), 9)
  expect_false(any(is.na(result$y)))
  expect_s3_class(result, "data.frame")
})

test_that("prepare_data preserves data types", {
  result <- prepare_data(test_data)

  expect_type(result$x, "integer")
  expect_type(result$y, "double")
  expect_type(result$group, "character")
})

test_that("prepare_data handles edge cases", {
  # Empty data frame
  empty_df <- data.frame(x = integer(), y = numeric(),
                         group = character())
  result_empty <- prepare_data(empty_df)
  expect_equal(nrow(result_empty), 0)

  # Single row
  single_row <- test_data[1, ]
  result_single <- prepare_data(single_row)
  expect_equal(nrow(result_single), 1)
})
```

### Essential Test Patterns

**Pattern 1: Input Validation Tests**

```r
test_that("function validates input types", {
  # Numeric input required
  expect_error(
    calculate_statistics("not_numeric"),
    "Input must be numeric"
  )

  # Non-empty input required
  expect_error(
    calculate_statistics(numeric()),
    "Input cannot be empty"
  )

  # Finite values required
  expect_error(
    calculate_statistics(c(1, 2, Inf)),
    "Input must contain finite values"
  )
})
```

**Pattern 2: Output Validation Tests**

```r
test_that("function produces expected output structure", {
  result <- analyze_data(test_data)

  # Check output class
  expect_s3_class(result, "analysis_result")

  # Check output components
  expect_named(result, c("summary", "statistics", "model"))

  # Check output dimensions
  expect_equal(nrow(result$summary), 2)
  expect_length(result$statistics, 5)
})
```

**Pattern 3: Numerical Accuracy Tests**

```r
test_that("function produces numerically accurate results", {
  # Known input with known output
  input <- c(1, 2, 3, 4, 5)
  expected_mean <- 3
  expected_sd <- sqrt(2.5)

  result <- calculate_statistics(input)

  # Use tolerance for floating point comparison
  expect_equal(result$mean, expected_mean, tolerance = 1e-10)
  expect_equal(result$sd, expected_sd, tolerance = 1e-10)
})
```

**Pattern 4: Edge Case Tests**

```r
test_that("function handles edge cases appropriately", {
  # Empty input
  expect_warning(
    process_data(data.frame()),
    "Empty data frame provided"
  )

  # All missing values
  all_na <- data.frame(x = rep(NA_real_, 10))
  expect_error(
    process_data(all_na),
    "No valid observations"
  )

  # Single observation
  single_obs <- data.frame(x = 1)
  result <- process_data(single_obs)
  expect_equal(nrow(result), 1)

  # Extreme values
  extreme <- data.frame(x = c(-1e10, 1e10))
  expect_silent(process_data(extreme))
})
```

**Pattern 5: Reproducibility Tests**

```r
test_that("function produces reproducible results", {
  set.seed(123)
  result1 <- run_simulation(n = 100)

  set.seed(123)
  result2 <- run_simulation(n = 100)

  # Results should be identical
  expect_identical(result1, result2)
})
```

### Test Coverage Analysis

**Measuring Coverage**:

```r
# Install covr package
install.packages("covr")

# Calculate test coverage
library(covr)
coverage <- package_coverage()
print(coverage)

# Generate HTML report
report(coverage)

# Check if coverage meets threshold
percent_coverage(coverage) >= 90
```

**Coverage Requirements by Function Type**:

- Data manipulation functions: 95%+
- Statistical functions: 90%+
- Plotting functions: 80%+
- Utility functions: 85%+

### Test Helpers

Create reusable test utilities in `tests/testthat/helper-functions.R`:

```r
# Helper: Create test data with known properties
create_test_data <- function(n = 100, seed = 42) {
  set.seed(seed)
  data.frame(
    id = 1:n,
    value = rnorm(n, mean = 50, sd = 10),
    group = sample(c("A", "B", "C"), n, replace = TRUE),
    date = seq.Date(from = as.Date("2020-01-01"),
                    by = "day", length.out = n)
  )
}

# Helper: Compare data frames with tolerance
expect_data_frame_equal <- function(actual, expected,
                                    tolerance = 1e-8) {
  expect_equal(dim(actual), dim(expected))
  expect_named(actual, names(expected))

  for (col in names(expected)) {
    if (is.numeric(actual[[col]])) {
      expect_equal(actual[[col]], expected[[col]],
                   tolerance = tolerance,
                   label = paste("Column:", col))
    } else {
      expect_identical(actual[[col]], expected[[col]],
                       label = paste("Column:", col))
    }
  }
}

# Helper: Validate plot objects
expect_valid_ggplot <- function(plot) {
  expect_s3_class(plot, "ggplot")
  expect_true("layers" %in% names(plot))
  expect_gt(length(plot$layers), 0)
}

# Helper: Create temporary test directory
create_temp_test_dir <- function() {
  temp_dir <- tempfile(pattern = "test_")
  dir.create(temp_dir, recursive = TRUE)
  temp_dir
}
```

## Integration Testing

### Integration Test Structure

Integration tests validate complete workflows:

```r
# tests/integration/test-data-pipeline.R

test_that("complete data pipeline executes successfully", {
  # Setup: Create temporary directory
  temp_dir <- create_temp_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))

  # Arrange: Prepare test data files
  raw_data_path <- file.path(temp_dir, "raw_data.csv")
  write.csv(test_data, raw_data_path, row.names = FALSE)

  # Act: Execute complete pipeline
  result <- run_data_pipeline(
    input_path = raw_data_path,
    output_dir = temp_dir
  )

  # Assert: Verify all outputs created
  expect_true(file.exists(
    file.path(temp_dir, "processed_data.csv")
  ))
  expect_true(file.exists(
    file.path(temp_dir, "summary_statistics.txt")
  ))
  expect_true(file.exists(
    file.path(temp_dir, "diagnostic_plots.pdf")
  ))

  # Assert: Verify output content
  processed <- read.csv(
    file.path(temp_dir, "processed_data.csv")
  )
  expect_equal(ncol(processed), 5)  # Original 3 + 2 derived
  expect_gt(nrow(processed), 0)
})
```

### Workflow Validation Tests

```r
# tests/integration/test-analysis-workflow.R

test_that("analysis workflow produces expected results", {
  # Complete analysis from raw data to final output

  # Stage 1: Data preparation
  raw_data <- load_raw_data("data/raw/penguins.csv")
  prepared_data <- prepare_data(raw_data)
  expect_equal(nrow(prepared_data), 333)  # Known after cleaning

  # Stage 2: Exploratory analysis
  eda_results <- exploratory_analysis(prepared_data)
  expect_named(eda_results,
               c("summary_stats", "correlation", "distributions"))

  # Stage 3: Statistical modeling
  model <- fit_model(prepared_data, formula = bill_depth ~ species)
  expect_s3_class(model, "lm")
  expect_gt(summary(model)$r.squared, 0.5)  # Known relationship

  # Stage 4: Validation
  validation <- validate_model(model, prepared_data)
  expect_true(validation$residuals_normal)
  expect_true(validation$homoscedasticity)

  # Stage 5: Visualization
  plots <- create_visualizations(prepared_data, model)
  expect_length(plots, 3)
  expect_valid_ggplot(plots$scatter)
  expect_valid_ggplot(plots$residuals)
  expect_valid_ggplot(plots$predictions)
})
```

### Data Quality Validation

```r
# tests/integration/test-data-quality.R

test_that("data quality checks identify issues", {
  # Test with deliberately flawed data
  flawed_data <- data.frame(
    id = c(1, 2, 2, 4, 5),           # Duplicate ID
    value = c(10, -999, 30, 40, 50), # Missing value code
    date = c("2020-01-01", "2020-01-02", "invalid",
             "2020-01-04", "2020-01-05")  # Invalid date
  )

  quality_report <- check_data_quality(flawed_data)

  # Assert: All issues detected
  expect_true(quality_report$has_duplicates)
  expect_true(quality_report$has_missing_codes)
  expect_true(quality_report$has_invalid_dates)

  # Assert: Specific issue counts
  expect_equal(quality_report$n_duplicates, 1)
  expect_equal(quality_report$n_missing_codes, 1)
  expect_equal(quality_report$n_invalid_dates, 1)
})
```

## Data Testing

### Input Data Validation

```r
# tests/testthat/test-data-validation.R

test_that("data validation catches common issues", {
  # Test 1: Missing required columns
  incomplete_data <- data.frame(x = 1:10)
  expect_error(
    validate_data(incomplete_data,
                  required = c("x", "y", "group")),
    "Missing required columns: y, group"
  )

  # Test 2: Incorrect data types
  wrong_types <- data.frame(
    x = as.character(1:10),  # Should be numeric
    y = rnorm(10),
    group = c("A", "B")
  )
  expect_error(
    validate_data(wrong_types),
    "Column 'x' must be numeric"
  )

  # Test 3: Out-of-range values
  out_of_range <- data.frame(
    age = c(25, 30, -5, 35, 150),  # Invalid ages
    score = c(85, 90, 75, 95, 88)
  )
  validation <- validate_data(out_of_range)
  expect_false(validation$valid)
  expect_match(validation$errors, "age.*out of valid range")
})
```

### Data Transformation Tests

```r
test_that("data transformations preserve properties", {
  original <- create_test_data(n = 100)

  # Log transformation
  transformed <- transform_data(original, method = "log")

  # Properties that should be preserved
  expect_equal(nrow(transformed), nrow(original))
  expect_equal(ncol(transformed), ncol(original))
  expect_named(transformed, names(original))

  # Properties that should change
  expect_false(identical(transformed$value, original$value))

  # Verify transformation correctness
  expect_equal(transformed$value,
               log(original$value),
               tolerance = 1e-10)
})
```

### Data Loading Tests

```r
test_that("data loading handles various file formats", {
  temp_dir <- create_temp_test_dir()
  on.exit(unlink(temp_dir, recursive = TRUE))

  test_data <- create_test_data(n = 50)

  # Test CSV loading
  csv_path <- file.path(temp_dir, "data.csv")
  write.csv(test_data, csv_path, row.names = FALSE)
  loaded_csv <- load_data(csv_path)
  expect_data_frame_equal(loaded_csv, test_data)

  # Test RDS loading
  rds_path <- file.path(temp_dir, "data.rds")
  saveRDS(test_data, rds_path)
  loaded_rds <- load_data(rds_path)
  expect_identical(loaded_rds, test_data)

  # Test invalid file
  expect_error(
    load_data(file.path(temp_dir, "nonexistent.csv")),
    "File not found"
  )
})
```

## Unified Research Compendium Testing

ZZCOLLAB uses a **progressive disclosure** testing approach based on the Marwick et al. (2018) unified research compendium architecture. Tests grow organically with your project.

### Phase 1: Data Analysis Testing (Day 1)

Start simple with analysis script validation:

```r
# tests/integration/test-analysis-workflow.R

test_that("data analysis pipeline executes successfully", {
  # Test data loading
  source("analysis/scripts/01_load_data.R")
  expect_true(exists("raw_data"))
  expect_s3_class(raw_data, "data.frame")

  # Test data processing
  source("analysis/scripts/02_process_data.R")
  expect_true(exists("processed_data"))
  expect_true(nrow(processed_data) > 0)

  # Test analysis
  source("analysis/scripts/03_analyze.R")
  expect_true(exists("analysis_results"))

  # Test figure generation
  source("analysis/scripts/04_create_figures.R")
  expect_true(file.exists("analysis/figures/figure1.png"))
})
```

### Phase 2: Manuscript Integration Testing (Week 2)

Add manuscript rendering validation when ready:

```r
# tests/integration/test-manuscript-rendering.R

test_that("manuscript renders successfully", {
  # Test manuscript compilation
  rmarkdown::render("analysis/report/report.Rmd", quiet = TRUE)
  expect_true(file.exists("analysis/report/paper.pdf"))

  # Test references are resolved
  pdf_text <- pdftools::pdf_text("analysis/report/paper.pdf")
  expect_true(any(grepl("References", pdf_text)))

  # Test figures are embedded
  pdf_info <- pdftools::pdf_info("analysis/report/paper.pdf")
  expect_gt(pdf_info$pages, 1)
})
```

### Phase 3: Function Extraction Testing (Month 1)

When code moves to R/, add comprehensive unit tests:

```r
# tests/testthat/test-data-functions.R

test_that("data cleaning functions work correctly", {
  # Test clean_penguin_data()
  test_data <- data.frame(
    species = c("Adelie", "Gentoo", NA),
    bill_length_mm = c(39.1, 50.5, NA),
    flipper_length_mm = c(181, 230, 195)
  )

  cleaned <- clean_penguin_data(test_data)

  # Verify NA removal
  expect_equal(nrow(cleaned), 2)
  expect_false(any(is.na(cleaned)))

  # Verify column presence
  expect_true("species" %in% names(cleaned))
  expect_true("bill_length_mm" %in% names(cleaned))
})

test_that("statistical functions produce valid output", {
  # Test calculate_correlation()
  x <- c(1, 2, 3, 4, 5)
  y <- c(2, 4, 6, 8, 10)

  result <- calculate_correlation(x, y)

  expect_type(result, "list")
  expect_true("r" %in% names(result))
  expect_true("p_value" %in% names(result))
  expect_equal(result$r, 1.0, tolerance = 0.001)
})
```

### Phase 4: Package Distribution Testing (Month 3)

Prepare for CRAN or internal distribution:

```r
# tests/testthat/test-package-structure.R

test_that("package structure meets R CMD check requirements", {
  # Test DESCRIPTION file completeness
  desc <- read.dcf("DESCRIPTION")
  expect_true("Package" %in% colnames(desc))
  expect_true("Version" %in% colnames(desc))
  expect_true("License" %in% colnames(desc))
  expect_true("Authors@R" %in% colnames(desc))

  # Test all exported functions are documented
  namespace <- getNamespaceExports(desc[1, "Package"])
  man_files <- list.files("man", pattern = "\\.Rd$")
  man_topics <- sub("\\.Rd$", "", man_files)

  expect_true(all(namespace %in% man_topics),
              info = "All exported functions must be documented")
})

test_that("examples run without errors", {
  # Test all .Rd examples execute successfully
  pkg <- read.dcf("DESCRIPTION")[1, "Package"]

  result <- tryCatch({
    tools::testInstalledPackage(pkg, types = "examples")
    TRUE
  }, error = function(e) {
    message("Examples failed: ", e$message)
    FALSE
  })

  expect_true(result)
})
```

### Progressive Disclosure Philosophy

**Key Principle**: Start simple, add complexity as needed.

1. **Data Analysis** (Day 1): Basic script validation
2. **Manuscript** (Week 2): Add rendering tests when writing
3. **Functions** (Month 1): Unit tests when extracting reusable code
4. **Package** (Month 3): CRAN compliance when ready to distribute

**No Upfront Commitment**: Your testing strategy evolves with your project. No need to decide "analysis vs manuscript vs package" paradigm upfront.

## Continuous Integration Testing

### GitHub Actions Configuration

ZZCOLLAB projects include comprehensive CI/CD testing:

```yaml
# .github/workflows/test.yml
name: R Package Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        r-version: ['4.2', '4.3', 'release']

    steps:
      - uses: actions/checkout@v3

      - name: Setup R
        uses: r-lib/actions/setup-r@v2
        with:
          r-version: ${{ matrix.r-version }}

      - name: Install dependencies
        run: |
          install.packages(c("remotes", "rcmdcheck"))
          remotes::install_deps(dependencies = TRUE)
        shell: Rscript {0}

      - name: Check package
        run: rcmdcheck::rcmdcheck(args = "--no-manual",
                                   error_on = "warning")
        shell: Rscript {0}

      - name: Test coverage
        run: covr::codecov()
        shell: Rscript {0}
```

### Docker-Based Testing

Test in reproducible Docker environment:

```yaml
# .github/workflows/docker-test.yml
name: Docker Environment Tests

on: [push, pull_request]

jobs:
  docker-test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Build Docker image
        run: make docker-build

      - name: Run tests in container
        run: make docker-test

      - name: Run integration tests
        run: make docker-integration-test

      - name: Check reproducibility
        run: make docker-check-renv
```

## Test Execution

### Running Tests Locally

**All Tests**:

```bash
# Native R (requires local R installation)
make test

# Docker environment (no local R required)
make docker-test
```

**Specific Test Files**:

```r
# Load testthat
library(testthat)

# Run specific test file
test_file("tests/testthat/test-data-functions.R")

# Run specific test
test_file("tests/testthat/test-data-functions.R",
          filter = "handles missing values")
```

**Interactive Testing**:

```r
# Load package
devtools::load_all()

# Run all tests
devtools::test()

# Run tests with coverage
covr::package_coverage()

# Run specific test interactively
testthat::test_that("my test", {
  # Test code here
})
```

### Test Output Interpretation

**Successful Test Output**:

```
✓ | F W S  OK | Context
✓ |         12 | Data preparation functions
✓ |          8 | Statistical functions
✓ |          6 | Visualization functions

══ Results ═════════════════════════════════════════
Duration: 2.3 s

[ FAIL 0 | WARN 0 | SKIP 0 | PASS 26 ]
```

**Failed Test Output**:

```
✓ | F W S  OK | Context
x |  1      11 | Data preparation functions

── Failure: prepare_data handles missing values ───
`result$y` has 10 rows, not 9.

Backtrace:
    ▆
 1. └─testthat::expect_equal(nrow(result), 9)
```

## Test Maintenance

### Updating Tests for Code Changes

When modifying functions:

1. Update function implementation
2. Run existing tests: `devtools::test()`
3. Update tests to match new behavior
4. Add tests for new functionality
5. Verify coverage: `covr::package_coverage()`

### Handling Flaky Tests

Address non-deterministic test failures:

```r
# Bad: Unreliable due to timing
test_that("function is fast", {
  start <- Sys.time()
  result <- expensive_function()
  duration <- Sys.time() - start
  expect_lt(duration, 1)  # May fail due to system load
})

# Good: Test algorithmic complexity
test_that("function scales linearly", {
  time_small <- system.time(
    expensive_function(n = 100)
  )["elapsed"]

  time_large <- system.time(
    expensive_function(n = 1000)
  )["elapsed"]

  # Allow for some overhead, but should scale linearly
  expect_lt(time_large / time_small, 15)
})

# Good: Use fixed seeds for randomness
test_that("simulation produces expected distribution", {
  set.seed(42)  # Fixed seed for reproducibility
  results <- run_simulation(n = 10000)

  # Statistical tests with tolerance
  expect_equal(mean(results), 0, tolerance = 0.05)
  expect_equal(sd(results), 1, tolerance = 0.05)
})
```

### Deprecation Testing

Test backward compatibility:

```r
test_that("deprecated functions still work with warning", {
  expect_warning(
    result <- old_function(x = 10),
    "old_function is deprecated"
  )

  expect_equal(result, new_function(x = 10))
})
```

## Performance Testing

### Benchmarking

```r
# tests/performance/test-benchmarks.R

test_that("critical functions meet performance requirements", {
  library(bench)

  # Benchmark critical operation
  bm <- mark(
    prepare_data(large_dataset),
    iterations = 10,
    check = FALSE
  )

  # Performance requirements
  expect_lt(median(bm$median), as_bench_time("500ms"))
  expect_lt(median(bm$mem_alloc), as_bench_bytes("100MB"))
})
```

### Memory Testing

```r
test_that("functions do not leak memory", {
  library(pryr)

  initial_mem <- mem_used()

  # Run function many times
  for (i in 1:100) {
    result <- process_data(test_data)
  }

  # Force garbage collection
  gc()

  final_mem <- mem_used()

  # Memory increase should be minimal
  expect_lt(final_mem - initial_mem, 10 * 1024^2)  # 10 MB
})
```

## Best Practices

### General Testing Principles

1. **Test Behavior, Not Implementation**: Focus on what functions
   do, not how they do it
2. **One Assertion Per Test**: Make test failures easy to diagnose
3. **Independent Tests**: Tests should not depend on execution order
4. **Fast Execution**: Keep unit tests under 1 second each
5. **Clear Naming**: Test names should describe the scenario and
   expected outcome

### Test Organization

```r
# Good: Organized by functionality
tests/
├── testthat/
│   ├── test-data-loading.R      # All data loading tests
│   ├── test-data-cleaning.R     # All cleaning tests
│   ├── test-statistical-tests.R # All statistical tests
│   └── test-visualization.R     # All visualization tests

# Bad: Organized by file structure
tests/
├── testthat/
│   ├── test-file1.R  # Mixed functionality
│   ├── test-file2.R  # Mixed functionality
```

### Test Documentation

```r
test_that("prepare_data handles missing values correctly", {
  # Purpose: Verify that missing value removal works as expected
  # Related Issue: #42
  # Edge Case: All values missing should return empty data frame

  data_with_na <- test_data
  data_with_na$y[3] <- NA

  result <- prepare_data(data_with_na, remove_na = TRUE)

  expect_equal(nrow(result), 9)
})
```

## Troubleshooting

### Common Testing Issues

**Issue**: Tests pass locally but fail in CI

**Solution**: Check for environment-specific assumptions:

```r
# Bad: Assumes specific directory structure
test_data <- read.csv("../data/test.csv")

# Good: Use here package
test_data <- read.csv(here::here("data", "test.csv"))

# Better: Use testthat test_path
test_data <- read.csv(
  testthat::test_path("fixtures", "test.csv")
)
```

**Issue**: Floating point comparison failures

**Solution**: Use tolerance in numeric comparisons:

```r
# Bad: May fail due to floating point precision
expect_equal(result, 0.3)

# Good: Use tolerance
expect_equal(result, 0.3, tolerance = 1e-10)
```

**Issue**: Tests timeout or hang

**Solution**: Add explicit timeouts:

```r
test_that("function completes in reasonable time", {
  setTimeLimit(cpu = 5, elapsed = 5, transient = TRUE)
  on.exit(setTimeLimit(cpu = Inf, elapsed = Inf,
                       transient = FALSE))

  result <- potentially_slow_function()

  expect_true(TRUE)  # If we get here, function completed
})
```

## References

### Documentation

- testthat Documentation: https://testthat.r-lib.org/
- R Packages Testing Chapter: https://r-pkgs.org/testing-basics.html
- Advanced R Testing: http://adv-r.had.co.nz/Testing.html

### Related Guides

- ZZCOLLAB User Guide: Comprehensive usage documentation
- Development Guide (DEVELOPMENT.md): Testing and validation commands
- Configuration Guide (CONFIGURATION.md): Testing environment setup
- Data Workflow Guide: Data validation and testing strategies

### Academic References

Testing in scientific computing:

- Wilson et al. (2014). "Best Practices for Scientific Computing."
  PLOS Biology.
- Sandve et al. (2013). "Ten Simple Rules for Reproducible
  Computational Research." PLOS Computational Biology.
- Stodden et al. (2016). "Enhancing reproducibility for
  computational methods." Science.
