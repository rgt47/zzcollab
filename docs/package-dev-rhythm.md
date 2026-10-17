# Package Development Rhythm in zzcollab
*2026-10-17 12:19 PDT*

## Overview

A zzcollab project uses two package layers at runtime:

1. **Rocker site-library** (`/usr/local/lib/R/site-library`) -- packages
   baked into the base image (e.g. `rocker/verse`). Includes the full
   tidyverse stack, knitr, rmarkdown, and ~200 supporting packages.
   Accessible via `renv/settings.json` `external.libraries`.

2. **renv project library** (`/opt/renv/library`) -- packages recorded in
   `renv.lock` and installed by `renv::restore()` during `docker build`.
   Project-specific packages live here.

Understanding which layer a package comes from determines whether a Docker
image rebuild is required after adding it to the code.

## The Practical Rhythm

### Step 1: Work in the container

Start a session with `make r`. Add `library()` calls freely as you develop.
R can load any package present in either layer.

### Step 2: Quit R

The post-session hook in `make r` runs automatically after `q()`:

```
zzrenvcheck::check_packages(auto_fix = TRUE, strict = TRUE,
                             skip_image_pkgs = TRUE)
```

This scans the project source files and adds any newly referenced packages
to `DESCRIPTION`. Because the project uses `snapshot.type = "explicit"`,
`renv::snapshot()` then reads `DESCRIPTION` as the authoritative dependency
list and writes those packages to `renv.lock`. Packages already in the
Docker image are skipped (so `tidyverse` and its dependencies are not
written to `DESCRIPTION` or `renv.lock` redundantly).

The chain is: code references package → `DESCRIPTION` updated → `renv.lock`
updated via snapshot. A package does not reach `renv.lock` unless it first
appears in `DESCRIPTION`.

### Step 3: Decide whether to rebuild

The rebuild decision depends on where the new packages come from:

| Package source | Available next session? | Rebuild needed? |
|---|---|---|
| Rocker site-library (tidyverse, knitr, etc.) | Yes, immediately | No |
| Already in renv project library | Yes, immediately | No |
| New to renv.lock, not in image | No -- missing until rebuild | Yes |

**Rule of thumb:** if `library(pkg)` worked in the current session, it will
work in the next one. If you had to `install.packages()` interactively to
get it working, it will be missing next session until you rebuild.

### Step 4: Rebuild when ready

```bash
make docker-build
```

This runs `renv::restore()` inside the image, installing all packages now in
`renv.lock` into `/opt/renv/library`. After the rebuild, every collaborator
who pulls the image has the full package set.

## When to Rebuild

There is no fixed schedule. Practical triggers:

- You added a niche package not in the rocker base (e.g. `palmerpenguins`,
  `patchwork`, `corrplot`) and need it reliably available.
- You are about to share the image with a collaborator or push to a registry.
- CI is failing because a package in `renv.lock` is not installed in the
  image.
- You ran `make reset-lock` to refresh all version pins.

For a tidyverse-heavy analysis post, you can often work for many sessions
without rebuilding because most packages are already in the rocker
site-library. For a post that pulls in unusual packages, rebuild after the
first session that adds them.

## Checking What Is in Each Layer

From inside the container:

```r
# Packages available via external.libraries (rocker site-library)
installed.packages(lib.loc = "/usr/local/lib/R/site-library")[, "Package"]

# Packages in the renv project library
installed.packages(lib.loc = Sys.getenv("RENV_PATHS_LIBRARY"))[, "Package"]

# Everything on the search path
.libPaths()
```

From the host, query the built image directly:

```bash
docker run --rm pp-eda Rscript -e \
  "cat(rownames(installed.packages(
     lib.loc = '/usr/local/lib/R/site-library')), sep = '\n')"
```

## zzrenvcheck vs renv::snapshot

`renv::snapshot()` is a write operation: it records whatever is declared in
`DESCRIPTION` into `renv.lock` (under `snapshot.type = "explicit"`). It has
no opinion on whether `DESCRIPTION` is complete or whether the code actually
uses the declared packages.

`zzrenvcheck` is a validation and repair layer that runs upstream of the
snapshot:

1. Scans source files for `library()` / `require()` calls
2. Detects packages used in code but missing from `DESCRIPTION`
3. Adds them to `DESCRIPTION` (auto-repair)
4. Calls `renv::snapshot()` -- which now reads the corrected `DESCRIPTION`
5. Skips packages already in the Docker image (`skip_image_pkgs`)

The distinction matters: calling `renv::snapshot()` alone after adding a new
`library()` call will do nothing useful if `DESCRIPTION` has not been
updated first. `zzrenvcheck` ensures `DESCRIPTION` is the correct input
before the snapshot runs.

## Related Make Targets

| Target | Purpose |
|---|---|
| `make check-renv` | Validate and auto-fix `renv.lock` (all packages) |
| `make check-renv-slim` | Same, but skip packages already in the image |
| `make docker-build` | Rebuild image, baking current `renv.lock` |
| `make reset-lock` | Rebuild `renv.lock` from fresh code scan |
