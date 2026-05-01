#!/bin/bash
##############################################################################
# ZZCOLLAB DOCKER MODULE TESTS
##############################################################################
# Tests for modules/docker.sh - Docker containerization
# Tests pure functions that don't require Docker runtime.
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

load_module_for_testing "core.sh"
load_module_for_testing "docker.sh"

##############################################################################
# TEST: get_base_image_tools
##############################################################################

test_base_image_tools_rver_no_pandoc() {
  local result
  result=$(get_base_image_tools "rocker/r-ver:4.4.0")
  assert_equals "false" "$result" \
    "r-ver image should not have pandoc"
}

test_base_image_tools_tidyverse_has_pandoc() {
  local result
  result=$(get_base_image_tools "rocker/tidyverse:4.4.0")
  assert_equals "true" "$result" \
    "tidyverse image should have pandoc"
}

test_base_image_tools_verse_has_pandoc() {
  local result
  result=$(get_base_image_tools "rocker/verse:4.4.0")
  assert_equals "true" "$result" \
    "verse image should have pandoc"
}

test_base_image_tools_rstudio_has_pandoc() {
  local result
  result=$(get_base_image_tools "rocker/rstudio:4.4.0")
  assert_equals "true" "$result" \
    "rstudio image should have pandoc"
}

test_base_image_tools_shiny_has_pandoc() {
  local result
  result=$(get_base_image_tools "rocker/shiny:4.4.0")
  assert_equals "true" "$result" \
    "shiny image should have pandoc"
}

test_base_image_tools_custom_no_pandoc() {
  local result
  result=$(get_base_image_tools "myrepo/custom:latest")
  assert_equals "false" "$result" \
    "custom image should not have pandoc"
}

##############################################################################
# TEST: generate_tools_install
##############################################################################

test_tools_install_rver_includes_pandoc() {
  local result
  result=$(generate_tools_install "rocker/r-ver:4.4.0")
  assert_output_contains "$result" "pandoc" \
    "r-ver should include pandoc install"
}

test_tools_install_tidyverse_no_pandoc() {
  local result
  result=$(generate_tools_install "rocker/tidyverse:4.4.0")
  if echo "$result" | grep -q "Install pandoc"; then
    echo "FAIL: tidyverse should not install pandoc (already has it)" >&2
    return 1
  fi
}

test_tools_install_always_has_languageserver() {
  local result
  result=$(generate_tools_install "rocker/r-ver:4.4.0")
  assert_output_contains "$result" "languageserver" \
    "should always install languageserver"
}

test_tools_install_always_has_yaml() {
  local result
  result=$(generate_tools_install "rocker/r-ver:4.4.0")
  assert_output_contains "$result" "yaml" \
    "should always install yaml package"
}

test_tools_install_analysis_pdf_has_tinytex() {
  local result
  result=$(generate_tools_install "rocker/r-ver:4.4.0" "analysis_pdf")
  assert_output_contains "$result" "tinytex" \
    "analysis_pdf profile should install tinytex"
}

test_tools_install_analysis_no_tinytex() {
  local result
  result=$(generate_tools_install "rocker/r-ver:4.4.0" "analysis")
  if echo "$result" | grep -q "tinytex"; then
    echo "FAIL: analysis profile should not install tinytex" >&2
    return 1
  fi
}

##############################################################################
# TEST: extract_r_version (with mocked renv.lock)
##############################################################################

test_extract_r_version_from_renv_lock() {
  setup_test
  cat > "$TEST_TEMP_DIR/renv.lock" << 'EOF'
{
  "R": {
    "Version": "4.4.1",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "https://cran.rstudio.com"
      }
    ]
  }
}
EOF
  cd "$TEST_TEMP_DIR"
  local result
  result=$(extract_r_version 2>/dev/null)
  assert_equals "4.4.1" "$result" \
    "Should extract R version from renv.lock"
  teardown_test
}

test_extract_r_version_from_env_var() {
  setup_test
  export R_VERSION="4.3.2"
  local result
  result=$(extract_r_version 2>/dev/null)
  assert_equals "4.3.2" "$result" \
    "Should use R_VERSION env var when set"
  unset R_VERSION
  teardown_test
}

test_extract_r_version_no_renv_lock_fails() {
  setup_test
  cd "$TEST_TEMP_DIR"
  export ZZCOLLAB_ACCEPT_DEFAULTS=false
  if extract_r_version 2>/dev/null </dev/null; then
    echo "FAIL: Should fail when no renv.lock and no R_VERSION" >&2
    teardown_test
    return 1
  fi
  teardown_test
  return 0
}

##############################################################################
# TEST: compute_dockerfile_hash
##############################################################################

test_compute_dockerfile_hash_consistent() {
  setup_test
  cat > "$TEST_TEMP_DIR/Dockerfile" << 'EOF'
FROM rocker/r-ver:4.4.0
RUN echo "test"
EOF
  cd "$TEST_TEMP_DIR"
  local hash1 hash2
  hash1=$(compute_dockerfile_hash)
  hash2=$(compute_dockerfile_hash)
  assert_equals "$hash1" "$hash2" \
    "Same Dockerfile should produce same hash"
  teardown_test
}

test_compute_dockerfile_hash_changes() {
  setup_test
  cat > "$TEST_TEMP_DIR/Dockerfile" << 'EOF'
FROM rocker/r-ver:4.4.0
RUN echo "version1"
EOF
  cd "$TEST_TEMP_DIR"
  local hash1
  hash1=$(compute_dockerfile_hash)

  cat > "$TEST_TEMP_DIR/Dockerfile" << 'EOF'
FROM rocker/r-ver:4.4.0
RUN echo "version2"
EOF
  local hash2
  hash2=$(compute_dockerfile_hash)

  if [[ "$hash1" == "$hash2" ]]; then
    echo "FAIL: Different Dockerfiles should have different hashes" >&2
    teardown_test
    return 1
  fi
  teardown_test
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
