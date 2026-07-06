library(tinytest)

# find_zzcollab_script works
# Test that the function exists
expect_true(exists("find_zzcollab_script"))

# Test that it returns a character string
# Note: This might fail if zzcollab is not installed, which is expected
skip_if_not(file.exists("zzcollab.sh"), "zzcollab.sh not found in current directory")

result <- find_zzcollab_script()
expect_type(result, "character")
expect_length(result, 1)

# helper functions exist
# Test that all exported functions exist
expect_true(exists("init_project"))
expect_true(exists("join_project"))
expect_true(exists("setup_project"))
expect_true(exists("status"))
expect_true(exists("rebuild"))
expect_true(exists("team_images"))
expect_true(exists("add_package"))
expect_true(exists("sync_env"))
expect_true(exists("run_script"))
expect_true(exists("render_report"))
expect_true(exists("validate_repro"))
expect_true(exists("git_commit"))
expect_true(exists("git_push"))
expect_true(exists("create_pr"))
expect_true(exists("git_status"))
expect_true(exists("create_branch"))
expect_true(exists("zzcollab_help"))
expect_true(exists("zzcollab_next_steps"))

# Build mode tests removed - feature eliminated in favor of dynamic package management

# function parameters are properly validated
# Test that functions fail appropriately with missing required parameters
# init_project requires project_name
expect_error(init_project(), "project_name is required")

# join_project requires project_name
expect_error(join_project(), "project_name is required")

# Docker status function works
skip_if_not(nzchar(Sys.which("docker")), "Docker not available")

result <- status()
expect_type(result, "character")
expect_gte(length(result), 0)

# team_images function works
skip_if_not(nzchar(Sys.which("docker")), "Docker not available")

result <- team_images()
expect_true(is.data.frame(result))
expect_gte(nrow(result), 0)

# git functions handle missing git repository
# Test git functions in non-git directory
# Create a temporary directory for testing
temp_dir <- tempdir()
old_wd <- getwd()

# Create a test directory
test_dir <- file.path(temp_dir, "test_git")
if (dir.exists(test_dir)) unlink(test_dir, recursive = TRUE)
dir.create(test_dir)

on.exit({
  setwd(old_wd)
  if (dir.exists(test_dir)) unlink(test_dir, recursive = TRUE)
})

setwd(test_dir)

# Test git_status in non-git directory
# This should either work (if git is installed) or fail gracefully
result <- tryCatch({
  git_status()
}, error = function(e) {
  # Expected behavior - git commands may fail in non-git directories
  expect_true(TRUE)
  character(0)
})

expect_type(result, "character")

setwd(old_wd)

# rebuild function validates Makefile exists
# Test in directory without Makefile
temp_dir <- tempfile()
dir.create(temp_dir)
old_wd <- getwd()

on.exit({
  setwd(old_wd)
  unlink(temp_dir, recursive = TRUE)
})

setwd(temp_dir)

# Should error without Makefile
expect_error(
  rebuild(),
  "No Makefile found"
)

setwd(old_wd)

# run_script validates inputs
# Should error with non-existent script
expect_error(
  run_script("/nonexistent/script.R"),
  "Script file not found"
)

# Should error without Makefile
temp_dir <- tempfile()
dir.create(temp_dir)
temp_script <- file.path(temp_dir, "test.R")
file.create(temp_script)
old_wd <- getwd()

on.exit({
  setwd(old_wd)
  unlink(temp_dir, recursive = TRUE)
})

setwd(temp_dir)

expect_error(
  run_script("test.R"),
  "No Makefile found"
)

setwd(old_wd)

# render_report validates inputs
# Test without Makefile
temp_dir <- tempfile()
dir.create(temp_dir)
old_wd <- getwd()

on.exit({
  setwd(old_wd)
  unlink(temp_dir, recursive = TRUE)
})

setwd(temp_dir)

# Without Makefile, should error
expect_error(
  render_report(),
  "No Makefile found"
)

# Create a fake Makefile so we can test file validation
file.create("Makefile")

# Test with non-existent report (now should check file)
expect_error(
  render_report("/nonexistent/report.Rmd"),
  "Report file not found"
)

setwd(old_wd)

# run_script builds a make docker-script command
calls <- character(0)
local_mocked_bindings(
  safe_system = function(command, ...) {
    calls[[length(calls) + 1]] <<- command
    0L
  },
  .package = "zzcollab"
)

temp_dir <- tempfile()
dir.create(temp_dir)
file.create(file.path(temp_dir, "Makefile"))
file.create(file.path(temp_dir, "analysis.R"))
old_wd <- setwd(temp_dir)
# withr::defer (not on.exit) so we append to, rather than clobber, the
# restoration handler that local_mocked_bindings registered on this frame.
withr::defer({
  setwd(old_wd)
  unlink(temp_dir, recursive = TRUE)
})

