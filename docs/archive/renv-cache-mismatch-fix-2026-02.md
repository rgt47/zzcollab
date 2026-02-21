# renv Cache and Makefile Variable Bugs: Diagnosis and Resolution

**Date:** February 2026
**Affected Components:**
- `modules/docker.sh` - `create_renv_lock_minimal()`
- `lib/templates.sh` - `substitute_variables()`

**Impact:** Package downloads repeated across projects; container mounted to wrong path

## Summary

Two related bugs prevented the renv package cache from working correctly:

1. **Repository mismatch**: Initial renv.lock specified `"Repository": "CRAN"` but
   cached packages used `"RSPM"`, causing cache key mismatches
2. **Variable corruption**: The `envsubst` command corrupted Makefile shell
   variables, causing mounts to `/home/nalyst/` instead of `/home/analyst/`

## Bug 1: Repository Mismatch in renv.lock

### Symptom

When creating multiple zzcollab projects with identical configurations, renv
downloaded all packages fresh for each project (~12 MB, ~27 seconds) instead
of using the shared cache.

```
# Downloading packages -------------------------------------------------------
- Downloading testthat from CRAN ...            OK [2 Mb in 1.2s]
- Downloading brio from https://packagemanager.posit.co/... OK
```

### Root Cause

The `create_renv_lock_minimal()` function in `modules/docker.sh` generated
renv.lock files with repository settings that differed from cached packages:

| Field | Generated renv.lock | Cached Packages |
|-------|---------------------|-----------------|
| Repository URL | `https://cloud.r-project.org` | `https://packagemanager.posit.co/cran/__linux__/noble/latest` |
| Repository Field | `"CRAN"` | `"RSPM"` |

renv's cache key includes the repository identifier, so packages with
`"Repository": "CRAN"` could not match cache entries with `"Repository": "RSPM"`.

### Fix

Updated `create_renv_lock_minimal()` to use Posit Package Manager:

```bash
# Before (buggy)
local cran="${2:-https://cloud.r-project.org}"
...
"Repository": "CRAN"

# After (fixed)
local repo_url="${2:-https://packagemanager.posit.co/cran/__linux__/noble/latest}"
...
"Repository": "RSPM"
```

## Bug 2: Makefile Variable Corruption

### Symptom

Container showed `/home/nalyst/project` instead of `/home/analyst/project`:

```r
> getwd()
[1] "/home/nalyst/project"
```

This caused the renv cache mount to fail silently (mounted to wrong path).

### Root Cause

The `substitute_variables()` function in `lib/templates.sh` included
`$USERNAME` and `$BASE_IMAGE` in its envsubst variable list:

```bash
envsubst '... $BASE_IMAGE ... $USERNAME ...' < "$file" > "$file.tmp"
```

In the Makefile template, `$$USERNAME` is meant to be an escaped shell
variable for Make runtime. But envsubst processed it as:

1. First `$` treated as literal
2. `$USERNAME` matches substitution list → replaced with env var value `analyst`
3. Result: `$analyst`

In Make, `$analyst` expands to `$a` (undefined, empty) + `nalyst` = `nalyst`.

**Template (correct):**
```make
HOME_DIR="/home/$$USERNAME"
```

**Generated Makefile (corrupted):**
```make
HOME_DIR="/home/$analyst"
```

### Fix

Removed `$USERNAME` and `$BASE_IMAGE` from the envsubst variable list:

```bash
# Before (buggy)
envsubst '... $BASE_IMAGE $R_VERSION $USERNAME ...'

# After (fixed)
# Note: $USERNAME and $BASE_IMAGE are intentionally excluded - they are runtime
# shell variables in Makefile ($$USERNAME, $$BASE_IMAGE), not template placeholders
envsubst '... $R_VERSION ...'
```

## Verification

After applying both fixes:

```bash
# Create first project (populates cache)
mkdir ~/Dropbox/sbx/test5 && cd ~/Dropbox/sbx/test5
zzc analysis -y
zzc build --no-cache  # Force rebuild with correct USERNAME
make r
# Downloads packages, populates cache
q()

# Create second project (uses cache)
mkdir ~/Dropbox/sbx/test6 && cd ~/Dropbox/sbx/test6
zzc analysis -y
make r
```

**Success indicators:**

```
- Project '~/project' loaded. [renv 1.1.5]
- The library is already synchronized with the lockfile.
```

- Path shows `~/project` (correct, expands to `/home/analyst/project`)
- Message says "already synchronized" (packages restored from cache)
- No "Downloading" messages

## Technical Details

### renv Cache Architecture

renv maintains a global package cache at `~/.cache/R/renv/v5/` with structure:

```
{os}/{R-version}/{platform}/{package}/{version}/{hash}/{package}/
```

The hash incorporates package metadata including the repository identifier.
Packages from `"CRAN"` and `"RSPM"` have different hashes even for identical
versions.

### Configuration Consistency

All zzcollab components must use consistent repository settings:

| Component | Setting | Value |
|-----------|---------|-------|
| Dockerfile ENV | `RENV_CONFIG_REPOS_OVERRIDE` | `https://packagemanager.posit.co/...` |
| .Rprofile | `options(repos = ...)` | `https://packagemanager.posit.co/...` |
| .Rprofile | `options(renv.repos.cran = ...)` | `https://packagemanager.posit.co/...` |
| renv.lock | `Repositories.URL` | `https://packagemanager.posit.co/...` |
| renv.lock | `Packages.*.Repository` | `"RSPM"` |

### Make Variable Escaping

In Makefiles, shell variables require double-dollar escaping:

| Makefile syntax | Shell receives | Meaning |
|-----------------|----------------|---------|
| `$$USERNAME` | `$USERNAME` | Shell variable expansion at runtime |
| `$USERNAME` | Value of Make variable `USERNAME` | Make variable (usually empty) |
| `$analyst` | `$a` + `nalyst` | Make expands `$a`, leaves rest literal |

## Files Changed

1. **`modules/docker.sh`** - `create_renv_lock_minimal()`
   - Changed default repository URL to Posit PM
   - Changed `"Repository": "CRAN"` to `"Repository": "RSPM"`

2. **`lib/templates.sh`** - `substitute_variables()`
   - Removed `$USERNAME` and `$BASE_IMAGE` from envsubst variable list
   - Added comment explaining why they're excluded

## Lessons Learned

1. **Test cache behavior explicitly**: Add integration tests that verify cache
   hits across multiple project creations

2. **Be careful with envsubst**: When templates contain shell variable syntax
   (`$$VAR`), ensure those variables aren't in the envsubst substitution list

3. **Consistency matters for caching**: All components that influence package
   installation must use identical repository identifiers

---

*Document created: 2026-02-21*
*Verified working: 2026-02-21*
*Files: `modules/docker.sh`, `lib/templates.sh`*
