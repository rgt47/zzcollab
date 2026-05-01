# Test helper functions and sample data for penguin data tests

# Create sample penguin data for testing
create_sample_penguin_data <- function(n_rows = 10, include_missing = FALSE) {
  set.seed(42)  # For reproducible test data
  
  species_options <- c("Adelie", "Chinstrap", "Gentoo")
  island_options <- c("Torgersen", "Dream", "Biscoe")
  sex_options <- c("male", "female")
  year_options <- c(2007, 2008, 2009)
  
  data <- data.frame(
    species = sample(species_options, n_rows, replace = TRUE),
    island = sample(island_options, n_rows, replace = TRUE),
    bill_length_mm = round(runif(n_rows, 35, 50), 1),
    bill_depth_mm = round(runif(n_rows, 15, 22), 1),
    flipper_length_mm = as.integer(runif(n_rows, 170, 220)),
    body_mass_g = as.integer(runif(n_rows, 3000, 5000)),
    sex = sample(sex_options, n_rows, replace = TRUE),
    year = sample(year_options, n_rows, replace = TRUE),
    stringsAsFactors = FALSE
  )
  
  # Optionally introduce some missing values for testing
  if (include_missing && n_rows > 3) {
    # Introduce ~10% missing values in some columns
    missing_indices <- sample(seq_len(n_rows), size = max(1, floor(n_rows * 0.1)))
    data$bill_length_mm[missing_indices] <- NA
    
    # Add some missing body mass values
    mass_missing_indices <- sample(seq_len(n_rows), size = max(1, floor(n_rows * 0.05)))
    data$body_mass_g[mass_missing_indices] <- NA
    
    # Add some missing sex values
    sex_missing_indices <- sample(seq_len(n_rows), size = max(1, floor(n_rows * 0.15)))
    data$sex[sex_missing_indices] <- NA
  }
  
  return(data)
}

# Create invalid sample data for testing error conditions
create_invalid_penguin_data <- function(error_type = "missing_columns") {
  base_data <- create_sample_penguin_data(5)
  
  switch(error_type,
    "missing_columns" = base_data[, c("species", "bill_length_mm")],  # Missing required columns
    "wrong_types" = {
      base_data$bill_length_mm <- as.character(base_data$bill_length_mm)  # Wrong data type
      base_data$body_mass_g <- paste(base_data$body_mass_g, "grams")  # Wrong data type
      base_data
    },
    "invalid_values" = {
      base_data$body_mass_g[1] <- -500  # Negative body mass
      base_data$body_mass_g[2] <- 15000  # Unreasonably large
      base_data$species[3] <- "Emperor"  # Invalid species
      base_data$island[4] <- "Antarctica"  # Invalid island
      base_data
    },
    "empty_data" = data.frame(),
    base_data
  )
}

# Helper function to check if log transformation is mathematically correct
expect_log_transformation_correct <- function(data, mass_col = "body_mass_g", log_col = "log_body_mass_g") {
  if (!all(c(mass_col, log_col) %in% names(data))) {
    stop("Required columns not found in data")
  }
  
  # Remove rows with missing values for comparison
  complete_rows <- !is.na(data[[mass_col]]) & !is.na(data[[log_col]])
  if (sum(complete_rows) == 0) {
    stop("No complete cases for log transformation check")
  }
  
  expected_log <- log(data[[mass_col]][complete_rows])
  actual_log <- data[[log_col]][complete_rows]
  
  testthat::expect_equal(actual_log, expected_log, tolerance = 1e-10,
                        info = "Log transformation should be mathematically correct")
}

# Helper function to validate basic penguin data structure
expect_valid_penguin_structure <- function(data, min_rows = 1) {
  testthat::expect_s3_class(data, "data.frame")
  testthat::expect_gte(nrow(data), min_rows, info = paste("Should have at least", min_rows, "rows"))
  
  required_cols <- c("species", "island", "bill_length_mm", "bill_depth_mm", 
                     "flipper_length_mm", "body_mass_g", "sex", "year")
  missing_cols <- setdiff(required_cols, names(data))
  testthat::expect_length(missing_cols, 0, 
                         info = paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
}

# Helper to create temporary test files
create_temp_penguin_csv <- function(data, filename = "test_penguins.csv") {
  temp_dir <- tempdir()
  temp_file <- file.path(temp_dir, filename)
  write.csv(data, temp_file, row.names = FALSE)
  return(temp_file)
}

# Clean up temporary files
cleanup_temp_files <- function(file_paths) {
  for (file_path in file_paths) {
    if (file.exists(file_path)) {
      unlink(file_path)
    }
  }
}

# Helper to check data quality metrics
expect_reasonable_data_quality <- function(data) {
  # Check for excessive missing data
  missing_percentage <- function(x) sum(is.na(x)) / length(x) * 100
  
  for (col in names(data)) {
    missing_pct <- missing_percentage(data[[col]])
    testthat::expect_lt(missing_pct, 80, 
                       info = paste("Column", col, "has", round(missing_pct, 1), "% missing data"))
  }
  
  # Check for duplicate rows
  duplicate_count <- nrow(data) - nrow(unique(data))
  testthat::expect_lt(duplicate_count / nrow(data), 0.5, 
                     info = "Should not have excessive duplicate rows")
  
  # Check that numeric columns have reasonable variance
  numeric_cols <- sapply(data, is.numeric)
  for (col_name in names(data)[numeric_cols]) {
    col_data <- data[[col_name]][!is.na(data[[col_name]])]
    if (length(col_data) > 1) {
      col_var <- var(col_data)
      testthat::expect_gt(col_var, 0, 
                         info = paste("Column", col_name, "should have some variance"))
    }
  }
}

# Set up common test environment
setup_test_environment <- function() {
  # Ensure required packages are available for testing
  if (!requireNamespace("here", quietly = TRUE)) {
    stop("here package required for tests")
  }
  
  # Set seed for reproducible tests
  set.seed(12345)
  
  # Return environment info for debugging
  list(
    r_version = R.version.string,
    working_directory = getwd(),
    temp_directory = tempdir()
  )
}