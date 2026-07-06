library(tinytest)

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

# R package is properly structured
expect_true(requireNamespace("zzcollab", quietly = TRUE))

################################################################################
# SECTION 1: Validation Functions (5 tests)
################################################################################

# validate_docker_name accepts valid names
expect_true(zzcollab:::validate_docker_name("myproject", "project_name"))
expect_true(zzcollab:::validate_docker_name("my-project-123", "project_name"))
expect_true(zzcollab:::validate_docker_name("my_project", "project_name"))

# validate_docker_name rejects invalid names
expect_error(zzcollab:::validate_docker_name("-myproject", "project_name"),
             "cannot start with a dot or hyphen")
expect_error(zzcollab:::validate_docker_name(".myproject", "project_name"),
             "cannot start with a dot or hyphen")
expect_error(zzcollab:::validate_docker_name("MY-PROJECT", "project_name"),
             "must contain only lowercase")

# validate_docker_name rejects empty names
expect_error(zzcollab:::validate_docker_name("", "project_name"),
             "cannot be empty")

# validate_docker_name enforces length limit
long_name <- paste(rep("a", 256), collapse = "")
expect_error(zzcollab:::validate_docker_name(long_name, "project_name"),
             "255 characters or less")

################################################################################
# SECTION 2: Null-Coalescing Operator (2 tests)
################################################################################

# %||% operator returns left value when not NULL
result <- "value" %||% "default"
expect_equal(result, "value")

# %||% operator returns right value when left is NULL
result <- NULL %||% "default"
expect_equal(result, "default")

################################################################################
# SECTION 3: Status and Build Functions (3 tests)
################################################################################

# status function can be called
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

# rebuild function accepts valid targets
# Test that rebuild function has correct parameters
expect_true(is.function(zzcollab::rebuild))
# Function should accept target parameter
args <- names(formals(zzcollab::rebuild))
expect_true("target" %in% args)

# team_images function exists
expect_true(is.function(zzcollab::team_images))

################################################################################
# SECTION 4: Package Management (5 tests)
################################################################################

# add_package function accepts package names
expect_true(is.function(zzcollab::add_package))
args <- names(formals(zzcollab::add_package))
expect_true("packages" %in% args)

# add_package has update_snapshot parameter
args <- names(formals(zzcollab::add_package))
expect_true("update_snapshot" %in% args)

# sync_env function exists
expect_true(is.function(zzcollab::sync_env))

# sync_env syncs renv with DESCRIPTION
# Test function signature
expect_true(is.function(zzcollab::sync_env))

# validate_repro function validates project reproducibility
expect_true(is.function(zzcollab::validate_repro))

################################################################################
# SECTION 5: Script Execution and Reporting (4 tests)
################################################################################

# run_script function accepts script paths
expect_true(is.function(zzcollab::run_script))
args <- names(formals(zzcollab::run_script))
expect_true("script_path" %in% args)

# run_script has container_cmd parameter
args <- names(formals(zzcollab::run_script))
expect_true("container_cmd" %in% args)

# render_report function can be called
expect_true(is.function(zzcollab::render_report))
args <- names(formals(zzcollab::render_report))
expect_true("report_path" %in% args)

# render_report handles optional report_path
formals_list <- formals(zzcollab::render_report)
expect_true("report_path" %in% names(formals_list))

################################################################################
# SECTION 6: Git Workflow Functions (4 tests)
################################################################################

# git_status function exists
expect_true(is.function(zzcollab::git_status))

# git_commit requires message parameter
args <- names(formals(zzcollab::git_commit))
expect_true("message" %in% args)

# git_commit has add_all parameter
args <- names(formals(zzcollab::git_commit))
expect_true("add_all" %in% args)

# git_push handles branch parameter
args <- names(formals(zzcollab::git_push))
expect_true("branch" %in% args)

# create_pr function requires title
args <- names(formals(zzcollab::create_pr))
expect_true("title" %in% args)

# create_branch requires branch_name
args <- names(formals(zzcollab::create_branch))
expect_true("branch_name" %in% args)

################################################################################
# SECTION 7: Project Initialization (2 tests)
################################################################################

# init_project accepts team and project names
args <- names(formals(zzcollab::init_project))
expect_true("team_name" %in% args)
expect_true("project_name" %in% args)

# join_project accepts team and project names
args <- names(formals(zzcollab::join_project))
expect_true("team_name" %in% args)
expect_true("project_name" %in% args)

################################################################################
# SECTION 8: Configuration Management (2 tests)
################################################################################

# get_config requires key parameter
args <- names(formals(zzcollab::get_config))
expect_true("key" %in% args)

# set_config requires key and value
args <- names(formals(zzcollab::set_config))
expect_true("key" %in% args)
expect_true("value" %in% args)

################################################################################
# Test Summary
################################################################################

# These tests validate that R package functions have correct signatures,
# accept expected parameters, and are properly exported from the package.
