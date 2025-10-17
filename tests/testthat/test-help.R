# Tests for help system

test_that("zzcollab_help accepts valid topics", {
  valid_topics <- c(
    "init", "github", "quickstart", "workflow",
    "troubleshooting", "config", "dotfiles", "renv",
    "docker", "cicd", "next-steps"
  )

  for (topic in valid_topics) {
    # Should not error on topic validation
    result <- tryCatch({
      zzcollab_help(topic)
    }, error = function(e) {
      # Expect zzcollab script error, not topic validation error
      expect_false(grepl("Unknown.*topic", e$message))
      expect_true(grepl("zzcollab.*script", e$message, ignore.case = TRUE))
      character(0)
    })

    expect_type(result, "character")
  }
})

test_that("zzcollab_help rejects invalid topics", {
  skip_if_not(file.exists("zzcollab.sh"), "zzcollab script not found in current directory")

  # Invalid topic should error with helpful message
  expect_error(
    zzcollab_help("invalid_topic_xyz"),
    "Unknown.*topic"
  )

  expect_error(
    zzcollab_help("variants"),  # variants was removed
    "Unknown.*topic"
  )
})

test_that("zzcollab_help works with NULL (general help)", {
  result <- tryCatch({
    zzcollab_help(NULL)
  }, error = function(e) {
    expect_true(grepl("zzcollab.*script", e$message, ignore.case = TRUE))
    character(0)
  })

  expect_type(result, "character")
})

test_that("zzcollab_help lists all valid topics in error", {
  skip_if_not(file.exists("zzcollab.sh"), "zzcollab script not found in current directory")

  # Error message should list valid topics
  result <- tryCatch({
    zzcollab_help("invalid")
  }, error = function(e) {
    msg <- e$message

    # Should mention it's unknown
    expect_true(grepl("Unknown", msg))

    # Should list valid topics
    expect_true(grepl("init", msg))
    expect_true(grepl("docker", msg))
    expect_true(grepl("config", msg))

    # Should NOT mention removed topics
    expect_false(grepl("variants", msg))
    expect_false(grepl("build-modes", msg))

    TRUE
  })

  expect_true(result)
})

test_that("zzcollab_next_steps works", {
  result <- tryCatch({
    zzcollab_next_steps()
  }, error = function(e) {
    expect_true(grepl("zzcollab.*script", e$message, ignore.case = TRUE))
    character(0)
  })

  expect_type(result, "character")
})

test_that("help system uses new --help TOPIC pattern", {
  skip_if_not(exists("find_zzcollab_script"))

  # Mock find_zzcollab_script
  local_mocked_bindings(
    find_zzcollab_script = function() "/usr/local/bin/zzcollab",
    .package = "zzcollab"
  )

  # Capture the command that would be executed
  # The new pattern should be: zzcollab --help TOPIC
  # Not: zzcollab --help-TOPIC

  result <- tryCatch({
    zzcollab_help("docker")
  }, error = function(e) {
    # Command construction error should show our new pattern
    # Old pattern: --help-docker
    # New pattern: --help docker
    expect_false(grepl("--help-docker", e$message))
    TRUE
  })
})
