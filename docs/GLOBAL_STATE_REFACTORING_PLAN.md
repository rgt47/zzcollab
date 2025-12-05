# Global State Refactoring Plan - Issue 2.3
## Parameterize Globals for Loose Coupling

**Date:** December 5, 2025
**Status:** IN PROGRESS
**Phase:** Phase 2A - Docker Functions

---

## Executive Summary

This document outlines the plan for **Phase 2.3: Parameterize Globals**, which addresses HIGH-priority code quality issue #2.3 from CODE_REVIEW.md.

**Problem:** Functions read global variables directly instead of accepting them as parameters, creating tight coupling that:
- Prevents reuse in different contexts
- Makes testing difficult (hard to pass different values)
- Obscures dependencies (not visible in function signature)
- Creates hidden state mutations

**Solution:** Systematically convert functions to accept globals as parameters, making dependencies explicit and code testable.

---

## Phase 2A: Docker Functions (CURRENT)

### Functions Requiring Refactoring

#### 1. `build_docker_image()` (docker.sh, lines 821-927)

**Current Signature:**
```bash
build_docker_image() {
    # No parameters - reads globals directly
```

**Globals Read:**
- `R_VERSION` (lines 847, 895) - R version for Docker build
- `PKG_NAME` (lines 853, 856, 895, 902) - Package name/Docker image tag
- `BASE_IMAGE` (lines 862, 869, 895) - Docker base image
- `PROFILE_NAME` (line 884) - Current profile for logging
- `BUILD_DOCKER` (line 937 in zzcollab.sh) - Whether to build

**Proposed Signature:**
```bash
build_docker_image() {
    local r_version="$1"        # R version for Docker build
    local pkg_name="$2"         # Package name/Docker image tag
    local base_image="$3"       # Docker base image reference
    local profile_name="${4:-minimal}"  # Profile for logging
```

**Benefits:**
- Callers explicitly pass required values
- Testable with different R versions and packages
- Can be called from different contexts (not just zzcollab.sh)
- Dependencies visible in function signature

**Call Sites to Update:**
- zzcollab.sh, line 939: `build_docker_image` → `build_docker_image "$R_VERSION" "$PKG_NAME" "$BASE_IMAGE" "$PROFILE_NAME"`

---

#### 2. `get_docker_platform_args()` (docker.sh, lines 119-155)

**Current Status:** PARTIALLY PARAMETERIZED ✅

**Current Signature:**
```bash
get_docker_platform_args() {
    local base_image="${1:-}"   # Already accepts parameter!
```

**Globals Read:**
- `FORCE_PLATFORM` (line 123) - Platform override (auto|amd64|arm64|native)

**Issue:** `FORCE_PLATFORM` is read from global scope instead of parameter

**Proposed Signature:**
```bash
get_docker_platform_args() {
    local base_image="${1:-}"
    local force_platform="${2:-auto}"  # Add as parameter with default
```

**Benefits:**
- Can test different platform scenarios
- Caller controls platform behavior
- No hidden global dependency

**Call Sites to Update:**
- docker.sh, line 869: `get_docker_platform_args "$BASE_IMAGE"` → `get_docker_platform_args "$BASE_IMAGE" "$FORCE_PLATFORM"`

---

#### 3. `get_multiarch_base_image()` (docker.sh, lines 55-93)

**Current Status:** PARTIALLY PARAMETERIZED ✅

**Current Signature:**
```bash
get_multiarch_base_image() {
    local requested_variant="$1"  # Already accepts parameter!
```

**Globals Read:**
- `MULTIARCH_VERSE_IMAGE` (line 70) - Custom ARM64 verse alternative

**Issue:** Hardcoded reference to `MULTIARCH_VERSE_IMAGE` global instead of parameter

**Proposed Signature:**
```bash
get_multiarch_base_image() {
    local requested_variant="$1"
    local multiarch_verse_image="${2:-}"  # Custom ARM64 alternative
```

**Implementation Note:** Default to empty string; function logic returns standard `rocker/verse` if not provided

**Benefits:**
- Can test with different custom images
- Team-specific images can be passed in
- More flexible for different team configurations

**Call Sites to Update:**
- Need to search for all calls to this function
- docker.sh, line 52 (example in comment) - already shows parameter usage

---

## Phase 2B: Template Functions (QUEUED)

Will include parameterization of:
- `copy_template_file()` - Parameterize `TEMPLATES_DIR`
- `substitute_variables()` - Convert globals to parameters

## Phase 2C: Package Functions (QUEUED)

Will include parameterization of:
- `create_core_files()` - Parameterize `PKG_NAME`, `PROFILE_NAME`, `TEMPLATES_DIR`

---

## Implementation Strategy

### Step 1: Update Function Signatures ✓
1. Add parameters to function signature with appropriate defaults
2. Change `local var="${GLOBAL_VAR}"` to use parameters
3. Update function documentation with new parameters

### Step 2: Update All Call Sites
1. Find all calls to modified functions
2. Update each call to pass previously-global values as arguments
3. Verify backward compatibility where needed

### Step 3: Add Tests
1. Create tests that pass different parameter values
2. Verify functions work with various inputs
3. Ensure error handling still works

### Step 4: Documentation
1. Update function documentation with parameter lists
2. Add migration examples for internal callers
3. Update related code review documentation

---

## Detailed Implementation: Phase 2A

### Implementation Order

