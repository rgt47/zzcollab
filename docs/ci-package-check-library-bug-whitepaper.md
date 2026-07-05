# CI Bug: The renv-Restored Library Does Not Reach R CMD check

*2026-07-05 10:31 PDT*

Status: RESOLVED (E2 fixed the pilot; E3 confirmed no regression and ported the
fix to the shared template). This is a live document. It is updated after every
debugging experiment, whether the experiment succeeds or fails, so that the
reasoning trail is preserved in full. The running record is the Experiment Log at
the end.

This paper is written to be followed by a careful reader who is not an R or
continuous-integration specialist. The first section is a primer on the moving
parts; a reader already fluent in R packaging and GitHub Actions may skip it.

## 1. A primer on the moving parts

To understand the bug, six ideas need to be in place. Each is described here in
plain terms before the diagnosis uses it.

### 1.1 R packages and libraries

An R *package* is a bundle of reusable code (for example `ggplot2` for graphics,
or `mmrm` for a particular statistical model). To use a package, R must first
find it installed on disk. The folders on disk where R looks for installed
packages are collectively called the *library path*. Inside a running R session
the function `.libPaths()` returns this list of folders, in the order R searches
them. When code calls `library(mmrm)` or `mmrm::fit(...)`, R walks the library
path looking for a folder named `mmrm`; if it finds none, the operation fails
with a message of the form 'there is no package called mmrm'. The single most
important idea in this paper is therefore simple: **a package is only usable if
the folder it lives in is on the library path of the R session that needs it.**

### 1.2 A research compendium as an R package

Each project in this fleet is structured as an R package (this gives it a
standard, checkable layout even though its purpose is a research paper, not a
library for others). Two files at the root declare its dependencies:

- `DESCRIPTION` lists, by name, which packages the project needs, split into
  roles: `Imports` (needed by the project's own functions in the `R/` folder)
  and `Suggests` (needed only by the analysis or the tests).
- `renv.lock` is a machine-generated manifest that records the *exact version*
  of every package in the full dependency tree, so the environment can be
  reproduced precisely later.

`DESCRIPTION` says *what* is needed; `renv.lock` pins *which exact versions*.

### 1.3 renv, the environment manager

`renv` is a separate tool (itself an R package) whose job is to create and
restore a project-specific library from `renv.lock`. The key verb is
`renv::restore()`: read `renv.lock`, and install every recorded package at its
recorded version into a library dedicated to this project. renv also *activates*
itself through the project's `.Rprofile` file, a small script R runs
automatically at startup: when a normal R session starts inside the project,
`.Rprofile` runs, renv wakes up, and it silently sets `.libPaths()` to point at
the project's private library. This activation step is central to the bug,
because it only happens when `.Rprofile` is allowed to run.

### 1.4 Continuous integration and GitHub Actions

*Continuous integration* (CI) means: every time code is pushed to the shared
repository, an automated service checks it out onto a fresh machine and runs a
predefined sequence of commands, reporting pass or fail. Here the service is
GitHub Actions, and the sequence is written in a YAML file,
`.github/workflows/r-package.yml`. That file defines *jobs*, and each job is a
list of *steps*. Every step runs as its own shell command. A subtle but crucial
consequence: **each step is a fresh shell**. Variables set in one step, and the
in-memory state of an R session in one step, do not carry over to the next step.
What persists between steps is only what is written to disk on the shared
machine.

### 1.5 Containers and base images

To make the CI machine reproducible, the check job does not run on the bare
runner. It runs inside a *container*: a lightweight, prebuilt virtual
environment created from a *base image*. This job uses the base image
`rocker/tidyverse:4.6.0`, which ships with R and a fixed set of popular packages
(the tidyverse: `dplyr`, `ggplot2`, `tidyr`, and their dependencies, plus a few
others such as `Rcpp`) already installed in a system-wide library. Packages that
come with the base image are therefore already on the library path for free.
Packages *not* in the base image must be installed during the CI run, and, per
section 1.1, installed *onto the library path of the session that will use
them*. The whole bug lives in that last clause.

### 1.6 R CMD check, and why it runs as a subprocess

`R CMD check` is R's official quality gate for a package. Among many checks, an
early one, labelled 'checking package dependencies', verifies that every package
named in `DESCRIPTION` under `Imports` is actually installed and findable. If an
`Imports` package is missing from the library path, this check is a hard error
and the whole run fails.

The workflow does not call `R CMD check` directly; it calls it through a
convenience R package named `rcmdcheck`, via `rcmdcheck::rcmdcheck(...)`. An
important detail: `rcmdcheck` does not run the check inside the current R
session. It launches a brand-new, separate R process (a *subprocess*) to run
`R CMD check`, because a clean check must not be contaminated by whatever is
already loaded in the caller. That subprocess gets its library path from
`rcmdcheck`'s `libpath` argument (which `rcmdcheck` passes down to the child by
setting the `R_LIBS` environment variable). This means that adjusting
`.libPaths()` in the *calling* session does not, by itself, change what the
*check subprocess* can see; the library must be handed over explicitly through
`libpath`. This distinction is the second half of the bug.

