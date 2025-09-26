# Tests for Example Package Functions
# Package: {{PACKAGE_NAME}}
# Author: {{AUTHOR_NAME}} {{AUTHOR_LAST}}

# Test organization follows R package best practices:
# - One test file per R source file
# - Comprehensive test coverage including edge cases
# - Clear test descriptions and informative error messages
# - Use of testthat helper functions and expectations

test_that("hello_world returns correct greeting", {
  # Test default behavior
  result <- hello_world()
  expect_equal(result, "Hello World!")
  expect_type(result, "character")
  expect_length(result, 1)

  # Test with custom name
  expect_equal(hello_world("Alice"), "Hello Alice!")
  expect_equal(hello_world("Bob"), "Hello Bob!")

  # Test exclamation parameter
  expect_equal(hello_world("Charlie", exclaim = FALSE), "Hello Charlie.")
  expect_equal(hello_world("David", exclaim = TRUE), "Hello David!")

  # Test capitalization parameter
  expect_equal(hello_world("eve", capitalize = TRUE), "HELLO EVE!")
  expect_equal(hello_world("frank", capitalize = FALSE), "Hello frank!")

  # Test parameter combinations
  expect_equal(hello_world("grace", exclaim = FALSE, capitalize = TRUE),
               "HELLO GRACE.")
})

test_that("hello_world validates input parameters correctly", {
  # Test invalid name parameter
  expect_error(hello_world(123),
               "'name' must be a character string of length 1")
  expect_error(hello_world(c("Alice", "Bob")),
               "'name' must be a character string of length 1")
  expect_error(hello_world(character(0)),
               "'name' must be a character string of length 1")
  expect_error(hello_world(NA_character_),
               "'name' must be a character string of length 1")

  # Test invalid exclaim parameter
  expect_error(hello_world("Alice", exclaim = "yes"),
               "'exclaim' must be a logical value of length 1")
  expect_error(hello_world("Alice", exclaim = c(TRUE, FALSE)),
               "'exclaim' must be a logical value of length 1")
  expect_error(hello_world("Alice", exclaim = NA),
               "'exclaim' must be a logical value of length 1")

  # Test invalid capitalize parameter
  expect_error(hello_world("Alice", capitalize = "yes"),
               "'capitalize' must be a logical value of length 1")
  expect_error(hello_world("Alice", capitalize = c(TRUE, FALSE)),
               "'capitalize' must be a logical value of length 1")
})

test_that("goodbye_world returns correct farewell", {
  # Test default behavior
  result <- goodbye_world()
  expect_equal(result, "Goodbye World!")
  expect_type(result, "character")
  expect_length(result, 1)

  # Test with custom name
  expect_equal(goodbye_world("Alice"), "Goodbye Alice!")
  expect_equal(goodbye_world("Team"), "Goodbye Team!")

  # Test parameter variations
  expect_equal(goodbye_world("Bob", exclaim = FALSE), "Goodbye Bob.")
  expect_equal(goodbye_world("charlie", capitalize = TRUE), "GOODBYE CHARLIE!")
})

test_that("goodbye_world validates input parameters correctly", {
  # Similar validation tests as hello_world
  expect_error(goodbye_world(123),
               "'name' must be a character string of length 1")
  expect_error(goodbye_world(c("Alice", "Bob")),
               "'name' must be a character string of length 1")

  expect_error(goodbye_world("Alice", exclaim = "no"),
               "'exclaim' must be a logical value of length 1")
  expect_error(goodbye_world("Alice", capitalize = 1),
               "'capitalize' must be a logical value of length 1")
})

test_that("add_numbers performs basic arithmetic correctly", {
  # Test basic addition
  expect_equal(add_numbers(1, 2), 3)
  expect_equal(add_numbers(c(1, 2, 3), c(4, 5, 6)), c(5, 7, 9))

  # Test with different numeric types
  expect_equal(add_numbers(1L, 2L), 3)  # integers
  expect_equal(add_numbers(1.5, 2.3), 3.8, tolerance = 1e-10)  # doubles

  # Test vector recycling
  expect_equal(add_numbers(c(1, 2, 3), 10), c(11, 12, 13))
  expect_equal(add_numbers(5, c(1, 2, 3)), c(6, 7, 8))

  # Test zero-length vectors
  expect_equal(add_numbers(numeric(0), numeric(0)), numeric(0))

  # Test single values
  expect_equal(add_numbers(0, 0), 0)
  expect_equal(add_numbers(-1, 1), 0)
})

test_that("add_numbers handles missing values correctly", {
  # Test default NA handling (na.rm = FALSE)
  expect_equal(add_numbers(c(1, NA, 3), c(4, 5, 6)), c(5, NA, 9))
  expect_equal(add_numbers(c(1, 2), c(NA, 4)), c(NA, 6))

  # Test na.rm = TRUE
  expect_equal(add_numbers(c(1, NA, 3), c(4, 5, 6), na.rm = TRUE), c(5, 5, 9))
  expect_equal(add_numbers(c(1, 2), c(NA, 4), na.rm = TRUE), c(1, 6))

  # Test all NA values
  expect_true(is.na(add_numbers(NA, NA)))
  expect_equal(add_numbers(NA, NA, na.rm = TRUE), 0)
})

