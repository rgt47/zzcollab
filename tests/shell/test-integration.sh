#!/bin/bash
##############################################################################
# ZZCOLLAB INTEGRATION TESTS
##############################################################################
# End-to-end tests for project creation workflows.
# Tests run without Docker to validate scaffolding output.
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

ZZCOLLAB_SH="$ZZCOLLAB_ROOT/zzcollab.sh"

##############################################################################
# TEST: Solo project creation produces expected structure
##############################################################################

test_solo_project_creates_description() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true
  assert_file_exists "DESCRIPTION" \
    "Solo project should create DESCRIPTION"
  teardown_test
}

test_solo_project_creates_dockerfile() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true
  assert_file_exists "Dockerfile" \
    "Solo project should create Dockerfile"
  teardown_test
}

test_solo_project_creates_makefile() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true
  assert_file_exists "Makefile" \
    "Solo project should create Makefile"
  teardown_test
}

test_solo_project_creates_r_directory() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true
  assert_dir_exists "R" \
    "Solo project should create R/ directory"
  teardown_test
}

test_solo_project_creates_tests() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true
  assert_dir_exists "tests" \
    "Solo project should create tests/ directory"
  teardown_test
}

test_solo_project_creates_analysis_dirs() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true
  assert_dir_exists "analysis/data/raw_data" \
    "Solo project should create analysis/data/raw_data/"
  assert_dir_exists "analysis/data/derived_data" \
    "Solo project should create analysis/data/derived_data/"
  teardown_test
}

test_solo_project_creates_renv_lock() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true
  assert_file_exists "renv.lock" \
    "Solo project should create renv.lock"
  teardown_test
}

test_solo_project_creates_rprofile() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true
  assert_file_exists ".Rprofile" \
    "Solo project should create .Rprofile"
  teardown_test
}

##############################################################################
# TEST: Team project creation with -t and -p flags
##############################################################################

test_team_project_creates_structure() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal -t testlab -p testpkg \
    --no-docker --yes 2>/dev/null || true
  assert_file_exists "DESCRIPTION" \
    "Team project should create DESCRIPTION"
  assert_file_exists "Dockerfile" \
    "Team project should create Dockerfile"
  teardown_test
}

test_team_project_description_has_team() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal -t testlab -p testpkg \
    --no-docker --yes 2>/dev/null || true
  if [[ -f DESCRIPTION ]]; then
    local pkg_name
    pkg_name=$(grep '^Package:' DESCRIPTION | \
      sed 's/^Package:[[:space:]]*//')
    assert_equals "testpkg" "$pkg_name" \
      "DESCRIPTION Package should match project name"
  fi
  teardown_test
}

##############################################################################
# TEST: Five Pillars validation
##############################################################################

test_five_pillars_all_present() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true

  local missing=0
  [[ ! -f "Dockerfile" ]] && { echo "Missing: Dockerfile" >&2; missing=$((missing + 1)); }
  [[ ! -f "renv.lock" ]] && { echo "Missing: renv.lock" >&2; missing=$((missing + 1)); }
  [[ ! -f ".Rprofile" ]] && { echo "Missing: .Rprofile" >&2; missing=$((missing + 1)); }
  [[ ! -d "R" ]] && { echo "Missing: R/" >&2; missing=$((missing + 1)); }
  [[ ! -d "analysis/data/raw_data" ]] && { echo "Missing: analysis/data/raw_data/" >&2; missing=$((missing + 1)); }

  if [[ "$missing" -gt 0 ]]; then
    echo "FAIL: $missing of 5 pillars missing" >&2
    return 1
  fi
  teardown_test
}

##############################################################################
# TEST: Dockerfile content validation
##############################################################################

test_dockerfile_has_from() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true
  if [[ -f Dockerfile ]]; then
    if ! grep -q "^FROM" Dockerfile; then
      echo "FAIL: Dockerfile should have FROM instruction" >&2
      return 1
    fi
  fi
  teardown_test
}

test_dockerfile_has_analyst_user() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true
  if [[ -f Dockerfile ]]; then
    if ! grep -q "analyst" Dockerfile; then
      echo "FAIL: Dockerfile should reference analyst user" >&2
      return 1
    fi
  fi
  teardown_test
}

##############################################################################
# TEST: renv.lock content validation
##############################################################################

test_renv_lock_valid_json() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true
  if [[ -f renv.lock ]] && command -v jq &>/dev/null; then
    if ! jq empty renv.lock 2>/dev/null; then
      echo "FAIL: renv.lock should be valid JSON" >&2
      return 1
    fi
  fi
  teardown_test
}

test_renv_lock_has_r_version() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir testpkg && cd testpkg
  bash "$ZZCOLLAB_SH" minimal --no-docker --yes 2>/dev/null || true
  if [[ -f renv.lock ]] && command -v jq &>/dev/null; then
    local r_ver
    r_ver=$(jq -r '.R.Version // empty' renv.lock 2>/dev/null)
    assert_not_empty "$r_ver" \
      "renv.lock should contain R version"
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
    echo "$output" | head -5
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
