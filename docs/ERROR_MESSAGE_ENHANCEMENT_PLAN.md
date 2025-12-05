# Issue 3.2: Error Message Enhancement Plan

**Date:** December 5, 2025
**Status:** IN PROGRESS
**Priority:** MEDIUM
**Effort Estimate:** 4-5 hours
**Benefit:** Improved user experience, reduced support questions

---

## Overview

This document outlines the systematic improvement of error messages across the zzcollab codebase to follow a consistent pattern that helps users understand what went wrong and how to fix it.

---

## Current Assessment

### Strong Error Messages (Already Good ✅)

#### docker.sh (Lines 184-196, 212-215, 240-246, 400-406)
- ✅ Shows multiple recovery options
- ✅ Provides actionable commands
- ✅ Explains why the problem occurred
- **Example:**
```bash
log_error "Cannot determine R version: renv.lock not found"
log_error ""
log_error "For reproducible builds, you must specify the R version."
log_error "Choose one of these options:"
log_error ""
log_error "  Option 1 (Recommended): Initialize renv to create renv.lock"
log_error "    R -e \"renv::init()\""
```

#### profile_validation.sh (Lines 320-351)
- ✅ Includes reason for constraint (e.g., "Alpine uses apk package manager")
- ✅ Shows current value and expected value
- ✅ Lists alternative options
- **Example:**
```bash
errors+=("❌ Alpine base image requires --libs alpine")
errors+=("   Current: --libs ${libs_bundle}")
errors+=("   Reason: Alpine uses apk package manager, not apt-get")
```

#### cli.sh (Lines 69-91, 151-155, 178-179)
- ✅ Validates input format with regex
- ✅ Shows valid formats and examples
- ✅ Lists reserved names
- **Example:**
```bash
log_error "Invalid base image reference: '$image'"
log_error "Valid formats:"
log_error "  - 'rocker/rstudio' (Docker Hub)"
log_error "  - 'rocker/rstudio:4.3.1' (with tag)"
log_error "  - 'ghcr.io/org/image' (other registry)"
```

#### validation.sh - Missing Lock (Lines 1269-1322)
- ✅ Explains reproducibility impact
- ✅ Shows next steps for fixing
- ✅ Lists recovery commands
- **Example:**
```bash
log_error "Found ${#missing_ref[@]} packages in union but not in renv.lock"
echo "This breaks reproducibility! Collaborators cannot restore your environment."
echo ""
echo "Next steps:"
echo "  1. Start R to auto-install packages: make r"
echo "  2. Rebuild Docker image: make docker-build"
```

---

## Errors Needing Enhancement

### Category 1: Missing File Errors

**Current (Minimal):**
```bash
# validation.sh:66
log_error "DESCRIPTION file not found: $desc_file"
```

**Issues:**
- Doesn't explain why DESCRIPTION is needed
- Doesn't show how to create it
- No recovery steps

**Improved:**
```bash
log_error "DESCRIPTION file not found: $desc_file"
log_error ""
log_error "DESCRIPTION is required for R package metadata and dependency tracking."
log_error "Create one with:"
log_error ""
log_error "  printf 'Package: myproject\\n' > DESCRIPTION"
log_error "  printf 'Version: 0.1.0\\n' >> DESCRIPTION"
log_error "  printf 'Title: My Project\\n' >> DESCRIPTION"
log_error "  printf 'Description: Project description here\\n' >> DESCRIPTION"
log_error "  printf 'Authors@R: person(\\\"Your\\\", \\\"Name\\\", role = c(\\\"aut\\\", \\\"cre\\\"))\\n' >> DESCRIPTION"
log_error ""
log_error "See: docs/SETUP_DOCUMENTATION_SYSTEM.md for template"
```

**Locations to Fix:**
1. validation.sh:66 - DESCRIPTION not found
2. validation.sh:265 - renv.lock not found

---

### Category 2: YQ/YAML Parsing Errors

**Current (Minimal):**
```bash
# profile_validation.sh:47
log_error "❌ Failed to query ${bundle_type}.${bundle_name}${query_path} from $BUNDLES_FILE"
```

