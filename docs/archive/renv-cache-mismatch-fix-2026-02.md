# renv Cache Mismatch: Diagnosis and Resolution

**Date:** February 2026
**Affected Component:** `modules/docker.sh` - `create_renv_lock_minimal()`
**Impact:** Package downloads repeated across projects instead of using shared cache

## Problem Statement

When creating multiple zzcollab projects with identical configurations, renv
downloaded packages fresh for each project instead of utilizing the shared
cache. This resulted in:

- Redundant network traffic (~12 MB per project for testthat dependencies)
- Slower project initialization (~26 seconds download time per project)
- Wasted disk space from duplicate package storage

### Expected Behavior

After running `make r` in the first project, subsequent projects with the same
R version and package requirements should restore packages from the shared
cache in under 1 second.

### Observed Behavior

Each project downloaded all 23 packages (testthat + dependencies) from the
network, ignoring the populated cache.

## Technical Background

### renv Cache Architecture

renv maintains a global package cache to avoid redundant downloads and
installations. The cache structure follows this hierarchy:

```
~/.cache/R/renv/v5/
└── {os}/
    └── R-{major}.{minor}/
        └── {platform}/
            └── {package}/
                └── {version}/
                    └── {hash}/
                        └── {package}/
```

The critical component is the **hash**, computed from package metadata
including:

- Package name and version
- Source type (Repository, GitHub, etc.)
- **Repository identifier** (CRAN, RSPM, Bioconductor, etc.)
- Repository URL

### Cache Key Computation

When renv needs a package, it computes a hash from the renv.lock entry and
checks if that exact hash exists in the cache. If the hash matches, renv
copies or symlinks from cache. If not, it downloads fresh.

## Root Cause Analysis

### The Mismatch

The `create_renv_lock_minimal()` function in `modules/docker.sh` generated
renv.lock files with repository settings that differed from cached packages:

| Field | Generated renv.lock | Cached Packages |
|-------|---------------------|-----------------|
| Repository URL | `https://cloud.r-project.org` | `https://packagemanager.posit.co/cran/__linux__/noble/latest` |
| Repository Field | `"CRAN"` | `"RSPM"` |

### Why This Matters

Even though both URLs serve the same packages, renv treats them as distinct
sources. The repository identifier (`CRAN` vs `RSPM`) is incorporated into
the cache hash, causing a mismatch.

### Original Code

```bash
create_renv_lock_minimal() {
    local r_ver="$1"
    local cran="${2:-https://cloud.r-project.org}"  # <-- Wrong default

    cat > renv.lock << EOF
{
  "R": {
    "Version": "$r_ver",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "$cran"
      }
    ]
  },
  "Packages": {
    "renv": {
      "Package": "renv",
      "Version": "1.1.5",
      "Source": "Repository",
      "Repository": "CRAN"           # <-- Should be RSPM
    },
    "testthat": {
      "Package": "testthat",
      "Version": "3.3.1",
      "Source": "Repository",
      "Repository": "CRAN"           # <-- Should be RSPM
    }
  }
}
EOF
}
```

### Configuration Consistency

The zzcollab framework configures multiple components to use Posit Package
Manager:

| Component | Repository Setting |
|-----------|-------------------|
| Dockerfile ENV | `RENV_CONFIG_REPOS_OVERRIDE=https://packagemanager.posit.co/...` |
| .Rprofile | `options(repos = c(CRAN = "https://packagemanager.posit.co/..."))` |
| .Rprofile | `options(renv.repos.cran = "https://packagemanager.posit.co/...")` |
| renv.lock (initial) | `https://cloud.r-project.org` with `"Repository": "CRAN"` |

The renv.lock was the outlier, breaking cache compatibility.

## Diagnostic Process

### Step 1: Verify Cache Mount

Confirmed the host cache directory is correctly mounted into containers:

```bash
docker run --rm -it \
  -v $HOME/.cache/R/renv:/home/analyst/.cache/R/renv \
  test2:latest bash -c 'echo "RENV_PATHS_CACHE=$RENV_PATHS_CACHE"'
# Output: RENV_PATHS_CACHE=/home/analyst/.cache/R/renv
```

### Step 2: Verify Cache Contents

Confirmed packages exist in the cache:

```bash
ls ~/.cache/R/renv/v5/linux-ubuntu-noble/R-4.5/aarch64-unknown-linux-gnu/
# Output: brio callr cli crayon desc ...
```

### Step 3: Verify Container Access

Confirmed container can read cached packages:

```bash
docker run --rm -it \
  -v $HOME/.cache/R/renv:/home/analyst/.cache/R/renv \
  test2:latest bash -c 'ls /home/analyst/.cache/R/renv/v5/...'
# Output: brio callr cli crayon desc ...
```

### Step 4: Identify Hash Mismatch

Examined the download output and noticed packages were being downloaded
rather than copied:

