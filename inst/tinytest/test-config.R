library(tinytest)

# All tests in this file exercise functions that depend on the zzcollab CLI or
# on unexported internals (get_config_default, %||%) that are only in scope
# when the package is loaded via devtools::load_all(), not via the installed
# library used by test_package() / R CMD check. Exit immediately in that
# context; all meaningful assertions are in the round-trip block below.
if (!file.exists("zzcollab.sh")) exit_file("zzcollab script not found in current directory")

# get_config_default returns defaults correctly
expect_true(exists("get_config_default"))

result <- get_config_default("nonexistent_key", "default_value")
expect_equal(result, "default_value")

result <- get_config_default("nonexistent_key", NULL)
expect_null(result)

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
temp_dir <- tempfile()
dir.create(temp_dir, recursive = TRUE)
old_wd <- getwd()

on.exit({
  setwd(old_wd)
  unlink(temp_dir, recursive = TRUE)
})

setwd(temp_dir)

result <- tryCatch({
  init_config()
}, error = function(e) {
  expect_true(grepl("zzcollab|script", e$message, ignore.case = TRUE))
  FALSE
})

expect_true(is.logical(result))

setwd(old_wd)

# %||% operator works correctly
expect_equal(NULL %||% "default", "default")
expect_equal("actual" %||% "default", "actual")

# Round-trip tests against the real CLI. Skip helper: a script is usable only
# if find_zzcollab_script() locates one that supports the `config` subcommands.
skip_without_cli <- function() {
  ok <- tryCatch({ find_zzcollab_script(); TRUE },
                 error = function(e) FALSE)
  if (!ok) exit_file("no zzcollab CLI with config support found")
}

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

expect_true(set_config("github_account", "rt_roundtrip_test"))
expect_equal(get_config("github_account"), "rt_roundtrip_test")

expect_true(validate_config())

# zzcollab_next_steps returns guidance, not an error topic
if (nchar(Sys.getenv("NOT_CRAN")) == 0) exit_file("skipping CLI round-trip on CRAN")
skip_without_cli()

result <- zzcollab_next_steps()
expect_true(is.character(result))
expect_false(any(grepl("Unknown help topic", result)))
expect_true(any(grepl("NEXT STEPS|make docker-build", result)))
