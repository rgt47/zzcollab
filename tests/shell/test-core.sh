#!/bin/bash
##############################################################################
# ZZCOLLAB CORE MODULE TESTS
##############################################################################
# Tests for lib/core.sh - foundation infrastructure
##############################################################################

set -euo pipefail

# Load test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

# Load core module
load_module_for_testing "core.sh"

##############################################################################
# TEST: validate_package_name
##############################################################################

test_validate_package_name_valid() {
    local result
    result=$(validate_package_name "mypackage")
    assert_equals "mypackage" "$result" "Should return valid package name"
}

test_validate_package_name_with_dots() {
    local result
    result=$(validate_package_name "my.package")
    assert_equals "my.package" "$result" "Should allow dots in package name"
}

test_validate_package_name_strips_invalid() {
    local result
    result=$(validate_package_name "my-package_123")
    assert_equals "mypackage123" "$result" "Should strip invalid characters"
}

test_validate_package_name_starts_with_letter() {
    local result
    if result=$(validate_package_name "123pkg" 2>/dev/null); then
        echo "FAIL: Should reject names starting with number" >&2
        return 1
    fi
    return 0
}

test_validate_package_name_empty() {
    if validate_package_name "---" 2>/dev/null; then
        echo "FAIL: Should reject names that become empty after sanitization" >&2
        return 1
    fi
    return 0
}

##############################################################################
# TEST: command_exists
##############################################################################

test_command_exists_bash() {
    if ! command_exists "bash"; then
        echo "FAIL: bash should exist" >&2
        return 1
    fi
}

test_command_exists_nonexistent() {
    if command_exists "nonexistent_command_xyz_12345"; then
        echo "FAIL: nonexistent command should not exist" >&2
        return 1
    fi
}

##############################################################################
# TEST: logging functions (with mocked verbosity)
##############################################################################

test_log_error_always_outputs() {
    export VERBOSITY_LEVEL=0
    local output
    output=$(log_error "Test error message" 2>&1)
    assert_output_contains "$output" "Test error message" "log_error should output at verbosity 0"
}

test_log_success_respects_verbosity() {
    export VERBOSITY_LEVEL=0
    local output
    output=$(log_success "Test success" 2>&1)
    if [[ -n "$output" ]]; then
        echo "FAIL: log_success should be silent at verbosity 0" >&2
        return 1
    fi
}

test_log_success_shows_at_level_1() {
    export VERBOSITY_LEVEL=1
    local output
    output=$(log_success "Test success" 2>&1)
    assert_output_contains "$output" "Test success" "log_success should output at verbosity 1"
}

test_log_info_respects_verbosity() {
    export VERBOSITY_LEVEL=1
    local output
    output=$(log_info "Test info" 2>&1)
    if [[ -n "$output" ]]; then
        echo "FAIL: log_info should be silent at verbosity 1" >&2
        return 1
    fi
}

test_log_info_shows_at_level_2() {
    export VERBOSITY_LEVEL=2
    local output
    output=$(log_info "Test info" 2>&1)
    assert_output_contains "$output" "Test info" "log_info should output at verbosity 2"
}

##############################################################################
# TEST: safe_mkdir
##############################################################################

test_safe_mkdir_creates_directory() {
    setup_test
    export VERBOSITY_LEVEL=0
    safe_mkdir "testdir" 2>/dev/null
    assert_dir_exists "testdir" "safe_mkdir should create directory"
    teardown_test
}

test_safe_mkdir_creates_nested() {
    setup_test
    export VERBOSITY_LEVEL=0
    safe_mkdir "a/b/c" 2>/dev/null
    assert_dir_exists "a/b/c" "safe_mkdir should create nested directories"
    teardown_test
}

##############################################################################
# TEST: require_module
##############################################################################

test_require_module_loads_module() {
    # Core already loaded, test that it doesn't error on reload
    require_module "core"
}

test_require_module_nonexistent() {
    local exit_code=0
    ( require_module "nonexistent_module_xyz" ) 2>/dev/null || exit_code=$?
    if [[ "$exit_code" -eq 0 ]]; then
        echo "FAIL: require_module should fail for nonexistent module" >&2
        return 1
    fi
}

##############################################################################
# RUN TESTS
##############################################################################

echo "=========================================="
echo "CORE MODULE TESTS"
echo "=========================================="

tests=(
    test_validate_package_name_valid
    test_validate_package_name_with_dots
    test_validate_package_name_strips_invalid
    test_validate_package_name_starts_with_letter
    test_validate_package_name_empty
    test_command_exists_bash
    test_command_exists_nonexistent
    test_log_error_always_outputs
    test_log_success_respects_verbosity
    test_log_success_shows_at_level_1
    test_log_info_respects_verbosity
    test_log_info_shows_at_level_2
    test_safe_mkdir_creates_directory
    test_safe_mkdir_creates_nested
    test_require_module_loads_module
    test_require_module_nonexistent
)

pass=0
fail=0

for test in "${tests[@]}"; do
    if ( $test ) 2>/dev/null; then
        echo "  PASS: $test"
        pass=$((pass + 1))
    else
        echo "  FAIL: $test"
        fail=$((fail + 1))
    fi
done

echo "------------------------------------------"
echo "Results: $pass passed, $fail failed"
echo "=========================================="

if [[ $fail -gt 0 ]]; then
    exit 1
fi
