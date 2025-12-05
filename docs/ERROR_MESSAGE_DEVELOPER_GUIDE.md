# Error Message Developer Guide

**Date:** December 5, 2025
**Status:** ACTIVE
**For:** Developers maintaining and extending zzcollab

---

## Overview

This guide establishes the standard for writing helpful error messages in zzcollab. Good error messages help users understand what went wrong and how to fix it. Poor error messages waste time and generate support questions.

---

## The 3-Part Error Message Pattern

All error messages should follow this proven pattern:

### Part 1: State What's Wrong (1-2 lines)
```bash
log_error "❌ DESCRIPTION file not found: $desc_file"
```
- Use ❌ emoji for errors, ⚠️ for warnings
- Clear, specific problem statement
- Include relevant variables (filenames, values, etc.)
- No jargon or assumptions about user knowledge

### Part 2: Explain the Impact/Context (1-3 lines)
```bash
log_error ""
log_error "DESCRIPTION is required for R package metadata and dependency tracking."
log_error "It lists all packages your project depends on (in the Imports field)."
```
- Why does this problem matter?
- What will break if they ignore it?
- What is this file/setting for?
- Keep technical level appropriate for the error type

### Part 3: Show How to Fix It (3-6 lines)
```bash
log_error ""
log_error "Create one with:"
log_error "  printf 'Package: myproject\\nVersion: 0.1.0\\n' > DESCRIPTION"
log_error ""
log_error "Or copy the template:"
log_error "  cp templates/DESCRIPTION_template DESCRIPTION"
```
- Provide actionable steps
- Show exact commands to run
- List alternative options if applicable
- Point to relevant documentation

---

## Error Types and Patterns

### Type 1: Missing Files

**Pattern:**
```bash
log_error "❌ FILE not found: \$path"
log_error ""
log_error "[What the file is for]"
log_error ""
log_error "Create with:"
log_error "  [exact command]"
log_error ""
log_error "Or restore from:"
log_error "  git checkout [path]"
```

**Example:**
```bash
if [[ ! -f "$DESCRIPTION" ]]; then
    log_error "❌ DESCRIPTION file not found: $DESCRIPTION"
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

---

### Type 2: Invalid Input

**Pattern:**
```bash
log_error "❌ Invalid THING: '\$value'"
log_error ""
log_error "Expected: [description of valid format]"
log_error ""
log_error "Valid examples:"
log_error "  - [example 1]"
log_error "  - [example 2]"
```

**Example:**
```bash
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "❌ Invalid R version: '$version'"
    log_error ""
    log_error "Expected semantic version format: X.Y.Z"
    log_error ""
    log_error "Valid examples:"
    log_error "  - 4.3.1"
    log_error "  - 4.2.0"
    log_error "  - 3.6.3"
    return 1
fi
```

---

### Type 3: Configuration Not Found

**Pattern:**
```bash
log_error "❌ CONFIG not found: \$path"
log_error ""
log_error "Configuration file details:"
log_error "  - Used for: [purpose]"
log_error "  - Format: [format details]"
log_error ""
log_error "Recovery steps:"
log_error "  1. [step 1]"
log_error "  2. [step 2]"
log_error ""
log_error "See: docs/CONFIGURATION.md"
```

**Example:**
```bash
if [[ ! -f "$BUNDLES_FILE" ]]; then
    log_error "❌ Bundles file not found: $BUNDLES_FILE"
    log_error ""
    log_error "bundles.yaml defines Docker profiles and package collections."
    log_error ""
    log_error "Recovery steps:"
    log_error "  1. Copy from templates: cp templates/bundles.yaml ."
    log_error "  2. Or restore from git: git checkout bundles.yaml"
    log_error ""
    log_error "See: docs/VARIANTS.md for bundle configuration"
    return 1
fi
```

---

### Type 4: Operation Failed

**Pattern:**
```bash
log_error "❌ Failed to OPERATION: [reason]"
log_error ""
log_error "Possible causes:"
log_error "  - [cause 1]"
log_error "  - [cause 2]"
log_error ""
log_error "Troubleshooting:"
log_error "  [diagnostic command]"
log_error "  [recovery command]"
```

**Example:**
```bash
if ! add_package_to_description "$pkg"; then
    log_error "❌ Failed to add '$pkg' to DESCRIPTION"
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

---

### Type 5: Network/External Service Error

**Pattern:**
```bash
log_error "❌ Failed to OPERATION: [service/resource]"
log_error ""
log_error "Possible causes:"
log_error "  - No internet connection"
log_error "  - Service temporarily unavailable"
log_error "  - Invalid resource"
log_error ""
log_error "Recovery:"
log_error "  1. Check connection: [diagnostic command]"
log_error "  2. Try again: [retry command]"
log_error "  3. If persists, check: [documentation link]"
```

