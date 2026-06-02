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
# TEST: find_cached_image (set -e safety on a cache miss)
##############################################################################

# Regression: a cache MISS must return 0, not 1. When it returned 1, the
# caller `cached_image=$(find_cached_image ...)` tripped set -e and aborted the
# build silently before it started (every first build of a project). docker is
# mocked so these tests do not depend on the host daemon or its image cache.

test_find_cached_image_miss_returns_success() {
  docker() { return 0; }  # `docker images ... | head -1` prints nothing
  local out rc
  out=$(find_cached_image "deadbeef") && rc=0 || rc=$?
  unset -f docker
  assert_equals "0" "$rc" \
    "cache miss must return 0 so the caller's set -e does not abort the build"
  if [[ -n "$out" ]]; then
    echo "FAIL: cache miss should produce empty output, got: $out" >&2
    return 1
  fi
}

test_find_cached_image_hit_echoes_id() {
  docker() { echo "sha256:abc123"; }
  local out rc
  out=$(find_cached_image "deadbeef") && rc=0 || rc=$?
  unset -f docker
  assert_equals "0" "$rc" "cache hit must return 0"
  assert_equals "sha256:abc123" "$out" "cache hit must echo the image id"
}

test_find_cached_image_empty_hash_returns_failure() {
  local rc
  find_cached_image "" && rc=0 || rc=$?
  assert_equals "1" "$rc" \
    "empty hash is an invalid lookup and must return 1"
}

##############################################################################
# TEST: Dockerfile generation determinism (T-2)
##############################################################################

# Identical inputs must produce a byte-identical Dockerfile.
test_dockerfile_generation_is_deterministic() {
  setup_test
  cd "$TEST_TEMP_DIR"
  cat > renv.lock << 'EOF'
{
  "R": {"Version": "4.4.0", "Repositories": [{"Name": "CRAN", "URL": "https://cloud.r-project.org"}]},
  "Packages": {}
}
EOF
  PPM_SNAPSHOT=2026-01-01 generate_dockerfile_inline \
    "rocker/tidyverse" "4.4.0" "" "" "" > /dev/null 2>&1
  cp Dockerfile Dockerfile.first
  rm -f Dockerfile
  PPM_SNAPSHOT=2026-01-01 generate_dockerfile_inline \
    "rocker/tidyverse" "4.4.0" "" "" "" > /dev/null 2>&1
  if ! diff -q Dockerfile Dockerfile.first > /dev/null 2>&1; then
    echo "FAIL: Identical inputs produced different Dockerfiles" >&2
    diff Dockerfile Dockerfile.first >&2 || true
    teardown_test
    return 1
  fi
  teardown_test
}

# Hash stability: compute_dockerfile_hash must be stable WITH renv.lock present
# (the original test used an empty directory, exercising only the fallback).
test_compute_dockerfile_hash_stable_with_renv_lock() {
  setup_test
  cd "$TEST_TEMP_DIR"
  cat > Dockerfile << 'EOF'
FROM rocker/tidyverse:4.4.0
EOF
  cat > renv.lock << 'EOF'
{"R": {"Version": "4.4.0"}, "Packages": {}}
EOF
  local h1 h2
  h1=$(compute_dockerfile_hash)
  h2=$(compute_dockerfile_hash)
  assert_equals "$h1" "$h2" \
    "Hash must be stable across repeated calls with renv.lock present"
  teardown_test
}

# Mutating renv.lock must change the hash so stale cache entries are evicted.
test_compute_dockerfile_hash_changes_with_renv_lock_mutation() {
  setup_test
  cd "$TEST_TEMP_DIR"
  cat > Dockerfile << 'EOF'
FROM rocker/tidyverse:4.4.0
EOF
  cat > renv.lock << 'EOF'
{"R": {"Version": "4.4.0"}, "Packages": {}}
EOF
  local h1
  h1=$(compute_dockerfile_hash)
  # Mutate lockfile
  cat > renv.lock << 'EOF'
{"R": {"Version": "4.4.1"}, "Packages": {}}
EOF
  local h2
  h2=$(compute_dockerfile_hash)
  if [[ "$h1" == "$h2" ]]; then
    echo "FAIL: Hash did not change after renv.lock mutation" >&2
    teardown_test
    return 1
  fi
  teardown_test
}

##############################################################################
# RUN ALL TESTS
##############################################################################

run_test_suite