1. **First: Update `get_docker_platform_args()`**
   - Simple change (add one parameter)
   - Already partially parameterized
   - Used by `build_docker_image()` (which we'll update next)

2. **Second: Update `get_multiarch_base_image()`**
   - Simple change (add one parameter)
   - Already partially parameterized
   - May be used elsewhere

3. **Third: Update `build_docker_image()`**
   - Main refactoring (add 4 parameters)
   - Update zzcollab.sh call site
   - Add tests

---

## Before/After Examples

### Example 1: `build_docker_image()`

**Before (Current):**
```bash
# zzcollab.sh
if [[ "$BUILD_DOCKER" == "true" ]]; then
    log_info "Building Docker image..."
    # Function reads R_VERSION, PKG_NAME, BASE_IMAGE, PROFILE_NAME from globals
    if build_docker_image; then
        log_success "Docker image built successfully"
    fi
fi
```

**After (Parameterized):**
```bash
# zzcollab.sh
if [[ "$BUILD_DOCKER" == "true" ]]; then
    log_info "Building Docker image..."
    # Caller explicitly passes all required values
    if build_docker_image "$R_VERSION" "$PKG_NAME" "$BASE_IMAGE" "$PROFILE_NAME"; then
        log_success "Docker image built successfully"
    fi
fi
```

### Example 2: `get_docker_platform_args()`

**Before (Current):**
```bash
# In build_docker_image()
DOCKER_PLATFORM=$(get_docker_platform_args "$BASE_IMAGE")
# Function reads FORCE_PLATFORM from global scope
```

**After (Parameterized):**
```bash
# In build_docker_image()
DOCKER_PLATFORM=$(get_docker_platform_args "$BASE_IMAGE" "$FORCE_PLATFORM")
# All dependencies explicit in function call
```

---

## Backward Compatibility

**Consideration:** Should we maintain backward compatibility with code that calls these functions without parameters?

**Decision:** NO - These functions are internal implementation details (not exported API), so breaking changes are acceptable. However, we'll:
1. Update all internal call sites simultaneously
2. Update related documentation
3. Note the breaking change in CHANGELOG

---

## Testing Strategy

### Unit Tests to Add

**For `get_docker_platform_args()`:**
```bash
test_get_docker_platform_args_with_amd64_override() {
    result=$(get_docker_platform_args "rocker/r-ver" "amd64")
    assert_equals "--platform linux/amd64" "$result"
}

test_get_docker_platform_args_with_arm64_system() {
    # Mock uname to return arm64
    result=$(get_docker_platform_args "rocker/r-ver" "native")
    assert_equals "" "$result"  # native returns empty
}
```

**For `get_multiarch_base_image()`:**
```bash
test_get_multiarch_base_image_with_custom_verse() {
    result=$(get_multiarch_base_image "verse" "my-custom/verse-arm64")
    assert_equals "my-custom/verse-arm64" "$result"
}
```

**For `build_docker_image()`:**
```bash
test_build_docker_image_missing_dockerfile() {
    # Clean temp dir
    tmpdir=$(mktemp -d)
    cd "$tmpdir"

    result=0
    build_docker_image "4.4.0" "test-pkg" "rocker/r-ver" || result=$?

    assert_equals 1 "$result"  # Should fail - no Dockerfile
}

test_build_docker_image_validates_r_version() {
    # Call with empty R_VERSION
    result=0
    build_docker_image "" "test-pkg" "rocker/r-ver" || result=$?

    assert_equals 1 "$result"  # Should fail - empty R_VERSION
}
```

---

## Risk Assessment

### Low Risk Changes ✅
- Adding parameters with sensible defaults
- All call sites updated simultaneously
- No external API affected (functions are internal)
- Tests verify behavior unchanged

### Mitigation
- Comprehensive testing before and after
- Clear documentation of changes
- Syntax validation for modified files
- Integration testing with full zzcollab workflow

---

## Implementation Checklist

- [ ] **Get Docker Platform Args**
  - [ ] Add `force_platform` parameter
  - [ ] Update function implementation
  - [ ] Update call site (docker.sh:869)
  - [ ] Add tests
  - [ ] Syntax validation

- [ ] **Get Multiarch Base Image**
  - [ ] Add `multiarch_verse_image` parameter
  - [ ] Update function implementation
  - [ ] Search for all call sites and update
  - [ ] Add tests
  - [ ] Syntax validation

- [ ] **Build Docker Image**
  - [ ] Add 4 parameters (r_version, pkg_name, base_image, profile_name)
  - [ ] Update function implementation
  - [ ] Update zzcollab.sh call site (line 939)
  - [ ] Add comprehensive tests
  - [ ] Add integration test with full workflow
  - [ ] Syntax validation

- [ ] **Documentation**
  - [ ] Update function documentation headers
  - [ ] Add parameter descriptions
  - [ ] Create migration guide
  - [ ] Update this document with completion status

---

## Success Criteria

✅ **Implementation Complete When:**

1. All functions accept required values as parameters
2. All call sites updated to pass parameters
3. Functions work correctly with different parameter values
4. Tests pass (including new parameterization tests)
5. Syntax validation passes (`bash -n`)
6. No functional regression in zzcollab workflow
7. Documentation updated with new signatures

---

## References

- **CODE_REVIEW.md** - Issue 2.3 (Original problem statement)
- **PHASE_2_PROGRESS.md** - Phase 2 tracking
- **ERROR_HANDLING_GUIDE.md** - Related patterns for error handling

---

*Last Updated: December 5, 2025*
*Status: IMPLEMENTATION IN PROGRESS (Phase 2A)*
