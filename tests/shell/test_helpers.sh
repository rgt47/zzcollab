#!/bin/bash
##############################################################################
# ZZCOLLAB SHELL TEST HELPERS
##############################################################################
# Provides utilities for shell-based unit testing of zzcollab modules.
#
# USAGE: source test_helpers.sh
#
# FEATURES:
#   - Module loading with proper path setup
#   - Test assertion functions
#   - Temporary directory management
#   - Output capture utilities
##############################################################################

set -euo pipefail

# Resolve test directory (where this file lives)
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZZCOLLAB_ROOT="${TEST_DIR}/../.."

# Export paths for modules
export ZZCOLLAB_HOME="$ZZCOLLAB_ROOT"
export ZZCOLLAB_LIB_DIR="$ZZCOLLAB_ROOT/lib"
export ZZCOLLAB_MODULES_DIR="$ZZCOLLAB_ROOT/modules"

# Temp directory for test artifacts
TEST_TEMP_DIR=""

##############################################################################
# FUNCTION: setup_test
# PURPOSE:  Initialize test environment
##############################################################################
setup_test() {
    TEST_TEMP_DIR=$(mktemp -d)
    cd "$TEST_TEMP_DIR"
    export VERBOSITY_LEVEL=0
}

##############################################################################
# FUNCTION: teardown_test
# PURPOSE:  Clean up test environment
##############################################################################
teardown_test() {
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    cd "$TEST_DIR"
}

##############################################################################
# FUNCTION: load_module_for_testing
# PURPOSE:  Load a zzcollab module with proper path setup
# ARGS:     $1 - module name (e.g., "core.sh", "cli.sh")
##############################################################################
load_module_for_testing() {
    local module_name="$1"
    local module_path
    local module_base
    local loaded_var

    module_base="${module_name%.sh}"
    local module_base_upper
    module_base_upper=$(echo "$module_base" | tr '[:lower:]' '[:upper:]')
    loaded_var="ZZCOLLAB_${module_base_upper}_LOADED"

    # Skip if module already loaded (readonly variables would cause errors)
    if [[ "${!loaded_var:-}" == "true" ]]; then
        return 0
    fi

    # Determine module location (lib/ vs modules/)
    if [[ "$module_name" == "core.sh" ]] || \
       [[ "$module_name" == "constants.sh" ]] || \
       [[ "$module_name" == "templates.sh" ]]; then
        module_path="${ZZCOLLAB_LIB_DIR}/${module_name}"
    else
        module_path="${ZZCOLLAB_MODULES_DIR}/${module_name}"
    fi

    if [[ ! -f "$module_path" ]]; then
        echo "ERROR: Module not found: $module_path" >&2
        return 1
    fi

    # shellcheck source=/dev/null
    source "$module_path"
}

##############################################################################
# ASSERTION FUNCTIONS
##############################################################################

assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"

    if [[ "$expected" != "$actual" ]]; then
        echo "FAIL: Expected '$expected', got '$actual'" >&2
        [[ -n "$msg" ]] && echo "  $msg" >&2
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local msg="${2:-Value should not be empty}"

    if [[ -z "$value" ]]; then
        echo "FAIL: $msg" >&2
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local msg="${2:-Condition should be true}"

    if ! eval "$condition"; then
        echo "FAIL: $msg" >&2
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local msg="${2:-Condition should be false}"

    if eval "$condition"; then
        echo "FAIL: $msg" >&2
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local msg="${2:-File should exist: $file}"

    if [[ ! -f "$file" ]]; then
        echo "FAIL: $msg" >&2
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local msg="${2:-Directory should exist: $dir}"

    if [[ ! -d "$dir" ]]; then
        echo "FAIL: $msg" >&2
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-Exit code mismatch}"

    if [[ "$expected" != "$actual" ]]; then
        echo "FAIL: Expected exit code $expected, got $actual" >&2
        [[ -n "$msg" ]] && echo "  $msg" >&2
        return 1
    fi
}

assert_output_contains() {
    local output="$1"
    local pattern="$2"
    local msg="${3:-Output should contain pattern}"

    if [[ ! "$output" =~ $pattern ]]; then
        echo "FAIL: $msg" >&2
        echo "  Pattern: $pattern" >&2
        echo "  Output: $output" >&2
        return 1
    fi
}

##############################################################################
# TEST RUNNER UTILITIES
##############################################################################

# Run test in subshell to isolate exit calls
run_test() {
    local test_func="$1"
    ( $test_func ) 2>&1
}

# Print test result
print_result() {
    local test_name="$1"
    local status="$2"

    if [[ "$status" -eq 0 ]]; then
        echo "  PASS: $test_name"
    else
        echo "  FAIL: $test_name"
    fi
}
