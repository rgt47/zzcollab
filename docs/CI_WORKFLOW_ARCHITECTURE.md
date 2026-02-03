# ZZCOLLAB CI Workflow Architecture

## White Paper: Understanding the CI Design and Current Issues

**Author:** Claude Code Analysis
**Date:** February 2026
**Status:** Technical Review Document

---

## Executive Summary

This document analyzes the zzcollab CI workflow architecture, explains its intended
purpose, identifies the root cause of current failures across research repositories,
and proposes solutions aligned with the framework's reproducibility philosophy.

---

## 1. The Purpose of CI Workflows in ZZCOLLAB

### 1.1 Primary Objectives

The CI workflows serve five interdependent validation purposes:

1. **Reproducibility Verification** - Validates that analyses execute identically
   across different computational environments

2. **Dependency Completeness** - Detects when code uses packages not declared in
   `renv.lock` or DESCRIPTION

3. **Package Version Consistency** - Ensures all team members work with identical
   package versions

4. **Code Quality Assurance** - Runs R CMD check and test suites

5. **Collaborative Safety Nets** - Prevents merging code that breaks the
   reproducibility guarantee

### 1.2 What CI is Testing

The workflows validate three dimensions:

```
Dimension 1: Environmental Consistency
  Docker (R version + system libs)
      ↓
  renv.lock (exact package versions)
      ↓
  .Rprofile (session options)
      ↓
  Source code (computational logic)

Dimension 2: Dependency Synchronization
  Code ↔ DESCRIPTION ↔ renv.lock ↔ CRAN

Dimension 3: Union Model
  renv.lock = packages from ALL contributors
```

---

## 2. The Five Pillars Reproducibility Model

ZZCOLLAB's reproducibility guarantee rests on five version-controlled components:

| Pillar | Component | Responsibility |
|--------|-----------|----------------|
| 1 | Dockerfile | R version, system libraries, environment variables |
| 2 | renv.lock | **Source of truth** for exact package versions |
| 3 | .Rprofile | Session options (stringsAsFactors, contrasts, etc.) |
| 4 | Source Code | Explicit computational procedures |
| 5 | Research Data | Raw data (read-only) + derived data |

**Critical insight:** renv.lock is the source of truth, NOT the Docker image.
The Docker image provides a foundation and performance optimization, but renv.lock
specifies the actual requirements.

---

## 3. Two Workflow Templates: Design Intent

ZZCOLLAB contains two workflow templates with different philosophies:

### 3.1 Legacy Workflow (`templates/.github/workflows/r-package.yml`)

- **Container:** `rocker/verse:latest` (2.5 GB)
- **Package Management:** `remotes::install_deps()` from DESCRIPTION
- **Philosophy:** Full-featured research compendium with publishing
- **Use Case:** Traditional R packages, manuscripts, Quarto blogs

### 3.2 Modern Workflow (`templates/workflows/r-package.yml`)

- **Container:** `rocker/r-ver:latest` (800 MB)
- **Package Management:** `renv::restore()` from renv.lock
- **Philosophy:** Strict reproducibility via renv
- **Use Case:** zzcollab research compendia

**The modern workflow was intended to provide stricter reproducibility** by using
the same renv.lock that developers use locally, ensuring CI tests exactly what
developers have tested.

---

## 4. The Current Problem

### 4.1 Symptom Chain

The research repositories fail CI with a cascade of errors:

```
Error 1: "there is no package called 'renv'"
  → rocker/r-ver has no packages pre-installed

Error 2: "Host R session (renv skipped)"
  → .Rprofile checks ZZCOLLAB_CONTAINER env var

Error 3: "there is no package called 'rcmdcheck'"
  → renv creates isolated library; CI tools not in renv.lock
```

### 4.2 Root Cause Analysis

The modern workflow has a **fundamental design flaw**: it conflates two incompatible
approaches:

1. **renv-based reproducibility** - Uses isolated library containing only packages
   in renv.lock

2. **CI tool requirements** - Needs `rcmdcheck`, `testthat`, and other tools that
   are NOT project dependencies

**The conflict:** When renv is active, R only sees packages in the renv library.
CI tools installed via `install.packages()` go to a different location and are
invisible to the renv-managed R session.

### 4.3 Why This Wasn't Caught Earlier

The workflow was designed for local Docker development where:

- Users enter interactively (`make r`)
- The .Rprofile handles everything automatically
- CI tools aren't needed inside the research environment
- R CMD check isn't run inside the container

