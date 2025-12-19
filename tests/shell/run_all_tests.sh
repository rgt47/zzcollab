#!/bin/bash
##############################################################################
# ZZCOLLAB SHELL TEST RUNNER
##############################################################################
# Runs all shell-based unit tests for zzcollab modules.
#
# USAGE: ./run_all_tests.sh [options]
#
# OPTIONS:
#   -v, --verbose    Show verbose output
#   -h, --help       Show this help message
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE=false

##############################################################################
# Parse arguments
##############################################################################
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show verbose output"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

##############################################################################
# Run tests
##############################################################################

echo "=============================================="
echo "ZZCOLLAB SHELL TEST SUITE"
echo "=============================================="
echo ""

total_pass=0
total_fail=0
failed_suites=()

# Find all test files
test_files=("$SCRIPT_DIR"/test-*.sh)

if [[ ${#test_files[@]} -eq 0 ]]; then
    echo "No test files found in $SCRIPT_DIR"
    exit 1
fi

for test_file in "${test_files[@]}"; do
    if [[ ! -f "$test_file" ]]; then
        continue
    fi

    test_name=$(basename "$test_file" .sh)
    echo "Running: $test_name"

    if $VERBOSE; then
        if bash "$test_file"; then
            echo ""
        else
            failed_suites+=("$test_name")
            echo ""
        fi
    else
        output=$(bash "$test_file" 2>&1)
        exit_code=$?

        # Extract results line
        results=$(echo "$output" | grep "^Results:" || true)
        if [[ -n "$results" ]]; then
            pass=$(echo "$results" | sed -E 's/.*([0-9]+) passed.*/\1/')
            fail=$(echo "$results" | sed -E 's/.*([0-9]+) failed.*/\1/')
            total_pass=$((total_pass + pass))
            total_fail=$((total_fail + fail))
            echo "  $results"
        fi

        if [[ $exit_code -ne 0 ]]; then
            failed_suites+=("$test_name")
            if [[ "$VERBOSE" != "true" ]]; then
                # Show failures in non-verbose mode
                echo "$output" | grep "FAIL:" || true
            fi
        fi
    fi
done

echo ""
echo "=============================================="
echo "SUMMARY"
echo "=============================================="
echo "Total: $total_pass passed, $total_fail failed"

if [[ ${#failed_suites[@]} -gt 0 ]]; then
    echo ""
    echo "Failed test suites:"
    for suite in "${failed_suites[@]}"; do
        echo "  - $suite"
    done
    echo ""
    exit 1
else
    echo ""
    echo "All tests passed!"
    exit 0
fi
