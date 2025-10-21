# Package Management with renv

---

## What Is renv?

renv is R's package management system that ensures reproducibility.

**Key Concept**: renv records exact package versions in `renv.lock`
- Share `renv.lock` with collaborators
- Everyone gets IDENTICAL packages
- Analysis runs the same on all computers

Think of it like a "shopping list" for R packages:
- `renv.lock` = exact list of packages and versions
- `renv::restore()` = "go shopping" and install everything
- `renv::snapshot()` = "update the list" with new packages

---

## Why Use renv?

### WITHOUT RENV (danger!)

```r
# You:
install.packages("tidyverse")  # Gets tidyverse 2.0.0

# Collaborator:
install.packages("tidyverse")  # Gets tidyverse 2.1.0
```

Result:
- Different results!
- "Works on my machine" problem
- Not reproducible

### WITH RENV (safe)

```r
# You:
install.packages("tidyverse")
renv::snapshot()

# Collaborator:
renv::restore()
```

Result:
- Exact same tidyverse 2.0.0
- Identical results
- Perfect reproducibility!

---

## The Three Essential renv Commands

### 1. install.packages("packagename")

- **Purpose**: Install a new R package
- **When**: Whenever you need a new package

### 2. renv::snapshot()

- **Purpose**: Record current packages in renv.lock
- **When**: After installing new packages
- **Result**: Updates renv.lock file

### 3. renv::restore()

- **Purpose**: Install packages from renv.lock
- **When**: Joining project or syncing with team
- **Result**: Installs exact versions from renv.lock

**That's it!** These three commands handle 95% of package management.

---

## Complete renv Workflow

### Scenario 1: Adding a New Package

```r
# In RStudio (container):
install.packages("ggplot2")    # Install the package
library(ggplot2)               # Test that it works
renv::snapshot()               # Record in renv.lock
```

```bash
# On host:
git add renv.lock
git commit -m "Add ggplot2 package"
git push
```

### Scenario 2: Joining a Team Project

```bash
# Clone project
git clone https://github.com/team/project.git
cd project

# Start container
zzcollab -t team -p project --use-team-image
make docker-rstudio
```

```r
# In RStudio:
renv::restore()  # Install all packages from renv.lock
# Choose 1: Restore (most common choice)
```

### Scenario 3: Updating Packages

```r
# In RStudio:
install.packages("dplyr")  # Updates to latest version
renv::snapshot()           # Record new version
```

```bash
# Commit changes
git add renv.lock
git commit -m "Update dplyr to fix bug"
```

### Scenario 4: Checking Package Status

```r
# In RStudio:
renv::status()
# Shows:
# - Packages in code but not in renv.lock
# - Packages in renv.lock but not installed
# - Version mismatches
```

---

## renv Files Explained

Your project has these renv-related files:

### renv.lock (MOST IMPORTANT)

- **What**: JSON file listing exact package versions
- **When to commit**: Always! (crucial for reproducibility)

**Example contents**:
```json
{
  "R": {"Version": "4.3.1"},
  "Packages": {
    "ggplot2": {
      "Package": "ggplot2",
      "Version": "3.4.2",
      "Source": "CRAN"
    }
  }
}
```

### renv/ directory

- **What**: Package cache and library
- **When to commit**: Never! (add to .gitignore)
- **Purpose**: Stores installed packages locally

### .Rprofile

- **What**: Activates renv when R starts
- **When to commit**: Yes
- **Content**: `source("renv/activate.R")`

---

## Common renv Workflows

### Daily Development Workflow

1. Start RStudio: `make docker-rstudio`
2. Write code using existing packages
3. Need new package?
   ```r
   install.packages("packagename")
   renv::snapshot()
   ```
4. Close RStudio: `Ctrl+C`
5. Commit: `git add renv.lock && git commit -m "Add package"`

### Collaboration Workflow (Team Member)

1. Pull latest code: `git pull`
2. Check for package changes: `git diff renv.lock`
3. If renv.lock changed:
   ```bash
   make docker-rstudio
   ```
   ```r
   renv::restore()  # Sync packages with team
   ```
