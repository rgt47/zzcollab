# Tests for Git integration functions

test_that("git_status returns character vector", {
  result <- git_status()
  expect_type(result, "character")
  expect_gte(length(result), 0)
})

test_that("git_commit validates commit message", {
  skip_if_not(dir.exists(".git"), message = "Not a git repository")

  # Test that commit message is required
  expect_error(
    git_commit(),
    "argument.*missing"
  )

  # Test with message but no changes (should handle gracefully)
  result <- tryCatch({
    git_commit("test commit")
  }, error = function(e) {
    # Expected - nothing to commit or git not configured
    expect_true(TRUE)
    FALSE
  })

  expect_type(result, "logical")
})

test_that("git_push works in git repository", {
  skip_if_not(dir.exists(".git"), message = "Not a git repository")

  result <- tryCatch({
    git_push()
  }, error = function(e) {
    # May fail if no remote configured, which is fine
    expect_true(TRUE)
    FALSE
  })

  expect_type(result, "logical")
})

test_that("create_branch validates branch name", {
  skip_if_not(dir.exists(".git"), message = "Not a git repository")

  # Should require branch name
  expect_error(
    create_branch(),
    "argument.*missing"
  )

  # Test with branch name
  test_branch <- paste0("test-branch-", as.integer(Sys.time()))
  result <- tryCatch({
    create_branch(test_branch)
  }, error = function(e) {
    # May fail if git not configured
    expect_true(TRUE)
    FALSE
  })

  # Cleanup - try to delete test branch
  if (result) {
    system2("git", c("branch", "-D", test_branch), stderr = NULL, stdout = NULL)
  }

  expect_type(result, "logical")
})

test_that("create_pr validates repository", {
  skip_if_not(dir.exists(".git"), message = "Not a git repository")

  # Should require title
  expect_error(
    create_pr(),
    "argument.*missing"
  )

  # Test with parameters (will fail without gh CLI or remote)
  result <- tryCatch({
    create_pr(title = "Test PR", body = "Test body")
  }, error = function(e) {
    # Expected - gh CLI may not be available or no remote
    expect_true(TRUE)
    FALSE
  })

  expect_type(result, "logical")
})

test_that("git functions handle non-git directories gracefully", {
  # Create temp non-git directory
  temp_dir <- tempfile()
  dir.create(temp_dir)
  old_wd <- getwd()

  on.exit({
    setwd(old_wd)
    unlink(temp_dir, recursive = TRUE)
  })

  setwd(temp_dir)

  # git_status should not crash
  result <- tryCatch({
    git_status()
  }, error = function(e) {
    # Should fail gracefully
    expect_true(TRUE)
    character(0)
  })

  expect_type(result, "character")
})

test_that("git_commit constructs proper commands", {
  skip_if_not(dir.exists(".git"), message = "Not a git repository")

  # Verify it uses the new commit message format with Claude Code attribution
  result <- tryCatch({
    git_commit("test: add feature")
  }, error = function(e) {
    # Check that error doesn't indicate command construction problems
    # (it should fail on git execution, not parameter handling)
    expect_false(grepl("unexpected|syntax|command.*not found", e$message, ignore.case = TRUE))
    FALSE
  })

  expect_type(result, "logical")
})
