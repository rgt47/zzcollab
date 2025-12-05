# Error Handling Guide for zzcollab

**Purpose:** Establish clear patterns for error handling across the codebase
**Date:** December 5, 2025
**Status:** Framework defined for Phase 2 implementation

---

## Error Handling Principles

### When to Use `return 1` (Recoverable Errors)

Use `return 1` in functions for errors that:
- Caller might want to handle
- Could occur in automated/scripted contexts
- Are part of normal program flow
- Allow caller to decide response

**Examples:**
```bash
validate_team_name() {
    if [[ ... ]]; then
        log_error "Invalid team name"
        return 1  # Caller can retry or use default
    fi
}

add_package_to_description() {
    if [[ ! -f "DESCRIPTION" ]]; then
        log_error "DESCRIPTION not found"
        return 1  # Caller can create file or skip
    fi
}
```

### When to Use `exit 1` (Unrecoverable Errors)

Use `exit 1` only for:
- Installation errors (missing dependencies)
- Corrupted state (cannot continue safely)
- Fatal configuration errors
- Startup failures

**Examples:**
```bash
# Module initialization (line 539 of core.sh)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_error "core.sh should be sourced, not executed"
    exit 1  # Correct: unrecoverable
fi

# Critical dependency missing
if [[ ! -f "$REQUIRED_FILE" ]]; then
    log_error "Critical file missing"
    exit 1  # Correct: cannot continue
fi
```

---

## Current Issues

### Issue 2.1: Hard Exits in Functions (HIGH PRIORITY)

**Problem:** Functions call `exit 1` instead of `return 1`, preventing error handling

**Affected Areas:**
- cli.sh: Argument parsing validation (lines 360, 435)
- profile_validation.sh: Profile validation (lines 209, 958, 969, 980)
- rpackage.sh: Package validation (line 331)

**Impact:**
- Scripted invocations can't catch errors
- Prevents programmatic usage
- All-or-nothing error model

### Solution Pattern

**Before (Hard Exit):**
```bash
validate_function() {
    if [[ error_condition ]]; then
        log_error "Error message"
        exit 1  # ❌ Script terminates, caller can't handle
    fi
    return 0
}
```

**After (Recoverable Error):**
```bash
validate_function() {
    if [[ error_condition ]]; then
        log_error "Error message"
        return 1  # ✅ Caller decides response
    fi
    return 0
}
```

---

## Error Handling Patterns

### Pattern 1: Validation Functions

**Type:** Recoverable - caller might retry or use default
**Exit Code:** 0 on success, 1 on invalid

```bash
##############################################################################
# Function: validate_input
# Purpose: Check if input meets requirements
# Args: $1 - input to validate
# Returns: 0 if valid, 1 if invalid (RECOVERABLE)
##############################################################################
validate_input() {
    local input="$1"

    if [[ -z "$input" ]]; then
        log_error "Input cannot be empty"
        return 1  # Caller can retry
    fi

    if ! [[ "$input" =~ ^[a-z]+$ ]]; then
        log_error "Input must be lowercase letters only"
        return 1  # Caller can validate again
    fi

    return 0
}

# Usage:
if validate_input "$user_input"; then
    process_input "$user_input"
else
    log_warn "Using default value"
    user_input="default"
fi
```

### Pattern 2: File Operations

**Type:** Mixed - some errors recoverable, some not
**Strategy:** Use `return 1` for missing files, `exit 1` for permission errors

```bash
##############################################################################
# Function: read_config_file
# Purpose: Read configuration file with fallback
# Args: $1 - config file path
# Returns: 0 on success, 1 on recoverable error
##############################################################################
read_config_file() {
    local config_file="$1"

    # Recoverable: file doesn't exist (use default)
    if [[ ! -f "$config_file" ]]; then
        log_warn "Config file not found: $config_file (using defaults)"
        return 1  # Caller should use defaults
    fi

    # Recoverable: file not readable (might be permission issue but user can fix)
    if [[ ! -r "$config_file" ]]; then
        log_error "Cannot read config file: $config_file"
        return 1  # Caller can fix permissions and retry
    fi

    # Read the file
    if ! source "$config_file"; then
        log_error "Error parsing config file: $config_file"
        return 1  # Caller can investigate
    fi

    return 0
}

# Usage:
if ! read_config_file "$CONFIG_PATH"; then
    log_info "Using default configuration"
    load_default_config
fi
```

### Pattern 3: System Dependencies

**Type:** Unrecoverable - missing tools or resources
**Exit:** Use `exit 1` because cannot continue

```bash
##############################################################################
# Function: check_system_dependencies
# Purpose: Verify required tools are installed
# Args: None
# Returns: Never returns on failure (UNRECOVERABLE)
# Side Effects: Exits script if dependencies missing
##############################################################################
check_system_dependencies() {
    local missing=()

    for cmd in "docker" "git" "curl"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_error "Please install: ${missing[*]}"
        exit 1  # Correct: cannot continue without tools
    fi
}

# Call early in script
check_system_dependencies
```

