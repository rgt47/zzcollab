# Error Handling Guide

**Comprehensive guide to error handling and message formatting in zzcollab**

---

## Table of Contents

1. [Error Handling Principles](#error-handling-principles)
2. [Return vs Exit](#return-vs-exit)
3. [Error Message Format](#error-message-format)
4. [Error Types and Patterns](#error-types-and-patterns)
5. [Best Practices](#best-practices)
6. [Testing Error Handling](#testing-error-handling)
7. [Real-World Examples](#real-world-examples)

---

## Error Handling Principles

### When to Use `return 1` (Recoverable Errors)

Use `return 1` in functions for errors that:
- Caller might want to handle
- Could occur in automated/scripted contexts
- Are part of normal program flow
- Allow caller to decide response

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

```bash
# Module initialization
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_error "core.sh should be sourced, not executed"
    exit 1  # Correct: unrecoverable
fi

# Critical dependency missing
if ! command -v docker &>/dev/null; then
    log_error "Docker is required but not installed"
    exit 1  # Correct: cannot continue
fi
```

---

## Return vs Exit

### Solution Pattern

**Before (Hard Exit):**
```bash
validate_function() {
    if [[ error_condition ]]; then
        log_error "Error message"
        exit 1  # Script terminates, caller can't handle
    fi
}
```

**After (Recoverable Error):**
```bash
validate_function() {
    if [[ error_condition ]]; then
        log_error "Error message"
        return 1  # Caller decides response
    fi
}

# Usage:
if ! validate_function "$input"; then
    log_warn "Using default value"
    input="default"
fi
```

### Error Recovery Example

```bash
# 1. Function returns error (recoverable)
load_config() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        log_warn "Config not found: $config_file"
        return 1
    fi
    source "$config_file" || return 1
    return 0
}

# 2. Caller handles gracefully
main() {
    if load_config "/etc/myapp/config.conf"; then
        log_info "Loaded system config"
    elif load_config "$HOME/.myapp/config.conf"; then
        log_info "Loaded user config"
    else
        log_warn "No config found, using defaults"
        load_default_config
    fi
    process_data
}

# 3. Main script exits at top level
if ! main; then
    log_error "Fatal error occurred"
    exit 1
fi
```

---

## Error Message Format

### The 3-Part Pattern

All error messages should follow this pattern:

**Part 1: State What's Wrong**
```bash
log_error "DESCRIPTION file not found: $desc_file"
```

**Part 2: Explain the Impact**
```bash
log_error ""
log_error "DESCRIPTION is required for R package metadata."
```

**Part 3: Show How to Fix It**
```bash
log_error ""
log_error "Create with:"
log_error "  printf 'Package: myproject\\nVersion: 0.1.0\\n' > DESCRIPTION"
```

### Log Function Hierarchy

```bash
log_error()   # Always shown (even in --quiet)
log_warn()    # Shown at level >= 1 (default)
log_success() # Shown at level >= 1 (default)
log_info()    # Shown at level >= 2 (-v)
log_debug()   # Shown at level >= 3 (-vv)
```

---

## Error Types and Patterns

### Type 1: Missing Files

```bash
if [[ ! -f "$DESCRIPTION" ]]; then
    log_error "DESCRIPTION file not found: $DESCRIPTION"
    log_error ""
    log_error "DESCRIPTION is required for R package metadata."
    log_error ""
    log_error "Create with:"
    log_error "  printf 'Package: myproject\\nVersion: 0.1.0\\n' > DESCRIPTION"
    log_error ""
    log_error "Or restore:"
    log_error "  git checkout DESCRIPTION"
    return 1
fi
```

### Type 2: Invalid Input

```bash
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid R version: '$version'"
    log_error ""
    log_error "Expected semantic version format: X.Y.Z"
    log_error ""
    log_error "Valid examples:"
    log_error "  - 4.3.1"
    log_error "  - 4.2.0"
    return 1
fi
```

### Type 3: Configuration Not Found

```bash
if [[ ! -f "$BUNDLES_FILE" ]]; then
    log_error "Bundles file not found: $BUNDLES_FILE"
    log_error ""
    log_error "bundles.yaml defines Docker profiles and package collections."
    log_error ""
    log_error "Recovery steps:"
    log_error "  1. Copy from templates: cp templates/bundles.yaml ."
    log_error "  2. Or restore from git: git checkout bundles.yaml"
    log_error ""
    log_error "See: docs/variants.md for bundle configuration"
    return 1
fi
```

### Type 4: Operation Failed

```bash
if ! add_package_to_description "$pkg"; then
    log_error "Failed to add '$pkg' to DESCRIPTION"
    log_error ""
    log_error "Possible causes:"
    log_error "  - DESCRIPTION file not writable"
    log_error "  - Invalid package name"
    log_error "  - DESCRIPTION syntax error"
    log_error ""
    log_error "Troubleshooting:"
    log_error "  ls -la DESCRIPTION"
    log_error "  head -5 DESCRIPTION"
    return 1
fi
```

### Type 5: Network/External Service

```bash
if ! pkg_info=$(fetch_cran_package_info "$pkg"); then
    log_error "Failed to fetch metadata for '$pkg' from CRAN"
    log_error ""
    log_error "Possible causes:"
    log_error "  - No internet connection"
    log_error "  - CRAN API unavailable"
    log_error "  - Package does not exist on CRAN"
    log_error ""
    log_error "Recovery:"
    log_error "  1. Check connection: curl -I https://cran.r-project.org"
    log_error "  2. Verify package: https://cran.r-project.org/package=$pkg"
    return 1
fi
```

---

## Best Practices

### DO

- **Use specific values**: Show the actual filename, package name, etc.
- **Provide actionable steps**: Users should know exactly what command to run
- **Show examples**: "Valid examples: rocker/rstudio, rocker/rstudio:4.3.1"
- **Link to docs**: "See: docs/variants.md for details"
- **Keep it brief**: 3-6 lines of context is usually enough
- **Explain the "why"**: Why does this problem matter?
- **List options**: If multiple ways to fix, show them all

### DON'T

- **Be vague**: "ERROR: Command failed" is useless
- **Assume knowledge**: Explain what files are for
- **Require external lookup**: Inline the information
- **Use jargon**: Explain technical terms
- **Omit context**: "File not found" needs to say which file
- **Forget recovery**: Always show how to fix it
- **Spam output**: Too many errors hide the problem

### Anti-Patterns

**Bad (Vague):**
```bash
log_error "Invalid argument"
log_error "Command failed"
```

**Good (Specific):**
```bash
log_error "Invalid base image: '$image' (expected format: registry/name:tag)"
log_error "Failed to build Docker image (see: docker build output above)"
```

**Bad (No Recovery):**
```bash
log_error "DESCRIPTION file missing"
```

**Good (With Recovery):**
```bash
log_error "DESCRIPTION file not found"
log_error ""
log_error "Create with: printf 'Package: myproject\\n' > DESCRIPTION"
```

---

## Testing Error Handling

### Test Pattern: Error Recovery

```bash
test_validate_function_error_recovery() {
    setup_test_logging

    # Test: Function should return error code, not exit
    result=0
    validate_function "invalid_input" || result=$?

    # Verify: Error code is 1 (function returned, didn't exit)
    assert_equals "1" "$result" "Should return 1, not exit"

    # Verify: Script is still running
    assert_success echo "Script still running"
}
```

### Testing Error Messages

Before committing:

1. **Trigger the error**: Create the condition that causes the error
2. **Read it aloud**: Does it make sense?
3. **Would you understand it?**: If first time seeing, would you know what to do?
4. **Try the suggested fix**: Does the recovery command work?

### Error Message Checklist

- [ ] **Specific**: Does it say exactly what went wrong?
- [ ] **Context**: Does it explain why this matters?
- [ ] **Actionable**: Can user fix it with the information given?
- [ ] **Brief**: Is it 3-6 lines max?
- [ ] **Examples**: Does it show valid values/commands?
- [ ] **Documentation**: Does it reference relevant docs?
- [ ] **Variables**: Does it include relevant filenames/values?

---

## Real-World Examples

### CRAN API Error

```bash
if [[ $? -ne 0 ]] || [[ -z "$pkg_info" ]]; then
    log_error "Failed to fetch metadata for '$pkg' from CRAN"
    log_error ""
    log_error "Possible causes:"
    log_error "  - Package '$pkg' does not exist on CRAN"
    log_error "  - Network connection problem"
    log_error "  - CRAN API temporarily unavailable"
    log_error ""
    log_error "Recovery steps:"
    log_error "  1. Verify package: https://cran.r-project.org/package=$pkg"
    log_error "  2. Check connection: curl -I https://cran.r-project.org"
    log_error "  3. Try again: install.packages(\"$pkg\") in R session"
    return 1
fi
```

### Bundle Configuration Error

```bash
if [[ ! -f "$BUNDLES_FILE" ]]; then
    log_error "Bundles file not found: $BUNDLES_FILE"
    log_error ""
    log_error "Bundle configuration (bundles.yaml) is missing."
    log_error "This file defines all available Docker profiles."
    log_error ""
    log_error "Recovery steps:"
    log_error "  1. Check: ls -la bundles.yaml"
    log_error "  2. Copy from templates: cp templates/bundles.yaml ."
    log_error "  3. Restore from git: git checkout templates/bundles.yaml"
    return 1
fi
```

### Module Dependency Error

```bash
if [[ "${!module_var:-}" != "true" ]]; then
    {
        echo "Module Dependency Error: ${current_module}.sh requires ${module}.sh"
        echo ""
        echo "Module '${module}.sh' was not loaded before '${current_module}.sh'."
        echo ""
        echo "Recovery steps:"
        echo "  1. Check module loading order in zzcollab.sh"
        echo "  2. Ensure modules are sourced in correct order:"
        echo "     - constants.sh must load first"
        echo "     - core.sh must load before any other module"
        echo ""
        echo "See: docs/development.md for module initialization details"
    } >&2
    exit 1
fi
```

---

## Common Scenarios

### Package not on CRAN

```bash
log_error "Package '$pkg' not found on CRAN"
log_error ""
log_error "Possible reasons:"
log_error "  - Package name misspelled"
log_error "  - Package archived or removed"
log_error "  - Private/local package"
log_error ""
log_error "Verify: https://cran.r-project.org/package=$pkg"
```

### Permission Denied

```bash
log_error "Permission denied: $file"
log_error ""
log_error "Check ownership: ls -la $file"
log_error "Fix with: chmod u+w $file"
```

### YAML Syntax Error

```bash
log_error "Invalid YAML in $config_file"
log_error ""
log_error "Validate with: yq eval . $config_file"
log_error "See: docs/configuration.md for structure"
```

---

## Summary

- Use `return 1` for recoverable errors (caller handles)
- Use `exit 1` only for fatal/unrecoverable errors
- Follow the 3-part pattern: Problem → Context → Recovery
- Include specific values and actionable commands
- Test error messages by triggering actual errors

---

**Last Updated**: December 2025
