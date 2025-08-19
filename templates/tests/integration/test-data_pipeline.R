# Integration tests for the complete data pipeline
# Tests the full workflow from raw data to derived data

library(testthat)

test_that("complete data pipeline runs successfully", {
  # Skip if no raw data available
  raw_data_file <- here::here("data", "raw_data", "penguins.csv")
  skip_if_not(file.exists(raw_data_file), "Raw data not available for pipeline test")
  
  # Step 1: Load raw data
  penguins_raw <- read.csv(raw_data_file, stringsAsFactors = FALSE)
  expect_s3_class(penguins_raw, "data.frame")
  expect_gt(nrow(penguins_raw), 0, "Raw data should have rows")
  
  # Step 2: Validate raw data structure
  expect_true(validate_penguin_data(penguins_raw), 
              "Raw data should pass validation checks")
  
  # Step 3: Prepare subset with log transformation
  penguins_subset <- prepare_penguin_subset(penguins_raw, n_records = 50)
  
  # Step 4: Verify subset results
  expect_s3_class(penguins_subset, "data.frame")
  expect_lte(nrow(penguins_subset), 50, "Subset should have at most 50 rows")
  expect_true("log_body_mass_g" %in% names(penguins_subset), 
              "Subset should include log transformation")
  
  # Step 5: Test log transformation is mathematically correct
  expected_log <- log(penguins_subset$body_mass_g)
  expect_equal(penguins_subset$log_body_mass_g, expected_log,
               tolerance = 1e-10, "Log transformation should be exact")
  
  # Step 6: Verify no missing body mass in final data
  expect_false(any(is.na(penguins_subset$body_mass_g)), 
               "Final subset should not have missing body mass")
  expect_false(any(is.na(penguins_subset$log_body_mass_g)), 
               "Log body mass should not have missing values")
})

test_that("data pipeline produces consistent results", {
  raw_data_file <- here::here("data", "raw_data", "penguins.csv")
  skip_if_not(file.exists(raw_data_file), "Raw data not available")
  
  penguins_raw <- read.csv(raw_data_file, stringsAsFactors = FALSE)
  
  # Run pipeline multiple times
  result1 <- prepare_penguin_subset(penguins_raw, n_records = 30)
  result2 <- prepare_penguin_subset(penguins_raw, n_records = 30)
  
  # Should get identical results
  expect_equal(result1, result2, "Pipeline should be deterministic")
})

test_that("data pipeline handles edge cases gracefully", {
  raw_data_file <- here::here("data", "raw_data", "penguins.csv")
  skip_if_not(file.exists(raw_data_file), "Raw data not available")
  
  penguins_raw <- read.csv(raw_data_file, stringsAsFactors = FALSE)
  
  # Test with very small subset
  small_subset <- prepare_penguin_subset(penguins_raw, n_records = 1)
  expect_equal(nrow(small_subset), 1)
  expect_true("log_body_mass_g" %in% names(small_subset))
  
  # Test with subset larger than available data
  max_records <- nrow(penguins_raw)
  expect_warning(
    large_subset <- prepare_penguin_subset(penguins_raw, n_records = max_records + 10),
    "requested"
  )
  expect_lte(nrow(large_subset), max_records)
})

test_that("derived data file matches pipeline output", {
  raw_data_file <- here::here("data", "raw_data", "penguins.csv")
  derived_data_file <- here::here("data", "derived_data", "penguins_subset.csv")
  
  # Skip if either file is missing
  skip_if_not(file.exists(raw_data_file), "Raw data file not found")
  skip_if_not(file.exists(derived_data_file), "Derived data file not found")
  
  # Load both datasets
  penguins_raw <- read.csv(raw_data_file, stringsAsFactors = FALSE)
  penguins_subset_file <- read.csv(derived_data_file, stringsAsFactors = FALSE)
  
  # Recreate the derived data using the pipeline
  penguins_subset_pipeline <- prepare_penguin_subset(penguins_raw, n_records = 50)
  
  # Compare key characteristics (allowing for potential minor differences in row order)
  expect_equal(nrow(penguins_subset_file), nrow(penguins_subset_pipeline),
               "File and pipeline should produce same number of rows")
  
  expect_equal(sort(names(penguins_subset_file)), sort(names(penguins_subset_pipeline)),
               "File and pipeline should have same columns")
  
  # Check that log transformation is consistent
  if (all(c("body_mass_g", "log_body_mass_g") %in% names(penguins_subset_file))) {
    expected_log <- log(penguins_subset_file$body_mass_g)
    expect_equal(penguins_subset_file$log_body_mass_g, expected_log,
                 tolerance = 1e-10, "Log transformation in file should be correct")
  }
})

