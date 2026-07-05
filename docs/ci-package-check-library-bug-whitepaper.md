# CI Bug: renv-Restored Library Not Reaching R CMD check

*2026-07-05 10:31 PDT*

Status: OPEN (diagnosis complete, fix in progress). This is a live document,
updated after each debugging experiment. See the Experiment Log at the end.

## Abstract

The zzcollab `R Package Check` workflow (`.github/workflows/r-package.yml`)
passes for repositories whose `Imports` are all present in the base container
image (`rocker/tidyverse`), and fails for repositories that import a package
outside that base image. The failure surfaced during the pilot migration of the
`res/03-adaptive-alloc-mmrm` compendium, whose `Imports` include `mmrm` (a
package not in `rocker/tidyverse`). This paper records the symptom, the
diagnostic reasoning, the confirmed root cause, and the plan to fix it, and it
maintains a running log of fix experiments and their outcomes.

## Symptom

On commit `e2a8739` of `rgt47/adaptive-alloc-mmrm`, with a coherent manifest
(zzrenvcheck gate passing, `renv.lock` containing `mmrm 0.3.18`), CI reported:

- `Render Reports`: success
- `R Package Check`: failure

The `R CMD check` step reported (verified, from the run log):

```
* checking package dependencies ... ERROR
Package required but not available: 'mmrm'
Packages suggested but not available for checking: [Suggests set]
Status: 1 ERROR
```

The namespace check passed (`* checking package namespace information ... OK`),
so the earlier hypothesis that a stale `NAMESPACE` (one export versus twelve
`@export` tags) was the cause is rejected.

## Diagnosis process

The reasoning proceeded from the error message outward, labelling each finding
by epistemic status.

1. **Inspected.** The error is raised at `checking package dependencies`, an
   early `R CMD check` phase that only verifies declared dependencies are
   installed and findable on the library path. `mmrm` is declared in `Imports`,
   so its absence from the check library is a hard error.
2. **Verified (from the run log).** The restore step did install `mmrm`:
   `renv::restore` reported downloading and installing `mmrm 0.3.18` and its
   compiled dependency `TMB 1.9.21` into
   `~/.cache/R/renv/library/adaptive-alloc-mmrm-<hash>/linux-ubuntu-noble/R-4.6/`.
   So the package was retrieved; the failure is not a download or compile
   failure.
3. **Verified (from the run log).** The check job runs inside a container:
   `docker create ... rocker/tidyverse:4.6.0`. The `container:` key in the
   workflow fixes the check environment to `rocker/tidyverse:4.6.0`, a generic
   image, independent of the repository's own (verse) Dockerfile.
4. **Inspected (from the workflow source).** The check step runs
   `Rscript --no-init-file`, computes
   `rlib <- renv::paths[['library']]()`, sets
   `.libPaths(c(CI_TOOLS_LIB, rlib, .libPaths()))`, then calls
   `rcmdcheck::rcmdcheck(args = '--no-manual', error_on = 'error')` without an
   explicit `libpath`. The restore step, by contrast, runs a plain `Rscript`
   (init file sourced, so the project `.Rprofile` activates renv). The two
   steps therefore resolve renv in different activation states.
5. **Verified (cross-repository control).** The three repositories that pass this
   workflow all declare Imports that are present in the `rocker/tidyverse` base
   image or in base R: `peng1` imports `dplyr`, `ggplot2`; `fisher` imports
   `Rcpp`; `02` imports `stats`, `survival`. None of them has an Import outside
   the base image, so for those repositories `rcmdcheck` finds every Import in
   the container's own site library and the renv-restored library is never
   exercised. `03` is the first migrated repository with an Import
   (`mmrm`) outside the base image.

## Root cause

The `R CMD check` subprocess does not receive the renv-restored library on its
library path. `rcmdcheck` launches `R CMD check` as a child process whose
library path is governed by its `libpath` argument (propagated to the child via
`R_LIBS`). The workflow sets `.libPaths()` in the parent `Rscript` session but
does not pass `libpath` to `rcmdcheck`, and because the check step runs with
`--no-init-file`, renv is not activated there, so the `rlib` it computes does
not reliably match the location where the (renv-activated) restore step
installed the packages. The net effect is that the check subprocess sees only
the container's base site library. This is harmless for any package the base
image already ships, which is why the bug lay dormant across the first three
migrations, and fatal for any Import outside the base image.

This is a template defect, not a per-repository problem. It will affect every
compendium in the fleet that imports a specialised package (for example `mmrm`,
`TMB`-based models, `rstan`, geospatial stacks). The migration must not be
batched until the template is fixed and re-verified.

## Fix plan

The fix must ensure the check subprocess uses the library where renv restored
the packages, without regressing the three passing repositories. Candidate
approaches, in order of preference:

- **F1 (targeted, preferred).** In the check step, activate renv explicitly with
  `renv::load()` (which sets `.libPaths()` to the project library regardless of
  init-file state), and pass the resolved paths to `rcmdcheck` via its
  `libpath` argument. Minimal change; keeps the generic-container design.
- **F2.** Combine restore and check into a single renv-activated `Rscript`
  session, so `renv::paths$library()` and `.libPaths()` are guaranteed
  consistent with the restore. Slightly larger change; loses step separation.
- **F3 (fallback).** Run the check inside the repository's own built image (which
  bakes all dependencies via `renv::restore` at build time) rather than a
  generic container. Most faithful to the real environment, but heavier (an
  image build per check) and a larger redesign.

Validation protocol: apply the candidate to `03` only, push, and observe both CI
jobs. A candidate is accepted only when `R Package Check` and `Render Reports`
both pass on `03` AND a re-run of a known-good repository (`02`) still passes
(guarding against regression). Once accepted, port the change into
`templates/workflows/r-package.yml`, regenerate the workflow on the three
already-migrated repositories, and confirm they remain green before batching the
remaining fleet.

## Experiment Log

Each row records one debugging experiment: the change made, the commit, the
observed CI outcome, and the interpretation. Newest entries appended at the
bottom.

### E0: Baseline (the failure)

- **Change.** None; the pilot migration as first pushed.
- **Commit.** `e2a8739` (adaptive-alloc-mmrm).
- **Outcome.** `R Package Check`: failure (`mmrm` not available);
  `Render Reports`: success.
- **Interpretation.** Established the symptom and, with the cross-repository
  control, the root cause above. Baseline for all subsequent experiments.

### E1: F1, activate renv and pass libpath (PLANNED)

- **Change.** Replace the check step's `--no-init-file` path computation with
  `if (file.exists('renv.lock')) renv::load()` and call
  `rcmdcheck::rcmdcheck(..., libpath = c(CI_TOOLS_LIB, .libPaths()))`.
- **Commit.** (pending)
- **Outcome.** (pending)
- **Interpretation.** (pending)

---

*Source: ~/prj/sfw/07-zzcollab/zzcollab/docs/ci-package-check-library-bug-whitepaper.md*
