# validate.sh and the renv Cache

## Overview

A common question about zzcollab's validation system: **Does validate.sh modify the renv cache when syncing a new package?**

**Answer: No, validate.sh does NOT modify the renv cache.** It only updates manifest files (DESCRIPTION and renv.lock).

This document explains:
- The distinction between manifests and installations
- The two-phase architecture (manifest update vs package installation)
- Why this separation enables Docker-first workflows
- Complete workflow examples

## What validate.sh Actually Does

### ✅ What It DOES Modify

**1. DESCRIPTION file** (package metadata)
```
Package: myproject
Version: 0.1.0
Imports:
    dplyr,
    ggplot2,
    tidyr
```

**What changes:** Adds package names to the `Imports:` field

**2. renv.lock file** (package version manifest)
```json
{
  "R": {
    "Version": "4.5.0",
    "Repositories": [{"Name": "CRAN", "URL": "https://cloud.r-project.org"}]
  },
  "Packages": {
    "dplyr": {
      "Package": "dplyr",
      "Version": "1.1.4",
      "Source": "Repository",
      "Repository": "CRAN"
    },
    "ggplot2": {
      "Package": "ggplot2",
      "Version": "3.4.4",
      "Source": "Repository",
      "Repository": "CRAN"
    }
  }
}
```

**What changes:** Adds complete package entries with version information

### ❌ What It Does NOT Touch

**1. renv cache** (actual package installations)
```
~/.local/share/renv/cache/          # Linux
~/Library/Application Support/renv/  # macOS
```

**Contains:**
- Actual package installation files
- Binary compiled code
- R source files
- Documentation and metadata

**Status:** Not modified by validate.sh

**2. Project renv library** (local package directory)
```
project/renv/library/R-4.5/x86_64-pc-linux-gnu/
```

**Contains:**
- Symbolic links to cache
- Active package installations for this project

**Status:** Not modified by validate.sh

## The Two-Phase Architecture

Understanding zzcollab's package management requires recognizing two distinct phases:

### Phase 1: Manifest Update (validate.sh)

**Environment:** Host machine, no R required

**What happens:**
```bash
make check-renv

# Behind the scenes:
# 1. Scan code for package usage (grep, awk)
# 2. Query CRAN API for metadata (curl)
# 3. Update DESCRIPTION (awk)
# 4. Update renv.lock (jq)
```

**Result:**
- ✅ DESCRIPTION declares the dependency
- ✅ renv.lock specifies the exact version
- ❌ Packages NOT downloaded or installed
- ❌ Cache NOT modified

**Analogy:** Writing a shopping list (you've listed what you need, but haven't bought anything yet)

### Phase 2: Package Installation (renv::restore())

**Environment:** Container or host R session

**What happens:**
```bash
make docker-zsh

# When container starts, R automatically runs:
renv::restore()

# Behind the scenes:
# 1. Read renv.lock
# 2. Check cache for required packages
# 3. Download missing packages from CRAN
# 4. Install to cache (~/.local/share/renv/cache/)
# 5. Create symlinks in project library (renv/library/)
```

**Result:**
- ✅ Packages downloaded from CRAN
- ✅ Cache populated with package files
- ✅ Project library linked to cache
- ✅ Packages available for use in R

