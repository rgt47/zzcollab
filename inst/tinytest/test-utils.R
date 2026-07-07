library(tinytest)

# find_zzcollab_script exists in the package namespace (unexported helper)
expect_true(exists("find_zzcollab_script",
                    envir = asNamespace("zzcollab"),
                    inherits = FALSE))

# Test that it returns a character string
# Note: This might fail if zzcollab is not installed, which is expected
if (file.exists("zzcollab.sh")) {
  result <- find_zzcollab_script()
  expect_true(is.character(result))
  expect_equal(length(result), 1L)
}

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
if (nzchar(Sys.which("docker"))) {
  result <- status()
  expect_true(is.character(result))
  expect_true(length(result) >= 0)
}

# team_images function works
if (nzchar(Sys.which("docker"))) {
  result <- team_images()
  expect_true(is.data.frame(result))
  expect_true(nrow(result) >= 0)
}

# git_status handles missing git repository
# Use tempfile() for unique path; guard setwd in case dir creation fails
test_dir <- tempfile(pattern = "zzc_test_git_")
if (dir.create(test_dir, showWarnings = FALSE, recursive = TRUE)) {
  old_wd <- getwd()
  setwd(test_dir)
  result <- tryCatch({
    git_status()
  }, error = function(e) {
    expect_true(TRUE)
    character(0)
  })
  expect_true(is.character(result))
  setwd(old_wd)
  unlink(test_dir, recursive = TRUE)
}

# rebuild function validates Makefile exists
# Test in directory without Makefile
temp_dir <- tempfile()
if (dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)) {
  old_wd <- getwd()
  setwd(temp_dir)
  on.exit({ setwd(old_wd); unlink(temp_dir, recursive = TRUE) }, add = TRUE)

  expect_error(
    rebuild(),
    "No Makefile found"
  )

  setwd(old_wd)
  on.exit(NULL)
  unlink(temp_dir, recursive = TRUE)
}

# run_script validates inputs
# Should error with non-existent script
expect_error(
  run_script("/nonexistent/script.R"),
  "Script file not found"
)

# Should error without Makefile
temp_dir <- tempfile()
if (dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)) {
  temp_script <- file.path(temp_dir, "test.R")
  file.create(temp_script)
  old_wd <- getwd()
  setwd(temp_dir)
  on.exit({ setwd(old_wd); unlink(temp_dir, recursive = TRUE) }, add = TRUE)

  expect_error(
    run_script("test.R"),
    "No Makefile found"
  )

  setwd(old_wd)
  on.exit(NULL)
  unlink(temp_dir, recursive = TRUE)
}

# render_report validates inputs
# Test without Makefile
temp_dir <- tempfile()
if (dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)) {
  old_wd <- getwd()
  setwd(temp_dir)
  on.exit({ setwd(old_wd); unlink(temp_dir, recursive = TRUE) }, add = TRUE)

  expect_error(
    render_report(),
    "No Makefile found"
  )

  file.create("Makefile")

  expect_error(
    render_report("/nonexistent/report.Rmd"),
    "Report file not found"
  )

  setwd(old_wd)
  on.exit(NULL)
  unlink(temp_dir, recursive = TRUE)
}

# run_script and render_report routing tests use local_mocked_bindings
# (testthat-only); load testthat explicitly.
if (requireNamespace("testthat", quietly = TRUE)) {
  # run_script builds a make docker-script command
  calls <- character(0)
  testthat::local_mocked_bindings(
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
  withr::defer({
    setwd(old_wd)
    unlink(temp_dir, recursive = TRUE)
  })

  expect_true(run_script("analysis.R"))
  expect_true(any(grepl("make docker-script SCRIPT=", calls, fixed = TRUE)))
  expect_true(any(grepl("analysis.R", calls, fixed = TRUE)))
  expect_false(any(grepl("docker-r ", calls, fixed = TRUE)))
  expect_false(any(grepl("ARGS=", calls, fixed = TRUE)))

  # render_report passes REPORT= without a stray space
  calls <- character(0)
  testthat::local_mocked_bindings(
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
  withr::defer({
    setwd(old_wd)
    unlink(temp_dir, recursive = TRUE)
  })

  expect_true(render_report(custom))
  expect_true(any(grepl(
    paste0("make docker-render REPORT=", shQuote(custom)),
    calls, fixed = TRUE
  )))

  calls <- character(0)
  expect_true(render_report())
  expect_true(any(grepl("make docker-render", calls, fixed = TRUE)))
  expect_false(any(grepl("REPORT=", calls, fixed = TRUE)))
}

# sync_env validates renv.lock exists
# Test without renv.lock
temp_dir <- tempfile()
if (dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)) {
  old_wd <- getwd()
  setwd(temp_dir)
  on.exit({ setwd(old_wd); unlink(temp_dir, recursive = TRUE) }, add = TRUE)

  expect_error(
    sync_env(),
    "No renv.lock file found"
  )

  setwd(old_wd)
  on.exit(NULL)
  unlink(temp_dir, recursive = TRUE)
}

# add_package requires renv (only testable when renv is absent)
if (!requireNamespace("renv", quietly = TRUE)) {
  expect_error(
    add_package("test_package"),
    "renv package is required"
  )
}

# null-coalescing operator works correctly
# Test with NULL
expect_equal(zzcollab:::`%||%`(NULL, "default"), "default")

# Test with non-NULL value
expect_equal(zzcollab:::`%||%`("value", "default"), "value")

# Test with empty string (should not be NULL)
expect_equal(zzcollab:::`%||%`("", "default"), "")

# Test with FALSE (should not be NULL)
expect_equal(zzcollab:::`%||%`(FALSE, TRUE), FALSE)

# Test with 0 (should not be NULL)
expect_equal(zzcollab:::`%||%`(0, 1), 0)

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

# setup_project validates parameters (requires CLI in cwd)
if (file.exists("zzcollab.sh")) {
  expect_error(
    setup_project(base_image = "invalid_image"),
    "base_image must be in format"
  )
  expect_error(
    setup_project(base_image = c("image1", "image2")),
    "base_image must be a single character string"
  )
}

# create_pr validates GitHub CLI availability (only when gh is absent)
if (system("which gh", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0) {
  expect_error(
    create_pr("Test PR"),
    "GitHub CLI.*is required"
  )
}

# create_branch and git_commit in a git repository
if (dir.exists(".git")) {
  result <- suppressMessages(create_branch("..invalid.."))
  expect_true(is.logical(result))

  result <- tryCatch({
    git_commit("", add_all = FALSE)
  }, error = function(e) FALSE)
  expect_true(is.logical(result))
}
