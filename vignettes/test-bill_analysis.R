# Source function from R/
source('../../R/bill_analysis.R')

test_that('create_bill_plot produces valid ggplot', {
  plot <- create_bill_plot()

  # Valid ggplot object
  expect_s3_class(plot, 'ggplot')

  # Correct title
  expect_equal(plot$labels$title, 'Palmer Penguins: Bill Dimensions')
})

test_that('create_bill_plot handles missing data', {
  # Data with missing values
  test_data <- palmerpenguins::penguins
  test_data$bill_length_mm[1:5] <- NA

  plot <- create_bill_plot(test_data)

  # Should still produce plot
  expect_s3_class(plot, 'ggplot')
})

test_that('create_bill_plot includes all species', {
  plot <- create_bill_plot()

  # Should have species in color aesthetic
  expect_true('species' %in% names(plot$labels))
})
