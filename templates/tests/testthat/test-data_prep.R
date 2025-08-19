test_that("prepare_penguin_subset works with valid data", {
  # Create test data
  test_data <- data.frame(
    species = c("Adelie", "Chinstrap", "Gentoo", "Adelie", "Gentoo"),
    island = c("Torgersen", "Dream", "Biscoe", "Torgersen", "Biscoe"),
    bill_length_mm = c(39.1, 39.5, 46.1, 38.2, 42.0),
    bill_depth_mm = c(18.7, 17.4, 17.8, 18.1, 17.5),
    flipper_length_mm = c(181L, 186L, 193L, 180L, 197L),
    body_mass_g = c(3750L, 3800L, 4400L, 3900L, 4250L),
    sex = c("male", "female", "male", "male", "female"),
    year = c(2007L, 2008L, 2009L, 2007L, 2008L)
  )
  
  # Test basic functionality
  result <- prepare_penguin_subset(test_data, n_records = 3)
  
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
  expect_true("log_body_mass_g" %in% names(result))
  expect_equal(length(names(result)), length(names(test_data)) + 1)
  
  # Test log transformation
  expected_log <- log(test_data$body_mass_g[1:3])
  expect_equal(result$log_body_mass_g, expected_log)
})

test_that("prepare_penguin_subset handles missing body mass correctly", {
  # Test data with missing body mass
  test_data <- data.frame(
    species = c("Adelie", "Chinstrap", "Gentoo"),
    body_mass_g = c(3750, NA, 4400),
    year = c(2007, 2008, 2009)
  )
  
  # Test with remove_na_mass = TRUE (default)
  result <- prepare_penguin_subset(test_data, n_records = 3, remove_na_mass = TRUE)
  expect_equal(nrow(result), 2)
  expect_false(any(is.na(result$body_mass_g)))
  
  # Test with remove_na_mass = FALSE
  expect_error(
    prepare_penguin_subset(test_data, n_records = 3, remove_na_mass = FALSE),
    NA  # Should not error, but log(NA) will produce warning
  )
})

test_that("prepare_penguin_subset validates input correctly", {
  # Test non-data.frame input
  expect_error(
    prepare_penguin_subset("not a dataframe"),
    "Input 'data' must be a data frame"
  )
  
  # Test missing body_mass_g column
  test_data <- data.frame(species = "Adelie", bill_length_mm = 39.1)
  expect_error(
    prepare_penguin_subset(test_data),
    "Data must contain 'body_mass_g' column"
  )
  
  # Test invalid n_records
  test_data <- data.frame(body_mass_g = 3750)
  expect_error(
    prepare_penguin_subset(test_data, n_records = 0),
    "n_records must be a positive number"
  )
  
  expect_error(
    prepare_penguin_subset(test_data, n_records = "five"),
    "n_records must be a positive number"
  )
})

test_that("prepare_penguin_subset handles edge cases", {
  # Test with fewer rows than requested
  test_data <- data.frame(
    species = c("Adelie", "Chinstrap"),
    body_mass_g = c(3750, 3800)
  )
  
  expect_warning(
    result <- prepare_penguin_subset(test_data, n_records = 5),
    "Data has 2 rows but 5 requested"
  )
  expect_equal(nrow(result), 2)
  
  # Test with single row
  single_row <- data.frame(species = "Adelie", body_mass_g = 3750)
  result <- prepare_penguin_subset(single_row, n_records = 1)
  expect_equal(nrow(result), 1)
  expect_equal(result$log_body_mass_g, log(3750))
})