4. Continue work with synced packages

### Package Exploration Workflow

```r
# Try a package without committing:
install.packages("experimentalPkg")
library(experimentalPkg)
# Try it out...

# Don't like it? Don't snapshot!
# Just restart R - package won't be in renv.lock

# Like it? Snapshot to keep:
renv::snapshot()
```

---

## renv Troubleshooting

### ISSUE 1: "Package 'X' is not available"

**CAUSE**: Package not on CRAN or name misspelled

**SOLUTIONS**:

Check spelling:
```r
install.packages("ggplot2")  # not "ggplt2"
```

Package on GitHub:
```r
remotes::install_github("username/packagename")
renv::snapshot()
```

Package on Bioconductor:
```r
BiocManager::install("packagename")
renv::snapshot()
```

### ISSUE 2: "Package installation failed (non-zero exit)"

**CAUSE**: Missing system dependencies

**SOLUTION**:
```r
# Package needs system libraries (e.g., sf needs gdal)
# Options:
# 1. Use different build mode (comprehensive includes more)
# 2. Ask team lead to add to Docker image
# 3. Use alternative package
```

### ISSUE 3: "renv.lock is out of sync"

**Check status**:
```r
renv::status()
# Shows what's different
```

**Fix by syncing**:
```r
renv::snapshot()  # If you want to keep current packages
# OR
renv::restore()   # If you want renv.lock versions
```

### ISSUE 4: "Package works for me but not teammate"

**CAUSE**: Forgot to snapshot after installing

**SOLUTION**:
```r
# You (who installed package):
renv::snapshot()
```

```bash
git add renv.lock
git commit -m "Add missing package"
git push
```

```r
# Teammate:
# (After git pull)
renv::restore()
```

### ISSUE 5: "renv::restore() taking forever"

**CAUSE**: Installing many packages from source

**SOLUTION**:
```r
# Just wait - first time is slow
# Subsequent restores are faster (uses cache)

# Progress indicator:
renv::restore()
# Shows: Installing package [1/50] ...
```

### ISSUE 6: "Error: renv not installed"

**RARE** - renv included in zzcollab by default

**SOLUTION**:
```r
install.packages("renv")
renv::init()
```

### ISSUE 7: "Cache is corrupted"

**Purge and reinstall**:
```r
renv::purge("packagename")
install.packages("packagename")
renv::snapshot()
```

---

## Advanced renv Commands

### Check what's changed

```r
renv::status()
# Shows packages in code but not in renv.lock
# Shows packages in renv.lock but not installed
```

### Install specific version

```r
remotes::install_version("ggplot2", version = "3.3.6")
renv::snapshot()
```

### Remove package

```r
remove.packages("packagename")
renv::snapshot()  # Update renv.lock
```

### Update all packages

```r
renv::update()
# Updates all packages to latest versions
# Use carefully! May break code.
```

### Rollback to previous state

```bash
git checkout HEAD~1 renv.lock  # Previous version
```

```r
renv::restore()                # Install old versions
```

### Clean unused packages

```r
renv::clean()
# Removes packages not in renv.lock
```

---

## Understanding renv.lock

**Example renv.lock content**:

```json
{
  "R": {
    "Version": "4.3.1",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "https://cran.rstudio.com"
      }
    ]
  },
  "Packages": {
    "ggplot2": {
      "Package": "ggplot2",
      "Version": "3.4.2",
      "Source": "Repository",
      "Repository": "CRAN",
      "Hash": "abc123def456"
    },
    "dplyr": {
      "Package": "dplyr",
      "Version": "1.1.2",
      "Source": "Repository",
      "Repository": "CRAN",
      "Hash": "xyz789"
    }
  }
}
```

**Key fields**:
- **R Version**: Which R version was used
- **Package**: Package name
- **Version**: Exact version number
- **Source**: Where package came from (CRAN, GitHub, etc.)
- **Hash**: Checksum to verify package contents

---

## renv Best Practices

### 1. Always snapshot after installing packages

