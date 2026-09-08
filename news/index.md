# Changelog

## zzcollab 0.2.0

### Correctness and security fixes

- **Arguments passed to external commands are now quoted.**
  [`system2()`](https://rdrr.io/r/base/system2.html) does not quote: it
  pastes `args` together and hands the result to a shell.
  [`safe_system2()`](https://rgt47.github.io/zzcollab/reference/safe_system2.md)
  relied on it doing so, with a comment at each call site saying no
  quoting was needed.

  Every multi-word commit message failed. `git_commit("add feature x")`
  ran `git commit -m add feature x`; git rejected `feature` and `x` as
  pathspecs and no commit was made. The function reported failure, so
  the effect was a git wrapper that could not commit with an ordinary
  message.

  Shell metacharacters in user text also reached the shell. A commit
  message of `"msg; touch FILE"` created FILE. Commit messages, pull
  request titles and bodies, and branch names are all user-supplied, so
  this was a command injection.
  [`safe_system2()`](https://rgt47.github.io/zzcollab/reference/safe_system2.md)
  now applies [`shQuote()`](https://rdrr.io/r/base/shQuote.html) to
  every argument, at the one point they all pass through, and
  `git add .` is passed as two tokens rather than one string.

- **[`create_branch()`](https://rgt47.github.io/zzcollab/reference/create_branch.md)
  no longer branches from the wrong base while reporting success.** It
  ran `git checkout main` and `git pull` and discarded both exit
  statuses. With a dirty working tree the checkout failed, the pull
  failed, and the branch was cut from whatever branch the caller was on
  while the function returned `TRUE`; in a collaboration framework that
  silently stacks a feature branch on another feature branch and the
  eventual pull request carries the other branch’s commits. A failed
  checkout is now an error. A failed pull, which happens offline or with
  no upstream, warns: the base is still main, only possibly not the
  newest main.

### Tests

- `test-git.R` called
  [`git_commit()`](https://rgt47.github.io/zzcollab/reference/git_commit.md),
  [`git_push()`](https://rgt47.github.io/zzcollab/reference/git_push.md)
  and
  [`create_branch()`](https://rgt47.github.io/zzcollab/reference/create_branch.md)
  against the working directory, and asserted `expect_true(TRUE)` from
  inside an error handler, so each test passed whether the call worked
  or threw. They were dormant only because `.git` is not visible from
  the test directory; a run started from the package root would have
  staged everything, committed, and pushed. The file now builds a
  throwaway repository under the temp directory and makes assertions
  that can fail.
- New `test-arg-quoting.R` covers the quoting and injection fixes.

## zzcollab 0.1.0

Re-baseline release. The R package version is reset to 0.1.0 to align
with the unified `ZZCOLLAB_VERSION` (CLI and template framework);
release notes prior to this reset are archived in `NEWS-pre-0.1.0.md`.

### Changes

- The R wrapper tracks the presence-driven reproducibility-toggle CLI:
  project status, verification, and the self-adapting Docker/renv
  environment. See `CHANGELOG.md` for the full framework history.