## 2. Symptom

On commit `e2a8739` of the pilot repository `rgt47/adaptive-alloc-mmrm`, with a
verified-coherent manifest (the zzrenvcheck gate passed, and `renv.lock`
contained `mmrm 0.3.18`), CI reported:

- `Render Reports`: success (the manuscript PDF built).
- `R Package Check`: failure.

The failing step reported (verified, quoted from the run log):

```
* checking package dependencies ... ERROR
Package required but not available: 'mmrm'
Packages suggested but not available for checking: [the Suggests set]
Status: 1 ERROR
```

Read against section 1.6: `R CMD check` looked for `mmrm` (declared under
`Imports`) on its library path and did not find it. Note also that the immediately
preceding namespace check passed, so the earlier suspicion that a stale
`NAMESPACE` file was to blame is rejected; the sole error is the missing package.

## 3. Diagnosis process

The reasoning moved from the error outward, and every finding below is tagged
with its epistemic status: *verified* (executed and observed in the logs),
*inspected* (read directly from a source file), or *inferred* (deduced from
surrounding evidence).

1. **Inspected.** The error arises at 'checking package dependencies', which only
   asks whether declared dependencies are installed and on the path (section
   1.6). So the question is narrowly: why is `mmrm` not on the check
   subprocess's library path?
2. **Verified.** `mmrm` was in fact downloaded and installed during the run. The
   restore step's log shows `renv::restore` fetching and installing `mmrm 0.3.18`
   and its compiled companion `TMB 1.9.21` into a renv library under
   `~/.cache/R/renv/library/adaptive-alloc-mmrm-<hash>/`. So this is not a
   download or compilation failure; the package exists on disk somewhere. The
   fault is that the check cannot see *where* it was put.
3. **Verified.** The check job runs inside the `rocker/tidyverse:4.6.0` container
   (the run log shows the `docker create ... rocker/tidyverse:4.6.0` command).
   The container is fixed and generic; it is not the project's own (verse) image.
4. **Inspected.** The two relevant steps resolve renv differently. The restore
   step runs a plain `Rscript`, so `.Rprofile` runs and renv activates (section
   1.3); packages land in renv's project library. The check step runs
   `Rscript --no-init-file`, a flag that tells R to skip `.Rprofile`; renv
   therefore never activates in the check step. Because each step is a fresh
   shell (section 1.4), nothing about renv's active library state carries from
   the restore step into the check step.
5. **Verified (a controlled comparison).** Three sibling repositories pass this
   very workflow: `peng1` (imports `dplyr`, `ggplot2`), `fisher` (imports
   `Rcpp`), and `02` (imports `stats`, `survival`). Every one of those `Imports`
   is a package already present in the `rocker/tidyverse` base image or in base
   R. So for those three, the check subprocess finds all Imports in the
   container's own library and never needs the renv-restored library at all. The
   bug was therefore invisible until a repository imported something outside the
   base image. `03` is the first such case: `mmrm` is not in the base image.

The controlled comparison in step 5 is the decisive move. It converts a vague
'something about the library is wrong' into a precise, testable claim: the
renv-restored library is not reaching the check, and this only shows up for
Imports absent from the base image.

## 4. Root cause

Combining sections 1.1, 1.4, and 1.6: the packages that `renv::restore` installs
do not end up on the library path of the `R CMD check` subprocess. There are two
compounding reasons, and the debugging (section 6) peeled them apart in order.

- The check step skips `.Rprofile` (`--no-init-file`), so renv is not active
  there and the step cannot even rely on renv to tell it where the project
  library is, nor to place that library on the path.
