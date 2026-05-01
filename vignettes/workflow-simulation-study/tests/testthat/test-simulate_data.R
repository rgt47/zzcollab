# test-simulate_data.R
# Unit tests for data simulation functions

library(testthat)

source("../../R/simulate_data.R")

# Tests for simulate_longitudinal_binary -------------------------------------

test_that("simulate_longitudinal_binary returns correct structure", {
  data <- simulate_longitudinal_binary(
    n_subjects = 10,
    n_timepoints = 4,
    seed = 42
  )

  expect_s3_class(data, "data.frame")
  expect_equal(nrow(data), 40)
  expect_true(all(c("subject_id", "time", "treatment", "y") %in% names(data)))
})

test_that("simulate_longitudinal_binary respects seed", {
  data1 <- simulate_longitudinal_binary(n_subjects = 20, seed = 123)
  data2 <- simulate_longitudinal_binary(n_subjects = 20, seed = 123)

  expect_identical(data1, data2)
})

test_that("simulate_longitudinal_binary produces different data without seed", {
  data1 <- simulate_longitudinal_binary(n_subjects = 50, seed = 1)
  data2 <- simulate_longitudinal_binary(n_subjects = 50, seed = 2)

  expect_false(identical(data1$y, data2$y))
})

test_that("simulate_longitudinal_binary produces valid binary outcomes", {
  data <- simulate_longitudinal_binary(n_subjects = 100, seed = 42)

  expect_true(all(data$y %in% c(0, 1)))
})

test_that("simulate_longitudinal_binary balances treatment assignment", {
  data <- simulate_longitudinal_binary(n_subjects = 1000, seed = 42)

  subject_treatment <- unique(data[, c("subject_id", "treatment")])
  prop_treated <- mean(subject_treatment$treatment == "treatment")

  expect_gt(prop_treated, 0.45)
  expect_lt(prop_treated, 0.55)
})

test_that("simulate_longitudinal_binary has correct time structure", {
  data <- simulate_longitudinal_binary(
    n_subjects = 10,
    n_timepoints = 5,
    seed = 42
  )

  expect_equal(sort(unique(data$time)), 0:4)

  time_per_subject <- tapply(data$time, data$subject_id, function(x) {
    identical(sort(x), 0:4)
  })
  expect_true(all(time_per_subject))
})

test_that("simulate_longitudinal_binary treatment is constant within subject", {
  data <- simulate_longitudinal_binary(n_subjects = 50, seed = 42)

  treatment_per_subject <- tapply(data$treatment, data$subject_id, function(x) {
    length(unique(x)) == 1
  })
  expect_true(all(treatment_per_subject))
})

test_that("simulate_longitudinal_binary validates beta length", {
  expect_error(
    simulate_longitudinal_binary(n_subjects = 10, beta = c(1, 2)),
    "beta must have 4 elements"
  )
})

test_that("simulate_longitudinal_binary validates n_subjects", {
  expect_error(
    simulate_longitudinal_binary(n_subjects = 1),
    "n_subjects must be at least 2"
  )
})

test_that("simulate_longitudinal_binary validates n_timepoints", {
  expect_error(
    simulate_longitudinal_binary(n_subjects = 10, n_timepoints = 1),
    "n_timepoints must be at least 2"
  )
})

test_that("simulate_longitudinal_binary validates sigma_b", {
  expect_error(
    simulate_longitudinal_binary(n_subjects = 10, sigma_b = -0.5),
    "sigma_b must be non-negative"
  )
})

test_that("simulate_longitudinal_binary handles zero sigma_b", {
  data <- simulate_longitudinal_binary(
    n_subjects = 50,
    sigma_b = 0,
    seed = 42
  )

  expect_s3_class(data, "data.frame")
  expect_equal(nrow(data), 200)
})

test_that("simulate_longitudinal_binary responds to beta parameters", {
  data_low <- simulate_longitudinal_binary(
    n_subjects = 500,
    beta = c(-2, 0, 0, 0),
    sigma_b = 0,
    seed = 42
  )

  data_high <- simulate_longitudinal_binary(
    n_subjects = 500,
    beta = c(2, 0, 0, 0),
    sigma_b = 0,
    seed = 42
  )

  expect_lt(mean(data_low$y), mean(data_high$y))
})

# Tests for create_simulation_grid -------------------------------------------

test_that("create_simulation_grid produces correct dimensions", {
  grid <- create_simulation_grid(
    n_subjects = c(50, 100),
    beta_interaction = c(0, 0.3),
    sigma_b = 0.5,
    n_sims = 10
  )

  expect_equal(nrow(grid), 2 * 2 * 1 * 10)
  expect_true("scenario_id" %in% names(grid))
  expect_true("sim_id" %in% names(grid))
  expect_true("seed" %in% names(grid))
})

test_that("create_simulation_grid has unique seeds", {
  grid <- create_simulation_grid(
    n_subjects = c(50, 100),
    beta_interaction = c(0, 0.3),
    sigma_b = c(0.5, 1.0),
    n_sims = 100
  )

  expect_equal(length(unique(grid$seed)), nrow(grid))
})

test_that("create_simulation_grid has correct scenario structure", {
  grid <- create_simulation_grid(
    n_subjects = c(50, 100, 200),
    beta_interaction = c(0, 0.3, 0.5),
    sigma_b = c(0.5, 1.0),
    n_sims = 5
  )

  n_scenarios <- 3 * 3 * 2
  expect_equal(length(unique(grid$scenario_id)), n_scenarios)

  expect_true(all(grid$sim_id >= 1 & grid$sim_id <= 5))
})

test_that("create_simulation_grid validates inputs", {
  expect_error(
    create_simulation_grid(n_subjects = 1),
    "n_subjects values must be at least 2"
  )

  expect_error(
    create_simulation_grid(sigma_b = -0.5),
    "sigma_b values must be non-negative"
  )

  expect_error(
    create_simulation_grid(n_sims = 0),
    "n_sims must be at least 1"
  )
})

# Tests for utility functions ------------------------------------------------

test_that("inv_logit returns correct values", {
  expect_equal(inv_logit(0), 0.5)
  expect_equal(inv_logit(-Inf), 0)
  expect_equal(inv_logit(Inf), 1)

  expect_true(abs(inv_logit(-1) - 0.2689) < 0.001)
  expect_true(abs(inv_logit(1) - 0.7311) < 0.001)
})

test_that("logit returns correct values", {
  expect_equal(logit(0.5), 0)

  expect_true(abs(logit(0.2689) - (-1)) < 0.01)
  expect_true(abs(logit(0.7311) - 1) < 0.01)
})

test_that("logit and inv_logit are inverses", {
  p_values <- c(0.1, 0.25, 0.5, 0.75, 0.9)

  for (p in p_values) {
    expect_equal(inv_logit(logit(p)), p, tolerance = 1e-10)
  }
})

test_that("logit validates input range", {
  expect_error(logit(0), "must be between 0 and 1")
  expect_error(logit(1), "must be between 0 and 1")
  expect_error(logit(-0.1), "must be between 0 and 1")
  expect_error(logit(1.1), "must be between 0 and 1")
})
