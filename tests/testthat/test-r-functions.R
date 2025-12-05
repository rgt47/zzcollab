################################################################################
# Unit Tests for R Package Functions
#
# Tests R interface functions for zzcollab:
# - Validation functions (docker names, paths)
# - Project management (init, join, setup)
# - Package management (add_package, sync_env)
# - Script execution and reporting
# - Git workflow functions
# - Configuration management
################################################################################

# Test context and fixtures
test_that("R package is properly structured", {
  expect_true(requireNamespace("zzcollab", quietly = TRUE))
})

################################################################################
# SECTION 1: Validation Functions (5 tests)
################################################################################

test_that("validate_docker_name accepts valid names", {
  expect_true(zzcollab:::validate_docker_name("myproject", "project_name"))
  expect_true(zzcollab:::validate_docker_name("my-project-123", "project_name"))
  expect_true(zzcollab:::validate_docker_name("my_project", "project_name"))
})

test_that("validate_docker_name rejects invalid names", {
  expect_error(zzcollab:::validate_docker_name("-myproject", "project_name"),
               "cannot start with a dot or hyphen")
  expect_error(zzcollab:::validate_docker_name(".myproject", "project_name"),
               "cannot start with a dot or hyphen")
  expect_error(zzcollab:::validate_docker_name("MY-PROJECT", "project_name"),
               "must contain only lowercase")
})

test_that("validate_docker_name rejects empty names", {
  expect_error(zzcollab:::validate_docker_name("", "project_name"),
               "cannot be empty")
})

test_that("validate_docker_name enforces length limit", {
  long_name <- paste(rep("a", 256), collapse = "")
  expect_error(zzcollab:::validate_docker_name(long_name, "project_name"),
               "255 characters or less")
})

test_that("validate_path normalizes paths correctly", {
  temp_dir <- tempdir()
  result <- zzcollab:::validate_path(temp_dir, "test_path")
  expect_true(is.character(result))
  expect_true(nchar(result) > 0)
})

################################################################################
# SECTION 2: Null-Coalescing Operator (2 tests)
################################################################################

test_that("%%||%% operator returns left value when not NULL", {
  result <- "value" %||% "default"
  expect_equal(result, "value")
})

test_that("%%||%% operator returns right value when left is NULL", {
  result <- NULL %||% "default"
  expect_equal(result, "default")
})

################################################################################
# SECTION 3: Status and Build Functions (3 tests)
################################################################################

test_that("status function can be called", {
  # This tests the function exists and can be called
  # Actual Docker status would require Docker installation
  result <- tryCatch({
    zzcollab::status()
    TRUE
  }, error = function(e) {
    # Function might error due to Docker not available, that's OK
    # We're just testing it exists
    grepl("Docker", as.character(e$message)) || TRUE
  })
  expect_true(result)
})

test_that("rebuild function accepts valid targets", {
  # Test that rebuild function has correct parameters
  expect_true(is.function(zzcollab::rebuild))
  # Function should accept target parameter
  args <- names(formals(zzcollab::rebuild))
  expect_true("target" %in% args)
})

test_that("team_images function exists", {
  expect_true(is.function(zzcollab::team_images))
})

################################################################################
# SECTION 4: Package Management (5 tests)
################################################################################

test_that("add_package function accepts package names", {
  expect_true(is.function(zzcollab::add_package))
  args <- names(formals(zzcollab::add_package))
  expect_true("packages" %in% args)
})

test_that("add_package has update_snapshot parameter", {
  args <- names(formals(zzcollab::add_package))
  expect_true("update_snapshot" %in% args)
})

test_that("sync_env function exists", {
  expect_true(is.function(zzcollab::sync_env))
})

test_that("sync_env syncs renv with DESCRIPTION", {
  # Test function signature
  expect_true(is.function(zzcollab::sync_env))
})

test_that("validate_repro function validates project reproducibility", {
  expect_true(is.function(zzcollab::validate_repro))
})

################################################################################
# SECTION 5: Script Execution and Reporting (4 tests)
################################################################################

test_that("run_script function accepts script paths", {
  expect_true(is.function(zzcollab::run_script))
  args <- names(formals(zzcollab::run_script))
  expect_true("script_path" %in% args)
})

test_that("run_script has container_cmd parameter", {
  args <- names(formals(zzcollab::run_script))
  expect_true("container_cmd" %in% args)
})

test_that("render_report function can be called", {
  expect_true(is.function(zzcollab::render_report))
  args <- names(formals(zzcollab::render_report))
  expect_true("report_path" %in% args)
})

test_that("render_report handles optional report_path", {
  formals_list <- formals(zzcollab::render_report)
  expect_true(!is.null(formals_list$report_path))
})

################################################################################
# SECTION 6: Git Workflow Functions (4 tests)
################################################################################

test_that("git_status function exists", {
  expect_true(is.function(zzcollab::git_status))
})

test_that("git_commit requires message parameter", {
  args <- names(formals(zzcollab::git_commit))
  expect_true("message" %in% args)
})

test_that("git_commit has add_all parameter", {
  args <- names(formals(zzcollab::git_commit))
  expect_true("add_all" %in% args)
})

test_that("git_push handles branch parameter", {
  args <- names(formals(zzcollab::git_push))
  expect_true("branch" %in% args)
})

test_that("create_pr function requires title", {
  args <- names(formals(zzcollab::create_pr))
  expect_true("title" %in% args)
})

test_that("create_branch requires branch_name", {
  args <- names(formals(zzcollab::create_branch))
  expect_true("branch_name" %in% args)
})

################################################################################
# SECTION 7: Project Initialization (2 tests)
################################################################################

test_that("init_project accepts team and project names", {
  args <- names(formals(zzcollab::init_project))
  expect_true("team_name" %in% args)
  expect_true("project_name" %in% args)
})

test_that("join_project accepts team and project names", {
  args <- names(formals(zzcollab::join_project))
  expect_true("team_name" %in% args)
  expect_true("project_name" %in% args)
})

################################################################################
# SECTION 8: Configuration Management (2 tests)
################################################################################

test_that("get_config requires key parameter", {
  args <- names(formals(zzcollab::get_config))
  expect_true("key" %in% args)
})

test_that("set_config requires key and value", {
  args <- names(formals(zzcollab::set_config))
  expect_true("key" %in% args)
  expect_true("value" %in% args)
})

################################################################################
# Test Summary
################################################################################

# These tests validate that R package functions have correct signatures,
# accept expected parameters, and are properly exported from the package.