```r
install.packages("packagename")
renv::snapshot()  # Don't forget!
```

### 2. Commit renv.lock to git (crucial!)

```bash
git add renv.lock
git commit -m "Add/update packages"
```

### 3. Run renv::status() regularly

```r
# Catches packages you forgot to snapshot
```

### 4. Restore after pulling team changes

```bash
git pull
# If renv.lock changed:
```

```r
renv::restore()
```

### 5. Don't commit renv/ directory

```bash
# Already in .gitignore, keep it that way!
```

### 6. Use renv::snapshot() strategically

- After adding package
- After updating package
- Before sharing with team
- Before submitting final analysis

### 7. Test with renv::restore() occasionally

```r
# Ensures renv.lock is complete
# Verifies reproducibility
```

### 8. Document package purposes

```r
# In code comments, explain why you need each package
```

---

## renv + zzcollab Integration

zzcollab build modes control initial packages:

### MINIMAL mode (3 packages)

- renv, here, usethis
- Add all analysis packages via `install.packages()`

### FAST mode (9 packages)

- renv, here, usethis, devtools, testthat
- knitr, rmarkdown, targets, palmerpenguins
- Add additional packages as needed

### STANDARD mode (17 packages)

- Fast packages + tidyverse core
- Most workflows covered
- Occasionally add specialized packages

### COMPREHENSIVE mode (47+ packages)

- Includes most common packages
- Rarely need to add more

**Key insight**: Build mode affects Docker image → renv.lock records project-specific additions → renv.lock + Docker image = perfect reproducibility!

---

## Common Questions

**Q: "When should I run renv::snapshot()?"**
A: After `install.packages()`, before committing to git.

**Q: "When should I run renv::restore()?"**
A: After `git pull` if renv.lock changed, or when joining project.

**Q: "Do I need to install renv?"**
A: No, included in all zzcollab Docker images.

**Q: "Can I use install.packages() without renv::snapshot()?"**
A: Yes, but package won't be recorded - lost when container restarts!

**Q: "What if I accidentally installed wrong package?"**
A: Don't snapshot! Restart R and package is forgotten.

**Q: "Should I commit renv/ directory?"**
A: NO! Only commit renv.lock (.gitignore handles this).

**Q: "Can I manually edit renv.lock?"**
A: Don't! Use `renv::snapshot()` and `renv::restore()` instead.

**Q: "What if renv.lock conflicts in git merge?"**
A: Resolve conflict, then run `renv::restore()` to sync.

**Q: "How do I share experimental package without affecting team?"**
A: Use feature branch, install+snapshot there, merge when stable.

---

## Real-World Example: Team Collaboration

This example shows how three team members collaborate on a time-series forecasting project using renv.

### Day 1: Team Lead Sets Up Project

**Alice (Team Lead)**:
```bash
mkdir ~/projects/sales-forecast && cd ~/projects/sales-forecast
zzcollab --team acme --project-name sales-forecast --r-version 4.4.0
git init && git add . && git commit -m "Initial setup"
make docker-rstudio
```

**In RStudio**:
```r
# Install core packages
install.packages(c("tidyverse", "forecast", "tsibble"))
renv::snapshot()  # Records: tidyverse 2.0.0, forecast 8.21, tsibble 1.1.3
```

```bash
# Back on host
git add renv.lock && git commit -m "Add forecasting packages" && git push
```

### Day 2: Bob Joins Project

**Bob (Team Member)**:
```bash
git clone https://github.com/acme/sales-forecast.git
cd sales-forecast
zzcollab --use-team-image
make docker-rstudio
```

**In RStudio**:
```r
# renv automatically detects renv.lock
renv::restore()  # Installs EXACT versions: tidyverse 2.0.0, forecast 8.21, tsibble 1.1.3

# Bob's analysis needs prophet
install.packages("prophet")
renv::snapshot()  # Updates renv.lock: adds prophet 1.0
```

```bash
git add renv.lock && git commit -m "Add prophet for seasonal decomposition" && git push
```

### Day 3: Alice Pulls Bob's Changes

