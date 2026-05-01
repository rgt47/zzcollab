# The Dependency Triad: DESCRIPTION, renv.lock, and Dockerfile

## Problem Statement

Running `zzc validate --fix` on a fresh workspace inflates DESCRIPTION
from 2 declared dependencies to 24, adding every transitive dependency of
`testthat`. This defeats the purpose of DESCRIPTION as a declaration of
*direct* dependencies and creates confusion about what the project
actually requires.

This document traces the generation and validation of the three
interdependent files --- DESCRIPTION, renv.lock, and Dockerfile ---
and proposes corrections to the validation logic.

## 1. The Three Files and Their Distinct Roles

Each file answers a different question:

| File | Question it answers | Scope |
|------|-------------------|-------|
| DESCRIPTION | What packages does this project *directly* use? | Direct deps only |
| renv.lock | What *exact* versions reproduce this environment? | Full transitive closure |
| Dockerfile | How do we build the container that runs this code? | Build instructions |

The critical invariant:

```
DESCRIPTION ⊆ renv.lock (direct deps are a subset of the lockfile)
renv.lock   ⊇ DESCRIPTION (lockfile includes transitive deps too)
```

DESCRIPTION should never contain transitive dependencies. That is the
sole responsibility of renv.lock.

## 2. Current Init Sequence

When the user runs `zzc init` or `zzc docker`, the files are created
in this order:

```
Step 1: setup_project()
        └── create_r_package_files()
            └── install_template("DESCRIPTION") or create_description_file()
            Creates: DESCRIPTION with Imports: renv, testthat

Step 2: create_renv_lock_minimal(r_version)
        Creates: renv.lock with Packages: {renv, testthat}
        (seed lockfile --- only 2 packages, no transitive deps)

Step 3: generate_dockerfile()
        └── extract_r_packages()
            Reads: code files + DESCRIPTION + renv.lock
        └── generate_dockerfile_inline()
            Creates: Dockerfile with COPY renv.lock + renv::restore()
```

This ordering is correct. Each step depends only on the output of
prior steps.

## 3. The Validation Bug

### 3a. What `validate_package_environment()` does

```
validation.sh:518  validate_package_environment()

1. Scan code      → code_packages     (e.g., {dplyr, ggplot2})
2. Parse DESC     → desc_imports      (e.g., {renv, testthat})
3. Parse renv.lock → renv_packages    (after snapshot: {renv, testthat,
                                       cli, rlang, glue, ...24 total})
4. Union all three → all_packages     ({dplyr, ggplot2, renv, testthat,
                                       cli, rlang, glue, ...})
5. Find missing from DESCRIPTION:
     all_packages - desc_imports      = {dplyr, ggplot2, cli, rlang, ...}
6. With --fix: add ALL missing to DESCRIPTION
```

### 3b. The defect

Step 5 compares the **full union** (which includes renv.lock's
transitive deps) against DESCRIPTION. Every transitive dependency in
renv.lock that is not in DESCRIPTION gets flagged as "missing" and,
with `--fix`, gets added.

After `renv::snapshot()` runs inside the container, renv.lock
legitimately contains the full transitive closure (24 packages for
`testthat` alone). The next `zzc validate --fix` or `make check-renv`
then dumps all 24 into DESCRIPTION's Imports field.

### 3c. Why this is wrong

DESCRIPTION exists to declare what the *author* uses, not what the
*resolver* computed. R's own `install.packages()` and `renv::restore()`
handle transitive resolution. Listing transitive deps in DESCRIPTION:

- Makes it impossible to distinguish direct from indirect dependencies
- Creates maintenance burden (manual version bumps for deps the author
  never explicitly chose)
- Violates CRAN submission norms (CRAN reviewers flag unnecessary
  Imports)
- Defeats `renv::snapshot(type = "explicit")`, which reads DESCRIPTION
  to decide what belongs in renv.lock

## 4. The renv.lock Lifecycle

Understanding the renv.lock lifecycle reveals when and how it acquires
transitive dependencies:

```
Phase 1: zzc init / zzc docker
          create_renv_lock_minimal() writes a SEED lockfile
          Contains: renv + testthat only (2 packages)

Phase 2: docker build → renv::restore()
          renv reads the seed lockfile inside the container
          Installs renv + testthat + all transitive deps
          The container now has ~24 packages installed

Phase 3: User works inside container (make r)
          Writes code using library(dplyr), library(ggplot2), etc.
          Runs renv::snapshot() (or auto-snapshot on exit)
          renv.lock now contains the FULL transitive closure
          of everything installed

Phase 4: zzc validate --fix  ← BUG MANIFESTS HERE
          Reads the now-fat renv.lock
          Unions it with code + DESCRIPTION
          Adds all transitive deps to DESCRIPTION
```

## 5. A Second Issue: testthat in Imports vs Suggests

The DESCRIPTION template places `testthat` under `Imports`:

```
Imports:
    renv,
    testthat (>= 3.0.0)
```

Per R packaging convention, `testthat` belongs in `Suggests` because it
is a development/testing dependency, not a runtime dependency.
`Imports` means "this package cannot be loaded without testthat", which
is false for a research compendium.

