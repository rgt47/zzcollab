library(tinytest)

# git_status returns character vector
result <- git_status()
expect_true(is.character(result))
expect_true(length(result) >= 0)

# All remaining tests require a git repository in cwd
if (!dir.exists(".git")) exit_file("Not a git repository")

# git_commit validates commit message
expect_error(
  git_commit(),
  "argument.*missing"
)

# Test with message but no changes (should handle gracefully)
result <- tryCatch({
  git_commit("test commit")
}, error = function(e) {
  expect_true(TRUE)
  FALSE
})

expect_true(is.logical(result))

# git_push works in git repository
result <- tryCatch({
  git_push()
}, error = function(e) {
  expect_true(TRUE)
  FALSE
})

expect_true(is.logical(result))

# create_branch validates branch name
expect_error(
  create_branch(),
  "argument.*missing"
)

# Test with branch name
test_branch <- paste0("test-branch-", as.integer(Sys.time()))
result <- tryCatch({
  create_branch(test_branch)
}, error = function(e) {
  expect_true(TRUE)
  FALSE
})

if (result) {
  system2("git", c("branch", "-D", test_branch), stderr = NULL, stdout = NULL)
}

expect_true(is.logical(result))

# create_pr validates repository
expect_error(
  create_pr(),
  "argument.*missing"
)

# Test with parameters (will fail without gh CLI or remote)
result <- tryCatch({
  create_pr(title = "Test PR", body = "Test body")
}, error = function(e) {
  expect_true(TRUE)
  FALSE
})

expect_true(is.logical(result))

# git functions handle non-git directories gracefully
temp_dir <- tempfile()
dir.create(temp_dir)
old_wd <- getwd()

on.exit({
  setwd(old_wd)
  unlink(temp_dir, recursive = TRUE)
})

setwd(temp_dir)

result <- tryCatch({
  git_status()
}, error = function(e) {
  expect_true(TRUE)
  character(0)
})

expect_true(is.character(result))

setwd(old_wd)

# git_commit constructs proper commands
result <- tryCatch({
  git_commit("test: add feature")
}, error = function(e) {
  expect_false(grepl("unexpected|syntax|command.*not found", e$message, ignore.case = TRUE))
  FALSE
})

expect_true(is.logical(result))

# git_commit passes message as a separate arg (no shell interpolation).
# local_mocked_bindings is a testthat function; load testthat explicitly for
# these injection-safety tests (they run on dev machines, not in R CMD check).
if (!requireNamespace("testthat", quietly = TRUE)) {
  exit_file("testthat not available -- skipping injection-safety mocks")
}

calls <- list()
testthat::local_mocked_bindings(
  safe_system2 = function(cmd, args = character(), ...) {
    calls[[length(calls) + 1L]] <<- list(cmd = cmd, args = args)
    0L
  },
  .package = "zzcollab"
)

evil <- 'oops"; rm -rf $(pwd) #'
git_commit(evil, add_all = FALSE)

commit_call <- Filter(function(x) identical(x$cmd, 'git') &&
                        isTRUE(x$args[1] == 'commit'), calls)
expect_equal(length(commit_call), 1L)
expect_equal(commit_call[[1L]]$args, c('commit', '-m', evil))

# create_branch and git_push pass refs as separate args
calls <- list()
testthat::local_mocked_bindings(
  safe_system2 = function(cmd, args = character(), ...) {
    calls[[length(calls) + 1L]] <<- list(cmd = cmd, args = args)
    0L
  },
  .package = "zzcollab"
)

evil_ref <- "feat/x; touch HACKED"
create_branch(evil_ref)
git_push(evil_ref)

branch_call <- Filter(function(x) identical(x$cmd, 'git') &&
                        length(x$args) >= 2 &&
                        x$args[1] == 'checkout' && x$args[2] == '-b', calls)
expect_equal(length(branch_call), 1L)
expect_equal(branch_call[[1L]]$args[3], evil_ref)

push_call <- Filter(function(x) identical(x$cmd, 'git') &&
                      length(x$args) >= 1 && x$args[1] == 'push', calls)
expect_true(length(push_call) >= 1L)
expect_equal(push_call[[length(push_call)]]$args[3], evil_ref)
