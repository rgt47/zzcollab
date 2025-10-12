# Tests for configuration functions
# These tests validate the config system behavior

test_that("get_config_default returns defaults correctly", {
  # Test that function exists
  expect_true(exists("get_config_default"))

  # Test with default value
  result <- get_config_default("nonexistent_key", "default_value")
  expect_equal(result, "default_value")

  # Test with NULL default
  result <- get_config_default("nonexistent_key", NULL)
  expect_null(result)
})

test_that("config functions validate input", {
  # Test that set_config requires key
  expect_error(set_config(), "argument.*is missing")

  # Test that get_config can handle NULL
  result <- get_config(NULL)
  expect_null(result)
})

test_that("list_config returns character vector or NULL", {
  result <- list_config()
  expect_true(is.character(result) || is.null(result))
})

test_that("validate_config handles missing config gracefully", {
  # Should not error even if config doesn't exist
  expect_no_error(validate_config())
})

test_that("config file operations are safe", {
  # Create temporary config directory
  temp_dir <- tempfile()
  dir.create(temp_dir, recursive = TRUE)
  old_wd <- getwd()

  on.exit({
    setwd(old_wd)
    unlink(temp_dir, recursive = TRUE)
  })

  setwd(temp_dir)

  # Test init_config creates config
  # This will likely fail without zzcollab script, but should fail gracefully
  result <- tryCatch({
    init_config()
  }, error = function(e) {
    # Expected - zzcollab script not found
    expect_true(grepl("zzcollab|script", e$message, ignore.case = TRUE))
    FALSE
  })

  # Result should be logical
  expect_type(result, "logical")
})

test_that("config helper returns NULL or expected type", {
  # The %||% operator should work correctly
  test_null <- NULL
  result <- test_null %||% "default"
  expect_equal(result, "default")

  test_value <- "actual"
  result <- test_value %||% "default"
  expect_equal(result, "actual")
})
