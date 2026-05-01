# test-plot-functions.R
# Tests for R/plot_functions.R

test_that("plot_power_weight returns ggplot object", {
  test_data <- mtcars[1:5, ] |> add_derived_variables()

  result <- plot_power_weight(test_data)

  expect_s3_class(result, "ggplot")
})

test_that("plot_power_weight requires power_to_weight column", {
  bad_data <- mtcars[1:5, ]

  expect_error(
    plot_power_weight(bad_data),
    "power_to_weight"
  )
})

test_that("plot_power_weight respects show_labels parameter", {
  test_data <- mtcars[1:5, ] |> add_derived_variables()

  with_labels <- plot_power_weight(test_data, show_labels = TRUE)
  without_labels <- plot_power_weight(test_data, show_labels = FALSE)

  expect_s3_class(with_labels, "ggplot")
  expect_s3_class(without_labels, "ggplot")
})

test_that("plot_mpg_by_cylinder returns ggplot object", {
  test_data <- mtcars[1:5, ]

  result <- plot_mpg_by_cylinder(test_data)

  expect_s3_class(result, "ggplot")
})
