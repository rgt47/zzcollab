# Package Validation Quick Reference

**Purpose**: Fast reference for ZZCOLLAB's validation system and common scenarios.

---

## Validation Commands

### Basic Validation (Standard Mode)
```bash
make check-renv                    # Check DESCRIPTION ↔ renv.lock consistency
modules/validation.sh              # Direct validation script call
modules/validation.sh --verbose    # Show list of missing packages
```

**Scans**: `.` (root), `R/`, `scripts/`, `analysis/`

### Strict Validation
```bash
make check-renv-strict            # Also scans tests/ and vignettes/
modules/validation.sh --strict    # Direct script call with strict mode
```

**Scans**: `.` (root), `R/`, `scripts/`, `analysis/`, `tests/`, `vignettes/`, `inst/`

### Automatic Validation
```bash
make docker-zsh                   # Enter container
# ... work inside container ...
exit                              # Auto-validates on exit!
```

All `docker-*` targets automatically validate after container exits.

---

## Common Scenarios

### Scenario 1: Add New Package

**Workflow**:
```bash
make docker-zsh
```

Inside container:
```r
install.packages("newpkg")
exit
```

Back on host:
```bash
# Auto-snapshot + validation already ran!
# Verify package added:
jq '.Packages.newpkg' renv.lock
```

**Result**: Package automatically added to renv.lock, validation passed.

---

### Scenario 2: Package Used But Not Installed

**Symptoms**:
```bash
make check-renv
# ✗ Package validation failed
# Missing packages: dplyr
```

**Solution**:
```bash
make docker-zsh
install.packages("dplyr")
exit
# Auto-snapshot adds to renv.lock
# Validation passes ✓
```

---

### Scenario 3: Package in Code But Not in DESCRIPTION

**Symptoms**:
```bash
make check-renv
# ✗ Package validation failed
# Packages used in code but not in DESCRIPTION: ggplot2
```

**Solution 1** (Recommended - Use in code):
```bash
# Edit DESCRIPTION, add to Imports:
nano DESCRIPTION
```

Add:
```
Imports:
    ggplot2,
    dplyr
```