expect_true(run_script("analysis.R"))
# Target and SCRIPT= variable must match templates/Makefile docker-script.
expect_true(any(grepl("make docker-script SCRIPT=", calls, fixed = TRUE)))
expect_true(any(grepl("analysis.R", calls, fixed = TRUE)))
# The removed ARGS mechanism and nonexistent docker-r target must not return.
expect_false(any(grepl("docker-r ", calls, fixed = TRUE)))
expect_false(any(grepl("ARGS=", calls, fixed = TRUE)))

# render_report passes REPORT= without a stray space
calls <- character(0)
local_mocked_bindings(
  safe_system = function(command, ...) {
    calls[[length(calls) + 1]] <<- command
    0L
  },
  .package = "zzcollab"
)

temp_dir <- tempfile()
dir.create(temp_dir)
file.create(file.path(temp_dir, "Makefile"))
custom <- file.path("analysis", "report", "custom.Rmd")
dir.create(file.path(temp_dir, "analysis", "report"), recursive = TRUE)
file.create(file.path(temp_dir, custom))
old_wd <- setwd(temp_dir)
# withr::defer (not on.exit) so we append to, rather than clobber, the
# restoration handler that local_mocked_bindings registered on this frame.
withr::defer({
  setwd(old_wd)
  unlink(temp_dir, recursive = TRUE)
})

expect_true(render_report(custom))
# REPORT= must be immediately followed by the quoted path (no space, which
# would split it into a separate make goal and silently render the default).
expect_true(any(grepl(
  paste0("make docker-render REPORT=", shQuote(custom)),
  calls, fixed = TRUE
)))

calls <- character(0)
expect_true(render_report())
expect_true(any(grepl("make docker-render", calls, fixed = TRUE)))
expect_false(any(grepl("REPORT=", calls, fixed = TRUE)))

# sync_env validates renv.lock exists
# Test without renv.lock
temp_dir <- tempfile()
dir.create(temp_dir)
old_wd <- getwd()

on.exit({
  setwd(old_wd)
  unlink(temp_dir, recursive = TRUE)
})

setwd(temp_dir)

expect_error(
  sync_env(),
  "No renv.lock file found"
)

setwd(old_wd)

# add_package requires renv
# This test assumes renv might not be available in test environment
# Function should handle this gracefully
skip_if(requireNamespace("renv", quietly = TRUE), "renv is available")

expect_error(
  add_package("test_package"),
  "renv package is required"
)

# null-coalescing operator works correctly
# Test with NULL
expect_equal(NULL %||% "default", "default")

# Test with non-NULL value
expect_equal("value" %||% "default", "value")

# Test with empty string (should not be NULL)
expect_equal("" %||% "default", "")

# Test with FALSE (should not be NULL)
expect_equal(FALSE %||% TRUE, FALSE)

# Test with 0 (should not be NULL)
expect_equal(0 %||% 1, 0)

# init_project validates required parameters
# Should error without project_name
expect_error(
  init_project(team_name = "myteam", project_name = NULL),
  "project_name is required"
)

# Should error with invalid team_name format
expect_error(
  init_project(team_name = "My Team", project_name = "test"),
  "team_name must contain only lowercase"
)

# Should error with invalid project_name format
expect_error(
  init_project(team_name = "myteam", project_name = "My Project"),
  "project_name must contain only lowercase"
)

# join_project validates required parameters
# Should error without project_name
expect_error(
  join_project(team_name = "myteam", project_name = NULL),
  "project_name is required"
)

# Should error with invalid team_name format
expect_error(
  join_project(team_name = "My Team", project_name = "test"),
  "team_name must contain only lowercase"
)

# Should error with invalid project_name format
expect_error(
  join_project(team_name = "myteam", project_name = "My Project"),
  "project_name must contain only lowercase"
)

# setup_project validates parameters
skip_if_not(file.exists("zzcollab.sh"), "zzcollab.sh not found")

# Should handle invalid base_image format
expect_error(
  setup_project(base_image = "invalid_image"),
  "base_image must be in format"
)

# Should handle multiple base_image values
expect_error(
  setup_project(base_image = c("image1", "image2")),
  "base_image must be a single character string"
)

# create_pr validates GitHub CLI availability
skip_if(system("which gh", ignore.stdout = TRUE, ignore.stderr = TRUE) == 0,
        "GitHub CLI is available")

# Should error if gh CLI not available
expect_error(
  create_pr("Test PR"),
  "GitHub CLI.*is required"
)

# create_branch returns logical
skip_if(!dir.exists(".git"), "Not a git repository")

# Test with invalid branch name (should fail but return FALSE)
result <- suppressMessages(create_branch("..invalid.."))
expect_type(result, "logical")

# git_commit handles errors gracefully
skip_if(!dir.exists(".git"), "Not a git repository")

# Function should return logical even on error
result <- tryCatch({
  git_commit("", add_all = FALSE)  # Empty message should fail
}, error = function(e) {
  FALSE
})

expect_type(result, "logical")
