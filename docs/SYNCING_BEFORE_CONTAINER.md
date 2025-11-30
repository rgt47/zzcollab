# Syncing Dependencies Before Entering Container

## Overview

When transitioning from host-based development to container-based development in zzcollab, running validation **before** entering the container is critical for ensuring your container environment matches your code's requirements.

This guide covers:
- Why validation before container entry is essential
- The disconnect between host R and container R
- Recommended workflow for smooth transitions
- Edge cases and alternatives

## The Problem: Two Isolated R Environments

**Host R and Container R are completely separate:**

```
Host Machine                    Docker Container
├── R installation             ├── R installation (isolated)
├── Package library            ├── renv-managed library
│   ~/R/library/               │   renv/library/
│   ├── dplyr/                 │   (empty until restored)
│   ├── ggplot2/               │
│   └── tidyr/                 │
└── Your code                  └── Your code (mounted)
    analysis.R                     analysis.R
```

**Key insight**: Installing packages on host R does **not** make them available in the container. The container environment is defined by `renv.lock`, not your host R library.

## Common Scenario: Host Development → Container Transition

### Your Current State

After developing on the host machine with R installed:

```bash
✅ Code files with library(dplyr), library(ggplot2), etc.
✅ Host R library has these packages installed
❌ DESCRIPTION doesn't reflect new packages
❌ renv.lock is still minimal (doesn't track host installations)
```

### The Critical Gap

**renv.lock doesn't automatically know about host installations!**

