# test-allometry.R
# Unit tests for allometry functions

library(testthat)

# Create test data for all tests
create_test_data <- function() {
  set.seed(42)
  data.frame(
    y = c(rnorm(50, 10, 1), rnorm(50, 12, 1)),
    x = c(rnorm(50, 5, 0.5), rnorm(50, 6, 0.5)),
    species = factor(rep(c("A", "B"), each = 50))
  )
}

# Tests for extract_species_slopes -------------------------------------------

test_that("extract_species_slopes returns correct structure", {
  test_data <- create_test_data()
  model <- lm(y ~ x * species, data = test_data)

  result <- extract_species_slopes(model, "x", "species")

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_true("species" %in% names(result))
  expect_true("slope" %in% names(result))
})

test_that("extract_species_slopes handles three-level factor", {
  test_data <- data.frame(
    y = c(rnorm(30, 10), rnorm(30, 12), rnorm(30, 14)),
    x = c(rnorm(30, 5), rnorm(30, 6), rnorm(30, 7)),
    species = factor(rep(c("A", "B", "C"), each = 30))
  )
  model <- lm(y ~ x * species, data = test_data)

  result <- extract_species_slopes(model, "x", "species")

  expect_equal(nrow(result), 3)
  expect_equal(result$species, c("A", "B", "C"))
})

test_that("extract_species_slopes validates model input", {
  expect_error(
    extract_species_slopes("not a model"),
    "must be an lm object"
  )
})

test_that("extract_species_slopes validates x_var exists", {
  test_data <- create_test_data()
  model <- lm(y ~ x * species, data = test_data)

  expect_error(
    extract_species_slopes(model, "nonexistent", "species"),
    "not found in model coefficients"
  )
})

test_that("extract_species_slopes warns on additive model", {
  test_data <- create_test_data()
  model <- lm(y ~ x + species, data = test_data)

  expect_warning(
    result <- extract_species_slopes(model, "x", "species"),
    "No interaction terms found"
  )

  expect_equal(nrow(result), 1)
  expect_equal(result$species, "all")
})

test_that("extract_species_slopes calculates slopes correctly", {
  test_data <- create_test_data()
  model <- lm(y ~ x * species, data = test_data)
  coefs <- coef(model)

  result <- extract_species_slopes(model, "x", "species")

  expect_equal(result$slope[1], coefs["x"], ignore_attr = TRUE)
  expect_equal(result$slope[2], coefs["x"] + coefs["x:speciesB"],
               ignore_attr = TRUE)
})

# Tests for compare_allometric_models ----------------------------------------

test_that("compare_allometric_models returns all three models", {
  test_data <- create_test_data()

  result <- compare_allometric_models(test_data, "y", "x", "species")

  expect_type(result, "list")
  expect_true("pooled" %in% names(result))
  expect_true("additive" %in% names(result))
  expect_true("interaction" %in% names(result))
  expect_s3_class(result$pooled, "lm")
  expect_s3_class(result$additive, "lm")
  expect_s3_class(result$interaction, "lm")
})

test_that("compare_allometric_models returns AIC values", {
  test_data <- create_test_data()

  result <- compare_allometric_models(test_data, "y", "x", "species")

  expect_true("aic" %in% names(result))
  expect_length(result$aic, 3)
  expect_named(result$aic, c("pooled", "additive", "interaction"))
})

test_that("compare_allometric_models returns ANOVA comparison", {
  test_data <- create_test_data()

  result <- compare_allometric_models(test_data, "y", "x", "species")

  expect_true("anova" %in% names(result))
  expect_s3_class(result$anova, "anova")
})

test_that("interaction model has more parameters than additive", {
  test_data <- create_test_data()

  result <- compare_allometric_models(test_data, "y", "x", "species")

  additive_df <- result$additive$df.residual
  interaction_df <- result$interaction$df.residual

  expect_lt(interaction_df, additive_df)
})

# Integration test with palmerpenguins-like data -----------------------------

test_that("functions work with realistic penguin-like data", {
  skip_if_not_installed("palmerpenguins")

  library(palmerpenguins)

  data <- penguins |>
    dplyr::filter(!is.na(body_mass_g), !is.na(bill_length_mm)) |>
    dplyr::mutate(
      log_body_mass = log(body_mass_g),
      log_bill_length = log(bill_length_mm)
    )

  model <- lm(log_bill_length ~ log_body_mass * species, data = data)
  result <- extract_species_slopes(model)

  expect_equal(nrow(result), 3)
  expect_true(all(c("Adelie", "Chinstrap", "Gentoo") %in% result$species))

  comparison <- compare_allometric_models(
    data, "log_bill_length", "log_body_mass", "species"
  )

  expect_lt(comparison$aic["interaction"], comparison$aic["pooled"])
})
