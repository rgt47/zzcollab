# test-data-functions.R
# Tests for R/data_functions.R

test_that("validate_mtcars_data accepts valid data", {
  valid_data <- data.frame(
    mpg = c(21, 22), cyl = c(6, 4), disp = c(160, 140),
    hp = c(110, 93), drat = c(3.9, 3.85), wt = c(2.6, 2.3),
    qsec = c(16.5, 18.6), vs = c(0, 1), am = c(1, 1),
    gear = c(4, 4), carb = c(4, 2)
  )

  expect_true(validate_mtcars_data(valid_data))
})

test_that("validate_mtcars_data rejects missing columns", {
  incomplete_data <- data.frame(mpg = 21, cyl = 6)

  expect_error(
    validate_mtcars_data(incomplete_data),
    "Missing required columns"
  )
})

test_that("validate_mtcars_data rejects empty data", {
  empty_data <- mtcars[0, ]

  expect_error(validate_mtcars_data(empty_data), "empty")
})

test_that("validate_mtcars_data rejects invalid mpg", {
  bad_data <- mtcars[1:2, ]
  bad_data$mpg[1] <- -5

  expect_error(validate_mtcars_data(bad_data), "mpg must be positive")
})

test_that("add_derived_variables creates expected columns", {
  test_data <- mtcars[1:5, ]
  result <- add_derived_variables(test_data)

  expect_true("efficiency_class" %in% names(result))
  expect_true("weight_kg" %in% names(result))
  expect_true("power_to_weight" %in% names(result))
})

test_that("add_derived_variables calculates efficiency_class correctly", {
  test_data <- data.frame(
    mpg = c(25, 17, 12),
    wt = c(2.5, 3.0, 3.5),
    hp = c(100, 150, 200)
  )

  result <- add_derived_variables(test_data)

  expect_equal(result$efficiency_class, c("high", "medium", "low"))
})

test_that("add_derived_variables calculates weight_kg correctly", {
  test_data <- data.frame(mpg = 20, wt = 1, hp = 100)
  result <- add_derived_variables(test_data)

  expect_equal(result$weight_kg, 453.592, tolerance = 0.001)
})

test_that("add_derived_variables requires correct input columns", {
  bad_data <- data.frame(x = 1, y = 2)

  expect_error(
    add_derived_variables(bad_data),
    "must contain mpg, wt, and hp"
  )
})