- Even with the path known, adjusting `.libPaths()` in the calling session does
  not propagate to the check subprocess unless it is passed via `rcmdcheck`'s
  `libpath` argument.

An analogy. Imagine the restore step is a delivery that drops the needed books
into a specific reading room, but records the room number only on a note that is
thrown away at the end of the shift (the fresh-shell boundary). The check step is
a new librarian who arrives, is never told which reading room to search, and so
searches only the building's permanent open shelves (the base image). If every
requested book happens to be on the open shelves already (the three passing
repos), no one notices the lost note. The first time a book is requested that
lives only in the delivered reading room (`mmrm`), the search fails.

This is a defect in the shared workflow *template*, not in any one repository. It
will strike every compendium in the fleet that imports a specialised package
(for example `mmrm`, other `TMB`-based models, `rstan`, geospatial stacks). The
migration must not be batched until the template is fixed and re-verified.

### 4.1 The library paths in play, in detail

The whole bug is an accounting error about folders. It is worth being fully
explicit about which folders exist, what each contains, and which R session can
see each one. During a check run there are, at various moments, five distinct
library locations on the machine.

| # | Location | Put there by | Contains | Default visibility |
| --- | --- | --- | --- | --- |
| L1 | Container base site-library, `/usr/local/lib/R/site-library` | Baked into `rocker/tidyverse` | the tidyverse and its dependencies (`dplyr`, `ggplot2`, `Rcpp`, ...), base-recommended packages (`MASS`, `nlme`, `survival`) | On `.libPaths()` of *every* R session in the container, automatically |
| L2 | renv project library, `~/.cache/R/renv/library/<project>-<hash>/.../` | `renv::restore` when renv is *activated* | the pinned packages from `renv.lock`, including `mmrm` | Only visible to a session where renv has been activated |
| L3 | renv global cache, `~/.cache/R/renv/cache/...` | renv, underneath everything | one content-addressed copy of each package binary; L2 is symlinks into it | Not a library path itself; it backs L2 and is what `actions/cache` persists |
| L4 | CI tools library, `/tmp/ci-tools` (`CI_TOOLS_LIB`) | an explicit `install.packages(lib = ...)` step | `rcmdcheck`, `tinytest` | Only when a step explicitly prepends it to `.libPaths()` |
| L5 | The R CMD check subprocess's path | `rcmdcheck` via `R_LIBS` | whatever `libpath` it is handed | Set fresh for the child process; does *not* inherit the parent's `.libPaths()` unless passed |

The three things that make this confusing are all in this table. First, L1 is
free and always present, which is exactly why the bug hides: if an Import is in
L1, no other location matters. Second, L2 (where `mmrm` actually goes) is only
visible after activation, and activation is precisely what the check step
suppresses with `--no-init-file`. Third, L5 is a *separate* path belonging to the
check subprocess; the parent session's `.libPaths()` is not automatically the
child's, so a package can be perfectly visible to the calling `Rscript` and still
invisible to the check.

It helps to trace the path arithmetic of each experiment as a small ledger of
'where did the package go' versus 'where did the check look'.

**E0 (baseline).** Restore ran with `.Rprofile` active, so renv activated and
installed `mmrm` into L2. The check step ran `--no-init-file`, so renv did not
activate and L2 was not on its path. Its path was, in effect, `[L4, rlib, L1]`,
where `rlib` was computed by `tryCatch(renv::paths[['library']](), error =
Sys.glob('renv/library/*/*')[1])`. Because renv was not importable in this step
(see E1), the `tryCatch` fell to the glob, which matched the *project-relative*
folder `renv/library/...`, an empty or non-existent path, not the real L2 under
`~/.cache`. So the effective path was `[L4, (nothing useful), L1]`, and since
`mmrm` lives only in L2, the check subprocess (whose L5 defaulted to the parent
path) could not find it. `MASS` and `nlme` did resolve, but only because they are
base-recommended packages sitting in L1. The failure was thus guaranteed for
`mmrm` and impossible for `MASS`, which matches the observation exactly.

