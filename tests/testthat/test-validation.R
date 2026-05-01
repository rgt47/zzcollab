# Tests for validation functions and error handling
# Tests for Phase 2 improvements: safe_system(), validate_docker_name(), validate_path()

test_that("validate_docker_name accepts valid names", {
  # Valid Docker names
  expect_true(validate_docker_name("myteam", "team_name"))
  expect_true(validate_docker_name("my-team", "team_name"))
  expect_true(validate_docker_name("my.team", "team_name"))
  expect_true(validate_docker_name("my_team", "team_name"))
  expect_true(validate_docker_name("myteam123", "team_name"))
  expect_true(validate_docker_name("ab", "team_name"))  # Minimum 2 chars
  expect_true(validate_docker_name(paste(rep("a", 255), collapse = ""), "team_name"))  # Max length
})

test_that("validate_docker_name rejects invalid names", {
  # Empty string
  expect_error(
    validate_docker_name("", "team_name"),
    "team_name cannot be empty"
  )

  # Not a character
  expect_error(
    validate_docker_name(123, "team_name"),
    "team_name must be a single character string"
  )

  # Multiple values
  expect_error(
    validate_docker_name(c("team1", "team2"), "team_name"),
    "team_name must be a single character string"
  )

  # Starts with dot
  expect_error(
    validate_docker_name(".myteam", "team_name"),
    "team_name cannot start with a dot or hyphen"
  )

  # Starts with hyphen
  expect_error(
    validate_docker_name("-myteam", "team_name"),
    "team_name cannot start with a dot or hyphen"
  )

  # Contains uppercase
  expect_error(
    validate_docker_name("MyTeam", "team_name"),
    "team_name must contain only lowercase"
  )

  # Contains spaces
  expect_error(
    validate_docker_name("my team", "team_name"),
    "team_name must contain only lowercase"
  )

  # Contains special characters
  expect_error(
    validate_docker_name("my@team", "team_name"),
    "team_name must contain only lowercase"
  )

  # Too long
  expect_error(
    validate_docker_name(paste(rep("a", 256), collapse = ""), "team_name"),
    "team_name must be 255 characters or less"
  )
})

test_that("validate_path handles NULL values", {
  # NULL should return NULL
  expect_null(validate_path(NULL, "some_path"))
})

test_that("validate_path normalizes valid paths", {
  # Should normalize path
  result <- validate_path("~/test", "test_path")
  expect_type(result, "character")
  expect_length(result, 1)
  # Should expand ~
  expect_false(grepl("^~", result))
})

test_that("validate_path rejects invalid input", {
  # Not a character
  expect_error(
    validate_path(123, "test_path"),
    "test_path must be a single character string"
  )

  # Multiple values
  expect_error(
    validate_path(c("path1", "path2"), "test_path"),
    "test_path must be a single character string"
  )
})

test_that("validate_path checks existence when required", {
  # Create a temporary file
  temp_file <- tempfile()
  file.create(temp_file)
  on.exit(unlink(temp_file))

  # Should succeed for existing file
  expect_type(validate_path(temp_file, "test_path", must_exist = TRUE), "character")

  # Should fail for non-existent file
  expect_error(
    validate_path("/nonexistent/path/file.txt", "test_path", must_exist = TRUE),
    "test_path does not exist"
  )
})

test_that("safe_system handles successful commands", {
  # Simple successful command
  result <- safe_system("echo 'test'", intern = TRUE)
  expect_type(result, "character")
  expect_equal(result, "test")

  # Command that returns exit code
  result <- safe_system("echo 'test'", intern = FALSE)
  expect_equal(result, 0)
})

test_that("safe_system handles failed commands", {
  skip_on_os("windows")

  # Command that fails (non-zero exit code)
  expect_warning(
    result <- safe_system("exit 1", intern = FALSE),
    "Command failed with exit code 1"
  )
  expect_equal(result, 1)

  # Command with custom error message
  expect_warning(
    safe_system("exit 1", intern = FALSE, error_msg = "Custom error"),
    "Custom error.*exit code: 1"
  )
})

test_that("safe_system handles command errors", {
  # Command that doesn't exist
  expect_error(
    safe_system("nonexistent_command_12345", intern = TRUE),
    "System command error"
  )

  # Command with custom error message
  expect_error(
    safe_system("nonexistent_command_12345", intern = TRUE, error_msg = "Custom error"),
    "Custom error"
  )
})

test_that("safe_system respects ignore flags", {
  # Should suppress stdout
  result <- safe_system("echo 'test'", intern = FALSE, ignore.stdout = TRUE)
  expect_equal(result, 0)

  # Should suppress stderr
  result <- safe_system("echo 'test' >&2", intern = FALSE, ignore.stderr = TRUE)
  expect_equal(result, 0)
})

test_that("safe_system integrates with find_zzcollab_script", {
  # This tests the real-world usage of safe_system
  skip_if_not(file.exists("zzcollab.sh"), "zzcollab.sh not found")

  # find_zzcollab_script uses safe_system internally
  result <- find_zzcollab_script()
  expect_type(result, "character")
  expect_length(result, 1)
})

test_that("validation functions provide helpful error messages", {
  # validate_docker_name should mention parameter name
  expect_error(
    validate_docker_name("", "project_name"),
    "project_name cannot be empty"
  )

  expect_error(
    validate_docker_name("My Project", "github_account"),
    "github_account must contain only lowercase"
  )

  # validate_path should mention parameter name
  expect_error(
    validate_path(c("a", "b"), "some_path"),
    "some_path must be a single character string"
  )

  expect_error(
    validate_path("/nonexistent", "config_file", must_exist = TRUE),
    "config_file does not exist"
  )
})

test_that("edge cases are handled correctly", {
  # validate_docker_name with minimum length
  expect_true(validate_docker_name("ab", "name"))

  # validate_docker_name with all allowed characters
  expect_true(validate_docker_name("abc123._-xyz", "name"))

  # validate_path with relative path
  result <- validate_path(".", "current_dir")
  expect_type(result, "character")
  expect_true(nchar(result) > 1)  # Should be expanded to absolute path
})
