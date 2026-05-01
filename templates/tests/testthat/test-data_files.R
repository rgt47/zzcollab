# Test data files structure and integrity
# These tests check that the actual data files meet expected standards

library(testthat)

test_that("raw data files exist and are accessible", {
  # Check that raw data directory exists
  raw_data_dir <- here::here("data", "raw_data")
  expect_true(dir.exists(raw_data_dir), "Raw data directory should exist")
  
  # Check for expected raw data file
  penguins_file <- here::here("data", "raw_data", "penguins.csv")
  
  # Skip test if file doesn't exist (for new projects)
  skip_if_not(file.exists(penguins_file), "Raw data file not found - skip data tests")
  
  # Test file accessibility
  expect_true(file.exists(penguins_file), "Penguins data file should exist")
  expect_gt(file.info(penguins_file)$size, 0, "Data file should not be empty")
})

test_that("raw penguin data has correct structure", {
  penguins_file <- here::here("data", "raw_data", "penguins.csv")
  skip_if_not(file.exists(penguins_file), "Raw data file not found")
  
  # Load the data
  penguins_raw <- read.csv(penguins_file, stringsAsFactors = FALSE)
  
  # Test data frame structure
  expect_s3_class(penguins_raw, "data.frame")
  expect_gt(nrow(penguins_raw), 0, "Should have at least one row of data")
  
  # Test expected columns are present
  expected_cols <- c("species", "island", "bill_length_mm", "bill_depth_mm", 
                     "flipper_length_mm", "body_mass_g", "sex", "year")
  expect_true(all(expected_cols %in% names(penguins_raw)), 
              "All expected columns should be present")
  
  # Test data types
  expect_true(is.character(penguins_raw$species) || is.factor(penguins_raw$species))
  expect_true(is.character(penguins_raw$island) || is.factor(penguins_raw$island))
  expect_true(is.numeric(penguins_raw$bill_length_mm))
  expect_true(is.numeric(penguins_raw$bill_depth_mm))
  expect_true(is.numeric(penguins_raw$flipper_length_mm))
  expect_true(is.numeric(penguins_raw$body_mass_g))
  expect_true(is.numeric(penguins_raw$year))
})

test_that("raw penguin data has reasonable value ranges", {
  penguins_file <- here::here("data", "raw_data", "penguins.csv")
  skip_if_not(file.exists(penguins_file), "Raw data file not found")
  
  penguins_raw <- read.csv(penguins_file, stringsAsFactors = FALSE)
  
  # Test species values
  valid_species <- c("Adelie", "Chinstrap", "Gentoo")
  unique_species <- unique(penguins_raw$species[!is.na(penguins_raw$species)])
  expect_true(all(unique_species %in% valid_species), 
              "All species should be valid Palmer Penguins species")
  
  # Test islands
  valid_islands <- c("Torgersen", "Biscoe", "Dream")
  unique_islands <- unique(penguins_raw$island[!is.na(penguins_raw$island)])
  expect_true(all(unique_islands %in% valid_islands),
              "All islands should be valid Palmer Station islands")
  
  # Test numeric ranges (excluding NAs)
  bill_length <- penguins_raw$bill_length_mm[!is.na(penguins_raw$bill_length_mm)]
  if (length(bill_length) > 0) {
    expect_true(all(bill_length >= 25 & bill_length <= 65), 
                "Bill length should be between 25-65mm")
  }
  
  bill_depth <- penguins_raw$bill_depth_mm[!is.na(penguins_raw$bill_depth_mm)]
  if (length(bill_depth) > 0) {
    expect_true(all(bill_depth >= 10 & bill_depth <= 25), 
                "Bill depth should be between 10-25mm")
  }
  
  flipper_length <- penguins_raw$flipper_length_mm[!is.na(penguins_raw$flipper_length_mm)]
  if (length(flipper_length) > 0) {
    expect_true(all(flipper_length >= 150 & flipper_length <= 250), 
                "Flipper length should be between 150-250mm")
  }
  
  body_mass <- penguins_raw$body_mass_g[!is.na(penguins_raw$body_mass_g)]
  if (length(body_mass) > 0) {
    expect_true(all(body_mass >= 2000 & body_mass <= 7000), 
                "Body mass should be between 2000-7000g")
    expect_true(all(body_mass > 0), "Body mass should be positive")
  }
  
  # Test years
  years <- penguins_raw$year[!is.na(penguins_raw$year)]
  if (length(years) > 0) {
    expect_true(all(years %in% c(2007, 2008, 2009)), 
                "Years should be 2007, 2008, or 2009")
  }
})

