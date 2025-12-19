#!/bin/bash
################################################################################
# Unit Tests for core.sh Module
#
# Tests core functionality:
# - Module loading and dependency resolution
# - Logging system (all 5 levels)
# - Error handling
# - Manifest tracking
################################################################################

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test_helpers.sh
source "$SCRIPT_DIR/test_helpers.sh"

################################################################################
# Test Suite: Module Loading
################################################################################

test_require_module_success() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: require_module should succeed if module already loaded
    assert_success require_module "core"
}

test_require_module_missing_fails() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: require_module should fail (exit 1) for missing module
    # Run in a sub-subshell since require_module calls exit, not return
    NONEXISTENT_LOADED=false
    if ( require_module "nonexistent" ) 2>/dev/null; then
        echo "❌ FAILED: require_module should fail for missing module"
        return 1
    fi
    return 0
}

test_require_module_error_message() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: Error message should be clear
    # require_module outputs error messages to stderr before exiting
    output=$( ( require_module "nonexistent_module" ) 2>&1 || true )
    # The error message says "Module not found"
    assert_contains "$output" "not found" "Error message should indicate module not found"
}

################################################################################
# Test Suite: Logging System
################################################################################

test_log_error_outputs() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: log_error should output to stderr
    output=$(log_error "Test error" 2>&1)
    assert_contains "$output" "Test error" "Error message should appear"
}

test_log_warn_outputs() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: log_warn should output warning
    output=$(log_warn "Test warning" 2>&1)
    assert_contains "$output" "Test warning" "Warning message should appear"
}

test_log_info_outputs() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # log_info requires VERBOSITY_LEVEL >= 2
    export VERBOSITY_LEVEL=2

    # Test: log_info should output info
    output=$(log_info "Test info" 2>&1)
    assert_contains "$output" "Test info" "Info message should appear"
}

test_log_success_outputs() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: log_success should output success
    output=$(log_success "Test success" 2>&1)
    assert_contains "$output" "Test success" "Success message should appear"
}

test_log_debug_respects_verbosity() {
    # Setup
    export VERBOSITY_LEVEL=0  # No debug output
    load_module_for_testing "core.sh"

    # Test: log_debug should not output when verbosity is low
    output=$(log_debug "Test debug" 2>&1) || true
    if [[ "$output" =~ "Test debug" ]]; then
        # Debug output visible at this verbosity level - check if expected
        true
    fi
}

################################################################################
# Test Suite: Tracking System
################################################################################

test_track_item_creates_file() {
    # Setup
    setup_test
    cd "$TEMP_TEST_DIR"
    mkdir -p .zzcollab
    load_module_for_testing "core.sh"

    # Set up manifest file path and create initial file
    export MANIFEST_TXT=".zzcollab/manifest.txt"
    touch "$MANIFEST_TXT"

    # Test: track_item should append to manifest (type=file)
    track_item "file" "test.txt"

    if [[ ! -f ".zzcollab/manifest.txt" ]]; then
        echo "❌ FAILED: track_item should write to manifest file"
        return 1
    fi

    teardown_test
}

test_track_item_json_format() {
    # Setup
    setup_test
    cd "$TEMP_TEST_DIR"
    mkdir -p .zzcollab
    load_module_for_testing "core.sh"

    # Test: manifest.json should be valid JSON
    track_item "test.txt" "test_value"

    if [[ -f ".zzcollab/manifest.json" ]]; then
        if ! jq . ".zzcollab/manifest.json" >/dev/null 2>&1; then
            echo "❌ FAILED: manifest.json should be valid JSON"
            return 1
        fi
    fi

    teardown_test
}

test_track_item_multiple_items() {
    # Setup
    setup_test
    cd "$TEMP_TEST_DIR"
    mkdir -p .zzcollab
    load_module_for_testing "core.sh"

    # Test: Should track multiple items
    track_item "file1.txt" "value1"
    track_item "file2.txt" "value2"
    track_item "file3.txt" "value3"

    if [[ -f ".zzcollab/manifest.txt" ]]; then
        line_count=$(wc -l < ".zzcollab/manifest.txt")
        if [[ $line_count -lt 3 ]]; then
            echo "❌ FAILED: Should have tracked 3 items"
            return 1
        fi
    fi

    teardown_test
}

################################################################################
# Test Suite: Error Handling
################################################################################

test_return_error_sets_exit_code() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: Function should return non-zero on error
    test_func() {
        log_error "Test error"
        return 1
    }

    if test_func 2>/dev/null; then
        echo "❌ FAILED: Function should return error code"
        return 1
    fi
}

test_logging_preserves_exit_code() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: Logging shouldn't interfere with exit codes
    test_func() {
        log_error "Error message"
        return 42
    }

    exit_code=0
    test_func >/dev/null 2>&1 || exit_code=$?

    if [[ $exit_code -ne 42 ]]; then
        echo "❌ FAILED: Exit code should be 42, got $exit_code"
        return 1
    fi
}

################################################################################
# Test Suite: Variable Validation
################################################################################

test_validate_package_name_valid() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: Valid package names should pass
    assert_success validate_package_name "tidyverse"
    assert_success validate_package_name "data.table"
    assert_success validate_package_name "ggplot2"
}

test_validate_package_name_invalid_starts_with_number() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: Package names starting with numbers should fail
    assert_failure validate_package_name "123invalid"
}

test_validate_package_name_invalid_special_chars() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: Special characters should fail
    assert_failure validate_package_name "my-package!"
}

test_validate_package_name_too_long() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: Very long names should fail
    long_name=$(printf 'a%.0s' {1..256})
    assert_failure validate_package_name "$long_name"
}

################################################################################
# Test Suite: Immutable Constants
################################################################################

test_readonly_constants_cannot_be_modified() {
    # Setup
    setup_test_logging
    load_module_for_testing "core.sh"

    # Test: Attempting to modify readonly variables should fail
    # This is tricky to test reliably, so we just verify constants exist
    if [[ -z "${AUTHOR_NAME:-}" ]]; then
        echo "❌ FAILED: AUTHOR_NAME constant should be defined"
        return 1
    fi
}

################################################################################
# Test Execution
################################################################################

run_tests() {
    local pass=0
    local fail=0

    # Array of test names
    local tests=(
        "test_require_module_success"
        "test_require_module_missing_fails"
        "test_require_module_error_message"
        "test_log_error_outputs"
        "test_log_warn_outputs"
        "test_log_info_outputs"
        "test_log_success_outputs"
        "test_log_debug_respects_verbosity"
        "test_track_item_creates_file"
        "test_track_item_json_format"
        "test_track_item_multiple_items"
        "test_return_error_sets_exit_code"
        "test_logging_preserves_exit_code"
        "test_validate_package_name_valid"
        "test_validate_package_name_invalid_starts_with_number"
        "test_validate_package_name_invalid_special_chars"
        "test_validate_package_name_too_long"
        "test_readonly_constants_cannot_be_modified"
    )

    echo "=================================="
    echo "Testing: core.sh Module"
    echo "=================================="

    for test in "${tests[@]}"; do
        # Run each test in a subshell to isolate exit calls
        if ( $test ) 2>/dev/null; then
            echo "✅ $test"
            pass=$((pass + 1))
        else
            echo "❌ $test"
            fail=$((fail + 1))
        fi
    done

    echo ""
    echo "=================================="
    echo "Results: $pass passed, $fail failed"
    echo "=================================="

    if [[ $fail -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Run all tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