**Solution 2** (Don't use - Remove from code):
```bash
# Remove library(ggplot2) calls from code
# Re-validate
make check-renv
```

---

### Scenario 4: Package in DESCRIPTION But Not in renv.lock

**Symptoms**:
```bash
make check-renv
# ✗ Package validation failed
# DESCRIPTION Imports not in renv.lock: tidyr
```

**Solution**:
```bash
make docker-zsh
install.packages("tidyr")
exit
# Auto-snapshot adds to renv.lock ✓
```

---

### Scenario 5: Clean Slate Validation

**Use Case**: New team member joins, wants to verify setup

**Workflow**:
```bash
git clone https://github.com/team/project.git
cd project
zzcollab -u                       # Pull team Docker image
make check-renv                   # Validate consistency
# ✓ Package validation passed

make docker-zsh
renv::restore()                   # Install all packages
exit
```

---

## Validation Output Explained

### Success Output
```
✓ Validation completed successfully
✓ All packages in code exist in DESCRIPTION
✓ All Imports/Depends exist in renv.lock
```

**Meaning**: Perfect consistency across all three sources.

### Warning: Unused Packages
```
⚠ Warning: Packages in renv.lock but not used in code:
  - oldpackage
  - unusedpkg
```

**Meaning**: Packages installed but not imported anywhere. Consider removing.

**Action** (Optional):
```bash
make docker-zsh
renv::remove("oldpackage")
exit
```

### Error: Missing from DESCRIPTION
```
✗ Package validation failed
Packages used in code but not in DESCRIPTION:
  - ggplot2
  - dplyr
```

**Meaning**: Code uses packages, but DESCRIPTION doesn't declare dependency.

**Fix**: Add to DESCRIPTION Imports: field

### Error: Missing from renv.lock
```
✗ Package validation failed
DESCRIPTION Imports not in renv.lock:
  - tidyr
  - broom
```

**Meaning**: DESCRIPTION declares packages, but they're not installed.

**Fix**: Install packages in container

---

## Validation Architecture

### Three Sources of Truth

1. **Code Analysis** (`.` (root), `R/`, `scripts/`, `analysis/`, and optionally `tests/`, `vignettes/`, `inst/`)
   - Scans for `library()`, `require()`, `package::function()` calls
   - Pure shell: grep, sed, awk

2. **DESCRIPTION** (Package metadata)
   - Imports: field lists required packages
   - Pure shell: awk parsing

3. **renv.lock** (Installed packages)
   - JSON file with exact versions
   - Pure shell: jq parsing

### Validation Logic

```
Code Packages ⊆ DESCRIPTION Imports ⊆ renv.lock Packages

If Code uses "dplyr":
  → DESCRIPTION must Import: dplyr
    → renv.lock must contain dplyr

Violations = validation failure
```

---

## Strict Mode Differences

### Standard Mode
**Scans**:
- `R/*.R`
- `analysis/scripts/*.R`
- `analysis/paper/*.Rmd`

**Use Case**: Daily development, package changes

### Strict Mode
**Scans**:
- Everything in standard mode
- `tests/testthat/*.R`
- `vignettes/*.Rmd`

**Use Case**: Pre-commit checks, CI/CD, release preparation

**Enable**:
```bash
make check-renv-strict
```

---

## CI/CD Integration

### GitHub Actions Validation

Automatic validation on every push:
```yaml
- name: Validate package environment
  run: |
    make check-renv-strict
```

**Location**: `.github/workflows/r-package-check.yml`

**Triggers**:
- Push to main branch
- Pull requests
- Manual workflow dispatch

---

## No Host R Required

**Key Feature**: Validation works WITHOUT R installed on host machine!

**Pure Shell Tools**:
- `grep` - Find library() calls
- `sed` - Extract package names
- `awk` - Parse DESCRIPTION
- `jq` - Parse renv.lock JSON
- `bash` - Orchestrate validation

**Proof**:
```bash
which R
# If not found, that's OK!

make check-renv
# ✓ Still works!
```

---

## Integration with Auto-Snapshot

### Workflow Integration

```
Container Exit
    ↓
Run renv::snapshot()
    ↓
Adjust RSPM timestamp (for binaries)
    ↓
Run validation (modules/validation.sh)
    ↓
Report results to user
```

**Configured in**: `templates/.Rprofile` (.Last() function)

**Environment Variables**:
```bash
# Disable auto-snapshot (not recommended)
docker run -e ZZCOLLAB_AUTO_SNAPSHOT=false ...
```

---

## Troubleshooting

### Validation Script Not Found

**Error**: `make: modules/validation.sh: No such file or directory`

**Solution**:
```bash
# Re-run zzcollab to regenerate
zzcollab -u
```

### jq Not Installed

**Error**: `jq: command not found`

**Solution**:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Fallback: Use text manifest
# Validation falls back to .zzcollab/manifest.txt automatically
```

### False Positive: Package Detected But Not Used

**Scenario**: Validation says package used, but you can't find it

**Solution**:
```bash
# Find exact usage
grep -r "library(packagename)" R/ analysis/

# Common false positives:
# - Commented out code
# - Strings containing package names
# - Package names in documentation

# Fix: Remove or uncomment
```

### Auto-Snapshot Didn't Run

**Symptoms**: Exited R session, renv.lock unchanged

**Check**:
```bash
# Verify .Rprofile exists and contains .Last() function
grep -A 10 "^\.Last <- function" .Rprofile

# Check if auto-snapshot is enabled
grep "ZZCOLLAB_AUTO_SNAPSHOT" .Rprofile
```

**Manual Snapshot**:
```bash
make docker-zsh
# In R:
renv::snapshot()
exit
```

---

## Best Practices

### 1. Validate Before Committing
```bash
make check-renv-strict
git add .
git commit -m "Your message"
git push
```

### 2. Use Auto-Snapshot
```bash
# Don't manually snapshot!
# Just exit container, it happens automatically
make docker-zsh
install.packages("pkg")
exit  # ← Auto-snapshot here
```

### 3. Keep DESCRIPTION Current
```bash
# When adding packages, add to DESCRIPTION
nano DESCRIPTION
# Add to Imports: field
```

### 4. Review Validation Output
```bash
# Don't ignore warnings!
⚠ Warning: Packages in renv.lock but not used in code:
  - oldpkg

# Consider: Do you still need oldpkg?
```

### 5. Trust the Validation
```bash
# If validation passes, you're consistent ✓
make check-renv
# ✓ Package validation passed

# Means:
# - Code has dependencies declared
# - DESCRIPTION has imports listed
# - renv.lock has packages installed
# - Ready to commit!
```

---

## Quick Decision Tree

```
Need to add package?
├─ Enter container: make docker-zsh
├─ Install: install.packages("pkg")
├─ Exit: exit (auto-snapshot + validate)
└─ Add to DESCRIPTION Imports: if used in R/

Validation failed?
├─ Missing from DESCRIPTION?
│  └─ Add to Imports: field
├─ Missing from renv.lock?
│  └─ Install in container
└─ Package unused?
   └─ Remove with renv::remove()

Want to verify consistency?
├─ Standard check: make check-renv
├─ Strict check: make check-renv-strict
└─ Full rebuild: git clone + zzcollab -u

Team member joining?
├─ Clone repo: git clone
├─ Pull image: zzcollab -u
├─ Validate: make check-renv
└─ Restore: make docker-zsh → renv::restore()
```

---

## Summary

**Three Commands to Remember**:

1. `make check-renv` - Validate consistency
2. `make docker-zsh` - Work in container (auto-validates on exit)
3. `modules/validation.sh` - Direct validation call

**Key Principle**:
> Code packages ⊆ DESCRIPTION ⊆ renv.lock

**Best Feature**:
> No host R required! Pure shell validation.

For comprehensive tutorial, see: `docs/REPRODUCIBILITY_WORKFLOW_TUTORIAL.md`
