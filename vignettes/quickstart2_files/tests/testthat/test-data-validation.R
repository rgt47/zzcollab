# test-data-validation.R
# Tests for data integrity and validation functions

test_that("raw data file exists and is readable", {
  raw_data_path <- "analysis/data/raw_data/mtcars.csv"

  expect_true(file.exists(raw_data_path))

  data <- read.csv(raw_data_path, row.names = 1)
  expect_s3_class(data, "data.frame")
})

test_that("raw data has expected dimensions", {
  data <- read.csv("analysis/data/raw_data/mtcars.csv", row.names = 1)

  expect_equal(nrow(data), 32)
  expect_equal(ncol(data), 11)
})

test_that("raw data contains required columns", {
  data <- read.csv("analysis/data/raw_data/mtcars.csv", row.names = 1)

  required_cols <- c("mpg", "cyl", "disp", "hp", "drat", "wt",
                     "qsec", "vs", "am", "gear", "carb")

  expect_true(all(required_cols %in% names(data)))
})

test_that("raw data values are within expected ranges", {
  data <- read.csv("analysis/data/raw_data/mtcars.csv", row.names = 1)

  expect_true(all(data$mpg > 0 & data$mpg < 50))
  expect_true(all(data$cyl %in% c(4, 6, 8)))
  expect_true(all(data$hp > 0 & data$hp < 500))
  expect_true(all(data$wt > 0))
})

test_that("derived data has correct subset size", {
  skip_if_not(file.exists("analysis/data/derived_data/mtcars_processed.rds"))

  data <- readRDS("analysis/data/derived_data/mtcars_processed.rds")

  expect_equal(nrow(data), 16)
})