```
- Downloading testthat from CRAN ...            OK [2 Mb in 1.2s]
- Downloading brio from https://packagemanager.posit.co/... OK
```

The key insight: testthat came "from CRAN" while dependencies came from
"packagemanager.posit.co". This indicated the initial renv.lock specified
CRAN as the source.

### Step 5: Trace renv.lock Generation

Located the source in `modules/docker.sh:93-123` where the initial renv.lock
hardcoded `"Repository": "CRAN"` and defaulted to `cloud.r-project.org`.

## Solution

### Code Change

Updated `create_renv_lock_minimal()` to use Posit Package Manager URL and
RSPM repository identifier:

```bash
create_renv_lock_minimal() {
    local r_ver="$1"
    local repo_url="${2:-https://packagemanager.posit.co/cran/__linux__/noble/latest}"

    cat > renv.lock << EOF
{
  "R": {
    "Version": "$r_ver",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "$repo_url"
      }
    ]
  },
  "Packages": {
    "renv": {
      "Package": "renv",
      "Version": "1.1.5",
      "Source": "Repository",
      "Repository": "RSPM"
    },
    "testthat": {
      "Package": "testthat",
      "Version": "3.3.1",
      "Source": "Repository",
      "Repository": "RSPM"
    }
  }
}
EOF
}
```

### Why RSPM?

- **RSPM** (RStudio Package Manager, now Posit Package Manager) is the
  repository identifier that renv assigns to packages from
  `packagemanager.posit.co`
- Using RSPM ensures cache compatibility with packages installed during
  container sessions
- Pre-compiled Linux binaries from Posit PM install faster than source
  packages from CRAN

## Verification

After applying the fix, test with:

```bash
# Clean previous test projects
rm -rf ~/Dropbox/sbx/test ~/Dropbox/sbx/test2

# Create first project (populates cache)
mkdir ~/Dropbox/sbx/test && cd ~/Dropbox/sbx/test
zzc analysis -y
make r
# Exit R session

# Create second project (should use cache)
mkdir ~/Dropbox/sbx/test2 && cd ~/Dropbox/sbx/test2
zzc analysis -y
make r
```

**Success indicators:**

- Output shows "Copying" or "Linking" instead of "Downloading"
- Package restoration completes in under 2 seconds
- No network activity during restore

**Failure indicators:**

- Output shows "Downloading" for packages
- 20+ second restoration time
- Network traffic to packagemanager.posit.co

## Related Configuration

Ensure these components remain synchronized:

1. **Dockerfile** (`RENV_CONFIG_REPOS_OVERRIDE`): Posit PM URL
2. **.Rprofile** (`options(repos = ...)`): Posit PM URL
3. **.Rprofile** (`options(renv.repos.cran = ...)`): Posit PM URL
4. **Initial renv.lock**: Posit PM URL with `"Repository": "RSPM"`

## Future Considerations

### Platform-Specific URLs

The current fix hardcodes `__linux__/noble` in the URL. If zzcollab needs to
support other Linux distributions, consider:

- Making the distribution configurable
- Detecting the distribution from the base image
- Using a more generic Posit PM endpoint

### renv Version Updates

When updating the bundled renv version (currently 1.1.5), verify that the
cache hash computation hasn't changed in ways that would affect compatibility.

### Cache Invalidation

If users experience persistent cache misses after this fix, they may need to
clear their existing cache:

```bash
rm -rf ~/.cache/R/renv/v5
```

This forces a fresh cache build with consistent repository identifiers.

---

## Related Bug: Makefile Variable Corruption

During investigation, a second bug was discovered in `lib/templates.sh`.

### Symptom

Container showed `/home/nalyst/project` instead of `/home/analyst/project`.

### Root Cause

The `envsubst` command in `substitute_variables()` included `$USERNAME` and
`$BASE_IMAGE` in its substitution list:

```bash
envsubst '... $BASE_IMAGE ... $USERNAME ...' < "$file" > "$file.tmp"
```

In the Makefile template, `$$USERNAME` is meant to be an escaped shell variable
for Make. But envsubst processed it as:

1. First `$` is literal
2. `$USERNAME` matches substitution list → replaced with `analyst`
3. Result: `$analyst` (Make interprets as `$a` + `nalyst` = `nalyst`)

### Fix

Removed `$USERNAME` and `$BASE_IMAGE` from the envsubst variable list in
`lib/templates.sh:121`. These are runtime shell variables in the Makefile,
not template placeholders.

```bash
# Before (buggy):
envsubst '... $BASE_IMAGE ... $USERNAME ...'

# After (fixed):
# Note: $USERNAME and $BASE_IMAGE are intentionally excluded
envsubst '... $R_VERSION ...'
```

---

*Document created: 2026-02-21*
*Source: `/Users/zenn/prj/sfw/07-zzcollab/zzcollab/modules/docker.sh`, `/Users/zenn/prj/sfw/07-zzcollab/zzcollab/lib/templates.sh`*
