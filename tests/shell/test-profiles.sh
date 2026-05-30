#!/bin/bash
##############################################################################
# ZZCOLLAB PROFILES MODULE TESTS
##############################################################################
# Tests for modules/profiles.sh - system dependency mapping and profiles
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

load_module_for_testing "core.sh"
load_module_for_testing "profiles.sh"

##############################################################################
# TEST: get_package_build_deps
##############################################################################

test_build_deps_sf() {
  local result
  result=$(get_package_build_deps "sf")
  assert_output_contains "$result" "libgdal-dev" \
    "sf should require libgdal-dev"
}

test_build_deps_xml2() {
  local result
  result=$(get_package_build_deps "xml2")
  assert_output_contains "$result" "libxml2-dev" \
    "xml2 should require libxml2-dev"
}

test_build_deps_curl() {
  local result
  result=$(get_package_build_deps "curl")
  assert_output_contains "$result" "libcurl4-openssl-dev" \
    "curl should require libcurl4-openssl-dev"
}

test_build_deps_openssl() {
  local result
  result=$(get_package_build_deps "openssl")
  assert_output_contains "$result" "libssl-dev" \
    "openssl should require libssl-dev"
}

test_build_deps_unknown_package() {
  local result
  result=$(get_package_build_deps "nonexistent_pkg_xyz")
  if [[ -n "$result" ]]; then
    echo "FAIL: Unknown package should have no deps, got: $result" >&2
    return 1
  fi
}

##############################################################################
# TEST: get_profile_base_image
##############################################################################

test_profile_base_image_fallback() {
  ZZCOLLAB_TEMPLATES_DIR="/nonexistent"
  local result
  result=$(get_profile_base_image "analysis" 2>/dev/null)
  assert_equals "rocker/r-ver" "$result" \
    "Should fall back to rocker/r-ver when bundles.yaml not found"
  unset ZZCOLLAB_TEMPLATES_DIR
}

##############################################################################
# TEST: profile lookup with real bundles.yaml
##############################################################################

test_profile_base_image_from_bundles() {
  local bundles="${ZZCOLLAB_HOME}/templates/bundles.yaml"
  if [[ ! -f "$bundles" ]]; then
    echo "SKIP: bundles.yaml not found" >&2
    return 0
  fi
  export ZZCOLLAB_TEMPLATES_DIR="${ZZCOLLAB_HOME}/templates"
  local result
  result=$(get_profile_base_image "minimal" 2>/dev/null)
  assert_not_empty "$result" \
    "minimal profile should have a base image"
}

test_profile_analysis_has_tidyverse() {
  local bundles="${ZZCOLLAB_HOME}/templates/bundles.yaml"
  if [[ ! -f "$bundles" ]]; then
    echo "SKIP: bundles.yaml not found" >&2
    return 0
  fi
  export ZZCOLLAB_TEMPLATES_DIR="${ZZCOLLAB_HOME}/templates"
  local result
  result=$(get_profile_base_image "analysis" 2>/dev/null)
  assert_output_contains "$result" "tidyverse" \
    "analysis profile should use tidyverse base image"
}

##############################################################################
# RUN ALL TESTS
##############################################################################

TESTS_PASSED=0
TESTS_FAILED=0

for test_func in $(declare -F | awk '/test_/ {print $3}'); do
  output=$(run_test "$test_func" 2>&1) || true
  if echo "$output" | grep -q "^FAIL:"; then
    print_result "$test_func" 1
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "$output" | head -3
  elif echo "$output" | grep -q "^SKIP:"; then
    print_result "$test_func (SKIPPED)" 0
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    print_result "$test_func" 0
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
done

echo ""
echo "  Results: $TESTS_PASSED passed, $TESTS_FAILED failed"

[[ "$TESTS_FAILED" -eq 0 ]]
