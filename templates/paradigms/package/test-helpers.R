# Test Helper Functions
# Package: {{PACKAGE_NAME}}
# Author: {{AUTHOR_NAME}} {{AUTHOR_LAST}}

# This file contains helper functions and utilities for testing.
# Helper functions reduce code duplication and provide common testing utilities.

#' Create Sample Test Data
#'
#' Creates standardized test datasets for use across multiple test files.
#' This ensures consistent test data and reduces duplication.
#'
#' @param n_rows Integer. Number of rows in the test dataset.
#' @param include_missing Logical. Whether to include missing values.
#' @param seed Integer. Random seed for reproducible test data.
#'
#' @return A data.frame with test data
#'
#' @examples
#' test_data <- create_test_data(100, include_missing = TRUE)
#' small_data <- create_test_data(10, include_missing = FALSE)
create_test_data <- function(n_rows = 50, include_missing = FALSE, seed = 123) {
  set.seed(seed)

  # Create base data
  data <- data.frame(
    id = seq_len(n_rows),
    numeric_var = rnorm(n_rows, mean = 10, sd = 2),
    integer_var = sample(1:20, n_rows, replace = TRUE),
    character_var = sample(letters[1:5], n_rows, replace = TRUE),
    factor_var = factor(sample(c("Group1", "Group2", "Group3"), n_rows, replace = TRUE)),
    logical_var = sample(c(TRUE, FALSE), n_rows, replace = TRUE),
    date_var = seq(as.Date("2024-01-01"), by = "day", length.out = n_rows)
  )

  # Add missing values if requested
  if (include_missing && n_rows > 10) {
    # Add missing values to ~10% of numeric data
    missing_indices <- sample(seq_len(n_rows), size = ceiling(n_rows * 0.1))
    data$numeric_var[missing_indices] <- NA

    # Add missing values to character data
    char_missing <- sample(seq_len(n_rows), size = ceiling(n_rows * 0.05))
    data$character_var[char_missing] <- NA
  }

  return(data)
}

#' Expect Approximately Equal Vectors
#'
#' Custom expectation function for comparing numeric vectors with tolerance.
#' Useful for testing functions that perform floating-point arithmetic.
#'
#' @param object Numeric vector to test
#' @param expected Numeric vector with expected values
#' @param tolerance Numeric tolerance for comparison
#' @param info Optional info to print on failure
expect_approximately_equal <- function(object, expected, tolerance = 1e-10, info = NULL) {
  testthat::expect_true(
    all(abs(object - expected) < tolerance),
    info = info %||% paste("Vectors not approximately equal within tolerance", tolerance)
  )
}

#' Expect Valid Package Function Output
#'
#' Custom expectation to validate common properties of package function outputs.
#' Checks for proper return types, structure, and common package conventions.
#'
#' @param object Object returned by package function
#' @param expected_type Expected R type ("character", "numeric", etc.)
#' @param expected_length Expected length (NULL to skip check)
#' @param expected_class Expected S3 class (NULL to skip check)
expect_valid_output <- function(object, expected_type, expected_length = NULL, expected_class = NULL) {
  # Check type
  testthat::expect_type(object, expected_type)

  # Check length if specified
  if (!is.null(expected_length)) {
    testthat::expect_length(object, expected_length)
  }

  # Check class if specified
  if (!is.null(expected_class)) {
    testthat::expect_s3_class(object, expected_class)
  }

  # Check for common issues
  if (expected_type %in% c("character", "numeric", "logical")) {
    testthat::expect_false(any(is.null(object)), info = "Output contains NULL values")
  }
}

#' Expect Error with Specific Pattern
#'
#' Enhanced error expectation that checks both error occurrence and message pattern.
#' More specific than base testthat::expect_error for better test precision.
#'
#' @param expr Expression to evaluate
#' @param pattern Regular expression pattern to match in error message
#' @param class Expected error class (optional)
expect_error_with_pattern <- function(expr, pattern, class = NULL) {
  # Capture the error
  error_occurred <- FALSE
  error_message <- ""
  error_class <- NULL

  tryCatch({
    eval(expr)
  }, error = function(e) {
    error_occurred <<- TRUE
    error_message <<- e$message
    error_class <<- class(e)[1]
  })

  # Check that error occurred
  testthat::expect_true(error_occurred, info = "Expected error did not occur")

  # Check error message pattern
  testthat::expect_true(
    grepl(pattern, error_message, ignore.case = TRUE),
    info = paste("Error message '", error_message, "' does not match pattern '", pattern, "'")
  )

  # Check error class if specified
  if (!is.null(class)) {
    testthat::expect_equal(error_class, class)
  }
}

#' Expect Function Has Proper Documentation
#'
#' Checks that a function has proper roxygen2 documentation by examining
#' the help file. Useful for ensuring package functions meet documentation standards.
#'
#' @param func_name Character string of function name
#' @param package_name Character string of package name (optional)
expect_documented_function <- function(func_name, package_name = NULL) {
  # Try to get help for the function
  help_available <- FALSE

  tryCatch({
    if (is.null(package_name)) {
      help_obj <- utils::help(func_name)
    } else {
      help_obj <- utils::help(func_name, package = package_name)
    }
    help_available <- length(help_obj) > 0
  }, error = function(e) {
    help_available <<- FALSE
  })

  testthat::expect_true(
    help_available,
    info = paste("Function", func_name, "does not have help documentation")
  )
}

#' Skip Test if Package Not Available
#'
#' Utility function to skip tests when optional dependencies are not available.
#' Useful for tests that require suggested packages.
#'
#' @param package Character string of package name
#' @param message Custom message for skip (optional)
skip_if_not_installed <- function(package, message = NULL) {
  if (!requireNamespace(package, quietly = TRUE)) {
    message <- message %||% paste("Package", package, "not available")
    testthat::skip(message)
  }
}

#' Expect No Visible Bindings
#'
#' Checks that a package function doesn't create visible binding issues
#' commonly flagged by R CMD check. Useful for testing NSE functions.
#'
#' @param expr Expression to evaluate
expect_no_visible_bindings <- function(expr) {
  # This is a placeholder implementation
  # In practice, you might use tools::checkUsage() or similar
  # for more sophisticated checking

  # For now, just ensure the expression evaluates without error
  testthat::expect_error(expr, NA)
}

# Test data constants for use across test files
TEST_SEED <- 42
SMALL_N <- 10
MEDIUM_N <- 100
LARGE_N <- 1000

# Common test tolerances
FLOAT_TOLERANCE <- 1e-10
APPROX_TOLERANCE <- 1e-6

# Utility function for creating temporary test files
create_temp_test_file <- function(content = "test content", extension = ".txt") {
  temp_file <- tempfile(fileext = extension)
  writeLines(content, temp_file)
  return(temp_file)
}

# Cleanup function for temporary test files
cleanup_temp_files <- function(file_paths) {
  for (path in file_paths) {
    if (file.exists(path)) {
      unlink(path)
    }
  }
}

# Null-coalescing operator for helper functions
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}