**Issues:**
- Doesn't show where bundles.yaml is
- Doesn't explain what went wrong
- Doesn't list available options

**Improved:**
```bash
log_error "❌ Failed to query ${bundle_type}.${bundle_name} from $BUNDLES_FILE"
log_error ""
log_error "Bundle configuration error - cannot read: $BUNDLES_FILE"
log_error ""
log_error "Possible causes:"
log_error "  1. File missing or not readable at: $BUNDLES_FILE"
log_error "  2. YAML syntax error in bundles file"
log_error "  3. yq command not installed or not working"
log_error ""
log_error "Recovery steps:"
log_error "  1. Verify bundles file exists: ls -la $BUNDLES_FILE"
log_error "  2. Validate YAML syntax: yq eval . $BUNDLES_FILE"
log_error "  3. Check yq installation: which yq && yq --version"
log_error ""
log_error "If file is missing, see: docs/VARIANTS.md for bundle configuration"
```

**Locations to Fix:**
1. profile_validation.sh:47 - Query bundle from BUNDLES_FILE
2. profile_validation.sh:37 - BUNDLES_FILE not found

---

### Category 3: Validation Failures

**Current (Minimal):**
```bash
# profile_validation.sh:176
log_error "❌ Unknown profile: ${profile_name}"
# ... then lists 30+ lines of options
```

**Assessment:** Actually already has good options listing. This is already good.

---

### Category 4: Silent Failures (No Error Message At All)

**Issue:** Some error conditions may not produce output

**Locations to Check:**
1. Core module loading failures
2. Manifest tracking failures
3. File operation failures

---

## Error Message Pattern Template

### Standard 3-Part Pattern

All error messages should follow this structure:

```
1. STATE WHAT'S WRONG
   log_error "❌ [Clear statement of problem]"

2. EXPLAIN THE IMPACT / CONTEXT
   log_error ""
   log_error "[Why this matters / what broke]"

3. SHOW HOW TO FIX IT
   log_error ""
   log_error "Recovery steps:"
   log_error "  1. [First step]"
   log_error "  2. [Second step]"
   log_error "  3. [Next step if needed]"

   OR

   log_error "Available options:"
   log_error "  - [Option 1]"
   log_error "  - [Option 2]"

   OR

   log_error "Command to fix:"
   log_error "  $command_here"
```

### Example: Following the Pattern

```bash
# State what's wrong
log_error "❌ Bundle '$bundle' not found in available bundles"

# Explain context
log_error ""
log_error "The bundle name you specified doesn't exist in bundles.yaml"

# Show how to fix
log_error ""
log_error "Available package bundles:"
yq eval ".package_bundles | keys" "$BUNDLES_FILE" | sed 's/^/  - /'

log_error ""
log_error "See: docs/VARIANTS.md for bundle details"
```

---

## Implementation Roadmap

### Phase 1: File Not Found Errors (30 minutes)

Improve error messages for missing critical files:
- [ ] validation.sh:66 - DESCRIPTION not found
- [ ] validation.sh:265 - renv.lock not found
- [ ] profile_validation.sh:37 - BUNDLES_FILE not found

### Phase 2: YAML/Bundle Errors (45 minutes)

Improve error messages for bundle and configuration errors:
- [ ] profile_validation.sh:47 - Failed to query bundle
- [ ] profile_validation.sh:176 - Unknown profile (already good, verify)

### Phase 3: Complex Operation Errors (60 minutes)

Ensure complex errors have recovery context:
- [ ] docker.sh - Build failures (already good, verify)
- [ ] validation.sh - Package validation errors (already good, verify)

### Phase 4: Edge Cases (45 minutes)

Find and fix any remaining minimal error messages:
- [ ] core.sh - Module loading errors
- [ ] cli.sh - Argument parsing (already good, verify)
- [ ] Other modules - Scan for unhelpful messages

### Phase 5: Documentation (30 minutes)

- [ ] Create SHELL_ERROR_MESSAGE_GUIDE.md for developers
- [ ] Document the 3-part pattern for all contributors
- [ ] Add examples of good vs bad error messages

