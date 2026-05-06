# Integration tests for the complete data pipeline
# Tests the full workflow from raw data to derived data

library(here)

raw_data_file <- here('data', 'raw_data', 'penguins.csv')
if (!file.exists(raw_data_file)) {
  exit_file('Raw data not available for pipeline test')
}

if (!exists('prepare_penguin_subset') ||
    !exists('validate_penguin_data') ||
    !exists('summarize_penguin_data')) {
  exit_file('Pipeline functions not loaded')
}

# --- Complete data pipeline runs successfully ---
penguins_raw <- read.csv(raw_data_file, stringsAsFactors = FALSE)
expect_inherits(penguins_raw, 'data.frame')
expect_true(nrow(penguins_raw) > 0)

expect_true(validate_penguin_data(penguins_raw),
            info = 'Raw data should pass validation checks')

penguins_subset <- prepare_penguin_subset(penguins_raw, n_records = 50)
expect_inherits(penguins_subset, 'data.frame')
expect_true(nrow(penguins_subset) <= 50)
expect_true('log_body_mass_g' %in% names(penguins_subset))

expected_log <- log(penguins_subset$body_mass_g)
expect_equal(penguins_subset$log_body_mass_g, expected_log, tolerance = 1e-10)

expect_false(any(is.na(penguins_subset$body_mass_g)))
expect_false(any(is.na(penguins_subset$log_body_mass_g)))

# --- Pipeline is deterministic ---
result1 <- prepare_penguin_subset(penguins_raw, n_records = 30)
result2 <- prepare_penguin_subset(penguins_raw, n_records = 30)
expect_equal(result1, result2)

# --- Edge cases handled ---
small_subset <- prepare_penguin_subset(penguins_raw, n_records = 1)
expect_equal(nrow(small_subset), 1)
expect_true('log_body_mass_g' %in% names(small_subset))

max_records <- nrow(penguins_raw)
expect_warning(
  large_subset <- prepare_penguin_subset(penguins_raw, n_records = max_records + 10),
  pattern = 'requested'
)
expect_true(nrow(large_subset) <= max_records)

# --- Summary statistics are reasonable ---
summary_stats <- summarize_penguin_data(penguins_subset)
expect_inherits(summary_stats, 'data.frame')
expect_true(nrow(summary_stats) > 0)

if ('body_mass_g' %in% summary_stats$variable) {
  body_mass_stats <- summary_stats[summary_stats$variable == 'body_mass_g', ]
  expect_true(body_mass_stats$mean > 2000)
  expect_true(body_mass_stats$mean < 6000)
  expect_true(body_mass_stats$sd > 0)
}

# --- Log transformation produces no impossible values ---
expect_false(any(is.infinite(penguins_subset$log_body_mass_g)))
expect_false(any(penguins_subset$log_body_mass_g < 0 &
                 !is.na(penguins_subset$log_body_mass_g)))

# --- Error handling works ---
invalid_data <- data.frame(
  not_a_penguin_column = c('A', 'B', 'C'),
  another_wrong_column = c(1, 2, 3)
)

expect_error(prepare_penguin_subset(invalid_data), pattern = 'body_mass_g')
expect_false(validate_penguin_data(invalid_data))
expect_error(summarize_penguin_data(invalid_data), pattern = 'validation failed')