---

## Implementation Checklist

### Phase 2: Error Recovery Implementation

**High Priority Functions** (should use `return 1`):

- [ ] cli.sh: `parse_cli_arguments()` - validate inputs during parsing
- [ ] profile_validation.sh: `validate_profile_combination()` - validation should be recoverable
- [ ] profile_validation.sh: Bundle validation functions
- [ ] rpackage.sh: Package validation functions

**Keep as `exit 1`** (unrecoverable):

- [ ] core.sh: Module loading checks (line 516, 539)
- [ ] constants.sh: Fatal configuration errors (line 124)
- [ ] Dependency checks (Docker, git, etc.)

---

## Testing Error Recovery

### Test Pattern: Error Recovery

```bash
test_validate_function_error_recovery() {
    # Setup
    setup_test_logging

    # Test: Function should return error code, not exit
    result=0
    validate_function "invalid_input" || result=$?

    # Verify: Error code is 1 (function returned, didn't exit)
    assert_equals "1" "$result" "Should return 1, not exit"

    # Verify: Script is still running (can check with $?)
    assert_success echo "Script still running"
}
```

---

## Error Message Best Practices

### Include Actionable Information

**Bad (No Context):**
```bash
log_error "Validation failed"  # User doesn't know what to do
return 1
```

**Good (Actionable):**
```bash
log_error "Profile '$PROFILE_NAME' not found in bundles.yaml"
log_error "Available profiles:"
list_available_profiles | sed 's/^/  - /'
return 1  # User knows what profiles are valid
```

### Different Error Levels

```bash
# Debug: Detailed info for developers
log_debug "Checking profile: $PROFILE_NAME"

# Error: User-facing error with recovery options
log_error "Profile not found: $PROFILE_NAME"
log_error "Try one of: tidyverse, minimal, analysis"
return 1

# Warn: Something unexpected but recovery possible
log_warn "Config file missing, using defaults"
return 0  # Operation can continue
```

---

## Common Patterns to Refactor

### Pattern A: Argument Validation

**Current (exits hard):**
```bash
require_arg() {
    [[ -n "${2:-}" ]] || { echo "Error: $1 requires argument" >&2; exit 1; }
}
```

**Improved (returns error):**
```bash
require_arg() {
    if [[ -z "${2:-}" ]]; then
        echo "Error: $1 requires argument" >&2
        return 1  # Let caller handle
    fi
}

# Usage:
if ! require_arg "--team" "$team_arg"; then
    log_error "Team name required"
    show_usage
    exit 1  # Script decides to exit
fi
```

### Pattern B: Configuration Validation

**Current (exits hard):**
```bash
validate_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config missing"
        exit 1  # Cannot recover
    fi
}
```

**Improved (returns error):**
```bash
validate_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "Config missing: $CONFIG_FILE"
        return 1  # Caller can use defaults
    fi
}

# Usage:
if ! validate_config; then
    log_info "Using default configuration"
    load_defaults
fi
```

---

## Error Recovery Example: Full Flow

```bash
#!/bin/bash

# 1. Function returns error (recoverable)
load_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        log_warn "Config not found: $config_file"
        return 1
    fi

    source "$config_file" || {
        log_error "Failed to parse config"
        return 1
    }

    return 0
}

# 2. Caller handles error gracefully
main() {
    if load_config "/etc/myapp/config.conf"; then
        log_info "Loaded custom config"
    elif load_config "$HOME/.myapp/config.conf"; then
        log_info "Loaded user config"
    else
        log_warn "No config found, using defaults"
        load_default_config
    fi

    # Program can continue with defaults
    process_data
}

# 3. Main script calls error handler
if ! main; then
    log_error "Fatal error occurred"
    exit 1  # Only exit at top level
fi

exit 0
```

---

## Migration Path

### Step 1: Identify Functions
- Functions that call `exit 1`
- That are not module initialization
- That are called during normal execution

### Step 2: Assess Recovery Options
- Can caller do something useful with return value?
- Are there sensible defaults?
- Should caller have choice?

### Step 3: Change to `return 1`
- Replace `exit 1` with `return 1`
- Verify caller handles return code
- Add error handling test

### Step 4: Update Callers
- Use `||` to check return code
- Implement fallback logic
- Add meaningful error messages

---

## References

**Related Documentation:**
- CODE_REVIEW.md (Issue 2.1: Error Recovery Disabled)
- SHELL_TESTING_SETUP.md (Test patterns)
- test-validation.sh (Example test for error handling)

**Shell Best Practices:**
- Return codes: 0 = success, 1 = failure
- Use `set -e` carefully (exits on any error)
- Prefer returning errors for recoverable situations
- Use `exit` only for fatal/unrecoverable errors

---

**Framework Created:** December 5, 2025
**Status:** Ready for Phase 2 implementation
**Impact:** Better error handling, more resilient code, easier testing
