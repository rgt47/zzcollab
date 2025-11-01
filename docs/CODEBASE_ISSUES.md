# ZZCOLLAB Codebase Issues Tracking

**Last Updated**: 2025-10-31
**Analysis Date**: 2025-10-31
**Total Issues**: 27
**Status**: In Progress

---

## Issue Summary

| Severity | Count | Fixed | In Progress | Remaining |
|----------|-------|-------|-------------|-----------|
| CRITICAL | 3     | 0     | 0           | 3         |
| HIGH     | 7     | 0     | 0           | 7         |
| MEDIUM   | 5     | 0     | 0           | 5         |
| LOW      | 12    | 0     | 0           | 12        |
| **TOTAL**| **27**| **0** | **0**       | **27**    |

---

## CRITICAL Issues

### Issue #1: Race Condition in renv.lock Auto-Snapshot ⚠️ CRITICAL

**Status**: 🔴 Not Started
**Priority**: P0 (Immediate)
**File**: `templates/zzcollab-entrypoint.sh:45-54`

**Problem**:
Multiple containers exiting simultaneously can corrupt renv.lock during auto-snapshot. No file locking mechanism prevents concurrent writes.

**Impact**:
- Data loss in renv.lock
- Non-reproducible environments
- Team collaboration failures

**Example Failure Scenario**:
```bash
# Container 1 and 2 both exit at same time
# Container 1: renv::snapshot() writes packages A, B, C
# Container 2: renv::snapshot() writes packages D, E, F
# Result: Only D, E, F saved (A, B, C lost)
```

**Solution**:
Add file locking with `flock` before renv.lock manipulation:
```bash
{
    flock -x 200
    if Rscript -e "renv::snapshot(type = 'explicit', prompt = FALSE)" 2>/dev/null; then
        # Timestamp adjustment while holding lock
        touch -d "7 days ago" "$PROJECT_DIR/renv.lock" 2>/dev/null
    fi
} 200>"$PROJECT_DIR/.renv.lock.lock"
```

**Test Case**:
```bash
# Launch 3 containers simultaneously, each installing different package
for i in 1 2 3; do
  docker run -v $(pwd):/home/analyst/project pkg bash -c "install.packages('pkg$i'); exit" &
done
wait
# Verify all 3 packages in renv.lock
jq '.Packages | keys | .[]' renv.lock | grep -c "pkg[123]"
# Should be 3, not 1
```

**Files to Modify**:
- `templates/zzcollab-entrypoint.sh`

**Estimated Effort**: 1 hour

---

### Issue #2: mktemp Cleanup Leak in Manifest Tracking ⚠️ CRITICAL

**Status**: 🔴 Not Started
**Priority**: P0 (Immediate)
**File**: `modules/core.sh:264-311`

**Problem**:
The `track_item()` function creates 6 temporary files with `mktemp` but never cleans them up on failure. No trap handlers ensure cleanup.

**Impact**:
- Disk space leak (temp files accumulate)
- Manifest corruption if jq succeeds but mv fails
- No rollback mechanism

**Example Failure**:
```bash
# jq succeeds, creates /tmp/tmp.abc123
# mv fails (disk full, permissions)
# /tmp/tmp.abc123 remains forever
# Manifest is partially updated (corrupted state)
```

**Solution**:
Add trap-based cleanup and atomic updates:
```bash
track_item() {
    local tmp=""
    cleanup_tmp() {
        [[ -n "$tmp" ]] && [[ -f "$tmp" ]] && rm -f "$tmp"
    }
    trap cleanup_tmp RETURN

    tmp=$(mktemp)
    if jq --arg dir "$data1" '.directories += [$dir]' "$MANIFEST_FILE" > "$tmp"; then
        mv "$tmp" "$MANIFEST_FILE" || {
            log_error "Failed to update manifest"
            return 1
        }
    else
        log_error "jq failed to process manifest"
        return 1
    fi
}
```

**Test Case**:
```bash
# Count temp files before
before=$(ls /tmp/tmp.* 2>/dev/null | wc -l)

# Simulate failure
export JQ_AVAILABLE=true
alias jq='false'
track_directory "test_dir" || true

# Count temp files after
after=$(ls /tmp/tmp.* 2>/dev/null | wc -l)

# Should be same, but will show leak
[[ $after -eq $before ]] || echo "LEAK: $((after - before)) files"
```

**Files to Modify**:
- `modules/core.sh`

**Estimated Effort**: 2 hours

---

### Issue #3: R Version Validation Logic Hole ⚠️ CRITICAL