**E1 (activate renv, pass libpath).** The intent was to replace the guesswork
with `renv::load()`, which would set the path to L2 authoritatively, then pass
that path into L5 via `libpath`. But the step tried to call `renv::load()` before
renv was on the path: renv had been installed into L2 (redirected there by
activation during E0's restore), and the check step could not see L2. So the very
first token, `renv::`, failed with 'there is no package called renv'. The
experiment never reached the check. Its value was diagnostic: it proved that even
renv itself was mislocated, upgrading the diagnosis from 'the path is computed
wrongly' to 'the provisioning put things where this step cannot look'.

**E2 (one explicit library).** The remedy is to stop using L2 at all and route
everything through L4, which is an ordinary folder on the shared disk that any
step can see if it prepends it to the path. renv is installed into L4; then
`renv::restore(library = L4)` is told, explicitly, to place the pinned packages
(including `mmrm`) into L4 rather than into renv's default L2; the pre-existing
step installs `rcmdcheck` and `tinytest` into L4; and the check hands `libpath =
[L4, ...]` to the subprocess so L5 includes L4. Now a single folder, L4, holds
renv, the restored dependencies, and the check tools, and it is on the path of
both the calling session and the check subprocess. L3 (the global cache) still
does its job underneath, so nothing is recompiled needlessly and the between-run
cache still helps. If the accounting is right, `mmrm` is finally in the one place
the check looks.

## 5. Fix plan

A correct fix must guarantee that the check subprocess searches the same library
into which the dependencies were installed, without breaking the three
repositories that already pass. Candidate approaches, in order of preference:

- **F1 (targeted).** In the check step, activate renv explicitly with
  `renv::load()` so `.libPaths()` points at the project library regardless of
  whether `.Rprofile` ran, and hand that path to `rcmdcheck` via `libpath`.
  Smallest change; keeps the generic-container design. (Tested as E1; failed,
  see the log: it assumes renv is importable in the check step, which it is not.)
- **F2 (single explicit library).** Stop depending on renv's project-library
  resolution and on cross-step activation. Install renv and the check tools into
  one fixed folder that persists across steps (`CI_TOOLS_LIB`, at `/tmp/ci-tools`)
  and is placed first on the path; restore the pinned packages into that same
  folder with `renv::restore(library = CI_TOOLS_LIB)`; then run the check with
  `libpath` pointed at it. Everything the check needs then lives in one known
  place on the path, independent of activation state. (Testing as E2.)
- **F3 (fallback).** Run the check inside the repository's own built image, which
  bakes every dependency at build time, rather than a generic container. Most
  faithful to the real environment, but heavier (an image build per check) and a
  larger redesign.

Validation protocol. A candidate is applied to `03` alone and pushed. It is
accepted only when both `R Package Check` and `Render Reports` pass on `03`, AND
a re-run of a known-good repository (`02`) still passes, to guard against
regression. Once accepted, the change is ported into
`templates/workflows/r-package.yml`, regenerated onto the three already-migrated
repositories, and confirmed green there before the remaining fleet is batched.

## 6. Experiment Log

Each entry records one experiment: the change, the commit it was pushed as, the
observed CI outcome, and the interpretation that motivated the next experiment.
Entries are appended in order; the newest is at the bottom.

### E0: Baseline (the failure as first observed)

- **Change.** None; the pilot migration exactly as first pushed. The check step
  read `rlib <- tryCatch(renv::paths[['library']](), error = function(e)
  Sys.glob('renv/library/*/*')[1])`, set `.libPaths(c(CI_TOOLS_LIB, rlib,
  .libPaths()))`, and called `rcmdcheck::rcmdcheck(error_on = 'error')` with no
  `libpath` argument.
- **Commit.** `e2a8739` (adaptive-alloc-mmrm).
- **Outcome.** `R Package Check`: failure, 'Package required but not available:
  mmrm'. `Render Reports`: success.
- **Interpretation.** Established the symptom and, via the controlled comparison
  (section 3, step 5), the root cause. Note in hindsight that the `tryCatch`
  here was hiding a more fundamental error: if `renv::paths[...]` itself failed
  because renv was not importable, the fallback silently substituted a
  project-relative glob that did not match the real install location. E1 removed
  the mask and revealed this.

### E1: F1, activate renv and pass libpath (FAILED)

- **Change.** Replaced the path computation with
  `if (file.exists('renv.lock')) renv::load()` and called
  `rcmdcheck::rcmdcheck(..., libpath = c(CI_TOOLS_LIB, .libPaths()))`.
- **Commit.** `35fcee1` (adaptive-alloc-mmrm).
- **Outcome.** `R Package Check`: failure, with a *different* error (verified):
  `Error in loadNamespace(x) : there is no package called 'renv'`, raised at the
  `renv::load()` call.
- **Interpretation.** A changed error is progress: it shows the previous error
  was masking this one. renv itself is not on the check step's library path.
  Since the check step skips `.Rprofile` (`--no-init-file`) and each step is a
  fresh shell, the renv that the restore step used is not visible here. This also
  explains E0 precisely: E0's `tryCatch` was catching this same missing-renv
  error and falling back to a wrong path. The true root cause is therefore
  library *provisioning* across steps, one level deeper than path *resolution*.
  F1 is rejected because it presumes renv is importable in the check step.

### E2: F2, single explicit library for tools, restore, and check (SUCCEEDED)

- **Change.** Install `renv` into the fixed `CI_TOOLS_LIB` with that folder first
  on `.libPaths()`; run `renv::restore(library = CI_TOOLS_LIB)` so the pinned
  packages (including `mmrm`) install into the same folder; leave the existing
  step that installs `rcmdcheck` and `tinytest` into `CI_TOOLS_LIB`; and run the
  check with `libpath = c(CI_TOOLS_LIB, .libPaths())`. After this, renv, the
  restored dependencies, and the check tools all live in one folder (L4) that is
  on the path, so the check subprocess can find every Import. renv's global
  package cache (L3) still backs the installs, so caching between runs is
  preserved.
- **Commit.** `59d7981` (adaptive-alloc-mmrm).
- **Outcome.** `R Package Check`: success (verified). `Render Reports` remained
  success (unaffected by the workflow-only change). Both jobs green on `03`.
- **Interpretation.** The path accounting is now correct: `mmrm` is installed
  into L4 and the check subprocess is handed L4, so the 'checking package
  dependencies' phase finds it. F2 is validated on the pilot. Remaining before
  the fix is considered complete: (i) the regression guard, re-verify a
  known-good repository still passes under the same change, and (ii) port the
  change into `templates/workflows/r-package.yml` and regenerate it onto the
  already-migrated repositories, confirming they stay green. These are E3 and E4
  below.

### E3: Port F2 to the template and regenerate on migrated repos (SUCCEEDED)

- **Change.** Applied the E2 edit to `templates/workflows/r-package.yml` in
  zzcollab (commit `39eeaa0`), then regenerated the workflow on `fisher`,
  `peng1`, and `02` via `zzc doctor --fix --force` and pushed (`743de58`,
  `041d8b1`, `b79f08d`).
- **Outcome.** All three `R Package Check` runs: success (verified). No
  regression.
- **Interpretation.** The fix is confirmed safe for repositories whose Imports
  were already satisfied by the base image: routing everything through
  `CI_TOOLS_LIB` does not disturb them, and it repairs the case (`03`) that the
  base image could not satisfy. The bug is resolved at the template source, so
  every future scaffold and every migrated repository inherits the working check.

## 7. Resolution and lessons

The `R Package Check` workflow now installs renv, restores the pinned
dependencies, and installs the check tools all into one explicit library
(`CI_TOOLS_LIB`), and hands that library to the `R CMD check` subprocess via
`rcmdcheck`'s `libpath`. Because that single folder is on the path of both the
calling session and the check subprocess, every declared Import resolves,
whether or not it happens to be present in the container base image.

Three lessons generalise beyond this bug.

- **A dormant defect needs an adversarial input to surface.** The workflow had
  passed for three repositories only because their Imports coincided with the
  base image. The bug became visible the moment a repository imported something
  outside it (`mmrm`). Piloting one representative repository end to end, rather
  than batching, is what exposed it before it could fail a large fraction of the
  fleet.
- **A changing error message is progress.** E1 did not fix the problem, but by
  turning 'mmrm not available' into 'no package called renv' it proved the first
  error had been masking a deeper one, and it redirected the fix from path
  *resolution* to library *provisioning*.
- **Cross-boundary state is where CI bugs hide.** The two boundaries here were
  the fresh-shell boundary between steps (in-session `.libPaths()` does not
  persist) and the parent-to-subprocess boundary inside `rcmdcheck` (the child's
  path must be passed explicitly). Both were invisible until a package depended
  on crossing them correctly.

---

*Source: ~/prj/sfw/07-zzcollab/zzcollab/docs/ci-package-check-library-bug-whitepaper.md*