**Analogy:** Going shopping and bringing groceries home (you've acquired the items from your list)

## Visual Workflow

### Complete Dependency Update Flow

```
┌─────────────────────────────────────────────────┐
│ 1. Developer writes code on host                │
│                                                  │
│    vim analysis/scripts/clean.R                 │
│    # Add: library(dplyr)                        │
└─────────────────┬───────────────────────────────┘
                  │
                  │ No R required on host
                  │
┌─────────────────▼───────────────────────────────┐
│ 2. validate.sh scans code (pure shell)          │
│                                                  │
│    make check-renv                              │
│    ├── Detects dplyr usage (grep)              │
│    ├── Queries CRAN API (curl)                 │
│    ├── Updates DESCRIPTION (awk)               │
│    └── Updates renv.lock (jq)                  │
│                                                  │
│    Output:                                       │
│    ✅ Added dplyr to DESCRIPTION Imports        │
│    ✅ Added dplyr (1.1.4) to renv.lock          │
└─────────────────┬───────────────────────────────┘
                  │
                  │ ❌ No package installation yet!
                  │ ❌ Cache not modified!
                  │ ❌ Can't use dplyr yet!
                  │
┌─────────────────▼───────────────────────────────┐
│ 3. Enter container (Docker, has R)             │
│                                                  │
│    make docker-zsh                              │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│ 4. renv::restore() runs automatically           │
│                                                  │
│    Container startup:                            │
│    ├── Reads renv.lock                          │
│    ├── Checks cache for dplyr                   │
│    ├── Package not found in cache               │
│    ├── Downloads from CRAN                      │
│    │   https://cran.r-project.org/.../dplyr_... │
│    ├── Installs to cache                        │
│    │   ~/.local/share/renv/cache/.../dplyr/...  │
│    └── Links to project library                 │
│        renv/library/.../dplyr -> cache          │
│                                                  │
│    Output:                                       │
│    Installing dplyr [1.1.4] ...                 │
│    OK [linked from cache]                       │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│ 5. Package available in R session               │
│                                                  │
│    R                                             │
│    > library(dplyr)                             │
│    ✅ Works!                                     │
│                                                  │
│    > filter(mtcars, mpg > 20)                   │
│    ✅ Functions available                       │
└─────────────────────────────────────────────────┘
```

## Analogy: Blueprint vs Construction

### validate.sh = Architect (Updates Blueprint)

**Responsibilities:**
- Draw the plans (update renv.lock)
- List materials needed (update DESCRIPTION)
- Specify versions and sources

**Does NOT:**
- Order materials
- Build anything
- Install packages

**Tools:** Paper, pencil, catalogs (curl, jq, awk)

### renv::restore() = Construction Crew (Builds from Blueprint)

**Responsibilities:**
- Read the plans (read renv.lock)
- Order materials (download packages from CRAN)
- Build the structure (install to cache and library)

**Does NOT:**
- Update the plans
- Modify DESCRIPTION or renv.lock

**Tools:** Truck, tools, materials (R, renv package manager)

## Why This Separation Is Important

### 1. Host Can Stay Lightweight

**Without R installation:**
```bash
# Host machine: No R, no packages, no cache
which R
# R not found

# Check cache directory
ls ~/.local/share/renv/cache/
# Directory doesn't exist or is empty

# Still can validate dependencies!
make check-renv
# ✅ Works perfectly
# ✅ Updates DESCRIPTION
# ✅ Updates renv.lock
```

### 2. Container Has Complete Environment

**Full R environment:**
```bash
# Inside container: Full R + all packages
make docker-zsh

R
> library(dplyr)
# ✅ Available

> .libPaths()
# [1] "/workspace/renv/library/R-4.5/x86_64-pc-linux-gnu"
# [2] "/usr/local/lib/R/site-library"

> packageVersion("dplyr")
# [1] '1.1.4'
```

### 3. Clean Separation of Concerns

| Phase | Tool | Purpose | Location |
|-------|------|---------|----------|
| **Declaration** | validate.sh | Dependency metadata management | Host (no R) |
| **Installation** | renv::restore() | Package download and installation | Container (R) |

**Benefits:**
- Fast host-side validation (no R startup overhead)
- Docker-first development workflow
- CI/CD in minimal containers
- No R version conflicts on host

## Complete Example: Adding a New Package

### Scenario: Add dplyr to Analysis

**Starting state:**
- Code exists but doesn't use dplyr
- DESCRIPTION doesn't mention dplyr
- renv.lock doesn't include dplyr
- Cache doesn't have dplyr installed

### Step-by-Step Workflow

#### Step 1: Write Code (Host)

```bash
vim analysis/scripts/clean_data.R
```

```r
# analysis/scripts/clean_data.R
library(dplyr)

data <- read.csv("data/raw_data/penguins.csv")

clean_data <- data %>%
  filter(!is.na(body_mass_g)) %>%
  mutate(body_mass_kg = body_mass_g / 1000)
```

#### Step 2: Run Validation (Host, No R Required)

```bash
make check-renv
```

**Output:**
```
ℹ️  Validating package dependencies...
ℹ️  Scanning for R files in: . R scripts analysis
ℹ️  Found 1 packages in code
ℹ️  Found 0 packages in DESCRIPTION Imports
ℹ️  Found 2 packages in renv.lock
❌ Found 1 packages used in code but not in DESCRIPTION Imports

  - dplyr

ℹ️  Auto-fixing: Adding missing packages to DESCRIPTION and renv.lock...
🔍 Adding dplyr to DESCRIPTION Imports...
✅ Added dplyr to DESCRIPTION Imports
🔍 Fetching metadata for dplyr from CRAN...
🔍 Adding dplyr version 1.1.4 to renv.lock...
✅ Added dplyr (1.1.4) to renv.lock
✅ All missing packages added
```

#### Step 3: Verify Manifest Updates (Host)

**Check DESCRIPTION:**
```bash
grep -A 5 "^Imports:" DESCRIPTION
```

```
Imports:
    dplyr
```

**Check renv.lock:**
```bash
jq '.Packages.dplyr' renv.lock
```

```json
{
  "Package": "dplyr",
  "Version": "1.1.4",
  "Source": "Repository",
  "Repository": "CRAN"
}
```

#### Step 4: Verify Cache Status (Host)

**Cache is still empty:**
```bash
ls ~/.local/share/renv/cache/v5/R-4.5/x86_64-pc-linux-gnu/dplyr/
# ls: No such file or directory
```

**If you have R on host (optional):**
```bash
R
> library(dplyr)
# Error in library(dplyr) : there is no package called 'dplyr'
```

**Why?** validate.sh only updated manifests, didn't install packages

#### Step 5: Commit Manifest Changes (Host)

```bash
git add DESCRIPTION renv.lock
git commit -m "Add dplyr dependency for data cleaning"
git push
```

#### Step 6: Enter Container (Container Environment)

```bash
make docker-zsh
```

**Container startup output:**
```
Starting zzcollab development container...
* Project '~/workspace' loaded. [renv 1.1.4]
The following package(s) will be installed:
- dplyr [1.1.4]
These packages will be installed into "~/workspace/renv/library/R-4.5/x86_64-pc-linux-gnu".

Do you want to proceed? [Y/n]: Y

# Installing dplyr [1.1.4] ...
        OK [linked from cache]
Successfully installed 1 package in 2.1 seconds.
```

#### Step 7: Verify Package Installation (Container)

**Inside container:**
```r
R

> library(dplyr)
# No error - package loads successfully!

> packageVersion("dplyr")
# [1] '1.1.4'

> .libPaths()
# [1] "/workspace/renv/library/R-4.5/x86_64-pc-linux-gnu"
# [2] "/usr/local/lib/R/site-library"
```

#### Step 8: Verify Cache Population (Container)

**Check cache:**
```bash
ls ~/.local/share/renv/cache/v5/R-4.5/x86_64-pc-linux-gnu/dplyr/1.1.4/
```

```
DESCRIPTION  LICENSE  Meta  NAMESPACE  NEWS.md  R  help  html  libs  po
```

**Check project library (symlink):**
```bash
ls -la renv/library/R-4.5/x86_64-pc-linux-gnu/dplyr
```

```
lrwxrwxrwx 1 user user 71 Nov 15 10:30 dplyr ->
  /home/user/.local/share/renv/cache/v5/R-4.5/x86_64-pc-linux-gnu/dplyr/1.1.4
```

#### Step 9: Run Analysis (Container)

```r
source("analysis/scripts/clean_data.R")
# ✅ Works perfectly!
```

## File System Layout

### renv Cache Structure

**Linux:**
```
~/.local/share/renv/cache/
└── v5/                                    # Cache version
    └── R-4.5/                             # R version
        └── x86_64-pc-linux-gnu/           # Platform
            ├── dplyr/
            │   └── 1.1.4/                 # Package version
            │       ├── DESCRIPTION        # Package metadata
            │       ├── NAMESPACE          # Export declarations
            │       ├── R/                 # R source code
            │       │   ├── filter.R
            │       │   ├── mutate.R
            │       │   └── ...
            │       ├── libs/              # Compiled code
            │       │   └── dplyr.so
            │       ├── help/              # Documentation
            │       └── Meta/              # Package metadata
            ├── ggplot2/
            │   └── 3.4.4/
            │       └── ...
            └── tidyr/
                └── 1.3.0/
                    └── ...
```

**macOS:**
```
~/Library/Application Support/renv/
└── cache/
    └── v5/
        └── R-4.5/
            └── aarch64-apple-darwin/      # macOS ARM platform
                ├── dplyr/
                │   └── 1.1.4/
                └── ggplot2/
                    └── 3.4.4/
```

### Project Library Structure

**Symbolic links to cache:**
```
project/
├── renv/
│   └── library/
│       └── R-4.5/
│           └── x86_64-pc-linux-gnu/
│               ├── dplyr -> ~/.local/share/renv/cache/.../dplyr/1.1.4/
│               ├── ggplot2 -> ~/.local/share/renv/cache/.../ggplot2/3.4.4/
│               └── tidyr -> ~/.local/share/renv/cache/.../tidyr/1.3.0/
```

**Why symlinks?**
- Save disk space (one installation serves multiple projects)
- Faster setup (no redundant installations)
- Consistent versions across projects

## Component Responsibility Matrix

### What Modifies What

| Component | Modified by validate.sh? | Modified by renv::restore()? | Modified by install.packages()? |
|-----------|-------------------------|------------------------------|--------------------------------|
| **DESCRIPTION** | ✅ Yes (adds to Imports) | ❌ No | ❌ No |
| **renv.lock** | ✅ Yes (adds package entry) | ❌ No | ❌ No (requires renv::snapshot()) |
| **renv cache** | ❌ No | ✅ Yes (downloads & installs) | ✅ Yes (installs to cache) |
| **renv/library/** | ❌ No | ✅ Yes (creates symlinks) | ✅ Yes (creates symlinks) |
| **Code files** | ❌ No | ❌ No | ❌ No |

### What Reads What

| Tool | Reads DESCRIPTION? | Reads renv.lock? | Reads Code? | Reads Cache? |
|------|-------------------|------------------|-------------|--------------|
| **validate.sh** | ✅ Yes (parse Imports) | ✅ Yes (parse packages) | ✅ Yes (extract library() calls) | ❌ No |
| **renv::restore()** | ✅ Yes (dependencies) | ✅ Yes (versions to install) | ❌ No | ✅ Yes (check if installed) |
| **renv::snapshot()** | ❌ No | ✅ Yes (existing entries) | ❌ No | ✅ Yes (installed packages) |
| **install.packages()** | ❌ No | ❌ No | ❌ No | ✅ Yes (install location) |

## Common Misconceptions

### ❌ Misconception 1: "validate.sh installs packages"

**Reality:** No, it only updates manifest files (DESCRIPTION and renv.lock)

**Evidence:**
```bash
make check-renv
# Output: "✅ Added dplyr (1.1.4) to renv.lock"
# Does NOT say: "Installing dplyr..."

# Verify cache
ls ~/.local/share/renv/cache/ | grep dplyr
# Empty result - package not installed
```

### ❌ Misconception 2: "If package is in renv.lock, it's installed"

**Reality:** renv.lock is just a manifest, not an installation record

**Analogy:** Having a recipe doesn't mean you've cooked the meal

**Evidence:**
```bash
# renv.lock includes dplyr
jq '.Packages | keys' renv.lock
# ["dplyr", "ggplot2", "renv"]

# But cache might be empty
ls ~/.local/share/renv/cache/v5/R-4.5/*/dplyr/
# ls: No such file or directory

# Need to run renv::restore() to materialize the manifest
```

### ❌ Misconception 3: "validate.sh requires R to work"

**Reality:** Runs entirely using shell tools (no R required)

**Tools used:**
- `grep` - Extract package names from code
- `awk` - Modify DESCRIPTION file
- `jq` - Manipulate renv.lock JSON
- `curl` - Query CRAN API

**No R calls:**
```bash
grep -r "Rscript\|R CMD\|R -e" modules/validation.sh
# Only finds documentation examples, no actual R execution
```

### ❌ Misconception 4: "Host and container share the same cache"

**Reality:** Depends on configuration, but typically isolated

**Default behavior:**
- Host cache: `~/.local/share/renv/cache/` (host filesystem)
- Container cache: `/root/.local/share/renv/cache/` (container filesystem)

**Can be shared via volume mount:**
```yaml
# docker-compose.yml
volumes:
  - ~/.local/share/renv:/root/.local/share/renv
```

## Workflow Comparison

### Traditional R Workflow (Host R Required)

```bash
# 1. Install package
Rscript -e 'install.packages("dplyr")'
# Downloads, compiles, installs to library
# Time: 10-30 seconds

# 2. Update renv.lock
Rscript -e 'renv::snapshot()'
# Scans installed packages, updates renv.lock
# Time: 5-10 seconds

# Total time: 15-40 seconds
# Requires: R installation on host
```

### zzcollab Workflow (No Host R Required)

```bash
# 1. Update manifests (no R)
make check-renv
# Scans code, queries CRAN API, updates files
# Time: 1-2 seconds
# Requires: curl, jq, awk (standard shell tools)

# 2. Install packages (in container)
make docker-zsh
# Container runs renv::restore() on startup
# Time: 10-30 seconds (first time)
# Requires: Docker (R isolated in container)

# Total time: 11-32 seconds
# Host machine: No R required!
```

**Benefits of zzcollab approach:**
- Host stays lightweight (no R installation)
- Fast validation (no R startup overhead)
- Works in CI/CD with minimal containers
- Consistent across team (Docker ensures uniformity)

## Troubleshooting

### Issue: "Package shows in renv.lock but not available in R"

**Diagnosis:**
```r
R
> library(dplyr)
# Error: there is no package called 'dplyr'

> system("ls ~/.local/share/renv/cache/v5/R-4.5/*/dplyr/")
# ls: No such file or directory
```

**Cause:** Manifest updated (Phase 1) but installation not run (Phase 2)

**Solution:**
```r
# Inside R session
renv::restore()

# Or restart container (runs renv::restore() automatically)
exit
make docker-zsh
```

### Issue: "make check-renv says packages missing but they work in R"

**Diagnosis:**
```bash
make check-renv
# Found 1 packages used in code but not in DESCRIPTION Imports
#   - dplyr

R
> library(dplyr)  # Works fine!
```

**Cause:** Package installed but not declared in DESCRIPTION

**Why this matters:** Reproducibility - collaborators can't discover the dependency

**Solution:**
```bash
# Let validate.sh fix it
make check-renv
# Auto-adds dplyr to DESCRIPTION and renv.lock

# Commit the update
git add DESCRIPTION renv.lock
git commit -m "Declare dplyr dependency"
```

### Issue: "Different package versions on host vs container"

**Diagnosis:**
```bash
# Host
R
> packageVersion("dplyr")
# [1] '1.1.2'

# Container
make docker-zsh
R
> packageVersion("dplyr")
# [1] '1.1.4'
```

**Cause:** Host using different package source than renv.lock

**Why this matters:** Reproducibility - different versions can produce different results

**Solution:** Use container for all development
```bash
# Don't use host R for analysis
# Always work in container
make docker-zsh
# Container uses exact versions from renv.lock
```

## Best Practices

### 1. Validate Before Entering Container

**Pattern:**
```bash
# After writing code
vim analysis/scripts/analyze.R

# Sync manifests first
make check-renv
git add DESCRIPTION renv.lock
git commit -m "Add analysis dependencies"

# Then enter container (packages auto-install)
make docker-zsh
```

**Why:** Ensures container has all dependencies on startup

### 2. Commit Manifest Changes Separately

**Good:**
```bash
# Commit 1: Dependencies
make check-renv
git add DESCRIPTION renv.lock
git commit -m "Add dplyr, ggplot2 dependencies"

# Commit 2: Code
git add analysis/scripts/
git commit -m "Implement data cleaning pipeline"
```

**Why:** Clear separation between infrastructure and implementation

### 3. Don't Mix Host and Container Development

**Anti-pattern:**
```bash
# BAD: Install on host
Rscript -e 'install.packages("dplyr")'

# BAD: Then work in container
make docker-zsh
```

**Better:**
```bash
# Work exclusively in container
make docker-zsh
# Install packages in container
# Auto-snapshot captures them on exit
```

**Why:** Avoids version conflicts and ensures reproducibility

### 4. Use Validation in CI/CD

**GitHub Actions example:**
```yaml
name: Validate Dependencies
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install jq
        run: sudo apt-get install -y jq

      - name: Validate package environment
        run: make check-renv-no-fix

      - name: Check for uncommitted changes
        run: git diff --exit-code DESCRIPTION renv.lock
```

**Why:** Catches undeclared dependencies before merge

## Summary

**validate.sh is a manifest management tool, not a package installer.**

### Key Points

1. **Two-phase architecture**
   - Phase 1 (validate.sh): Update manifests (DESCRIPTION, renv.lock)
   - Phase 2 (renv::restore()): Install packages (cache, library)

2. **Cache modification**
   - validate.sh: ❌ No cache modification
   - renv::restore(): ✅ Downloads and installs packages
   - install.packages(): ✅ Installs directly to cache

3. **Separation enables Docker-first workflow**
   - Host: Lightweight, no R required
   - Container: Complete environment, all packages installed
   - Clean boundary between declaration and installation

4. **Analogy: Blueprint vs construction**
   - validate.sh = Architect (draws plans, doesn't build)
   - renv::restore() = Construction crew (builds from plans)

5. **Best practice workflow**
   ```bash
   # 1. Write code
   # 2. Validate (updates manifests)
   make check-renv
   # 3. Commit manifests
   git add DESCRIPTION renv.lock && git commit
   # 4. Enter container (installs packages)
   make docker-zsh
   ```

This separation is fundamental to zzcollab's design philosophy: **manifest management on host (fast, no R), package installation in container (isolated, reproducible)**.
