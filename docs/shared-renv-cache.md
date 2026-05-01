# Shared renv Cache Architecture

## Summary

This document records the investigation into renv.lock growth during
workspace initialization and the subsequent decision to replace
per-project renv caches with a single shared host-level cache.

**Date:** 2026-02-19
**Status:** Implemented
**Files changed:**

- `templates/Makefile` -- host-side mount path
- `templates/.Rprofile` -- container-side cache path
- `modules/validation.sh` -- transitive dependency warning


## Problem Statement

When a new zzcollab workspace is created with the `analysis` profile
and a user enters the container via `make r`, renv installs a large
number of packages from the network. For a minimal Rmd file referencing
five direct packages (`knitr`, `rmarkdown`, `rms`, `survival`,
`zztab2fig`), the resulting `renv.lock` file contained 85 packages
and 3,139 lines after `renv::snapshot()`.

Every new project repeated this full download because the renv cache
was mounted from the project directory itself, providing no
cross-project reuse.


## Investigation

### Baseline

The `create_renv_lock_minimal()` function in `modules/docker.sh`
produces a skeleton `renv.lock` containing exactly two packages:

- `renv` (1.1.5)
- `testthat` (3.3.1)

The profile's package bundle definition in `bundles.yaml` (which
lists `renv`, `devtools`, `tidyverse`, `here` for the `analysis`
profile) is not written into `renv.lock` at project creation time.
The bundle determines the base Docker image and system libraries
but has no mechanical link to the lock file.

### Pre-session validation

The `make r` target depends on `check-renv`, which runs:

```
zzcollab validate --fix --strict --verbose
```

This scans all `.R`, `.Rmd`, `.qmd`, and `.Rnw` files for
`library()`, `require()`, and `pkg::fn()` calls. It then adds
any missing packages to both `DESCRIPTION` and `renv.lock` by
fetching metadata from the crandb API.

Critically, the host-side validation adds only direct packages.
It does not resolve or record transitive dependencies. For the
test workspace, this step brought `renv.lock` from 2 to 6
packages.

### Container session

When the container starts, `.Rprofile` activates renv via
`source("renv/activate.R")`. Because the renv library is empty
in a fresh container, `renv::restore()` installs the 6 packages
from `renv.lock` plus their full transitive dependency trees.
This is the source of the large installation volume.

### Post-session snapshot

On container exit, the entrypoint runs
`renv::snapshot(type = 'explicit', prompt = FALSE)`, which
writes the complete dependency graph into `renv.lock`. The file
grew from 6 entries to 85.

### Dependency expansion

The 6 direct packages expanded as follows:

| Direct package | Approximate transitive deps |
|:---------------|:----------------------------|
| `rms`          | ~30 (Hmisc, ggplot2 tree, quantreg, multcomp, ...) |
| `rmarkdown`    | ~15 (bslib, sass, htmltools, tinytex, ...) |
| `testthat`     | ~15 (callr, processx, waldo, pkgload, ...) |
| `knitr`        | ~5 (xfun, evaluate, highr, yaml) |
| `survival`     | ~2 (Matrix) |
| `renv`         | 0 |

### Cache architecture (before)

The Makefile mounted the renv cache from within the project:

```makefile
mkdir -p .cache/R/renv 2>/dev/null || true
-v $(pwd)/.cache/R/renv:$HOME_DIR/.cache/R/renv
```

The `.Rprofile` reinforced this by setting:

```r
Sys.setenv(
  RENV_PATHS_CACHE = file.path(getwd(), ".cache/R/renv")
)
```

Consequence: each project maintained an isolated cache at
`<project>/.cache/R/renv`. No packages were shared across
projects, and every new workspace incurred the full download
cost.


## Decision

Replace the per-project cache with a shared host-level cache
at `~/.cache/R/renv`.

### Rationale

- renv's cache is designed for cross-project sharing. It stores
  packages by name, version, and hash, and hard-links them into
  project-specific libraries. A single cached copy of a package
  serves all projects without duplication.
- The first project to use a given package version pays the
  download cost. All subsequent projects link from the cache
  with negligible overhead.
- The cache is machine-specific (compiled packages are not
  portable across OS or R versions), so there is no benefit
  to syncing it via Dropbox or similar services. Hard links
  also do not survive cross-filesystem copies.

### Changes

**`templates/Makefile`** -- mount shared host cache:

```makefile
mkdir -p $$HOME/.cache/R/renv 2>/dev/null || true
-v $$HOME/.cache/R/renv:$$HOME_DIR/.cache/R/renv
```

**`templates/.Rprofile`** -- point renv at home directory:

```r
if (Sys.getenv("RENV_PATHS_CACHE") == "") {
  Sys.setenv(
    RENV_PATHS_CACHE = file.path(
      Sys.getenv("HOME"), ".cache/R/renv"
    )
  )
}
```

**`modules/validation.sh`** -- added a warning when `--fix`
adds packages to `renv.lock`, noting that transitive
dependencies are not included and a container session with
`renv::restore()` + `renv::snapshot()` is required to complete
the lock file.

### Files not changed

- `modules/docker.sh` (lines 584, 598) -- these set the cache
  path inside the Dockerfile, which is the container-side
  target. The mount overlays this directory at runtime.
- `templates/renv/activate.R` -- renv's default fallback to
  `~/.cache/R/renv` is already correct.
- `templates/workflows/*.yml` -- GitHub Actions cache paths
  are unrelated to Docker mounts.
- `templates/unified/Dockerfile` -- container-internal path;
  overridden by the volume mount.


## Migration

Existing projects retain their per-project Makefile and
`.Rprofile`. To adopt the shared cache:

1. Update the `r` target in the project Makefile to mount
   `$$HOME/.cache/R/renv` instead of `$$(pwd)/.cache/R/renv`.
2. Update `.Rprofile` to use `Sys.getenv("HOME")` instead of
   `getwd()` for `RENV_PATHS_CACHE`.
3. Optionally delete the project-local `.cache/R/renv`
   directory to reclaim disk space.

New projects created with `zzc` will use the shared cache
automatically.


## Remaining Considerations

- **Validation does not resolve transitive dependencies.**
  The host-side `--fix` adds only directly referenced packages
  to `renv.lock`. A warning now alerts users that the lock
  file is incomplete until `renv::restore()` and
  `renv::snapshot()` run inside the container.

- **`renv.lock` size is inherent to renv's design.** The 85
  packages (3,139 lines) for a modest analysis workspace is
  expected behavior. The lock file records the complete
  dependency graph to ensure bitwise reproducibility. This
  cannot be reduced without changing the snapshot strategy
  (e.g., using `renv::snapshot(type = "implicit")` or
  locking only direct dependencies).

- **`create_renv_lock_minimal()` does not use bundle
  definitions.** The profile's package list in `bundles.yaml`
  is not written to `renv.lock` at project creation. The
  lock file starts with only `renv` and `testthat` regardless
  of profile. Whether this should change is a separate
  decision.