**Status**: 🔴 Not Started
**Priority**: P0 (Immediate)
**File**: `modules/docker.sh:466-502`

**Problem**:
`validate_r_version_early()` uses `2>/dev/null` which silently fails if extraction has errors. Empty string comparison always triggers mismatch error.

**Impact**:
- False positive mismatch errors on valid renv.lock
- Poor error messages
- Blocks valid Docker builds

**Example Failure**:
```bash
# renv.lock exists but jq returns empty string (not error code)
lockfile_r_version=$(extract_r_version_from_lockfile 2>/dev/null)
# lockfile_r_version = "" (empty)
# if [[ "4.4.0" != "" ]]; then  # ALWAYS TRUE!
#     log_error "MISMATCH!"  # FALSE POSITIVE
```

**Solution**:
Capture stderr and validate extraction before comparison:
```bash
local lockfile_r_version
lockfile_r_version=$(extract_r_version_from_lockfile 2>&1)
local extract_status=$?

if [[ $extract_status -ne 0 ]]; then
    log_warn "Could not extract R version from renv.lock"
    log_debug "Extract error: $lockfile_r_version"
    return 0  # Non-fatal, allow build to continue
elif [[ -z "$lockfile_r_version" ]]; then
    log_warn "renv.lock exists but R version is empty"
    return 0  # Non-fatal
elif [[ "${r_version_to_check}" != "${lockfile_r_version}" ]]; then
    log_error "R version MISMATCH!"
    return 1
fi
```

**Test Case**:
```bash
# Create renv.lock with missing R.Version
echo '{"Packages":{}}' > renv.lock

# Should NOT trigger mismatch error
zzcollab --r-version 4.4.0
# Current: ERROR - MISMATCH
# Expected: WARNING - could not extract version
```

**Files to Modify**:
- `modules/docker.sh`

**Estimated Effort**: 1 hour

---

## HIGH Severity Issues

### Issue #4: Package Extraction Regex Too Permissive 🔴 HIGH

**Status**: 🔴 Not Started
**Priority**: P1 (Next Sprint)
**File**: `modules/validation.sh:58-73`

**Problem**:
Regex patterns for extracting package names are too permissive:
- Requires minimum 3 chars (misses "sf", "gt", etc.)
- Matches unclosed parentheses
- Doesn't validate R package naming rules

**Impact**:
- False negatives: misses valid 2-char packages
- False positives: extracts non-existent packages
- Validation fails on valid code

**Solution**:
Use accurate R package naming rules (letters, numbers, dots; min 2 chars):
```bash
grep -oP '(?:library|require)\s*\(\s*["'\'']?([a-zA-Z][a-zA-Z0-9.]{0,})["\x27]?\s*\)' "$file"
```

**Test Case**:
```r
library(sf)          # 2-char (currently MISSED)
library(data.table)  # dots (should match)
library(ggplot2      # unclosed (currently matches - WRONG)
```

**Files to Modify**:
- `modules/validation.sh`

**Estimated Effort**: 2 hours

---

### Issue #5: Docker Hub API Missing Error Handling 🔴 HIGH

**Status**: 🔴 Not Started
**Priority**: P1 (Next Sprint)
**File**: `modules/docker.sh:275-294`

**Problem**:
`check_docker_image_exists()` returns success (0) if curl is not installed, allowing invalid R versions to pass validation.

**Impact**:
- Docker builds fail 10-20 minutes later
- Wastes CI/CD time
- No early error detection

**Solution**:
Require curl and provide clear error messages:
```bash
if ! command -v curl >/dev/null 2>&1; then
    log_warn "curl not available - cannot validate R version"
    log_warn "Install: apt-get install curl (Linux) or brew install curl (macOS)"
    return 0  # Best-effort validation
fi

local http_code
http_code=$(curl -sf -w "%{http_code}" --max-time 5 "$api_url" -o /dev/null 2>&1)

if [[ "$http_code" == "200" ]]; then
    return 0  # Confirmed exists
elif [[ "$http_code" == "404" ]]; then
    return 1  # Confirmed doesn't exist
else
    log_warn "Docker Hub API error (HTTP $http_code)"
    return 0  # API error is non-fatal
fi
```

**Test Case**:
```bash
# Test without curl
PATH="/usr/bin" zzcollab --r-version 99.99.99
# Should warn about missing curl AND invalid R version
```

**Files to Modify**:
- `modules/docker.sh`

**Estimated Effort**: 1 hour

---

