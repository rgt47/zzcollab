# test-fit_models.R
# Unit tests for model fitting functions

library(testthat)

source("../../R/simulate_data.R")
source("../../R/fit_models.R")

# Helper function to create test data
create_test_data <- function(n = 50, seed = 42) {
  simulate_longitudinal_binary(n_subjects = n, seed = seed)
}

# Tests for fit_gee ----------------------------------------------------------

test_that("fit_gee returns expected structure", {
  skip_if_not_installed("geepack")

  data <- create_test_data()
  result <- fit_gee(data)

  expect_type(result, "list")
  expect_true("estimate" %in% names(result))
  expect_true("se" %in% names(result))
  expect_true("converged" %in% names(result))
  expect_true("method" %in% names(result))
  expect_true("corstr" %in% names(result))
  expect_equal(result$method, "GEE")
})

test_that("fit_gee works with different correlation structures", {
  skip_if_not_installed("geepack")

  data <- create_test_data(n = 100)

  result_exch <- fit_gee(data, corstr = "exchangeable")
  result_ar1 <- fit_gee(data, corstr = "ar1")
  result_ind <- fit_gee(data, corstr = "independence")

  expect_equal(result_exch$corstr, "exchangeable")
  expect_equal(result_ar1$corstr, "ar1")
  expect_equal(result_ind$corstr, "independence")

  expect_true(result_exch$converged)
  expect_true(result_ar1$converged)
  expect_true(result_ind$converged)
})

test_that("fit_gee validates correlation structure", {
  skip_if_not_installed("geepack")

  data <- create_test_data()

  expect_error(
    fit_gee(data, corstr = "invalid"),
    "corstr must be one of"
  )
})

test_that("fit_gee validates data structure", {
  skip_if_not_installed("geepack")

  bad_data <- data.frame(x = 1:10, z = 1:10)

  expect_error(
    fit_gee(bad_data),
    "data must contain columns"
  )
})

test_that("fit_gee handles convergence failures gracefully", {
  skip_if_not_installed("geepack")

  data <- create_test_data(n = 10)
  data$y <- 0

  result <- fit_gee(data)

  expect_type(result, "list")
  expect_true("converged" %in% names(result))
})

# Tests for fit_glmm ---------------------------------------------------------

test_that("fit_glmm returns expected structure", {
  skip_if_not_installed("lme4")

  data <- create_test_data()
  result <- fit_glmm(data)

  expect_type(result, "list")
  expect_true("estimate" %in% names(result))
  expect_true("se" %in% names(result))
  expect_true("converged" %in% names(result))
  expect_true("method" %in% names(result))
  expect_equal(result$method, "GLMM")
})

test_that("fit_glmm validates data structure", {
  skip_if_not_installed("lme4")

  bad_data <- data.frame(x = 1:10, z = 1:10)

  expect_error(
    fit_glmm(bad_data),
    "data must contain columns"
  )
})

test_that("fit_glmm handles edge cases gracefully", {
  skip_if_not_installed("lme4")

  data <- create_test_data(n = 10)
  data$y <- 0

  result <- fit_glmm(data)

  expect_type(result, "list")
  expect_false(is.null(result$converged))
})

test_that("fit_glmm returns numeric estimates for valid data", {
  skip_if_not_installed("lme4")

  data <- create_test_data(n = 100, seed = 123)
  result <- fit_glmm(data)

  if (result$converged) {
    expect_type(result$estimate, "double")
    expect_type(result$se, "double")
    expect_false(is.na(result$estimate))
    expect_false(is.na(result$se))
  }
})

# Tests for fit_conditional --------------------------------------------------

test_that("fit_conditional returns expected structure", {
  skip_if_not_installed("survival")

  data <- create_test_data()
  result <- fit_conditional(data)

  expect_type(result, "list")
  expect_true("estimate" %in% names(result))
  expect_true("se" %in% names(result))
  expect_true("converged" %in% names(result))
  expect_true("method" %in% names(result))
  expect_equal(result$method, "Conditional")
})

test_that("fit_conditional validates data structure", {
  skip_if_not_installed("survival")

  bad_data <- data.frame(x = 1:10, z = 1:10)

  expect_error(
    fit_conditional(bad_data),
    "data must contain columns"
  )
})

test_that("fit_conditional handles edge cases gracefully", {
  skip_if_not_installed("survival")

  data <- create_test_data(n = 10)
  data$y <- 0

  result <- fit_conditional(data)

  expect_type(result, "list")
})

# Tests for fit_all_models ---------------------------------------------------

test_that("fit_all_models returns results for all methods", {
  skip_if_not_installed("geepack")
  skip_if_not_installed("lme4")
  skip_if_not_installed("survival")

  data <- create_test_data(n = 100)
  results <- fit_all_models(data)

  expect_s3_class(results, "data.frame")
  expect_equal(nrow(results), 5)
  expect_true(all(c("gee_exch", "gee_ar1", "gee_ind", "glmm", "conditional")
                  %in% results$method))
})

test_that("fit_all_models works with subset of methods", {
  skip_if_not_installed("geepack")

  data <- create_test_data()
  results <- fit_all_models(data, methods = c("gee_exch", "gee_ar1"))

  expect_equal(nrow(results), 2)
  expect_true(all(results$method %in% c("gee_exch", "gee_ar1")))
})

test_that("fit_all_models validates method names", {
  data <- create_test_data()

  expect_error(
    fit_all_models(data, methods = c("invalid_method")),
    "Invalid methods"
  )
})

test_that("fit_all_models returns consistent column structure", {
  skip_if_not_installed("geepack")
  skip_if_not_installed("lme4")
  skip_if_not_installed("survival")

  data <- create_test_data(n = 100)
  results <- fit_all_models(data)

  expect_true(all(c("method", "estimate", "se", "converged") %in%
                    names(results)))

  expect_type(results$estimate, "double")
  expect_type(results$se, "double")
  expect_type(results$converged, "logical")
})

# Integration test -----------------------------------------------------------

test_that("full pipeline produces reasonable estimates", {
  skip_if_not_installed("geepack")
  skip_if_not_installed("lme4")
  skip_if_not_installed("survival")

  set.seed(42)

  true_interaction <- 0.5
  data <- simulate_longitudinal_binary(
    n_subjects = 200,
    beta = c(-1, 0, 0.2, true_interaction),
    sigma_b = 0.5,
    seed = 42
  )

  results <- fit_all_models(data)

  converged_results <- results[results$converged, ]

  expect_gt(nrow(converged_results), 0)

  for (i in seq_len(nrow(converged_results))) {
    est <- converged_results$estimate[i]
    se <- converged_results$se[i]

    expect_true(abs(est - true_interaction) < 3 * se,
                info = paste("Method:", converged_results$method[i]))
  }
})