**Alice**:
```bash
git pull
make docker-rstudio
```

**In RStudio**:
```r
# renv detects Bob added prophet
renv::status()
# > - "prophet" [1.0] is recorded in the lockfile but not installed

renv::restore()  # Installs prophet 1.0 (exact version Bob used)

# Now Alice can run Bob's code!
source("analysis/scripts/seasonal_analysis.R")  # Uses prophet
```

### Day 5: Carol Adds Visualization Packages

**Carol (Team Member)**:
```bash
git clone https://github.com/acme/sales-forecast.git
cd sales-forecast
zzcollab --use-team-image && make docker-rstudio
```

**In RStudio**:
```r
renv::restore()  # Gets tidyverse, forecast, tsibble, prophet (all exact versions!)

# Add interactive visualizations
install.packages(c("plotly", "shiny"))
renv::snapshot()
```

```bash
git add renv.lock && git commit -m "Add interactive visualization packages" && git push
```

### Day 6: Full Team Sync

**Everyone runs**:
```bash
git pull
make docker-rstudio
```

**In RStudio**:
```r
renv::restore()  # All team members now have IDENTICAL package versions
renv::status()   # "No issues found -- the project is in a consistent state"
```

### Key Observations

1. **Automatic detection**: renv notices when renv.lock changes
2. **Exact versions**: Everyone has tidyverse 2.0.0 (not 2.0.1 or 2.1.0)
3. **Incremental updates**: Each team member adds packages, team accumulates them
4. **No conflicts**: renv merges package additions automatically
5. **Reproducible analysis**: Any team member can run any script

### What's in renv.lock

```json
{
  "R": {
    "Version": "4.4.0"
  },
  "Packages": {
    "tidyverse": {
      "Package": "tidyverse",
      "Version": "2.0.0",
      "Source": "Repository",
      "Repository": "CRAN"
    },
    "forecast": {
      "Package": "forecast",
      "Version": "8.21",
      "Source": "Repository",
      "Repository": "CRAN"
    },
    "prophet": {
      "Package": "prophet",
      "Version": "1.0",
      "Source": "Repository",
      "Repository": "CRAN"
    }
  }
}
```

### Troubleshooting Scenario

**Problem**: Bob's machine-learning code fails on Carol's computer

```r
# Carol's R session:
Error in library(caret) : there is no package called 'caret'
```

**Diagnosis**:
```r
renv::status()
# > - "caret" [6.0-94] is used in the project but is not recorded in the lockfile
```

**Bob forgot to snapshot!**

**Solution (Bob)**:
```r
install.packages("caret")  # Install if needed
renv::snapshot()           # Record in renv.lock
```

```bash
git add renv.lock && git commit -m "Add caret package" && git push
```

**Carol**:
```bash
git pull
make docker-rstudio
```

```r
renv::restore()  # Installs caret 6.0-94
source("analysis/scripts/ml_model.R")  # Now works!
```

### Best Practices Illustrated

1. **Always snapshot after installing**: `install.packages()` → `renv::snapshot()`
2. **Commit renv.lock frequently**: Keeps team in sync
3. **Run renv::restore() after pull**: Gets latest package changes
4. **Use renv::status() to debug**: Shows missing/extra packages
5. **Don't commit renv/ directory**: It's a cache, can be regenerated

---

## Quick Reference

### Essential commands

```r
install.packages("pkg")  # Install package
renv::snapshot()         # Record in renv.lock
renv::restore()          # Install from renv.lock
renv::status()           # Check sync status
```

### Files

- `renv.lock` - Package versions (COMMIT THIS!)
- `renv/` - Package cache (DON'T COMMIT)
- `.Rprofile` - Activates renv (COMMIT THIS)

### Workflow

1. `install.packages("packagename")`
2. Test that it works
3. `renv::snapshot()`
4. `git add renv.lock`
5. `git commit -m "Add package"`
6. `git push`

---

## See Also

- `zzcollab --help` - General help
- `zzcollab --help-workflow` - Daily development workflow
- `zzcollab --help-troubleshooting` - Fix common problems
