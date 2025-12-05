#!/bin/bash
################################################################################
# Test Helper Functions for zzcollab Shell Tests
#
# Provides:
# - Test setup/teardown utilities
# - Temporary directory management
# - Logging capture utilities
# - Assertion helpers
# - Fixture data
################################################################################

set -euo pipefail

# Test configuration
export TEST_DIR="${TEST_DIR:-.}"
export FIXTURES_DIR="${TEST_DIR}/fixtures"
export TEMP_TEST_DIR=""

################################################################################
# Setup and Teardown
################################################################################

##############################################################################
# Function: setup_test
# Purpose: Initialize test environment
# Creates temporary directory for test files
##############################################################################
setup_test() {
    # Create temporary directory for test
    TEMP_TEST_DIR=$(mktemp -d) || {
        echo "❌ Failed to create temporary test directory" >&2
        exit 1
    }

    # Create fixtures directory if needed
    mkdir -p "$FIXTURES_DIR" 2>/dev/null || true

    export TEMP_TEST_DIR
}

##############################################################################
# Function: teardown_test
# Purpose: Clean up after test
# Removes temporary directory and files
##############################################################################
teardown_test() {
    if [[ -n "$TEMP_TEST_DIR" ]] && [[ -d "$TEMP_TEST_DIR" ]]; then
        rm -rf "$TEMP_TEST_DIR"
    fi
}

################################################################################
# Logging and Output Capture
################################################################################

##############################################################################
# Function: capture_output
# Purpose: Capture stdout from command
# Args: Command to execute
# Returns: Command exit code
# Globals: CAPTURED_OUTPUT
##############################################################################
capture_output() {
    CAPTURED_OUTPUT=$(
        set +e
        "$@" 2>&1
        set -e
    ) || return $?
}

##############################################################################
# Function: capture_stderr
# Purpose: Capture stderr from command
# Args: Command to execute
# Returns: Command exit code
# Globals: CAPTURED_STDERR
##############################################################################
capture_stderr() {
    CAPTURED_STDERR=$(
        set +e
        "$@" 2>&1 >/dev/null
        set -e
    ) || return $?
}

################################################################################
# Assertion Helpers
################################################################################

##############################################################################
# Function: assert_success
# Purpose: Assert command succeeds
# Args: Command to execute
##############################################################################
assert_success() {
    if ! "$@"; then
        echo "❌ FAILED: Expected command to succeed but got exit code: $?" >&2
        return 1
    fi
}

##############################################################################
# Function: assert_failure
# Purpose: Assert command fails
# Args: Command to execute
##############################################################################
assert_failure() {
    if "$@" 2>/dev/null; then
        echo "❌ FAILED: Expected command to fail but succeeded" >&2
        return 1
    fi
}

##############################################################################
# Function: assert_equals
# Purpose: Assert two strings are equal
# Args: $1 - expected, $2 - actual
##############################################################################
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [[ "$expected" != "$actual" ]]; then
        echo "❌ FAILED: $message" >&2
        echo "  Expected: '$expected'" >&2
        echo "  Got:      '$actual'" >&2
        return 1
    fi
}

##############################################################################
# Function: assert_contains
# Purpose: Assert string contains substring
# Args: $1 - haystack, $2 - needle
##############################################################################
assert_contains() {
    local haystack="$1"
    local needle="$2"

    if [[ ! "$haystack" =~ $needle ]]; then
        echo "❌ FAILED: Expected string to contain '$needle'" >&2
        echo "  Got: '$haystack'" >&2
        return 1
    fi
}

##############################################################################
# Function: assert_file_exists
# Purpose: Assert file exists
# Args: $1 - file path
##############################################################################
assert_file_exists() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "❌ FAILED: Expected file to exist: $file" >&2
        return 1
    fi
}

##############################################################################
# Function: assert_file_not_exists
# Purpose: Assert file does not exist
# Args: $1 - file path
##############################################################################
assert_file_not_exists() {
    local file="$1"

    if [[ -f "$file" ]]; then
        echo "❌ FAILED: Expected file not to exist: $file" >&2
        return 1
    fi
}

