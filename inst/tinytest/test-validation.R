library(tinytest)

# Tests for validation functions and error handling
# Tests for safe_system() and validate_docker_name()

# validate_docker_name accepts valid names
# Valid Docker names
expect_true(zzcollab:::validate_docker_name("myteam", "team_name"))
expect_true(zzcollab:::validate_docker_name("my-team", "team_name"))
expect_true(zzcollab:::validate_docker_name("my.team", "team_name"))
expect_true(zzcollab:::validate_docker_name("my_team", "team_name"))
expect_true(zzcollab:::validate_docker_name("myteam123", "team_name"))
expect_true(zzcollab:::validate_docker_name("ab", "team_name"))
expect_true(zzcollab:::validate_docker_name(paste(rep("a", 255), collapse = ""), "team_name"))

# validate_docker_name rejects invalid names
# Empty string
expect_error(
  zzcollab:::validate_docker_name("", "team_name"),
  "team_name cannot be empty"
)

# Not a character
expect_error(
  zzcollab:::validate_docker_name(123, "team_name"),
  "team_name must be a single character string"
)

# Multiple values
expect_error(
  zzcollab:::validate_docker_name(c("team1", "team2"), "team_name"),
  "team_name must be a single character string"
)

# Starts with dot
expect_error(
  zzcollab:::validate_docker_name(".myteam", "team_name"),
  "team_name cannot start with a dot or hyphen"
)

# Starts with hyphen
expect_error(
  zzcollab:::validate_docker_name("-myteam", "team_name"),
  "team_name cannot start with a dot or hyphen"
)

# Contains uppercase
expect_error(
  zzcollab:::validate_docker_name("MyTeam", "team_name"),
  "team_name must contain only lowercase"
)

# Contains spaces
expect_error(
  zzcollab:::validate_docker_name("my team", "team_name"),
  "team_name must contain only lowercase"
)

# Contains special characters
expect_error(
  zzcollab:::validate_docker_name("my@team", "team_name"),
  "team_name must contain only lowercase"
)

# Too long
expect_error(
  zzcollab:::validate_docker_name(paste(rep("a", 256), collapse = ""), "team_name"),
  "team_name must be 255 characters or less"
)

# safe_system handles successful commands
# Simple successful command
result <- zzcollab:::safe_system("echo 'test'", intern = TRUE)
expect_true(is.character(result))
expect_equal(result, "test")

# Command that returns exit code
result <- zzcollab:::safe_system("echo 'test'", intern = FALSE)
expect_equal(result, 0)

# safe_system handles failed commands (shell-dependent: skip on Windows)
if (.Platform$OS.type != "windows") {
  expect_warning(
    result <- zzcollab:::safe_system("exit 1", intern = FALSE),
    "Command failed with exit code 1"
  )
  expect_equal(result, 1)

  expect_warning(
    zzcollab:::safe_system("exit 1", intern = FALSE, error_msg = "Custom error"),
    "Custom error.*exit code: 1"
  )

  expect_error(
    zzcollab:::safe_system("nonexistent_command_12345", intern = TRUE),
    "System command error"
  )

  expect_error(
    zzcollab:::safe_system("nonexistent_command_12345", intern = TRUE, error_msg = "Custom error"),
    "Custom error"
  )

  result <- zzcollab:::safe_system("echo 'test'", intern = FALSE, ignore.stdout = TRUE)
  expect_equal(result, 0)

  result <- zzcollab:::safe_system("echo 'test' >&2", intern = FALSE, ignore.stderr = TRUE)
  expect_equal(result, 0)
}

# safe_system integrates with find_zzcollab_script
if (file.exists("zzcollab.sh")) {
  result <- zzcollab:::find_zzcollab_script()
  expect_true(is.character(result))
  expect_equal(length(result), 1L)
}

# validation functions provide helpful error messages
# validate_docker_name should mention parameter name
expect_error(
  zzcollab:::validate_docker_name("", "project_name"),
  "project_name cannot be empty"
)

expect_error(
  zzcollab:::validate_docker_name("My Project", "github_account"),
  "github_account must contain only lowercase"
)

# edge cases are handled correctly
# validate_docker_name with minimum length
expect_true(zzcollab:::validate_docker_name("ab", "name"))

# validate_docker_name with all allowed characters
expect_true(zzcollab:::validate_docker_name("abc123._-xyz", "name"))