- You installed packages via `install.packages()` on host
- Host R library was updated
- `renv.lock` was NOT updated (it's a static file)
- Container will use outdated `renv.lock`

## Without Validation: The Painful Path

```bash
# Enter container with minimal/outdated renv.lock
make r

# Inside container:
source("my_analysis.R")
# Error in library(dplyr): there is no package called 'dplyr'
# Error in library(ggplot2): there is no package called 'ggplot2'
# Error in library(tidyr): there is no package called 'tidyr'

# Manual reconstruction of environment:
install.packages("dplyr")
install.packages("ggplot2")
install.packages("tidyr")
install.packages("readr")
# ... tediously redoing all your host installations
# ... easy to forget packages
# ... risk of version mismatches
```

**Problems:**
- Tedious manual package installation
- Error-prone (easy to miss packages)
- No documentation of dependencies in DESCRIPTION
- Time-consuming debugging session

## With Validation: The Smooth Path

```bash
# 1. Sync dependencies from code to renv.lock
make check-renv

# Output shows automatic fixes:
# ✅ Added dplyr to DESCRIPTION Imports
# ✅ Added dplyr (1.1.4) to renv.lock
# ✅ Added ggplot2 to DESCRIPTION Imports
# ✅ Added ggplot2 (3.4.4) to renv.lock
# ✅ Added tidyr to DESCRIPTION Imports
# ✅ Added tidyr (1.3.0) to renv.lock
# ✅ All missing packages added

# 2. Review what was captured
git diff DESCRIPTION renv.lock

# 3. Commit synchronized state
git add DESCRIPTION renv.lock
git commit -m "Sync dependencies before containerization"

# 4. Enter container with complete renv.lock
make r

# Inside container:
# renv::restore() automatically installs all packages
# (happens during container startup)

source("my_analysis.R")      # ✅ Works immediately!
```

**Benefits:**
- Automatic dependency detection
- Complete environment reconstruction
- DESCRIPTION properly documented
- Container ready to run code immediately

## How Validation Bridges the Gap

### What `make check-renv` Does

1. **Scans code for package usage**
   - Extracts from `library(pkg)`
   - Extracts from `require(pkg)`
   - Extracts from `pkg::function()` calls

2. **Updates DESCRIPTION**
   - Adds missing packages to Imports section
   - Pure shell implementation (awk)

3. **Updates renv.lock**
   - Queries CRAN API for package metadata
   - Adds proper JSON entries with versions
   - Pure shell implementation (curl + jq)

4. **Ensures consistency**
   - Code → DESCRIPTION → renv.lock chain complete
   - Container has everything code needs

### Why This Works

**Validation looks at CODE, not host library:**
- Independent of where packages are installed on host
- Captures actual dependencies from code analysis
- Works even if you wrote code without running it
- Platform-independent (works on macOS, Linux, CI/CD)

## Recommended Transition Workflow

### Standard Pattern

```bash
# ============================================
# Phase 1: Host-Based Development
# ============================================

# Develop your analysis on host
vim analysis/scripts/my_analysis.R

# Install packages as needed (standard R workflow)
R
> install.packages("dplyr")
> install.packages("ggplot2")
> q()

# ============================================
# Phase 2: Synchronization Checkpoint
# ============================================

# Extract dependencies from code → DESCRIPTION → renv.lock
make check-renv

# Review captured dependencies
git diff DESCRIPTION renv.lock

# Commit synchronized state
git add DESCRIPTION renv.lock
git commit -m "Sync dependencies before containerization"

# ============================================
# Phase 3: Container Development
# ============================================

# Enter container with complete environment
make r

# Your code runs immediately
source("analysis/scripts/my_analysis.R")

# Continue development in container
# Packages installed in container auto-captured on exit
```

### Quick Reference Commands

```bash
# Full validation + auto-fix (recommended)
make check-renv

# Validation only (no auto-add)
make check-renv-no-fix

# Skip tests/ and vignettes/ directories
make check-renv-no-strict

# Enter container after validation
make r
```

## Edge Cases and Alternatives

### Scenario 1: Need Exact Host Versions

If you need the **exact same versions** from host (not latest from CRAN):

```bash
# Use renv on host to capture exact versions
Rscript -e 'renv::init()'       # Scans code + host library
Rscript -e 'renv::snapshot()'   # Captures exact host versions

# Review and commit
git add renv.lock
git commit -m "Capture exact host package versions"

# Enter container
make r                           # Gets identical versions
```

**Trade-off:**
- Pro: Exact version matching with host
- Con: Requires R on host
- Con: May capture unnecessary development packages

### Scenario 2: GitHub or Non-CRAN Packages

Validation auto-adds CRAN packages only. For GitHub packages:

```bash
# 1. Manually add to DESCRIPTION first
vim DESCRIPTION
# Add line: Remotes: tidyverse/dplyr

# 2. Run validation to ensure consistency
make check-renv

# 3. For GitHub packages, install in container
make r
# Inside container:
install.packages("remotes")
remotes::install_github("tidyverse/dplyr")
# Auto-snapshot on exit captures it
```

### Scenario 3: Wrote Code Without Running It

If you wrote code but never executed it (no host R usage):

```bash
# renv.lock is minimal (base packages only)
# Code has library() calls but packages never installed

# Validation extracts all dependencies from code
make check-renv

# Enter container with complete dependencies
make r

# Code runs for the first time in container
```

**This works because validation analyzes code statically**, not runtime state.

## Why Validation Before Container Is Essential

### 1. Prevents Runtime Errors

```r
# Without validation:
library(dplyr)  # Error: there is no package called 'dplyr'

# With validation:
library(dplyr)  # ✅ Works immediately
```

### 2. Ensures Dependency Completeness

- Captures all packages from code analysis
- Documents dependencies in DESCRIPTION
- Populates renv.lock for container restore
- Container environment matches code requirements

### 3. Smooth Development Transition

```bash
# Clean handoff from host to container
make check-renv              # Sync state
make r                       # Enter with complete environment
# Work continues without interruption
```

### 4. Maintains Best Practices

- DESCRIPTION serves as dependency manifest
- renv.lock provides reproducible environment
- Git tracks dependency changes
- CI/CD can validate consistency

## Validation Mechanisms

### Code Scanning

Validation extracts packages from:

```r
# Direct library loading
library(dplyr)
require(ggplot2)

# Namespace qualification
dplyr::filter(data, condition)
ggplot2::ggplot(data, aes(x, y))

# Mixed usage
library(tidyr)
data %>% tidyr::pivot_longer(cols)
```

### Package Filtering

Applies 19 filters to avoid false positives:

- Blocklist: "package", "myproject", "local", "any"
- Pattern-based: Pronouns (my, your), generic nouns (file, path)
- Skip comments: Lines starting with `#`
- Skip documentation: README.Rmd, examples/, CLAUDE.md
- Length filter: Minimum 3 characters

### CRAN API Integration

```bash
# For each detected package:
curl -s "https://crandb.r-pkg.org/dplyr" | jq '.'

# Returns:
{
  "Package": "dplyr",
  "Version": "1.1.4",
  "Repository": "CRAN",
  ...
}

# Adds to renv.lock with proper JSON structure
```

## Common Mistakes to Avoid

### ❌ Assuming Container Sees Host Packages

```bash
# Wrong assumption:
# "I installed dplyr on my Mac, so container should have it"

# Reality:
# Container is isolated, uses only renv.lock
```

### ❌ Skipping Validation

```bash
# Problematic workflow:
make r                       # Enter with outdated renv.lock
# Manual package installation nightmare begins

# Correct workflow:
make check-renv              # Sync dependencies first
make r                       # Enter with complete environment
```

### ❌ Not Committing Sync Results

```bash
# Lost work:
make check-renv              # Updates DESCRIPTION and renv.lock
make r                       # Uses updated files
# Exit container, discard changes
# Next container entry has outdated renv.lock again

# Correct:
make check-renv
git add DESCRIPTION renv.lock
git commit -m "Sync dependencies"
make r
```

## Integration with zzcollab Workflow

### Complete Development Cycle

```bash
# 1. Create project
zzcollab -p myproject -r analysis

# 2. Develop on host (optional)
vim analysis/scripts/explore.R
Rscript analysis/scripts/explore.R

# 3. Sync before containerization
make check-renv
git add DESCRIPTION renv.lock
git commit -m "Add initial dependencies"

# 4. Container-based development
make r
# Work in container
# Packages auto-captured on exit via .Last()

# 5. Validation after container exit (automatic)
# Runs automatically after all docker-* targets

# 6. Commit and share
git add renv.lock
git commit -m "Add analysis dependencies"
git push
```

### Team Collaboration

```bash
# Team Lead workflow:
make check-renv              # Sync local development
git add DESCRIPTION renv.lock
git commit -m "Update dependencies"
git push

# Team Member workflow:
git pull                     # Get updated renv.lock
make r                       # Container installs team's packages
# Work continues with consistent environment
```

## Summary

**Always run `make check-renv` before `make r`** when transitioning from host development to container development.

**Why:**
- Host R and container R are isolated environments
- renv.lock doesn't track host installations automatically
- Validation bridges the gap by analyzing code
- Container needs complete renv.lock for package restoration
- Prevents frustrating "package not found" errors

**The validation step is the essential mechanism** for capturing your development dependencies and making them available in the container.

**Pattern to remember:**
```bash
make check-renv              # Sync state
make r                       # Enter with complete environment
```

This ensures your container environment matches your code's expectations and provides a smooth development experience.