**Example:**
```bash
if ! pkg_info=$(fetch_cran_package_info "$pkg"); then
    log_error "❌ Failed to fetch metadata for '$pkg' from CRAN"
    log_error ""
    log_error "Possible causes:"
    log_error "  - No internet connection"
    log_error "  - CRAN API unavailable"
    log_error "  - Package does not exist on CRAN"
    log_error ""
    log_error "Recovery:"
    log_error "  1. Check connection: curl -I https://cran.r-project.org"
    log_error "  2. Verify package exists: https://cran.r-project.org/package=$pkg"
    log_error "  3. Try again: zzcollab --check-renv"
    return 1
fi
```

---

## Best Practices

### DO ✅

- **Use emoji for visual scan**: ❌ errors, ⚠️ warnings, ✅ success
- **Include specific values**: Show the actual filename, package name, etc.
- **Provide actionable steps**: Users should know exactly what command to run
- **Show examples**: "Valid examples: rocker/rstudio, rocker/rstudio:4.3.1"
- **Link to docs**: "See: docs/VARIANTS.md for details"
- **Use stderr for errors**: `log_error` outputs to stderr (correct)
- **Keep it brief**: 3-5 lines of context is usually enough
- **Explain the "why"**: Why does this matter? What broke?
- **List options**: If multiple ways to fix, show them all

### DON'T ❌

- **Don't be vague**: "ERROR: Command failed" → useless
- **Don't assume knowledge**: Explain what files are for
- **Don't require external lookup**: Inline the information
- **Don't use jargon**: Explain technical terms
- **Don't omit context**: "File not found" needs to say which file
- **Don't forget recovery**: Always show how to fix it
- **Don't spam the output**: Too many errors hide the problem
- **Don't use colors**: Use emoji instead (more compatible)
- **Don't give up**: If you don't know recovery, mention checking logs

---

## Anti-Patterns (What NOT to Do)

### Bad: Vague
```bash
# ❌ AVOID THIS
log_error "Invalid argument"
log_error "Command failed"
log_error "Error in configuration"
```

### Good: Specific
```bash
# ✅ DO THIS
log_error "❌ Invalid base image: '$image' (expected format: registry/name:tag)"
log_error "❌ Failed to build Docker image (see: docker build output above)"
log_error "❌ Bundle 'invalid_name' not found in bundles.yaml"
```

---

### Bad: No Recovery
```bash
# ❌ AVOID THIS
log_error "DESCRIPTION file missing"
# (user has no idea what to do)
```

### Good: With Recovery
```bash
# ✅ DO THIS
log_error "❌ DESCRIPTION file not found"
log_error ""
log_error "Create with: printf 'Package: myproject\\n' > DESCRIPTION"
log_error "Or restore: git checkout DESCRIPTION"
```

---

### Bad: Too Much Context
```bash
# ❌ AVOID THIS (10+ lines for one error)
log_error "The function validate_package_environment encountered an issue"
log_error "during execution of the package validation pipeline. The root cause"
log_error "appears to be related to the manifest tracking system which is used"
log_error "to record all files created during execution. The error occurred in"
log_error "the section that updates the manifest JSON structure..."
# (user is lost in the details)
```

### Good: Concise
```bash
# ✅ DO THIS
log_error "❌ Failed to update manifest"
log_error ""
log_error "Check manifest file: ls -la .zzcollab_manifest.json"
log_error "Restore with: git checkout .zzcollab_manifest.json"
```

---

## Error Message Checklist

When writing an error message, verify:

- [ ] **Specific**: Does it say exactly what went wrong? (not just "Error")
- [ ] **Context**: Does it explain why this matters?
- [ ] **Actionable**: Can user fix it with the information given?
- [ ] **Brief**: Is it 3-6 lines max?
- [ ] **Emoji**: Does it use ❌ or ⚠️ for visual scanning?
- [ ] **Examples**: Does it show valid values/commands?
- [ ] **Documentation**: Does it reference relevant docs?
- [ ] **Variables**: Does it include relevant filenames/values?
- [ ] **Readable**: Would someone new understand it?

---

## Common Scenarios and Templates

### Scenario: Package not on CRAN

```bash
log_error "❌ Package '$pkg' not found on CRAN"
log_error ""
log_error "Possible reasons:"
log_error "  - Package name misspelled"
log_error "  - Package archived or removed"
log_error "  - Private/local package (install manually)"
log_error ""
log_error "Verify: https://cran.r-project.org/package=$pkg"
```

### Scenario: File Permission Denied

```bash
log_error "❌ Permission denied: $file"
log_error ""
log_error "You don't have write permission for this file."
log_error ""
log_error "Check ownership: ls -la $file"
log_error "Fix with: chmod u+w $file"
log_error "Or ask owner: sudo chown \$USER $file"
```

### Scenario: Configuration Syntax Error

```bash
log_error "❌ Invalid YAML in $config_file"
log_error ""
log_error "YAML syntax error at line $line: $error_detail"
log_error ""
log_error "Validate with: yq eval . $config_file"
log_error "See: docs/CONFIGURATION.md for structure"
```

### Scenario: Network Timeout

```bash
log_error "❌ Timeout connecting to $service"
log_error ""
log_error "Cannot reach: $url"
log_error "Check connection: curl -I $url"
log_error "Retry with: zzcollab --retry"
log_error "See: docs/TROUBLESHOOTING.md"
```

---

## Testing Your Error Messages

Before committing:

1. **Trigger the error**: Create the condition that causes the error
2. **Read it aloud**: Does it make sense?
3. **Would you understand it?**: If this was your first time seeing this error, would you know what to do?
4. **Is it helpful?**: Does it save you from reading code or documentation?
5. **Try the suggested fix**: Does the recovery command actually work?

---

## Deprecation: Old Error Message Patterns

These patterns are no longer acceptable in zzcollab:

```bash
# ❌ OLD PATTERN (minimal)
log_error "File not found"
log_error "Invalid argument"
log_error "Command failed"

# ✅ NEW PATTERN (contextual)
log_error "❌ DESCRIPTION file not found"
log_error ""
log_error "Create with: printf 'Package: myproject\\n' > DESCRIPTION"
```

---

## Real-World Examples from zzcollab

### Example 1: CRAN API Error (validation.sh)
```bash
if [[ $? -ne 0 ]] || [[ -z "$pkg_info" ]]; then
    log_error "❌ Failed to fetch metadata for '$pkg' from CRAN"
    log_error ""
    log_error "Could not query package information from CRAN."
    log_error "Possible causes:"
    log_error "  - Package '$pkg' does not exist on CRAN"
    log_error "  - Network connection problem"
    log_error "  - CRAN API temporarily unavailable"
    log_error ""
    log_error "Recovery steps:"
    log_error "  1. Verify package exists on CRAN: https://cran.r-project.org/package=$pkg"
    log_error "  2. Check your internet connection: curl -I https://cran.r-project.org"
    log_error "  3. Try again: install.packages(\"$pkg\") in R session"
    return 1
fi
```

### Example 2: Bundle Configuration Error (profile_validation.sh)
```bash
if [[ ! -f "$BUNDLES_FILE" ]]; then
    log_error "❌ Bundles file not found: $BUNDLES_FILE"
    log_error ""
    log_error "Bundle configuration (bundles.yaml) is missing."
    log_error "This file defines all available Docker profiles and compatibility rules."
    log_error ""
    log_error "Recovery steps:"
    log_error "  1. Check if bundles.yaml exists: ls -la bundles.yaml"
    log_error "  2. If missing, copy from templates: cp templates/bundles.yaml ."
    log_error "  3. If templates/ missing, restore from git: git checkout templates/bundles.yaml"
    return 1
fi
```

### Example 3: Module Dependency Error (core.sh)
```bash
if [[ "${!module_var:-}" != "true" ]]; then
    {
        echo "❌ Module Dependency Error: ${current_module}.sh requires ${module}.sh"
        echo ""
        echo "Module '${module}.sh' was not loaded before '${current_module}.sh'."
        echo "This is a framework initialization error."
        echo ""
        echo "Recovery steps:"
        echo "  1. Check module loading order in zzcollab.sh"
        echo "  2. Ensure modules are sourced in correct order:"
        echo "     - constants.sh must load first"
        echo "     - core.sh must load before any other module"
        echo ""
        echo "See: docs/DEVELOPMENT.md for module initialization details"
    } >&2
    exit 1
fi
```

---

## For Framework Contributors

### When adding new error handling:

1. **Use the 3-part pattern**: Problem → Context → Recovery
2. **Test real error scenarios**: Actually trigger the error condition
3. **Run `bash -n`**: Ensure your code has no syntax errors
4. **Reference documentation**: Link to relevant docs
5. **Include actionable steps**: Users should know what command to run
6. **Use emoji consistently**: ❌ for errors, ⚠️ for warnings
7. **Verify recovery commands work**: Test the suggested fixes

### When reviewing error messages:

- Is it helpful or just complaining?
- Would someone new understand it?
- Does it say what to do next?
- Is it 3-6 lines max (not too verbose)?
- Does it include actual filenames/values?

---

## Related Documentation

- **[ERROR_MESSAGE_ENHANCEMENT_PLAN.md](ERROR_MESSAGE_ENHANCEMENT_PLAN.md)** - Implementation progress
- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Development guidelines
- **[SHELL_DEVELOPMENT_GUIDE.md](SHELL_DEVELOPMENT_GUIDE.md)** - Shell coding standards (when created)

---

*Created: December 5, 2025*
*Status: Active - Use for all new error messages*
