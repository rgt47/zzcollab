library(tinytest)

# Topics accepted by the CLI dispatcher in modules/help.sh.
help_topics <- c("docker", "profiles", "config", "next-steps")

# zzcollab_help rejects invalid topics (pure R validation, no CLI needed)
expect_error(
  zzcollab_help("invalid_topic_xyz"),
  "Unknown.*topic"
)

# Topics removed in the 0.9.x trim must be rejected
expect_error(
  zzcollab_help("troubleshooting"),
  "Unknown.*topic"
)

expect_error(
  zzcollab_help("variants"),
  "Unknown.*topic"
)

# zzcollab_help lists current valid topics in error message
result <- tryCatch({
  zzcollab_help("invalid")
}, error = function(e) {
  msg <- e$message
  expect_true(grepl("Unknown", msg))
  expect_true(grepl("docker", msg))
  expect_true(grepl("profiles", msg))
  expect_true(grepl("config", msg))
  expect_false(grepl("troubleshooting", msg))
  expect_false(grepl("variants", msg))
  TRUE
})
expect_true(result)

# zzcollab_help and zzcollab_next_steps fail gracefully without a CLI script
result <- tryCatch({
  zzcollab_help(NULL)
}, error = function(e) {
  expect_true(grepl("zzcollab.*script", e$message, ignore.case = TRUE))
  character(0)
})
expect_true(is.character(result))

result <- tryCatch({
  zzcollab_next_steps()
}, error = function(e) {
  expect_true(grepl("zzcollab.*script", e$message, ignore.case = TRUE))
  character(0)
})
expect_true(is.character(result))

# Mock-based routing tests: local_mocked_bindings requires a testthat test_that()
# environment to bind correctly. Wrap each section so the mock takes effect.
if (!requireNamespace("testthat", quietly = TRUE)) {
  exit_file("testthat not available -- skipping mock-based routing tests")
}

# zzcollab_help builds 'help TOPIC' commands for valid topics
testthat::test_that("zzcollab_help routes topics via help subcommand", {
  calls <- character(0)
  testthat::local_mocked_bindings(
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
    testthat::expect_true(any(grepl(paste("zzcollab help", topic), calls, fixed = TRUE)))
  }
})

# zzcollab_help with NULL or 'general' builds the bare help command
testthat::test_that("zzcollab_help NULL and general build bare help command", {
  calls <- character(0)
  testthat::local_mocked_bindings(
    find_zzcollab_script = function() "zzcollab",
    safe_system = function(command, ...) {
      calls[[length(calls) + 1]] <<- command
      character(0)
    },
    .package = "zzcollab"
  )
  zzcollab_help(NULL)
  zzcollab_help("general")
  testthat::expect_true(all(grepl("^zzcollab help$", trimws(calls))))
})

# zzcollab_help routes via 'help' subcommand (not a --help-TOPIC flag)
testthat::test_that("zzcollab_help uses help subcommand not --help-TOPIC flag", {
  captured <- NULL
  testthat::local_mocked_bindings(
    find_zzcollab_script = function() "zzcollab",
    safe_system = function(command, ...) {
      captured <<- command
      character(0)
    },
    .package = "zzcollab"
  )
  zzcollab_help("docker")
  testthat::expect_true(grepl("zzcollab help docker", captured, fixed = TRUE))
  testthat::expect_false(grepl("--help-docker", captured, fixed = TRUE))
})
