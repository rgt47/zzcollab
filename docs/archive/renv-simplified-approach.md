# Simplified renv Approach for ZZCOLLAB Users

**Date**: October 31, 2025
**Status**: Recommended documentation update

---

## Key Insight

Users do **NOT** need to understand or interact with renv directly. They can use standard R commands (`install.packages()`), and renv works invisibly in the background to ensure reproducibility.

---

## How renv Works in ZZCOLLAB (Behind the Scenes)

### What Users See (Simple)

```r
# Enter container
make r

# Add packages (standard R)
install.packages("ggplot2")
install.packages("dplyr")

# Exit container
exit

# Rebuild (packages automatically saved and restored)
make docker-build
```

### What Happens Automatically (Users Don't Need to Know)

```
1. Container exit
   ↓
2. zzcollab-entrypoint.sh runs renv::snapshot()
   ↓
3. renv.lock updated with package versions
   ↓
4. validation.sh checks DESCRIPTION consistency
   ↓
5. Next docker build: renv::restore() installs packages
   ↓
6. Packages available in new container
```

---

## Recommended Documentation Language

### Adding Packages (Simple Message)

```markdown
## Adding R Packages

Add packages as needed using standard R commands:

```r
install.packages("ggplot2")
install.packages("dplyr")
install.packages("tidyr")
```

When you exit the container, package versions are automatically captured in `renv.lock`
for reproducibility.

### For GitHub Packages

For packages hosted on GitHub, install `remotes` first:

```r
install.packages("remotes")
remotes::install_github("tidyverse/ggplot2")
```

**Alternative**: `renv::install()` works for both CRAN and GitHub packages:

```r
renv::install("ggplot2")              # CRAN
renv::install("tidyverse/ggplot2")    # GitHub
```

### How It Works

ZZCOLLAB automatically:
1. ✅ Captures package versions when you exit the container
2. ✅ Validates packages against DESCRIPTION
3. ✅ Restores exact versions in Docker builds
4. ✅ Ensures reproducibility across team members

You don't need to run `renv::snapshot()` manually - it happens automatically on container exit.
```

---

## What Changed from Previous Documentation

### Before (Complex)

```markdown
## Package Management with renv

ZZCOLLAB uses renv for reproducible package management.

### Adding Packages

Inside the Docker container, install packages using renv:

```r
renv::install("ggplot2")
renv::install("dplyr")
```

When you're done adding packages, take a snapshot:

```r
renv::snapshot()
```

This updates `renv.lock` with exact package versions.
```

**Problems with old approach:**
- Required understanding of renv
- Manual `renv::snapshot()` step (now automatic)
- Used `renv::install()` when standard R commands work fine
- More cognitive load for users

### After (Simple)

```markdown
## Adding R Packages

Add packages using standard R commands:

```r
install.packages("ggplot2")
```

Package versions are automatically captured when you exit the container.
```

**Benefits:**
- Uses familiar R commands everyone knows
- No manual snapshot step (automatic on exit)
- Clearer mental model (renv is infrastructure, not daily tool)
- Easier to explain to new users

---

## Technical Details (For Documentation Maintainers)

### Why install.packages() Works

1. **Installation**: Both `install.packages()` and `renv::install()` install packages to the R library
2. **Auto-snapshot**: On container exit, `renv::snapshot(type = "explicit")` scans code for package usage
3. **Type explicit**: Captures packages found in code via `library()`, `require()`, or `package::function()`
4. **Installation method irrelevant**: Doesn't matter HOW package was installed, only that it's installed and used

### The renv Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│ BUILD 1: Initial Project                                    │
├─────────────────────────────────────────────────────────────┤
│ renv.lock: minimal/empty                                    │
│ Dockerfile: RUN renv::restore()  (installs minimal/nothing) │
│ Developer: install.packages("ggplot2")                      │
│           exit → auto-snapshot                              │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ BUILD 2: After Adding Packages                              │
├─────────────────────────────────────────────────────────────┤
│ renv.lock: {ggplot2, dplyr, tidyr}                          │
│ Dockerfile: RUN renv::restore()  (installs all packages)    │
│ Result: Packages pre-installed in container                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ BUILD 3: Team Member Joins                                  │
├─────────────────────────────────────────────────────────────┤
│ git clone (gets renv.lock)                                  │
│ make docker-build                                            │
│ renv::restore() installs exact same versions                │
│ Result: Reproducible environment                            │
└─────────────────────────────────────────────────────────────┘
```

### Where renv is Used

1. **Docker build**: `RUN renv::restore()` installs packages into image
2. **Container exit**: `renv::snapshot()` captures versions (automatic via entrypoint)
3. **Validation**: `validation.sh` parses renv.lock (but doesn't execute renv)

**Not used at runtime**: Users don't interact with renv inside running containers

---

## Files to Update

### 1. Main README.md

**Section**: "Quick Start" or "Usage"

**Add:**
```markdown
## Adding Packages

