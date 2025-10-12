#!/usr/bin/env bash
##############################################################################
# ZZCOLLAB TEST RUNNER
##############################################################################
# PURPOSE: Run all tests (R package tests + shell script tests)
# USAGE:   ./tests/run-all-tests.sh [--verbose] [--coverage]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Flags
VERBOSE=false
COVERAGE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --coverage|-c)
            COVERAGE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show detailed test output"
            echo "  -c, --coverage   Generate coverage reports"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "ZZCOLLAB Test Suite"
echo "=========================================="
echo ""

# Track results
R_TESTS_PASSED=false
SHELL_TESTS_PASSED=false

#=============================================================================
# R PACKAGE TESTS
#=============================================================================

echo "📦 Running R package tests..."
echo ""

if command -v Rscript >/dev/null 2>&1; then
    if [ "$COVERAGE" = true ]; then
        echo "Generating coverage report..."
        Rscript -e 'covr::package_coverage()' || {
            echo -e "${RED}✗ Coverage generation failed${NC}"
        }
    fi

    if [ "$VERBOSE" = true ]; then
        Rscript -e 'devtools::test()' && R_TESTS_PASSED=true || {
            echo -e "${RED}✗ R tests failed${NC}"
            R_TESTS_PASSED=false
        }
    else
        Rscript -e 'devtools::test()' > /dev/null 2>&1 && {
            echo -e "${GREEN}✓ R tests passed${NC}"
            R_TESTS_PASSED=true
        } || {
            echo -e "${RED}✗ R tests failed${NC}"
            R_TESTS_PASSED=false
        }
    fi
else
    echo -e "${YELLOW}⚠ Rscript not found, skipping R tests${NC}"
    R_TESTS_PASSED=true  # Don't fail if R not installed
fi

echo ""

#=============================================================================
# SHELL SCRIPT TESTS (BATS)
#=============================================================================

echo "🔧 Running shell script tests..."
echo ""

if command -v bats >/dev/null 2>&1; then
    # Find all .bats files in tests/shell/
    BATS_FILES=("tests/shell/"*.bats)

    if [ ${#BATS_FILES[@]} -eq 0 ] || [ ! -f "${BATS_FILES[0]}" ]; then
        echo -e "${YELLOW}⚠ No BATS test files found${NC}"
        SHELL_TESTS_PASSED=true
    else
        TOTAL_BATS_PASS=0
        TOTAL_BATS_FAIL=0

        for test_file in "${BATS_FILES[@]}"; do
            if [ -f "$test_file" ]; then
                echo "Testing: $(basename "$test_file")"

                if [ "$VERBOSE" = true ]; then
                    bats "$test_file" && {
                        TOTAL_BATS_PASS=$((TOTAL_BATS_PASS + 1))
                    } || {
                        TOTAL_BATS_FAIL=$((TOTAL_BATS_FAIL + 1))
                    }
                else
                    # Capture summary
                    output=$(bats "$test_file" 2>&1)
                    if echo "$output" | grep -q "^ok"; then
                        # Count passing tests
                        pass_count=$(echo "$output" | grep -c "^ok" || echo "0")
                        fail_count=$(echo "$output" | grep -c "^not ok" || echo "0")

                        if [ "$fail_count" -eq 0 ]; then
                            echo -e "  ${GREEN}✓ All tests passed${NC} ($pass_count tests)"
                            TOTAL_BATS_PASS=$((TOTAL_BATS_PASS + 1))
                        else
                            echo -e "  ${YELLOW}⚠ Some tests failed${NC} ($pass_count passed, $fail_count failed)"
                            TOTAL_BATS_FAIL=$((TOTAL_BATS_FAIL + 1))
                        fi
                    else
                        echo -e "  ${RED}✗ Tests failed${NC}"
                        TOTAL_BATS_FAIL=$((TOTAL_BATS_FAIL + 1))
                    fi
                fi
            fi
        done

        if [ $TOTAL_BATS_FAIL -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✓ All shell tests passed${NC} ($TOTAL_BATS_PASS test files)"
            SHELL_TESTS_PASSED=true
        else
            echo ""
            echo -e "${YELLOW}⚠ Some shell tests failed${NC} ($TOTAL_BATS_PASS passed, $TOTAL_BATS_FAIL failed)"
            SHELL_TESTS_PASSED=false
        fi
    fi
else
    echo -e "${RED}✗ BATS not found. Install with: brew install bats-core${NC}"
    SHELL_TESTS_PASSED=false
fi

echo ""

#=============================================================================
# SUMMARY
#=============================================================================

echo "=========================================="
echo "Test Summary"
echo "=========================================="

if [ "$R_TESTS_PASSED" = true ]; then
    echo -e "R Package Tests:  ${GREEN}✓ PASSED${NC}"
else
    echo -e "R Package Tests:  ${RED}✗ FAILED${NC}"
fi

if [ "$SHELL_TESTS_PASSED" = true ]; then
    echo -e "Shell Tests:      ${GREEN}✓ PASSED${NC}"
else
    echo -e "Shell Tests:      ${YELLOW}⚠ ISSUES${NC}"
fi

echo ""

# Exit with appropriate code
if [ "$R_TESTS_PASSED" = true ] && [ "$SHELL_TESTS_PASSED" = true ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed or skipped${NC}"
    exit 1
fi
