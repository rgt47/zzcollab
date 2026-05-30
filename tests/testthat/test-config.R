# Tests for configuration functions
# These tests validate the config system behavior

test_that("get_config_default returns defaults correctly", {
  skip_if_not(file.exists("zzcollab.sh"), "zzcollab script not found in current directory")

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
  skip_if_not(file.exists("zzcollab.sh"), "zzcollab script not found in current directory")

  # Test that set_config requires key
  expect_error(set_config(), "argument.*is missing")

  # Test that get_config can handle NULL
  result <- get_config(NULL)
  expect_null(result)
})

test_that("list_config returns character vector or NULL", {
  skip_if_not(file.exists("zzcollab.sh"), "zzcollab script not found in current directory")

  result <- list_config()
  expect_true(is.character(result) || is.null(result))
})

test_that("validate_config handles missing config gracefully", {
  skip_if_not(file.exists("zzcollab.sh"), "zzcollab script not found in current directory")

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

# Round-trip tests against the real CLI. These exercise the exact command
# strings the wrappers build, so an interface drift (e.g. the removed
# `--config` flag form, or a renamed subcommand) fails here instead of
# silently returning NULL/FALSE in production. Regression guard for the
# 0.9.2 wrapper fixes.
# Skip helper: a script is usable only if find_zzcollab_script() locates one
# that supports the `config` subcommands. This runs wherever zzc/zzcollab is
# installed (CI, dev machine), not only when zzcollab.sh sits in cwd.
skip_without_cli <- function() {
  ok <- tryCatch({ find_zzcollab_script(); TRUE },
                 error = function(e) FALSE)
  skip_if_not(ok, "no zzcollab CLI with config support found")
}

test_that("set_config / get_config round-trip through the CLI", {
  skip_on_cran()
  skip_without_cli()

  # Isolate the user config so we never touch the developer's real ~/.zzcollab
  tmp_home <- tempfile("zzc-home-")
  dir.create(tmp_home, recursive = TRUE)
  old_env <- Sys.getenv(
    c("ZZCOLLAB_CONFIG_USER_DIR", "ZZCOLLAB_CONFIG_USER"),
    unset = NA, names = TRUE
  )
  Sys.setenv(
    ZZCOLLAB_CONFIG_USER_DIR = tmp_home,
    ZZCOLLAB_CONFIG_USER = file.path(tmp_home, "config.yaml")
  )
  on.exit({
    for (nm in names(old_env)) {
      if (is.na(old_env[[nm]])) Sys.unsetenv(nm) else Sys.setenv(structure(list(old_env[[nm]]), names = nm))
    }
    unlink(tmp_home, recursive = TRUE)
  }, add = TRUE)

  expect_true(init_config())

  # A value written via set_config must be readable via get_config.
  expect_true(set_config("github_account", "rt_roundtrip_test"))
  expect_equal(get_config("github_account"), "rt_roundtrip_test")

  # validate_config must succeed on the config we just wrote.
  expect_true(validate_config())
})

test_that("zzcollab_next_steps returns guidance, not an error topic", {
  skip_on_cran()
  skip_without_cli()

  result <- zzcollab_next_steps()
  expect_true(is.character(result))
  # Must not be the dispatcher's unknown-topic message.
  expect_false(any(grepl("Unknown help topic", result)))
  expect_true(any(grepl("NEXT STEPS|make docker-build", result)))
})