Similarly, `renv` is infrastructure, not a code dependency. Whether to
keep it in `Imports` is debatable, but it is at least defensible since
the `.Rprofile` calls `renv::activate()`.

Recommended template:

```
Imports:
    renv
Suggests:
    testthat (>= 3.0.0)
Config/testthat/edition: 3
```

## 6. A Third Issue: Two `create_renv_lock` Functions

Two separate functions create renv.lock files:

| Function | Location | Contents |
|----------|----------|----------|
| `create_renv_lock_minimal()` | docker.sh:104 | renv + testthat |
| `create_renv_lock()` | validation.sh:273 | Empty (no packages) |

`parse_renv_lock()` in validation.sh (line 393) calls the *empty*
version as a fallback:

```bash
[[ -f "renv.lock" ]] || { create_renv_lock || return 1; }
```

If validation runs before `zzc docker`, it creates an empty lockfile.
Then `cmd_docker` sees that renv.lock exists and skips
`create_renv_lock_minimal()`. The Dockerfile is generated with an
empty lockfile, and `renv::restore()` installs nothing.

## 7. Proposed Corrections

### 7a. Fix `validate_package_environment()` (the main bug)

DESCRIPTION should track packages found in **code**, not the union of
code + renv.lock. Change line 533 from:

```bash
# CURRENT (wrong): uses all_packages (union of code + DESC + renv.lock)
local missing_from_desc
mapfile -t missing_from_desc < \
    <(find_missing_from_description all_packages desc_imports)
```

to:

```bash
# PROPOSED: uses code_packages only (code is source of truth for DESC)
local missing_from_desc
mapfile -t missing_from_desc < \
    <(find_missing_from_description code_packages desc_imports)
```

The renv.lock check (line 534) should keep using the full union, since
renv.lock *is* supposed to contain everything.

### 7b. Fix the DESCRIPTION template

Move `testthat` from `Imports` to `Suggests`:

```
Imports:
    renv
Suggests:
    testthat (>= 3.0.0)
Config/testthat/edition: 3
```

Update the fallback `create_description_file()` in project.sh to match.

### 7c. Unify the two `create_renv_lock` functions

Either:

- (a) Remove `create_renv_lock()` from validation.sh and have
  `parse_renv_lock()` return an empty list instead of creating a
  file, OR
- (b) Have `create_renv_lock()` call `create_renv_lock_minimal()`
  so both paths produce the same seed lockfile.

Option (a) is cleaner: validation should not have the side effect of
creating files that affect the docker build.

### 7d. Consider the `compute_union_packages` scope

`compute_union_packages()` currently serves double duty:

1. Finding packages missing from DESCRIPTION
2. Finding packages missing from renv.lock

For purpose (1), the union should be code-only (or code + DESCRIPTION).
For purpose (2), the union of all three is appropriate since renv.lock
should be a superset of everything.

A clean separation would be:

```bash
# For DESCRIPTION: code is source of truth
local missing_from_desc
mapfile -t missing_from_desc < \
    <(find_missing_from_description code_packages desc_imports)

# For renv.lock: union of code + DESC is source of truth
local code_and_desc
mapfile -t code_and_desc < \
    <(printf '%s\n' "${code_packages[@]}" "${desc_imports[@]}" | sort -u)
local missing_from_lock
mapfile -t missing_from_lock < \
    <(find_missing_from_lock code_and_desc renv_packages)
```

This ensures:

- DESCRIPTION only gets packages the author explicitly uses in code
- renv.lock gets packages from both code and DESCRIPTION (since
  DESCRIPTION may declare deps not yet used in code, such as
  `testthat` before any tests are written)
- Neither file gets inflated with the other's transitive dependencies

## 8. Summary of File Relationships

```
                    ┌───────────────┐
                    │   R Code      │
                    │  library(X)   │
                    │  pkg::fn()    │
                    └──────┬────────┘
                           │ scanned by
                           │ extract_code_packages()
                           v
                    ┌───────────────┐
                    │  DESCRIPTION  │◄─── Author's direct deps
                    │  Imports: X   │     (code is source of truth)
                    │  Suggests: Y  │
                    └──────┬────────┘
                           │ read by renv::snapshot(type="explicit")
                           v
                    ┌───────────────┐
                    │  renv.lock    │◄─── Full transitive closure
                    │  X + deps(X)  │     (renv is source of truth)
                    │  Y + deps(Y)  │
                    └──────┬────────┘
                           │ COPY + renv::restore()
                           v
                    ┌───────────────┐
                    │  Dockerfile   │◄─── Build instructions
                    │  FROM rocker  │     (reads renv.lock + code)
                    │  renv::restore│
                    └───────────────┘
```

The arrows flow downward. Information should not flow upward:
renv.lock's transitive deps should never propagate back into
DESCRIPTION.

---

---
*Rendered on 2026-02-26 at 15:54 PST.*
*Source: /Users/zenn/prj/sfw/07-zzcollab/zzcollab/docs/white-paper-dependency-triad.md*
