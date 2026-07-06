library(tinytest)

# get_config_default returns defaults correctly -- pure R, no CLI needed
expect_true(exists("get_config_default"))

result <- get_config_default("nonexistent_key", "default_value")
expect_equal(result, "default_value")

result <- get_config_default("nonexistent_key", NULL)
expect_null(result)

# %||% operator works correctly
test_null <- NULL
expect_equal(test_null %||% "default", "default")
expect_equal("actual" %||% "default", "actual")

# All remaining tests require the zzcollab CLI in cwd
if (!file.exists("zzcollab.sh")) exit_file("zzcollab script not found in current directory")

# config functions validate input
expect_error(set_config(), "argument.*is missing")

result <- get_config(NULL)
expect_null(result)

result <- list_config()
expect_true(is.character(result) || is.null(result))

# validate_config handles missing config gracefully
err_result <- tryCatch(validate_config(), error = function(e) e)
expect_false(inherits(err_result, "error"),
             info = "validate_config() should not throw")

# config file operations are safe
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
expect_true(is.logical(result))

setwd(old_wd)

# config helper returns NULL or expected type
# The %||% operator should work correctly
test_null <- NULL
result <- test_null %||% "default"
expect_equal(result, "default")

test_value <- "actual"
result <- test_value %||% "default"
expect_equal(result, "actual")

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
  if (!ok) exit_file("no zzcollab CLI with config support found")
}

# set_config / get_config round-trip through the CLI
if (nchar(Sys.getenv("NOT_CRAN")) == 0) exit_file("skipping CLI round-trip on CRAN")
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

# zzcollab_next_steps returns guidance, not an error topic
if (nchar(Sys.getenv("NOT_CRAN")) == 0) exit_file("skipping CLI round-trip on CRAN")
skip_without_cli()

result <- zzcollab_next_steps()
expect_true(is.character(result))
# Must not be the dispatcher's unknown-topic message.
expect_false(any(grepl("Unknown help topic", result)))
expect_true(any(grepl("NEXT STEPS|make docker-build", result)))
