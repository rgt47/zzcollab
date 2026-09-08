library(tinytest)

# These tests exercise functions that mutate a git repository, so they
# run against a throwaway repository under tempdir(). The previous
# version called git_commit(), git_push() and create_branch() against
# the working directory: dormant in practice only because `.git` is not
# visible from the test directory, but a run started from the package
# root would have staged everything, committed, and pushed. The
# assertions were also written as expect_true(TRUE) inside an error
# handler, so they passed whether the call succeeded or failed.

has_git <- nzchar(Sys.which("git"))
if (!has_git) exit_file("git not available")

# A previous test file may have left the session in a directory that
# no longer exists, so anchor to an explicit temp root and verify the
# sandbox before entering it.
root <- normalizePath(Sys.getenv("TMPDIR", unset = "/tmp"),
                      mustWork = FALSE)
sandbox <- file.path(root, paste0("zzcollab-git-",
                                  as.integer(Sys.time()), "-",
                                  sample.int(1e6, 1)))
dir.create(sandbox, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(sandbox)) exit_file("could not create a sandbox repo")
old_wd <- tryCatch(getwd(), error = function(e) root)
setwd(sandbox)

q <- function(...) suppressWarnings(system2("git", c(...),
                                            stdout = FALSE, stderr = FALSE))
q("init", "-q", "-b", "main", ".")
q("config", "user.email", "test@example.invalid")
q("config", "user.name", "test")
writeLines("one", "a.txt")
q("add", "a.txt")
q("commit", "-qm", "first")

# --- git_status ---------------------------------------------------
expect_true(is.character(suppressMessages(git_status())),
  info = "git_status returns a character vector")
expect_equal(length(suppressMessages(git_status())), 0L,
  info = "a clean tree reports no changes")
writeLines("two", "b.txt")
expect_true(length(suppressMessages(git_status())) > 0L,
  info = "an untracked file is reported")

# --- git_commit ---------------------------------------------------
expect_error(git_commit(), "argument.*missing",
  info = "git_commit requires a message")
expect_true(suppressMessages(git_commit("add b")),
  info = "git_commit succeeds when there is something to commit")
expect_equal(length(suppressMessages(git_status())), 0L,
  info = "the tree is clean after committing")
# Nothing staged: git exits non-zero and the wrapper must report FALSE
# rather than claiming success.
expect_false(suppressMessages(git_commit("nothing to do")),
  info = "git_commit reports failure when there is nothing to commit")

# --- create_branch ------------------------------------------------
expect_error(create_branch(), "argument.*missing",
  info = "create_branch requires a name")
# No remote here, so the pull fails; the branch is still cut from main
# and the call warns rather than failing.
expect_warning(suppressMessages(create_branch("feature-x")),
  "may be behind the remote",
  info = "a failed pull warns but still branches from main")
expect_equal(system2("git", c("rev-parse", "--abbrev-ref", "HEAD"),
                     stdout = TRUE), "feature-x",
  info = "create_branch leaves the caller on the new branch")

# A dirty working tree makes `git checkout main` fail. The branch must
# not be created from the current branch while reporting success: that
# silently cuts a feature branch from another feature branch.
writeLines("three", "c.txt")
q("add", "c.txt")
q("commit", "-qm", "on-feature")
writeLines("dirty", "c.txt")
expect_error(suppressMessages(create_branch("feature-y")),
  "cut from the current branch",
  info = "create_branch refuses to branch when it cannot reach main")
expect_equal(system2("git", c("rev-parse", "--abbrev-ref", "HEAD"),
                     stdout = TRUE), "feature-x",
  info = "the refused call leaves the branch unchanged")
expect_false("feature-y" %in%
               system2("git", c("branch", "--format=%(refname:short)"),
                       stdout = TRUE),
  info = "the refused branch was not created")

# --- create_pr ----------------------------------------------------
if (!nzchar(Sys.which("gh"))) {
  expect_error(create_pr(title = "t"), "GitHub CLI",
    info = "create_pr requires the gh CLI and says so")
}

setwd(old_wd)
unlink(sandbox, recursive = TRUE)
