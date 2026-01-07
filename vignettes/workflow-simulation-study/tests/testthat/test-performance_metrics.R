# test-performance_metrics.R
# Unit tests for performance metric functions

library(testthat)

source("../../R/performance_metrics.R")

# Tests for calculate_performance --------------------------------------------

test_that("calculate_performance returns all expected metrics", {
  set.seed(42)
  estimates <- rnorm(100, mean = 0.5, sd = 0.1)
  ses <- rep(0.1, 100)

  perf <- calculate_performance(estimates, ses, true_value = 0.5)

  expected_names <- c("n_valid", "bias", "relative_bias", "empirical_se",
                      "average_model_se", "se_ratio", "mse", "coverage",
                      "power")
  expect_true(all(expected_names %in% names(perf)))
})

test_that("calculate_performance computes bias correctly", {
  estimates <- rep(0.6, 100)
  ses <- rep(0.1, 100)

  perf <- calculate_performance(estimates, ses, true_value = 0.5)

  expect_equal(perf["bias"], 0.1, tolerance = 1e-10)
})

test_that("calculate_performance computes relative bias correctly", {
  estimates <- rep(0.6, 100)
  ses <- rep(0.1, 100)

  perf <- calculate_performance(estimates, ses, true_value = 0.5)

  expect_equal(perf["relative_bias"], 20, tolerance = 1e-10)
})

test_that("calculate_performance returns NA relative_bias for null effect", {
  set.seed(42)
  estimates <- rnorm(100, mean = 0, sd = 0.1)
  ses <- rep(0.1, 100)

  perf <- calculate_performance(estimates, ses, true_value = 0)

  expect_true(is.na(perf["relative_bias"]))
})

test_that("calculate_performance computes empirical SE correctly", {
  set.seed(42)
  true_sd <- 0.15
  estimates <- rnorm(10000, mean = 0.5, sd = true_sd)
  ses <- rep(0.1, 10000)

  perf <- calculate_performance(estimates, ses, true_value = 0.5)

  expect_equal(perf["empirical_se"], true_sd, tolerance = 0.01)
})

test_that("calculate_performance computes coverage correctly", {
  set.seed(42)
  true_value <- 0.5
  estimates <- rnorm(10000, mean = true_value, sd = 0.1)
  ses <- rep(0.1, 10000)

  perf <- calculate_performance(estimates, ses, true_value)

  expect_true(perf["coverage"] > 0.94 & perf["coverage"] < 0.96)
})

test_that("calculate_performance detects undercoverage", {
  set.seed(42)
  estimates <- rnorm(1000, mean = 0.5, sd = 0.2)
  ses <- rep(0.1, 1000)

  perf <- calculate_performance(estimates, ses, true_value = 0.5)

  expect_lt(perf["coverage"], 0.80)
})

test_that("calculate_performance computes power correctly for null", {
  set.seed(42)
  estimates <- rnorm(10000, mean = 0, sd = 0.1)
  ses <- rep(0.1, 10000)

  perf <- calculate_performance(estimates, ses, true_value = 0)

  expect_true(perf["power"] > 0.04 & perf["power"] < 0.06)
})

test_that("calculate_performance detects power for true effect", {
  set.seed(42)
  true_value <- 0.5
  estimates <- rnorm(1000, mean = true_value, sd = 0.1)
  ses <- rep(0.1, 1000)

  perf <- calculate_performance(estimates, ses, true_value)

  expect_true(perf["power"] > 0.99)
})

test_that("calculate_performance handles missing values", {
  estimates <- c(0.5, 0.4, NA, 0.6, NA)
  ses <- c(0.1, 0.1, 0.1, NA, 0.1)

  perf <- calculate_performance(estimates, ses, true_value = 0.5)

  expect_equal(perf["n_valid"], 2)
})

test_that("calculate_performance returns NA for insufficient data", {
  estimates <- c(0.5, 0.4, 0.6)
  ses <- c(0.1, 0.1, 0.1)

  perf <- calculate_performance(estimates, ses, true_value = 0.5)

  expect_true(is.na(perf["bias"]))
  expect_true(is.na(perf["coverage"]))
})

test_that("calculate_performance validates input lengths", {
  estimates <- 1:10
  ses <- 1:5

  expect_error(
    calculate_performance(estimates, ses, true_value = 0.5),
    "same length"
  )
})

test_that("calculate_performance validates alpha", {
  estimates <- rnorm(100)
  ses <- rep(0.1, 100)

  expect_error(
    calculate_performance(estimates, ses, true_value = 0, alpha = 0),
    "alpha must be between"
  )

  expect_error(
    calculate_performance(estimates, ses, true_value = 0, alpha = 1),
    "alpha must be between"
  )
})

