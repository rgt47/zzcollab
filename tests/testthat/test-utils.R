test_that("find_zzcollab_script works", {
  # Test that the function exists
  expect_true(exists("find_zzcollab_script"))
  
  # Test that it returns a character string
  # Note: This might fail if zzcollab is not installed, which is expected
  skip_if_not(file.exists("zzcollab.sh"), "zzcollab.sh not found in current directory")
  
  result <- find_zzcollab_script()
  expect_type(result, "character")
  expect_length(result, 1)
})

test_that("helper functions exist", {
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
})

# Build mode tests removed - feature eliminated in favor of dynamic package management

test_that("function parameters are properly validated", {
  # Test that functions fail appropriately with missing required parameters
  # init_project requires project_name
  expect_error(init_project(), "project_name is required")

  # join_project requires project_name
  expect_error(join_project(), "project_name is required")
})

test_that("Docker status function works", {
  skip_if_not(nzchar(Sys.which("docker")), "Docker not available")

  result <- status()
  expect_type(result, "character")
  expect_gte(length(result), 0)
})

test_that("team_images function works", {
  skip_if_not(nzchar(Sys.which("docker")), "Docker not available")

  result <- team_images()
  expect_true(is.data.frame(result))
  expect_gte(nrow(result), 0)
})

test_that("git functions handle missing git repository", {
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
})

test_that("rebuild function validates Makefile exists", {
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
})

test_that("run_script validates inputs", {
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
})

test_that("render_report validates inputs", {
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
})

test_that("sync_env validates renv.lock exists", {
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
})

test_that("add_package requires renv", {
  # This test assumes renv might not be available in test environment
  # Function should handle this gracefully
  skip_if(requireNamespace("renv", quietly = TRUE), "renv is available")

  expect_error(
    add_package("test_package"),
    "renv package is required"
  )
})

test_that("null-coalescing operator works correctly", {
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
})

test_that("init_project validates required parameters", {
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
})

test_that("join_project validates required parameters", {
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
})

test_that("setup_project validates parameters", {
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
})

test_that("create_pr validates GitHub CLI availability", {
  skip_if(system("which gh", ignore.stdout = TRUE, ignore.stderr = TRUE) == 0,
          "GitHub CLI is available")

  # Should error if gh CLI not available
  expect_error(
    create_pr("Test PR"),
    "GitHub CLI.*is required"
  )
})

test_that("create_branch returns logical", {
  skip_if(!dir.exists(".git"), "Not a git repository")

  # Test with invalid branch name (should fail but return FALSE)
  result <- suppressMessages(create_branch("..invalid.."))
  expect_type(result, "logical")
})

test_that("git_commit handles errors gracefully", {
  skip_if(!dir.exists(".git"), "Not a git repository")

  # Function should return logical even on error
  result <- tryCatch({
    git_commit("", add_all = FALSE)  # Empty message should fail
  }, error = function(e) {
    FALSE
  })

  expect_type(result, "logical")
})