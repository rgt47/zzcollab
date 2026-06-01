# Tests for help system

# Topics accepted by the CLI dispatcher in modules/help.sh. "general"/NULL
# is handled separately below.
help_topics <- c("docker", "profiles", "config", "next-steps")

test_that("zzcollab_help builds 'help TOPIC' commands for valid topics", {
  calls <- character(0)
  local_mocked_bindings(
    find_zzcollab_script = function() "zzcollab",
    safe_system = function(command, ...) {
      calls[[length(calls) + 1]] <<- command
      character(0)
    },
    .package = "zzcollab"
  )

  for (topic in help_topics) {
    calls <- character(0)
    zzcollab_help(topic)
    expect_true(any(grepl(paste("zzcollab help", topic), calls, fixed = TRUE)))
  }
})

test_that("zzcollab_help with NULL or 'general' builds the bare help command", {
  calls <- character(0)
  local_mocked_bindings(
    find_zzcollab_script = function() "zzcollab",
    safe_system = function(command, ...) {
      calls[[length(calls) + 1]] <<- command
      character(0)
    },
    .package = "zzcollab"
  )

  zzcollab_help(NULL)
  zzcollab_help("general")
  expect_true(all(grepl("^zzcollab help$", trimws(calls))))
})

test_that("zzcollab_help rejects invalid topics", {
  # Topic validation happens in R before any shell call, so no script needed.
  expect_error(
    zzcollab_help("invalid_topic_xyz"),
    "Unknown.*topic"
  )

  # Topics that were valid before the help.sh trim must now be rejected.
  expect_error(
    zzcollab_help("troubleshooting"),
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

test_that("zzcollab_help lists current valid topics in error", {
  result <- tryCatch({
    zzcollab_help("invalid")
  }, error = function(e) {
    msg <- e$message

    # Should mention it's unknown
    expect_true(grepl("Unknown", msg))

    # Should list the current valid topics
    expect_true(grepl("docker", msg))
    expect_true(grepl("profiles", msg))
    expect_true(grepl("config", msg))

    # Should NOT mention removed topics
    expect_false(grepl("troubleshooting", msg))
    expect_false(grepl("variants", msg))

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

test_that("zzcollab_help routes topics via the 'help' subcommand", {
  captured <- NULL
  local_mocked_bindings(
    find_zzcollab_script = function() "zzcollab",
    safe_system = function(command, ...) {
      captured <<- command
      character(0)
    },
    .package = "zzcollab"
  )

  zzcollab_help("docker")
  # Topics use the 'help' subcommand (zzcollab help docker), not a
  # hyphenated --help-docker flag.
  expect_true(grepl("zzcollab help docker", captured, fixed = TRUE))
  expect_false(grepl("--help-docker", captured, fixed = TRUE))
})