test_that("derived data directory and files exist", {
  derived_dir <- here::here("data", "derived_data")
  expect_true(dir.exists(derived_dir), "Derived data directory should exist")
  
  # Check for expected derived file
  subset_file <- here::here("data", "derived_data", "penguins_subset.csv")
  
  # Only test if derived file exists
  if (file.exists(subset_file)) {
    expect_gt(file.info(subset_file)$size, 0, "Derived data file should not be empty")
    
    # Load and test derived data
    penguins_subset <- read.csv(subset_file, stringsAsFactors = FALSE)
    
    expect_s3_class(penguins_subset, "data.frame")
    expect_lte(nrow(penguins_subset), 50, "Subset should have at most 50 rows")
    expect_true("log_body_mass_g" %in% names(penguins_subset), 
                "Subset should have log_body_mass_g column")
    
    # Test log transformation is correct
    if ("body_mass_g" %in% names(penguins_subset) && nrow(penguins_subset) > 0) {
      calculated_log <- log(penguins_subset$body_mass_g)
      expect_equal(penguins_subset$log_body_mass_g, calculated_log,
                   tolerance = 1e-10, "Log transformation should be correct")
    }
  }
})

test_that("data quality checks pass", {
  penguins_file <- here::here("data", "raw_data", "penguins.csv")
  skip_if_not(file.exists(penguins_file), "Raw data file not found")
  
  penguins_raw <- read.csv(penguins_file, stringsAsFactors = FALSE)
  
  # Test for duplicate rows
  expect_equal(nrow(penguins_raw), nrow(unique(penguins_raw)), 
               "Should not have complete duplicate rows")
  
  # Test that we have data for each species
  if ("species" %in% names(penguins_raw)) {
    species_counts <- table(penguins_raw$species, useNA = "no")
    expect_true(all(species_counts > 0), "Should have data for each species")
    expect_gt(min(species_counts), 5, "Should have reasonable sample size per species")
  }
  
  # Test missing data patterns
  missing_counts <- sapply(penguins_raw, function(x) sum(is.na(x)))
  total_missing <- sum(missing_counts)
  total_cells <- nrow(penguins_raw) * ncol(penguins_raw)
  missing_percentage <- (total_missing / total_cells) * 100
  
  expect_lt(missing_percentage, 50, "Should have less than 50% missing data overall")
  
  # Test that body_mass_g has some valid values (needed for log transformation)
  if ("body_mass_g" %in% names(penguins_raw)) {
    valid_mass_count <- sum(!is.na(penguins_raw$body_mass_g))
    expect_gt(valid_mass_count, 0, "Should have at least some valid body mass values")
  }
})

test_that("data README file exists and is informative", {
  readme_file <- here::here("data", "README.md")
  
  if (file.exists(readme_file)) {
    readme_content <- readLines(readme_file, warn = FALSE)
    readme_text <- paste(readme_content, collapse = " ")
    
    expect_gt(length(readme_content), 10, "README should have substantial content")
    
    # Check for key sections
    expect_true(any(grepl("data.*directory", readme_content, ignore.case = TRUE)), 
                "README should describe data directory structure")
    expect_true(any(grepl("raw.data", readme_content, ignore.case = TRUE)), 
                "README should mention raw data")
    expect_true(any(grepl("derived.data|processed", readme_content, ignore.case = TRUE)), 
                "README should mention derived/processed data")
  }
})