### Issue #6: Makefile Timestamp Touch May Fail Silently 🔴 HIGH

**Status**: 🔴 Not Started
**Priority**: P1 (Next Sprint)
**File**: `templates/Makefile:150,157,164,204`

**Problem**:
Makefile restores renv.lock timestamp but doesn't check if touch succeeds. If it fails (readonly fs, permissions), error is silently ignored.

**Impact**:
- renv.lock keeps old timestamp
- Docker builds use wrong RSPM snapshot
- Binary packages unavailable

**Solution**:
Check touch exit code and report errors:
```makefile
@if [ -f renv.lock ]; then \
    if ! touch renv.lock; then \
        echo "⚠️  Warning: Failed to restore renv.lock timestamp" >&2; \
    fi; \
fi
```

**Test Case**:
```bash
chmod 444 renv.lock
make docker-zsh
# Should warn about readonly file
```

**Files to Modify**:
- `templates/Makefile`

**Estimated Effort**: 30 minutes

---

### Issue #7: Profile Defaults Missing Validation 🔴 HIGH

**Status**: 🔴 Not Started
**Priority**: P1 (Next Sprint)
**File**: `modules/dockerfile_generator.sh:31-96`

**Problem**:
`get_profile_defaults()` returns hardcoded bundle names without validating they exist in bundles.yaml. If bundle doesn't exist, Dockerfile is generated with no packages.

**Impact**:
- Silent failures (no R packages)
- Container missing expected packages
- No error message

**Solution**:
Validate bundles exist before returning:
```bash
get_profile_defaults() {
    local defaults="rocker/tidyverse:standard:analysis"

    IFS=':' read -r base libs pkgs <<< "$defaults"

    if ! validate_bundle_exists "library_bundles" "$libs"; then
        log_error "Profile references non-existent libs bundle: $libs"
        return 1
    fi

    echo "$defaults"
}
```

**Test Case**:
```bash
# Remove analysis bundle
yq eval 'del(.package_bundles.analysis)' -i templates/bundles.yaml
zzcollab --profile-name ubuntu_standard_analysis
# Should error, not generate empty Dockerfile
```

**Files to Modify**:
- `modules/dockerfile_generator.sh`

**Estimated Effort**: 2 hours

---

### Issue #8: Entrypoint Cleanup Doesn't Propagate Snapshot Failures 🔴 HIGH

**Status**: 🔴 Not Started
**Priority**: P1 (Next Sprint)
**File**: `templates/zzcollab-entrypoint.sh:13-60`

**Problem**:
If user's command succeeds (exit 0) but snapshot fails, container exits 0, hiding the snapshot failure.

**Impact**:
- Silent snapshot failures
- renv.lock not updated
- CI passes but reproducibility breaks

**Solution**:
Exit with error if snapshot fails but command succeeded:
```bash
cleanup() {
    local exit_code=$?
    local snapshot_failed=0

    if Rscript -e "renv::snapshot(...)" 2>/dev/null; then
        echo "✅ renv.lock updated"
    else
        echo "❌ ERROR: renv::snapshot() failed" >&2
        snapshot_failed=1
    fi

    if [[ $exit_code -eq 0 ]] && [[ $snapshot_failed -eq 1 ]]; then
        exit 1  # Report snapshot failure
    fi

    exit $exit_code
}
```

**Test Case**:
```bash
docker run -v $(pwd):/home/analyst/project pkg bash -c "rm -f renv/activate.R; exit 0"
echo $?  # Should be 1 (snapshot failed), currently 0
```

**Files to Modify**:
- `templates/zzcollab-entrypoint.sh`

**Estimated Effort**: 1 hour

---

### Issue #9: DESCRIPTION Parsing Breaks on Multi-Line Packages 🔴 HIGH

**Status**: 🔴 Not Started
**Priority**: P1 (Next Sprint)
**File**: `modules/validation.sh:107-127`

**Problem**:
The awk script assumes each package on separate line, but R allows comma-separated packages and version constraints spanning multiple lines.

**Impact**:
- False negatives: misses valid packages
- False positives: treats version numbers as packages
- Validation fails on correctly formatted files

**Solution**:
Read entire Imports section before splitting:
```bash
awk '
    BEGIN { in_imports = 0; imports = "" }
    /^Imports:/ { in_imports = 1; imports = $0; next }
    in_imports && /^[[:space:]]/ { imports = imports " " $0; next }
    in_imports && /^[A-Z]/ { in_imports = 0 }
    END {
        gsub(/\([^)]*\)/, "", imports)  # Remove versions
        gsub(/,/, "\n", imports)         # Split on commas
        print imports
    }
' DESCRIPTION
```