################################################################################
# Fixture Helpers
################################################################################

##############################################################################
# Function: create_test_description
# Purpose: Create a minimal DESCRIPTION file for testing
# Args: $1 - path, $2 - package name (optional)
##############################################################################
create_test_description() {
    local path="${1:-.}"
    local pkg_name="${2:-testpackage}"

    mkdir -p "$path"
    cat > "$path/DESCRIPTION" <<EOF
Package: $pkg_name
Version: 0.1.0
Title: Test Package
Description: A test package for unit testing
Authors@R: person("Test", "User")
License: MIT
Imports:
    base,
    utils
EOF
}

##############################################################################
# Function: create_test_r_file
# Purpose: Create a test R file with package usage
# Args: $1 - path, $2 - packages to import (space-separated)
##############################################################################
create_test_r_file() {
    local path="$1"
    local packages="${2:-}"

    mkdir -p "$(dirname "$path")"

    # Create R file with library calls
    {
        echo "# Test R file"
        for pkg in $packages; do
            echo "library($pkg)"
        done
    } > "$path"
}

##############################################################################
# Function: create_test_renv_lock
# Purpose: Create a minimal renv.lock file
# Args: $1 - path, $2 - packages (space-separated)
##############################################################################
create_test_renv_lock() {
    local path="${1:-.}"
    local packages="${2:-}"

    mkdir -p "$path"
    cat > "$path/renv.lock" <<'EOF'
{
  "R": {
    "Version": "4.3.1",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "https://cran.rstudio.com"
      }
    ]
  },
  "Packages": {}
}
EOF
}

################################################################################
# Logging Setup for Tests
################################################################################

##############################################################################
# Function: setup_test_logging
# Purpose: Initialize logging for tests
# Sets up log capture without interfering with test output
##############################################################################
setup_test_logging() {
    # Disable verbose logging for tests (reduces noise)
    export VERBOSITY_LEVEL=1  # Only errors
}

################################################################################
# Module Loading Helpers
################################################################################

##############################################################################
# Function: load_module_for_testing
# Purpose: Source a module for testing with minimal dependencies
# Args: $1 - module name (e.g., "core.sh", "validation.sh")
##############################################################################
load_module_for_testing() {
    local module_name="$1"
    local module_path="${TEST_DIR}/../../modules/${module_name}"

    if [[ ! -f "$module_path" ]]; then
        echo "❌ Module not found: $module_path" >&2
        return 1
    fi

    # Set up minimal environment
    export SCRIPT_DIR="${TEST_DIR}/../../"
    export MODULES_DIR="${TEST_DIR}/../../modules"
    export TEMPLATES_DIR="${TEST_DIR}/../../templates"
    export LOG_FILE=""

    # Source required dependencies in order
    # (most modules require core.sh)
    if [[ "$module_name" != "core.sh" ]] && [[ "$module_name" != "constants.sh" ]]; then
        # Source dependencies if not already loaded
        if ! type log_error &>/dev/null; then
            # shellcheck source=../modules/constants.sh
            source "${TEST_DIR}/../../modules/constants.sh" 2>/dev/null || true
            # shellcheck source=../modules/core.sh
            source "${TEST_DIR}/../../modules/core.sh" 2>/dev/null || true
        fi
    fi

    # Source the module
    # shellcheck source=/dev/null
    source "$module_path" || {
        echo "❌ Failed to load module: $module_name" >&2
        return 1
    }
}

################################################################################
# Export test functions
################################################################################

export -f setup_test
export -f teardown_test
export -f capture_output
export -f capture_stderr
export -f assert_success
export -f assert_failure
export -f assert_equals
export -f assert_contains
export -f assert_file_exists
export -f assert_file_not_exists
export -f create_test_description
export -f create_test_r_file
export -f create_test_renv_lock
export -f setup_test_logging
export -f load_module_for_testing
