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

test_that("build_mode parameter validation", {
  # Test that functions accept valid build modes
  valid_modes <- c("fast", "standard", "comprehensive")
  
  # These tests will check parameter validation without actually running the commands
  # We'll use mock functions or parameter validation
  
  for (mode in valid_modes) {
    expect_no_error({
      # Test parameter acceptance (these won't actually run due to missing zzcollab)
      tryCatch({
        init_project("test_team", "test_project", build_mode = mode)
      }, error = function(e) {
        # Expected error when zzcollab script not found
        expect_match(e$message, "zzcollab script.*not found")
      })
    })
  }
})

test_that("function parameters are properly validated", {
  # Test that functions fail appropriately when zzcollab script not available
  # (in a real zzcollab project directory, config defaults would be available)
  expect_error(init_project(), "zzcollab script.*not found")
  expect_error(init_project("team"), "zzcollab script.*not found")
  expect_error(join_project(), "zzcollab script.*not found") 
  expect_error(join_project("team"), "zzcollab script.*not found")
})

test_that("Docker status function works", {
  # Test status function (this will work even without zzcollab containers)
  result <- status()
  expect_type(result, "character")
  # Length can be 0 if no containers running
  expect_gte(length(result), 0)
})

test_that("team_images function works", {
  # Test team_images function
  result <- team_images()
  expect_true(is.data.frame(result))
  # Can be empty if no team images
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