**Test Case**:
```
Imports:
    dplyr (>= 1.0.0),
    tidyr (>=
        1.1.0)
```
Should extract: dplyr, tidyr (not "1.1.0)")

**Files to Modify**:
- `modules/validation.sh`

**Estimated Effort**: 2 hours

---

### Issue #10: Dockerfile Template Selection Ambiguity 🔴 HIGH

**Status**: 🔴 Not Started
**Priority**: P1 (Next Sprint)
**File**: `modules/dockerfile_generator.sh:173-200`

**Problem**:
`select_dockerfile_strategy()` doesn't normalize bundle names before matching, causing static templates to be missed.

**Impact**:
- Generates custom Dockerfile unnecessarily
- Slower builds
- Confusion about which Dockerfile is used

**Solution**:
Normalize bundles before matching:
```bash
# If user didn't specify libs, apply smart defaults
if [[ -z "${USER_PROVIDED_LIBS:-}" ]]; then
    case "$base" in
        *tidyverse*) libs="standard" ;;
        *) libs="standard" ;;
    esac
fi
```

**Test Case**:
```bash
zzcollab -b rocker/r-ver  # Should use Dockerfile.minimal (static)
grep "Profile: minimal" Dockerfile || echo "FAIL"
```

**Files to Modify**:
- `modules/dockerfile_generator.sh`

**Estimated Effort**: 1.5 hours

---

## MEDIUM Severity Issues

### Issue #11: Missing PROJECT_DIR Validation in Entrypoint 🟡 MEDIUM

**Status**: 🔴 Not Started
**Priority**: P2 (Backlog)
**File**: `templates/zzcollab-entrypoint.sh:11-30`

**Solution**: Add validation for directory existence and writability
**Estimated Effort**: 30 minutes

---

### Issue #12: Python JSON Parsing Captures Errors as Versions 🟡 MEDIUM

**Status**: 🔴 Not Started
**Priority**: P2 (Backlog)
**File**: `modules/docker.sh:206-231`

**Solution**: Capture stderr separately from stdout
**Estimated Effort**: 1 hour

---

### Issues #13-15: Template Validation and Logging 🟡 MEDIUM

**Status**: 🔴 Not Started
**Priority**: P2 (Backlog)
**Estimated Effort**: 2 hours total

---

## LOW Severity Issues

### Issues #16-27: Minor Quality Improvements 🟢 LOW

**Status**: 🔴 Not Started
**Priority**: P3 (Future)

These include:
- Bounds checking
- Logging improvements
- Internationalization
- Error code consistency
- Documentation

**Estimated Effort**: 8 hours total

---

## Fix Progress Tracking

### CRITICAL Fixes (P0 - Immediate)

- [ ] Issue #1: Race condition in renv.lock (1h)
- [ ] Issue #2: mktemp cleanup leak (2h)
- [ ] Issue #3: R version validation logic (1h)

**Total P0 Effort**: 4 hours

### HIGH Fixes (P1 - Next Sprint)

- [ ] Issue #4: Package extraction regex (2h)
- [ ] Issue #5: Docker Hub API error handling (1h)
- [ ] Issue #6: Makefile timestamp touch (30m)
- [ ] Issue #7: Profile defaults validation (2h)
- [ ] Issue #8: Entrypoint cleanup exit codes (1h)
- [ ] Issue #9: DESCRIPTION parsing multi-line (2h)
- [ ] Issue #10: Dockerfile template selection (1.5h)

**Total P1 Effort**: 10 hours

### MEDIUM/LOW Fixes (P2/P3 - Backlog)

- [ ] Issues #11-27: Various improvements (11h)

**Total P2/P3 Effort**: 11 hours

---

## Testing Plan

After each fix:

1. **Unit Test**: Test case from issue description
2. **Integration Test**: Full workflow (create project → add packages → validate)
3. **Regression Test**: Ensure fix doesn't break existing functionality
4. **Documentation**: Update relevant docs if behavior changes

---

## Notes

- **Test Environment**: All fixes will be tested with Palmer Penguins workflow from REPRODUCIBILITY_WORKFLOW_TUTORIAL.md
- **Backwards Compatibility**: Maintain compatibility where possible
- **Documentation Updates**: Update user guide and technical docs as needed
- **CI/CD**: Add regression tests to prevent issues from reoccurring

---

**Progress Updates**: This document will be updated as issues are fixed.