GitHub Actions CI has different requirements:

- Non-interactive execution
- Needs CI tools (`rcmdcheck`, `testthat`)
- These tools must coexist with renv's isolated library

---

## 5. Solution Options

### Option A: Add CI Tools to renv.lock

**Approach:** Include `rcmdcheck`, `testthat`, `covr` in every project's renv.lock.

**Pros:**
- CI uses exact same packages as local development
- Strictest reproducibility

**Cons:**
- Bloats renv.lock with non-research dependencies
- Every project must manually add these packages
- Mixes CI infrastructure with research dependencies

### Option B: Use Legacy Workflow for All Projects

**Approach:** Switch research repos to use the DESCRIPTION-based workflow.

**Pros:**
- CI tools install naturally via `remotes::install_deps()`
- Simpler, more standard R package approach
- Already working (zzcollab's own CI passes)

**Cons:**
- CI doesn't use renv.lock (different packages than local)
- Less strict reproducibility in CI (though still reproducible locally)

### Option C: Fix the Modern Workflow Properly

**Approach:** Modify workflow to install CI tools OUTSIDE renv's library.

```yaml
- name: Install CI tools (outside renv)
  run: |
    # Install to system library, not renv library
    Rscript -e "
      renv::deactivate()
      install.packages(c('rcmdcheck', 'testthat'), lib = .libPaths()[1])
      renv::activate()
    "
```

**Pros:**
- Maintains renv-based reproducibility for project packages
- CI tools available but separate from project dependencies

**Cons:**
- Complex library management
- Potential path ordering issues
- May confuse renv's dependency detection

### Option D: Hybrid Approach (Recommended)

**Approach:** Use renv for package restoration, but run R CMD check with explicit
library paths.

```yaml
env:
  ZZCOLLAB_CONTAINER: "true"

steps:
  - name: Install renv and restore
    run: |
      Rscript -e "install.packages('renv')"
      Rscript -e "renv::restore(prompt = FALSE)"

  - name: Install CI tools to separate library
    run: |
      mkdir -p /tmp/ci-tools
      Rscript -e "install.packages(c('rcmdcheck', 'testthat'),
                                   lib = '/tmp/ci-tools',
                                   repos = 'https://cloud.r-project.org')"

  - name: Run R CMD check
    run: |
      Rscript -e ".libPaths(c('/tmp/ci-tools', .libPaths()));
                  rcmdcheck::rcmdcheck(args = '--no-manual', error_on = 'error')"
```

**Pros:**
- Clear separation: project packages (renv) vs CI tools (/tmp/ci-tools)
- renv.lock remains pure (only research dependencies)
- CI tests with exact same packages as local development

**Cons:**
- More complex workflow
- Requires careful library path management

---

## 6. Recommendation

**Short term:** Use Option B (legacy workflow) to unblock research repos immediately.
The legacy workflow is battle-tested and working.

**Long term:** Implement Option D (hybrid approach) in zzcollab's template, then
propagate to research repos. This maintains the strict reproducibility philosophy
while properly handling CI tool requirements.

---

## 7. Implementation Plan

### Phase 1: Immediate Fix (Today)

1. Update failing research repos to use legacy workflow
2. Or: Add `rcmdcheck` and `testthat` to each project's DESCRIPTION Suggests field

### Phase 2: Template Fix (This Week)

1. Redesign `templates/workflows/r-package.yml` with hybrid approach
2. Test on one research repo
3. Document the CI tool isolation pattern

### Phase 3: Propagation (Next Week)

1. Update all research repos with fixed workflow
2. Add CI workflow documentation to ZZCOLLAB_USER_GUIDE.md

---

## Appendix: The .Rprofile Container Detection

The .Rprofile checks `ZZCOLLAB_CONTAINER=true` to decide behavior:

```r
in_container <- Sys.getenv("ZZCOLLAB_CONTAINER") == "true"

if (!in_container) {
  message("Host R session (renv skipped)")
} else {
  # Full renv workflow:
  # - Activate renv
  # - Auto-restore packages
  # - Auto-snapshot on exit
}
```

This design enables:

- **Host development:** Fast iteration without renv overhead
- **Container development:** Full reproducibility guarantee
- **CI environments:** Must set `ZZCOLLAB_CONTAINER=true` to enable renv

The CI workflow was missing this environment variable, causing renv to be skipped
even though `renv::restore()` was called explicitly afterward.