```r
make r
install.packages("ggplot2")
exit
```

Packages are automatically captured in `renv.lock` when you exit.
```

### 2. ZZCOLLAB_USER_GUIDE.md

**Section**: "Package Management"

**Replace** entire section with simplified version (see "Recommended Documentation Language" above)

### 3. vignettes/quickstart.Rmd

**Update** package installation examples:
```r
# Before
renv::install("ggplot2")

# After
install.packages("ggplot2")
```

### 4. vignettes/quickstart-R.Rmd

**Update** to match simplified approach

### 5. Help messages (modules/help.sh)

**Update** package management help section

---

## Benefits of This Approach

### For Users

1. **Familiar**: Standard R commands everyone already knows
2. **Simpler**: No need to understand renv internals
3. **Automatic**: No manual snapshot commands
4. **Clear**: renv is infrastructure, not something you interact with daily

### For Maintainers

1. **Easier to explain**: "Use install.packages(), exit container, done"
2. **Fewer questions**: Users don't need to learn renv API
3. **Better mental model**: renv is background infrastructure
4. **Same functionality**: No loss of features

### For Team Collaboration

1. **Lower barrier**: New team members use familiar commands
2. **Still reproducible**: renv.lock still captures exact versions
3. **Automatic sync**: Same auto-snapshot mechanism
4. **No workflow changes**: Team leads don't need to train on renv

---

## Edge Cases and Notes

### Bioconductor Packages

```r
# Standard approach
install.packages("BiocManager")
BiocManager::install("GenomicRanges")

# Alternative with renv
renv::install("bioc::GenomicRanges")
```

Both work and get captured by auto-snapshot.

### GitHub Packages

```r
# Need remotes (not always pre-installed)
install.packages("remotes")
remotes::install_github("user/package")

# Or use renv (always available)
renv::install("user/package")
```

### Package Not Captured in Snapshot?

If a package isn't captured, it means it's not used in code:

```r
# Installed but not used
install.packages("unused_package")

# Not in code:
# No library(unused_package)
# No unused_package::function()
# Not in DESCRIPTION

# Solution: Use it in code, or add to DESCRIPTION
library(unused_package)  # Now it will be captured
```

This is actually a **feature** - only packages actually used are locked, preventing bloat.

---

## FAQ

**Q: Do I need to run `renv::snapshot()` manually?**
A: No! It runs automatically when you exit the container.

**Q: Can I still use `renv::install()`?**
A: Yes! It works fine, but `install.packages()` is simpler for most cases.

**Q: What if I want to install a specific version?**
A: Use `remotes::install_version("package", "1.2.3")` or install it, use it, and exit - snapshot captures the installed version.

**Q: How do I know what's in my renv.lock?**
A: You don't need to check! If a package is used in your code, it's captured. If you're curious: `cat renv.lock | jq '.Packages | keys'`

**Q: What if renv.lock gets out of sync?**
A: `validation.sh` checks consistency automatically. If packages are used in code but not in DESCRIPTION, you'll get an error with specific package names to add.

**Q: Can I delete renv.lock and start over?**
A: Yes! Delete it, rebuild Docker image, add packages, exit. New renv.lock will be created with current packages.

---

## Implementation Checklist

- [ ] Update README.md with simplified package installation
- [ ] Update ZZCOLLAB_USER_GUIDE.md package management section
- [ ] Update vignettes/quickstart.Rmd examples
- [ ] Update vignettes/quickstart-R.Rmd examples
- [ ] Update modules/help.sh package management help
- [ ] Update zzcollab-entrypoint.sh message to mention install.packages()
- [ ] Add note about GitHub packages requiring remotes
- [ ] Test workflow with install.packages() to confirm it works
- [ ] Update any examples in templates/
- [ ] Update CLAUDE.md with simplified explanation

---

## Summary

**Old message**: "Use renv for package management. Run `renv::install()` and `renv::snapshot()`."

**New message**: "Use standard R commands like `install.packages()`. Packages are automatically saved when you exit."

**Impact**: Simpler, more intuitive, same reproducibility guarantees, lower learning curve.

**Technical change**: None - this is just clearer documentation of existing functionality.