test_that("calculate_performance respects alpha parameter", {
  set.seed(42)
  estimates <- rnorm(10000, mean = 0.5, sd = 0.1)
  ses <- rep(0.1, 10000)

  perf_95 <- calculate_performance(estimates, ses, true_value = 0.5,
                                   alpha = 0.05)
  perf_90 <- calculate_performance(estimates, ses, true_value = 0.5,
                                   alpha = 0.10)

  expect_gt(perf_95["coverage"], perf_90["coverage"])
})

test_that("calculate_performance computes MSE correctly", {
  set.seed(42)
  true_value <- 0.5
  estimates <- rnorm(10000, mean = 0.6, sd = 0.1)
  ses <- rep(0.1, 10000)

  perf <- calculate_performance(estimates, ses, true_value)

  expected_mse <- 0.1^2 + 0.01^2
  expect_equal(perf["mse"], expected_mse, tolerance = 0.005)
})

test_that("calculate_performance computes SE ratio correctly", {
  set.seed(42)
  estimates <- rnorm(1000, mean = 0.5, sd = 0.1)
  ses <- rep(0.1, 1000)

  perf <- calculate_performance(estimates, ses, true_value = 0.5)

  expect_true(abs(perf["se_ratio"] - 1) < 0.1)
})

# Tests for summarize_simulation ---------------------------------------------

test_that("summarize_simulation produces expected output structure", {
  results <- data.frame(
    scenario_id = rep(1:2, each = 100),
    method = rep(c("gee", "glmm"), times = 100),
    estimate = rnorm(200, 0.3, 0.1),
    se = rep(0.1, 200)
  )

  true_values <- data.frame(
    scenario_id = 1:2,
    beta_interaction = c(0.3, 0.3),
    n_subjects = c(50, 100),
    sigma_b = c(0.5, 0.5)
  )

  perf <- summarize_simulation(results, true_values)

  expect_s3_class(perf, "data.frame")
  expect_true("method" %in% names(perf))
  expect_true("bias" %in% names(perf))
  expect_true("coverage" %in% names(perf))
})

test_that("summarize_simulation validates input columns", {
  bad_results <- data.frame(x = 1:10)

  expect_error(
    summarize_simulation(bad_results, data.frame(scenario_id = 1)),
    "results must contain columns"
  )
})

test_that("summarize_simulation validates true_values columns", {
  results <- data.frame(
    scenario_id = 1:10,
    method = "gee",
    estimate = rnorm(10),
    se = rep(0.1, 10)
  )

  bad_true_values <- data.frame(scenario_id = 1)

  expect_error(
    summarize_simulation(results, bad_true_values),
    "true_values must contain columns"
  )
})

# Tests for MCSE functions ---------------------------------------------------

test_that("mcse_proportion returns correct values", {
  mcse <- mcse_proportion(0.5, 1000)
  expected <- sqrt(0.5 * 0.5 / 1000)

  expect_equal(mcse, expected)
})

test_that("mcse_proportion handles edge cases", {
  expect_equal(mcse_proportion(0, 1000), 0)
  expect_equal(mcse_proportion(1, 1000), 0)
})

test_that("mcse_mean returns correct values", {
  mcse <- mcse_mean(0.1, 100)
  expected <- 0.1 / sqrt(100)

  expect_equal(mcse, expected)
})

test_that("mcse_variance returns correct values", {
  mcse <- mcse_variance(0.1, 101)
  expected <- 0.1 * sqrt(2 / 100)

  expect_equal(mcse, expected)
})

# Tests for format_performance_table -----------------------------------------

test_that("format_performance_table selects correct columns", {
  performance <- data.frame(
    n_subjects = 100,
    beta_interaction = 0.3,
    sigma_b = 0.5,
    method = "gee",
    bias = 0.012345,
    coverage = 0.948,
    power = 0.823,
    mse = 0.01
  )

  result <- format_performance_table(performance,
                                     metrics = c("bias", "coverage"))

  expect_true("bias" %in% names(result))
  expect_true("coverage" %in% names(result))
  expect_false("power" %in% names(result))
  expect_false("mse" %in% names(result))
})

test_that("format_performance_table rounds correctly", {
  performance <- data.frame(
    n_subjects = 100,
    method = "gee",
    bias = 0.012345678
  )

  result <- format_performance_table(performance,
                                     metrics = "bias",
                                     digits = 3)

  expect_equal(result$bias, 0.012)
})