test_that("validate_penguin_data correctly identifies valid data", {
  # Valid penguin data
  valid_data <- data.frame(
    species = c("Adelie", "Chinstrap", "Gentoo"),
    island = c("Torgersen", "Dream", "Biscoe"),
    bill_length_mm = c(39.1, 39.5, 46.1),
    bill_depth_mm = c(18.7, 17.4, 17.8),
    flipper_length_mm = c(181, 186, 193),
    body_mass_g = c(3750, 3800, 4400),
    sex = c("male", "female", "male"),
    year = c(2007, 2008, 2009)
  )
  
  result <- validate_penguin_data(valid_data)
  expect_true(result)
  expect_null(attr(result, "validation_errors"))
})

test_that("validate_penguin_data catches data quality issues", {
  # Test non-data.frame input
  result <- validate_penguin_data("not a dataframe")
  expect_false(result)
  expect_match(attr(result, "validation_errors"), "not a data frame")
  
  # Test missing required columns
  incomplete_data <- data.frame(species = "Adelie")
  result <- validate_penguin_data(incomplete_data)
  expect_false(result)
  expect_match(attr(result, "validation_errors"), "Missing required columns")
  
  # Test wrong data types
  wrong_types <- data.frame(
    species = "Adelie",
    island = "Torgersen", 
    bill_length_mm = "39.1",  # Should be numeric
    bill_depth_mm = 18.7,
    flipper_length_mm = 181,
    body_mass_g = 3750,
    sex = "male",
    year = 2007
  )
  result <- validate_penguin_data(wrong_types)
  expect_false(result)
  expect_match(attr(result, "validation_errors"), "should be numeric")
  
  # Test unreasonable values
  bad_values <- data.frame(
    species = "Adelie",
    island = "Torgersen",
    bill_length_mm = 39.1,
    bill_depth_mm = 18.7,
    flipper_length_mm = 181,
    body_mass_g = -100,  # Negative body mass
    sex = "male",
    year = 2007
  )
  result <- validate_penguin_data(bad_values)
  expect_false(result)
  expect_match(attr(result, "validation_errors"), "non-positive values")
  
  # Test unexpected species
  bad_species <- data.frame(
    species = "Emperor",  # Not in expected species
    island = "Torgersen",
    bill_length_mm = 39.1,
    bill_depth_mm = 18.7,
    flipper_length_mm = 181,
    body_mass_g = 3750,
    sex = "male",
    year = 2007
  )
  result <- validate_penguin_data(bad_species)
  expect_false(result)
  expect_match(attr(result, "validation_errors"), "Unexpected species")
})

test_that("summarize_penguin_data produces correct summaries", {
  test_data <- data.frame(
    species = c("Adelie", "Adelie", "Chinstrap", "Chinstrap"),
    bill_length_mm = c(39.1, 38.2, 39.5, 40.1),
    bill_depth_mm = c(18.7, 18.1, 17.4, 17.9),
    flipper_length_mm = c(181, 180, 186, 190),
    body_mass_g = c(3750, 3900, 3800, 4000),
    island = c("Torgersen", "Torgersen", "Dream", "Dream"),
    sex = c("male", "male", "female", "male"),
    year = c(2007, 2007, 2008, 2008)
  )
  
  # Test overall summary
  summary_result <- summarize_penguin_data(test_data)
  
  expect_s3_class(summary_result, "data.frame")
  expect_equal(nrow(summary_result), 4)  # 4 numeric columns
  expect_true(all(c("variable", "n", "mean", "sd", "min", "max") %in% names(summary_result)))
  
  # Check specific calculations
  body_mass_row <- summary_result[summary_result$variable == "body_mass_g", ]
  expect_equal(body_mass_row$n, 4)
  expect_equal(body_mass_row$mean, mean(test_data$body_mass_g))
  expect_equal(body_mass_row$min, min(test_data$body_mass_g))
  expect_equal(body_mass_row$max, max(test_data$body_mass_g))
})

test_that("summarize_penguin_data handles invalid data", {
  invalid_data <- data.frame(species = "NotAPenguin", body_mass_g = "heavy")
  
  expect_error(
    summarize_penguin_data(invalid_data),
    "Data validation failed"
  )
})