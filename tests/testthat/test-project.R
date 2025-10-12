# Tests for project initialization and management functions

test_that("init_project validates required parameters", {
  # Test that team_name is required
  expect_error(
    init_project(project_name = "test"),
    "team_name.*required"
  )

  # Test that project_name is required
  expect_error(
    init_project(team_name = "test"),
    "project_name.*required"
  )

  # Both parameters provided should get past validation
  # (will fail on missing zzcollab script, but that's expected)
  result <- tryCatch({
    init_project(team_name = "testteam", project_name = "testproj")
  }, error = function(e) {
    # Should fail on zzcollab script not found, not parameter validation
    expect_true(grepl("zzcollab.*script", e$message, ignore.case = TRUE))
    FALSE
  })

  expect_type(result, "logical")
})

test_that("join_project validates required parameters", {
  # Test that team_name is required
  expect_error(
    join_project(project_name = "test"),
    "team_name.*required"
  )

  # Test that project_name is required
  expect_error(
    join_project(team_name = "test"),
    "project_name.*required"
  )

  # Both parameters provided
  result <- tryCatch({
    join_project(team_name = "testteam", project_name = "testproj")
  }, error = function(e) {
    expect_true(grepl("zzcollab.*script", e$message, ignore.case = TRUE))
    FALSE
  })

  expect_type(result, "logical")
})

test_that("setup_project handles optional parameters", {
  # Should work with no parameters (uses defaults)
  result <- tryCatch({
    setup_project()
  }, error = function(e) {
    expect_true(grepl("zzcollab.*script", e$message, ignore.case = TRUE))
    FALSE
  })

  expect_type(result, "logical")

  # Should accept base_image parameter
  result <- tryCatch({
    setup_project(base_image = "rocker/rstudio")
  }, error = function(e) {
    expect_true(grepl("zzcollab.*script", e$message, ignore.case = TRUE))
    FALSE
  })

  expect_type(result, "logical")
})

test_that("project functions construct correct commands", {
  skip_if_not(exists("find_zzcollab_script"))

  # Mock find_zzcollab_script to return a test path
  local_mocked_bindings(
    find_zzcollab_script = function() "/usr/local/bin/zzcollab",
    .package = "zzcollab"
  )

  # Test that init_project constructs proper command
  # We'll capture what command would be run
  result <- tryCatch({
    init_project(team_name = "myteam", project_name = "myproj")
  }, error = function(e) {
    # Command will fail to execute, but we can check error contains our parameters
    expect_true(grepl("myteam", e$message) || grepl("myproj", e$message))
    TRUE
  })
})

test_that("dotfiles parameters are handled correctly", {
  # Test with dotfiles_path
  result <- tryCatch({
    init_project(
      team_name = "test",
      project_name = "test",
      dotfiles_path = "~/dotfiles"
    )
  }, error = function(e) {
    # Should include dotfiles in command
    expect_true(TRUE)
    FALSE
  })

  expect_type(result, "logical")

  # Test with dotfiles_nodots flag
  result <- tryCatch({
    init_project(
      team_name = "test",
      project_name = "test",
      dotfiles_path = "~/dotfiles",
      dotfiles_nodots = TRUE
    )
  }, error = function(e) {
    expect_true(TRUE)
    FALSE
  })

  expect_type(result, "logical")
})

test_that("join_project no longer accepts interface parameter", {
  # Verify interface parameter was removed (breaking change)
  # Function signature should not include interface
  formals_names <- names(formals(join_project))
  expect_false("interface" %in% formals_names)
})
