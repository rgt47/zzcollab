#!/bin/bash
################################################################################
# Shell Test Runner
#
# Runs all shell unit tests and reports results
# Usage: ./run_all_tests.sh [--verbose] [--stop-on-fail]
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR"

# Parse options
VERBOSE=false
STOP_ON_FAIL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose)
            VERBOSE=true
            ;;
        --stop-on-fail)
            STOP_ON_FAIL=true
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

################################################################################
# Test execution
################################################################################

total_pass=0
total_fail=0
failed_tests=()

run_test_file() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)

    if [[ ! -f "$test_file" ]]; then
        echo "⚠️  Test file not found: $test_file"
        return 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        echo "Running: $test_name"
        echo "=========================================="
    fi

    # Run test file and capture output
    output=""
    exit_code=0
    if ! output=$(bash "$test_file" 2>&1); then
        exit_code=$?
    fi

    # Parse results from output
    if [[ "$output" =~ Results:\ ([0-9]+)\ passed,\ ([0-9]+)\ failed ]]; then
        pass="${BASH_REMATCH[1]}"
        fail="${BASH_REMATCH[2]}"

        total_pass=$((total_pass + pass))
        total_fail=$((total_fail + fail))

        if [[ $fail -gt 0 ]]; then
            failed_tests+=("$test_name")
            if [[ "$VERBOSE" == "true" ]]; then
                echo "$output"
            fi
            if [[ "$STOP_ON_FAIL" == "true" ]]; then
                return 1
            fi
        elif [[ "$VERBOSE" == "true" ]]; then
            echo "$output"
        fi
    fi

    return 0
}

################################################################################
# Main execution
################################################################################

echo "=========================================="
echo "Shell Unit Test Runner"
echo "=========================================="
echo ""

# Find and run all test files
test_files=(
    "$TEST_DIR/test-core.sh"
    "$TEST_DIR/test-validation.sh"
    "$TEST_DIR/test-cli.sh"
)

for test_file in "${test_files[@]}"; do
    if [[ -f "$test_file" ]]; then
        run_test_file "$test_file" || {
            if [[ "$STOP_ON_FAIL" == "true" ]]; then
                echo "❌ Stopping due to test failure"
                exit 1
            fi
        }
    fi
done

################################################################################
# Summary
################################################################################

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total Passed: $total_pass"
echo "Total Failed: $total_fail"

if [[ ${#failed_tests[@]} -gt 0 ]]; then
    echo ""
    echo "Failed Test Suites:"
    for failed_test in "${failed_tests[@]}"; do
        echo "  ❌ $failed_test"
    done
fi

echo "=========================================="
echo ""

# Exit with appropriate code
if [[ $total_fail -eq 0 ]]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi
