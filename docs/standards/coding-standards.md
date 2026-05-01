# ZZCOLLAB Coding Standards

**Shell scripting standards for consistent, maintainable code**

---

## Table of Contents
1. [Variable Naming Conventions](#variable-naming-conventions)
2. [Function Naming](#function-naming)
3. [Error Handling](#error-handling)
4. [Documentation Standards](#documentation-standards)
5. [Module Structure](#module-structure)

---

## Variable Naming Conventions

### Global Variables
**Pattern**: `UPPERCASE_WITH_UNDERSCORES`

```bash
# Exported/global variables
readonly PKG_NAME="mypackage"
readonly AUTHOR_NAME="Your Name"
readonly BASE_IMAGE="rocker/r-ver"
export PROFILE_NAME="minimal"
```

**Rules**:
- Always readonly when possible
- Export only when needed by subprocesses
- Declare at top of script/module
- Document purpose in comments

### Local Variables
**Pattern**: `lowercase_with_underscores`

```bash
function process_data() {
    local input_file="$1"
    local output_dir="$2"
    local temp_file=$(mktemp)

    # Process data
    ...
}
```

**Rules**:
- Always use `local` keyword in functions
- Descriptive names (avoid single letters except loop counters)
- Initialize when declaring when possible

### Module-Level Constants
**Pattern**: `ZZCOLLAB_MODULE_CONSTANT`

```bash
# In modules/constants.sh
readonly ZZCOLLAB_DEFAULT_BASE_IMAGE="rocker/r-ver"
readonly ZZCOLLAB_TEMPLATES_DIR="$SCRIPT_DIR/templates"
readonly ZZCOLLAB_AUTHOR_NAME="${ZZCOLLAB_AUTHOR_NAME:-Your Name}"
```

**Rules**:
- Prefix with `ZZCOLLAB_` to avoid conflicts
- Use for constants shared across modules
- Provide fallback values with `${VAR:-default}`

### Boolean Flags
**Pattern**: `UPPERCASE_FLAG` with true/false values

```bash
readonly BUILD_DOCKER=false
USE_TEAM_IMAGE=true
CREATE_GITHUB_REPO=false
```

**Rules**:
- Use `true`/`false` strings (not 0/1)
- Test with `[[ "$FLAG" == "true" ]]`
- Default to false for safety

### Loop Variables
**Pattern**: Single letter or descriptive name

```bash
# Acceptable
for file in *.sh; do
    echo "$file"
done

for module in "${modules_to_load[@]}"; do
    load_module "$module"
done

# Also acceptable for simple loops
for i in {1..10}; do
    echo "$i"
done
```

---

## Function Naming

### Public Functions
**Pattern**: `lowercase_with_underscores`

```bash
validate_package_name() {
    local dir_name
    dir_name=$(basename "$(pwd)")
    ...
}

create_docker_files() {
    ...
}
```

**Rules**:
- Verb-first naming (create_, validate_, get_, set_)
- Descriptive and specific
- Document with header comment

### Private/Helper Functions
**Pattern**: `_lowercase_with_leading_underscore`

```bash
_internal_helper() {
    # Not part of public API
    ...
}

_parse_yaml_value() {
    # Internal use only
    ...
}
```

**Rules**:
- Leading underscore indicates private
- Not for external use
- Less documentation required

### Module Entry Points
**Pattern**: `action_noun` or `verb_object`

```bash
# Good examples
create_directory_structure()
build_docker_image()
validate_team_member_flags()
generate_r_package_install_commands()
```

---

## Error Handling

### Logging Functions
Always use centralized logging:

```bash
# DO use log functions
log_info "Starting process..."
log_error "Failed to create directory: $dir"
log_warning "Configuration file not found, using defaults"
log_success "Build completed successfully"

# DON'T use raw echo
echo "Error: something failed" >&2  # ❌ Wrong
```

### Error Messages
**Format**: Emoji + descriptive message

```bash
# Through log functions (emoji added automatically)
log_error "Cannot create directory: $dir"
# Output: ❌ Cannot create directory: /path/to/dir

# Direct output (add emoji manually for consistency)
echo "❌ Error: Unknown option '$1'" >&2
```

### Return Codes
**Standard**:
- `0` = success
- `1` = general error
- `2` = misuse (wrong arguments)
- `>2` = specific error codes

```bash
validate_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    if [[ ! -r "$file" ]]; then
        log_error "File not readable: $file"
        return 2
    fi

    return 0
}
```

### Exit vs Return
```bash
# In functions: use return
function_name() {
    if [[ error_condition ]]; then
        log_error "Error occurred"
        return 1
    fi
}

# In main script or critical errors: use exit
if [[ ! -d "$MODULES_DIR" ]]; then
    log_error "Modules directory not found"
    exit 1
fi
```

---

## Documentation Standards

### Function Documentation Header

```bash
##############################################################################
# FUNCTION: function_name
# PURPOSE:  Brief one-line description of what the function does
# USAGE:    function_name arg1 arg2
# ARGS:
#   $1 - arg_name: Description of first argument
#   $2 - arg_name: Description of second argument (optional)
# RETURNS:
#   0 - Success with description
#   1 - Error condition description
# GLOBALS:
#   READ:  VAR1, VAR2 (variables read by function)
#   WRITE: VAR3 (variables modified by function)
# EXAMPLE:
#   result=$(function_name "input" "output")
#   if function_name "$file"; then
#       echo "Success"
#   fi
##############################################################################
function_name() {
    ...
}
```

### Module Documentation Header

```bash
#!/bin/bash
##############################################################################
# ZZCOLLAB MODULE_NAME MODULE - BRIEF DESCRIPTION
##############################################################################
#
# PURPOSE: Detailed description of module purpose and functionality
#          - Key feature 1
#          - Key feature 2
#          - Key feature 3
#
# DEPENDENCIES: List required modules (e.g., core.sh, templates.sh)
#
# FUNCTIONS:
#          - function1() - Brief description
#          - function2() - Brief description
#
# GLOBALS:
#          - GLOBAL_VAR1 - Description
#          - GLOBAL_VAR2 - Description
##############################################################################

# Module dependency validation
require_module "core" "templates"

# ... module code ...

# Set module loaded flag
readonly ZZCOLLAB_MODULENAME_LOADED=true
```

### Inline Comments

```bash
# Good: Explain WHY, not WHAT
# Calculate checksum to verify file integrity before processing
sha256sum "$file" > "$checksumfile"

# Bad: Stating the obvious
# Run sha256sum command
sha256sum "$file" > "$checksumfile"
```

---

## Module Structure

### Standard Module Template

```bash
#!/bin/bash
##############################################################################
# ZZCOLLAB MODULE_NAME - DESCRIPTION
##############################################################################

# Dependency validation
require_module "core"

#=============================================================================
# CONSTANTS
#=============================================================================

readonly MODULE_CONSTANT="value"

#=============================================================================
# HELPER FUNCTIONS (Private)
#=============================================================================

_private_helper() {
    ...
}

#=============================================================================
# PUBLIC FUNCTIONS
#=============================================================================

public_function() {
    ##############################################################################
    # FUNCTION: public_function
    # ... documentation ...
    ##############################################################################

    ...
}

#=============================================================================
# MODULE VALIDATION
#=============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "❌ Error: module_name.sh should be sourced, not executed" >&2
    exit 1
fi

readonly ZZCOLLAB_MODULENAME_LOADED=true
```

### Module Loading Order

1. **Core modules first**: constants.sh → core.sh
2. **Configuration**: config.sh, cli.sh
3. **Utilities**: templates.sh, utils.sh
4. **Feature modules**: structure.sh, docker.sh, etc.
5. **Validation last**: profile_validation.sh

---

## Code Style

### Bash Strict Mode
Always use at start of executable scripts:

```bash
#!/bin/bash
set -euo pipefail

# -e: exit on error
# -u: exit on undefined variable
# -o pipefail: exit if any pipe command fails
```

### Quoting
**Always quote variables** to prevent word splitting:

```bash
# DO
if [[ -f "$file" ]]; then
    cp "$source" "$destination"
fi

# DON'T
if [[ -f $file ]]; then      # ❌ Breaks with spaces
    cp $source $destination  # ❌ Breaks with spaces
fi
```

### Command Substitution
Use `$(...)` not backticks:

```bash
# DO
result=$(command arg1 arg2)
pkg_name=$(basename "$(pwd)")

# DON'T
result=`command arg1 arg2`  # ❌ Old style, harder to nest
```

### Conditionals
Use `[[...]]` for bash conditionals:

```bash
# DO
if [[ "$var" == "value" ]]; then
    ...
fi

# DON'T
if [ "$var" = "value" ]; then  # Works but less features
    ...
fi

if test "$var" = "value"; then  # Too verbose
    ...
fi
```

### Arrays
```bash
# Declaration
local files=()
local modules=("core" "templates" "utils")

# Iteration
for file in "${files[@]}"; do
    echo "$file"
done

# Length
echo "${#files[@]}"

# Adding elements
files+=("newfile")
```

---

## Testing Standards

### Unit Test Structure
```bash
# tests/shell/test-function.bats

@test "function_name handles valid input" {
    result=$(function_name "valid-input")
    [ "$result" = "expected-output" ]
}

@test "function_name fails on invalid input" {
    run function_name "invalid-input"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error" ]]
}
```

### Validation Checks
```bash
# Validate function exists
if ! command -v function_name >/dev/null; then
    log_error "Required function not found"
    exit 1
fi

# Validate module loaded
if [[ "${ZZCOLLAB_MODULE_LOADED:-}" != "true" ]]; then
    log_error "Required module not loaded"
    exit 1
fi
```

---

## Performance Guidelines

### Avoid Unnecessary Subshells
```bash
# DO
while IFS= read -r line; do
    process "$line"
done < "$file"

# DON'T
cat "$file" | while read line; do  # Extra process
    process "$line"
done
```

### Cache Command Results
```bash
# DO
if [[ "${JQ_AVAILABLE:-}" != "true" ]]; then
    readonly JQ_AVAILABLE=$(command -v jq >/dev/null && echo "true" || echo "false")
fi

# DON'T
if command -v jq >/dev/null; then  # Runs every time
    ...
fi
```

### Use Built-ins Over External Commands
```bash
# DO
if [[ -f "$file" ]]; then  # Bash built-in

# DON'T
if test -f "$file"; then  # External command (slower)
```

---

## Security Considerations

### Input Validation
```bash
# Validate before using
validate_package_name() {
    local name="$1"

    if [[ ! "$name" =~ ^[a-zA-Z][a-zA-Z0-9.]*$ ]]; then
        log_error "Invalid package name: $name"
        return 1
    fi
}
```

### Temporary Files
```bash
# DO
local temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT

# Work with temp file
...

# Cleanup handled by trap

# DON'T
local temp_file="/tmp/myfile.$$"  # Predictable, insecure
```

### Path Safety
```bash
# DO
cd "$(dirname "$file")" || exit 1  # Check cd success
rm -f "$specific_file"             # Explicit target

# DON'T
cd $(dirname $file)  # No error check, no quotes
rm -rf *             # Dangerous, avoid wildcards with rm -rf
```

---

## Enforcement

### Pre-commit Checks
- Shellcheck for syntax and best practices
- Function size limits (150 lines max)
- Documentation header presence
- Module dependency validation

### CI/CD Validation
- All tests must pass
- No shellcheck warnings
- Naming conventions verified
- Documentation complete

---

**Last Updated**: October 2025
**Version**: 1.0
