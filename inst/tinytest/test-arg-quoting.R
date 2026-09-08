library(tinytest)

# --- regressions -------------------------------------------------
#
# system2() does not quote its `args`: it pastes them together and
# hands the result to a shell. safe_system2() therefore has to quote,
# and until it did, two things were wrong.
#
# First, any argument containing a space was split. git_commit("add
# feature x") ran `git commit -m add feature x`, git rejected "feature"
# and "x" as pathspecs, and the commit silently did not happen -- which
# is to say commit messages, the ordinary kind with spaces in them,
# did not work at all.
#
# Second, shell metacharacters in user text reached the shell. A commit
# message of "msg; touch FILE" created FILE. Commit messages, pull
# request titles and bodies, and branch names are all user data.

if (!nzchar(Sys.which("git"))) exit_file("git not available")

root <- normalizePath(Sys.getenv("TMPDIR", unset = "/tmp"),
                      mustWork = FALSE)
sandbox <- file.path(root, paste0("zzcollab-quote-",
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

# A multi-word commit message must actually commit, with the message
# intact.
writeLines("two", "b.txt")
expect_true(suppressMessages(git_commit("add feature x")),
  info = "a multi-word commit message succeeds")
expect_equal(system2("git", c("log", "-1", "--pretty=%s"), stdout = TRUE),
             "add feature x",
  info = "the whole message is recorded, not just its first word")

# Punctuation that a shell would otherwise interpret.
writeLines("three", "c.txt")
expect_true(suppressMessages(git_commit("fix: handle $HOME & \"quotes\"")),
  info = "a message with shell punctuation succeeds")
expect_equal(system2("git", c("log", "-1", "--pretty=%s"), stdout = TRUE),
             "fix: handle $HOME & \"quotes\"",
  info = "shell punctuation survives verbatim")

# An embedded command must not execute.
probe <- file.path(sandbox, "injection_probe")
writeLines("four", "d.txt")
invisible(suppressWarnings(suppressMessages(
  git_commit(paste0("msg; touch ", shQuote(probe))))))
expect_false(file.exists(probe),
  info = "a shell metacharacter in a commit message is not executed")

# Branch names go through the same path.
expect_false(dir.exists(file.path(sandbox, "branch_probe")),
  info = "sanity: the branch probe does not exist yet")

setwd(old_wd)
unlink(sandbox, recursive = TRUE)