---

## Quality Criteria

An error message is "good" if it:
- ✅ Clearly states what went wrong (in plain English)
- ✅ Explains why it matters (context)
- ✅ Shows at least one way to fix it (recovery steps)
- ✅ If applicable, lists available options
- ✅ Uses consistent formatting (✅, ❌, ⚠️)
- ✅ Points to relevant documentation when appropriate

An error message is "minimal" if it:
- ❌ Only states the problem with no context
- ❌ Provides no recovery steps
- ❌ Doesn't explain why the issue occurred
- ❌ Assumes user knowledge of the system

---

## Files to Modify

1. **modules/validation.sh** (4-5 error messages)
   - Lines 66-67: DESCRIPTION not found
   - Lines 71-72: DESCRIPTION not writable
   - Lines 265-266: renv.lock not found
   - Lines 274-283: CRAN metadata fetch failure

2. **modules/profile_validation.sh** (2-3 error messages)
   - Lines 37-39: BUNDLES_FILE not found
   - Lines 47-48: Bundle query failure
   - Already good: Lines 176-192 (profile not found)

3. **modules/core.sh** (2-3 error messages)
   - Module loading errors
   - Manifest update failures
   - Directory creation failures

4. **modules/docker.sh** (Verify - appears to already be good)
   - Build failure messages
   - Platform detection issues

---

## Testing Strategy

### Before/After Comparison

For each error message updated:

1. **Trigger the error condition**
   - Create test scenario
   - Reproduce the error

2. **Compare outputs**
   - Old: minimal message
   - New: helpful message with context

3. **Verify format consistency**
   - Follows 3-part pattern
   - Uses appropriate emoji (✅, ❌, ⚠️)
   - References correct documentation

### Example Test Cases

```bash
# Test 1: DESCRIPTION missing
rm -f DESCRIPTION
./zzcollab.sh  # Should show improved error

# Test 2: Bundle not found
zzcollab -k invalid_bundle  # Should show available options

# Test 3: BUNDLES_FILE missing
rm -f bundles.yaml
zzcollab -r analysis  # Should guide to recovery
```

---

## Expected Improvements

### User Experience
- Users understand what went wrong
- Users know what to do next
- Fewer support questions
- Better self-service problem-solving

### Code Quality
- Consistent error message pattern
- Easier to maintain
- Better for new contributors to follow

### Documentation
- Error messages serve as documentation
- Reduces need for external help
- Improves discoverability

---

## Success Criteria

✅ **All error messages follow 3-part pattern:**
1. State what's wrong
2. Explain why it matters
3. Show how to fix it

✅ **Error messages are discoverable:**
- Can understand error without reading code
- Suggests next steps without external documentation
- Points to relevant docs when appropriate

✅ **Consistency achieved:**
- Same pattern across all modules
- Same emoji usage (✅, ❌, ⚠️)
- Same recovery step format

---

## Implementation Notes

### Current State Assessment

Based on code review:
- **~60% of error messages are good** (docker.sh, validation.sh recovery functions)
- **~40% need enhancement** (simple file not found, query failures)
- **~5% need investigation** (edge cases, module loading)

### Priority Order

1. **High-Impact Low-Effort** - File not found errors (easy to improve, affect many users)
2. **High-Impact Medium-Effort** - Bundle/config errors (affects setup process)
3. **Medium-Impact Medium-Effort** - Complex operation errors (verify already good)
4. **Consistency Improvements** - Ensure all follow same pattern

---

## Completion Checklist

- [ ] Phase 1: File not found errors updated
- [ ] Phase 2: Bundle/YAML errors updated
- [ ] Phase 3: Complex operation errors verified
- [ ] Phase 4: Edge cases checked
- [ ] Phase 5: Documentation created
- [ ] All changes tested with real error scenarios
- [ ] Code review complete
- [ ] Commit with message: "Issue 3.2: Enhance error messages with context and recovery steps"

---

*Document created: December 5, 2025*
*Status: Planning phase - ready for implementation*