test_that("add_numbers validates input parameters", {
  # Test non-numeric inputs
  expect_error(add_numbers("1", 2), "'x' must be numeric")
  expect_error(add_numbers(1, "2"), "'y' must be numeric")
  expect_error(add_numbers(TRUE, 2), "'x' must be numeric")
  expect_error(add_numbers(1, FALSE), "'y' must be numeric")

  # Test invalid na.rm parameter
  expect_error(add_numbers(1, 2, na.rm = "yes"), "'na.rm' must be a logical value of length 1")
  expect_error(add_numbers(1, 2, na.rm = c(TRUE, FALSE)), "'na.rm' must be a logical value of length 1")
  expect_error(add_numbers(1, 2, na.rm = NA), "'na.rm' must be a logical value of length 1")
})

test_that("summarize_data works with basic input", {
  # Create test data
  test_data <- data.frame(
    x = c(1, 2, 3, 4, 5),
    y = c(2, 4, 6, 8, 10),
    z = c("a", "b", "c", "d", "e")  # non-numeric column
  )

  # Test basic functionality
  result <- summarize_data(test_data)

  # Check structure
  expect_s3_class(result, "data.frame")
  expect_true("variable" %in% names(result))
  expect_equal(nrow(result), 2)  # Only numeric columns x and y

  # Check values for x column
  x_row <- result[result$variable == "x", ]
  expect_equal(x_row$mean, 3)
  expect_equal(x_row$n, 5)
  expect_equal(x_row$missing, 0)
})

test_that("summarize_data handles column selection", {
  test_data <- data.frame(
    a = 1:5,
    b = 6:10,
    c = 11:15
  )

  # Test specific column selection
  result <- summarize_data(test_data, columns = c("a", "c"))
  expect_equal(nrow(result), 2)
  expect_true(all(result$variable %in% c("a", "c")))

  # Test single column
  result_single <- summarize_data(test_data, columns = "b")
  expect_equal(nrow(result_single), 1)
  expect_equal(result_single$variable, "b")
})

test_that("summarize_data handles custom statistics", {
  test_data <- data.frame(x = c(1, 2, 3, NA, 5))

  # Test subset of statistics
  result <- summarize_data(test_data, stats = c("mean", "n", "missing"))
  expect_true(all(c("mean", "n", "missing") %in% names(result)))
  expect_false("median" %in% names(result))

  # Check values
  expect_equal(result$n, 5)
  expect_equal(result$missing, 1)
  expect_equal(result$mean, 2.75)  # (1+2+3+5)/4
})

test_that("summarize_data validates input correctly", {
  # Test non-data.frame input
  expect_error(summarize_data("not a data frame"), "'data' must be a data.frame")
  expect_error(summarize_data(matrix(1:4, 2, 2)), "'data' must be a data.frame")

  # Test empty data
  expect_error(summarize_data(data.frame()), "'data' must have at least one row")

  # Test invalid column names
  test_data <- data.frame(x = 1:3, y = 4:6)
  expect_error(summarize_data(test_data, columns = "z"), "Columns not found in data: z")
  expect_error(summarize_data(test_data, columns = c("x", "missing_col")),
               "Columns not found in data: missing_col")

  # Test non-character columns parameter
  expect_error(summarize_data(test_data, columns = 1), "'columns' must be a character vector")

  # Test invalid statistics
  expect_error(summarize_data(test_data, stats = "invalid_stat"), "Invalid statistics: invalid_stat")
  expect_error(summarize_data(test_data, stats = c("mean", "fake_stat")), "Invalid statistics: fake_stat")

  # Test invalid round_digits
  expect_error(summarize_data(test_data, round_digits = "two"), "'round_digits' must be a non-negative integer")
  expect_error(summarize_data(test_data, round_digits = -1), "'round_digits' must be a non-negative integer")
  expect_error(summarize_data(test_data, round_digits = c(2, 3)), "'round_digits' must be a non-negative integer")
})

test_that("summarize_data handles edge cases", {
  # Test data with only non-numeric columns
  non_numeric_data <- data.frame(
    letters = letters[1:3],
    factors = factor(c("A", "B", "C"))
  )
  expect_error(summarize_data(non_numeric_data), "No numeric columns found in data")

  # Test data with missing values
  test_data <- data.frame(
    x = c(1, NA, 3),
    y = c(NA, NA, NA)
  )
  result <- summarize_data(test_data)

  x_row <- result[result$variable == "x", ]
  y_row <- result[result$variable == "y", ]

  expect_equal(x_row$missing, 1)
  expect_equal(y_row$missing, 3)
  expect_equal(x_row$n, 3)
  expect_true(is.nan(y_row$mean))  # mean of all NA is NaN
})

test_that("rounding works correctly in summarize_data", {
  test_data <- data.frame(x = c(1/3, 2/3, 1))

  # Test default rounding (2 digits)
  result_default <- summarize_data(test_data, stats = "mean")
  expect_equal(result_default$mean, 0.67)  # (1/3 + 2/3 + 1) / 3 ≈ 0.6667 rounded to 0.67

  # Test custom rounding
  result_custom <- summarize_data(test_data, stats = "mean", round_digits = 4)
  expect_equal(result_custom$mean, 0.6667)

  # Test no rounding (round_digits = 0 still rounds to integers)
  result_zero <- summarize_data(test_data, stats = "mean", round_digits = 0)
  expect_equal(result_zero$mean, 1)  # 0.6667 rounded to 0 decimal places = 1
})