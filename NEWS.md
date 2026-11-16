# zzcollab 0.2.0

## Correctness and security fixes

* **Arguments passed to external commands are now quoted.** `system2()`
  does not quote: it pastes `args` together and hands the result to a
  shell. `safe_system2()` relied on it doing so, with a comment at each
  call site saying no quoting was needed.

  Every multi-word commit message failed. `git_commit("add feature x")`
  ran `git commit -m add feature x`; git rejected `feature` and `x` as
  pathspecs and no commit was made. The function reported failure, so
  the effect was a git wrapper that could not commit with an ordinary
  message.

  Shell metacharacters in user text also reached the shell. A commit
  message of `"msg; touch FILE"` created FILE. Commit messages, pull
  request titles and bodies, and branch names are all user-supplied,
  so this was a command injection. `safe_system2()` now applies
  `shQuote()` to every argument, at the one point they all pass
  through, and `git add .` is passed as two tokens rather than one
  string.

* **`create_branch()` no longer branches from the wrong base while
  reporting success.** It ran `git checkout main` and `git pull` and
  discarded both exit statuses. With a dirty working tree the checkout
  failed, the pull failed, and the branch was cut from whatever branch
  the caller was on while the function returned `TRUE`; in a
  collaboration framework that silently stacks a feature branch on
  another feature branch and the eventual pull request carries the
  other branch's commits. A failed checkout is now an error. A failed
  pull, which happens offline or with no upstream, warns: the base is
  still main, only possibly not the newest main.

* **`init_project()` now creates the project in `project_name` and
  accepts the CLI's profiles.** It ran the quickstart in the session
  working directory, so `project_name` only appeared in a message and
  the compendium was named after whatever directory R happened to be
  in. It now creates `./<project_name>` (or uses it if it exists and is
  empty; a non-empty directory is an error) and runs the scaffold
  there, without changing the session's working directory. The
  DockerHub and GitHub accounts are now written to the user config
  only after the scaffold succeeds; previously they were written first,
  so a failed init still rewrote the user's config. If the scaffold
  fails, a directory created by the call is removed when still empty.

  The `profile` whitelist was `minimal`, `analysis`, `rstudio`, which
  rejected the CLI's `tidyverse` and `publishing` profiles. It now
  matches `templates/bundles.yaml` (`minimal`, `tidyverse`, `rstudio`,
  `publishing`) plus the deprecated alias `analysis`, and the default
  is `tidyverse` instead of the alias (the same base image).

## Tests

* `test-git.R` called `git_commit()`, `git_push()` and
  `create_branch()` against the working directory, and asserted
  `expect_true(TRUE)` from inside an error handler, so each test passed
  whether the call worked or threw. They were dormant only because
  `.git` is not visible from the test directory; a run started from the
  package root would have staged everything, committed, and pushed.
  The file now builds a throwaway repository under the temp directory
  and makes assertions that can fail.
* New `test-arg-quoting.R` covers the quoting and injection fixes.
* New `test-init-project-profiles-dir.R` drives `init_project()`
  against a stub CLI on `PATH`, and in a source checkout checks the R
  profile set against `templates/bundles.yaml` and the CLI dispatcher.

# zzcollab 0.1.0

Re-baseline release. The R package version is reset to 0.1.0 to align with the
unified `ZZCOLLAB_VERSION` (CLI and template framework); release notes prior to
this reset are archived in `NEWS-pre-0.1.0.md`.

## Changes

* The R wrapper tracks the presence-driven reproducibility-toggle CLI: project
  status, verification, and the self-adapting Docker/renv environment. See
  `CHANGELOG.md` for the full framework history.
