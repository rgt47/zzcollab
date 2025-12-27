# Source functions
source('../../R/data_utils.R')

test_that("load_penguin_data loads valid data", {
  # This test assumes processing script has been run
  skip_if_not(file.exists("analysis/data/derived_data/penguins_clean.csv"))

  data <- load_penguin_data()

  # Check structure
  expect_true(is.data.frame(data))
  expect_gt(nrow(data), 0)

  # Check required columns
  expect_true("species" %in% names(data))
  expect_true("bill_length_mm" %in% names(data))
  expect_true("bill_depth_mm" %in% names(data))
  expect_true("bill_ratio" %in% names(data))
})

test_that("load_penguin_data fails gracefully with missing file", {
  expect_error(
    load_penguin_data("/nonexistent/path.csv"),
    "Clean data file not found"
  )
})

test_that("summarize_by_species produces valid output", {
  skip_if_not(file.exists("analysis/data/derived_data/penguins_clean.csv"))

  data <- load_penguin_data()
  summary <- summarize_by_species(data)

  # Check structure
  expect_true(is.data.frame(summary))
  expect_true("species" %in% names(summary))
  expect_true("n" %in% names(summary))
  expect_true("mean_bill_length" %in% names(summary))

  # Check values are numeric
  expect_type(summary$mean_bill_length, "double")
  expect_type(summary$mean_bill_depth, "double")

  # Check all means are positive
  expect_true(all(summary$mean_bill_length > 0))
  expect_true(all(summary$mean_bill_depth > 0))
})

test_that("bill_ratio is calculated correctly", {
  skip_if_not(file.exists("analysis/data/derived_data/penguins_clean.csv"))

  data <- load_penguin_data()

  # Verify bill_ratio calculation
  expected_ratio <- data$bill_length_mm / data$bill_depth_mm
  expect_equal(data$bill_ratio, expected_ratio)
})