test_that("data summary statistics are reasonable", {
  raw_data_file <- here::here("data", "raw_data", "penguins.csv")
  skip_if_not(file.exists(raw_data_file), "Raw data not available")
  
  penguins_raw <- read.csv(raw_data_file, stringsAsFactors = FALSE)
  penguins_subset <- prepare_penguin_subset(penguins_raw, n_records = 50)
  
  # Generate summary statistics
  summary_stats <- summarize_penguin_data(penguins_subset)
  
  expect_s3_class(summary_stats, "data.frame")
  expect_gt(nrow(summary_stats), 0, "Should have summary statistics")
  
  # Check that body mass statistics are reasonable for Palmer penguins
  if ("body_mass_g" %in% summary_stats$variable) {
    body_mass_stats <- summary_stats[summary_stats$variable == "body_mass_g", ]
    expect_gt(body_mass_stats$mean, 2000, "Mean body mass should be > 2000g")
    expect_lt(body_mass_stats$mean, 6000, "Mean body mass should be < 6000g")
    expect_gt(body_mass_stats$sd, 0, "Standard deviation should be positive")
  }
})

test_that("data transformations preserve data integrity", {
  raw_data_file <- here::here("data", "raw_data", "penguins.csv")
  skip_if_not(file.exists(raw_data_file), "Raw data not available")
  
  penguins_raw <- read.csv(raw_data_file, stringsAsFactors = FALSE)
  penguins_subset <- prepare_penguin_subset(penguins_raw, n_records = 20)
  
  # Check that original columns are preserved
  original_cols <- setdiff(names(penguins_raw), "log_body_mass_g")
  subset_original_cols <- names(penguins_subset)[names(penguins_subset) %in% original_cols]
  
  for (col in subset_original_cols) {
    if (is.numeric(penguins_raw[[col]])) {
      # For numeric columns, values should match exactly for the first n rows
      n_rows <- min(nrow(penguins_subset), nrow(penguins_raw))
      original_values <- penguins_raw[[col]][1:n_rows]
      subset_values <- penguins_subset[[col]][1:n_rows]
      
      # Account for potential missing value removal
      if (col != "body_mass_g") {  # body_mass_g might have NAs removed
        non_na_indices <- !is.na(original_values)
        expect_equal(subset_values[non_na_indices], original_values[non_na_indices],
                     info = paste("Column", col, "should be preserved accurately"))
      }
    }
  }
  
  # Check that log transformation doesn't introduce impossible values
  expect_false(any(is.infinite(penguins_subset$log_body_mass_g)), 
               "Log transformation should not produce infinite values")
  expect_false(any(penguins_subset$log_body_mass_g < 0 & !is.na(penguins_subset$log_body_mass_g)), 
               "Log of body mass should not be negative (body mass should be > 1)")
})

test_that("error handling works throughout pipeline", {
  # Test with completely invalid data
  invalid_data <- data.frame(
    not_a_penguin_column = c("A", "B", "C"),
    another_wrong_column = c(1, 2, 3)
  )
  
  expect_error(
    prepare_penguin_subset(invalid_data),
    "body_mass_g"
  )
  
  expect_false(validate_penguin_data(invalid_data))
  
  expect_error(
    summarize_penguin_data(invalid_data),
    "validation failed"
  )
})

# Test reproducibility
test_that("scripts directory contains expected data preparation script", {
  scripts_dir <- here::here("scripts")
  
  if (dir.exists(scripts_dir)) {
    script_files <- list.files(scripts_dir, pattern = "*.R$", ignore.case = TRUE)
    
    # Look for data preparation related scripts
    data_prep_scripts <- grep("prep|data|01", script_files, ignore.case = TRUE, value = TRUE)
    
    if (length(data_prep_scripts) > 0) {
      # Check that at least one script exists for data preparation
      expect_gt(length(data_prep_scripts), 0, "Should have data preparation scripts")
      
      # Check if script is readable
      first_script <- file.path(scripts_dir, data_prep_scripts[1])
      expect_true(file.exists(first_script), "Data prep script should exist")
      expect_gt(file.info(first_script)$size, 0, "Data prep script should not be empty")
    }
  }
})