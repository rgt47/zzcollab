#!/bin/bash
##############################################################################
# ZZCOLLAB INTEGRATION TESTS
##############################################################################
# End-to-end tests for project creation workflows.
# Tests run without Docker (--no-build) to validate scaffolding output.
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

ZZCOLLAB_SH="$ZZCOLLAB_ROOT/zzcollab.sh"

# Scaffold a minimal project into ./testpkg and fail the calling test if the
# scaffolding command does not exit cleanly. --no-build is the real flag that
# skips the Docker build, so no Docker daemon is required. A non-zero exit
# (e.g. an unrecognised flag or a scaffolding regression) is now asserted
# rather than swallowed with `|| true`.
scaffold_minimal() {
  mkdir testpkg && cd testpkg
  local rc=0
  bash "$ZZCOLLAB_SH" minimal --no-build --yes >/dev/null 2>&1 || rc=$?
  assert_exit_code 0 "$rc" "minimal scaffolding should exit cleanly"
}

##############################################################################
# TEST: Solo project creation produces expected structure
##############################################################################

test_solo_project_creates_description() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }
  assert_file_exists "DESCRIPTION" \
    "Solo project should create DESCRIPTION"
  teardown_test
}

test_solo_project_creates_dockerfile() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }
  assert_file_exists "Dockerfile" \
    "Solo project should create Dockerfile"
  teardown_test
}

test_solo_project_creates_makefile() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }
  assert_file_exists "Makefile" \
    "Solo project should create Makefile"
  teardown_test
}

test_solo_project_creates_r_directory() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }
  assert_dir_exists "R" \
    "Solo project should create R/ directory"
  teardown_test
}

test_solo_project_creates_tests() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }
  assert_dir_exists "tests" \
    "Solo project should create tests/ directory"
  teardown_test
}

test_solo_project_creates_analysis_dirs() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }
  assert_dir_exists "analysis/data/raw_data" \
    "Solo project should create analysis/data/raw_data/"
  assert_dir_exists "analysis/data/derived_data" \
    "Solo project should create analysis/data/derived_data/"
  teardown_test
}

test_solo_project_creates_renv_lock() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }
  assert_file_exists "renv.lock" \
    "Solo project should create renv.lock"
  teardown_test
}

test_solo_project_creates_rprofile() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }
  assert_file_exists ".Rprofile" \
    "Solo project should create .Rprofile"
  teardown_test
}

##############################################################################
# TEST: Scaffolded DESCRIPTION metadata
##############################################################################

test_description_package_matches_dir() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }
  assert_file_exists "DESCRIPTION" \
    "scaffold should create DESCRIPTION"
  local pkg_name
  pkg_name=$(grep '^Package:' DESCRIPTION | \
    sed 's/^Package:[[:space:]]*//')
  assert_equals "testpkg" "$pkg_name" \
    "DESCRIPTION Package should match project name"
  teardown_test
}

##############################################################################
# TEST: Five Pillars validation
##############################################################################

test_five_pillars_all_present() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }

  local missing=0
  [[ ! -f "Dockerfile" ]] && { echo "Missing: Dockerfile" >&2; missing=$((missing + 1)); }
  [[ ! -f "renv.lock" ]] && { echo "Missing: renv.lock" >&2; missing=$((missing + 1)); }
  [[ ! -f ".Rprofile" ]] && { echo "Missing: .Rprofile" >&2; missing=$((missing + 1)); }
  [[ ! -d "R" ]] && { echo "Missing: R/" >&2; missing=$((missing + 1)); }
  [[ ! -d "analysis/data/raw_data" ]] && { echo "Missing: analysis/data/raw_data/" >&2; missing=$((missing + 1)); }

  if [[ "$missing" -gt 0 ]]; then
    echo "FAIL: $missing of 5 pillars missing" >&2
    teardown_test
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
  scaffold_minimal || { teardown_test; return 1; }
  if ! grep -q "^FROM" Dockerfile; then
    echo "FAIL: Dockerfile should have FROM instruction" >&2
    teardown_test
    return 1
  fi
  teardown_test
}

test_dockerfile_has_analyst_user() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }
  if ! grep -q "analyst" Dockerfile; then
    echo "FAIL: Dockerfile should reference analyst user" >&2
    teardown_test
    return 1
  fi
  teardown_test
}

##############################################################################
# TEST: renv.lock content validation
##############################################################################

test_renv_lock_valid_json() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }
  if ! command -v jq &>/dev/null; then
    echo "SKIP: jq not installed" >&2
    teardown_test
    return 0
  fi
  if ! jq empty renv.lock 2>/dev/null; then
    echo "FAIL: renv.lock should be valid JSON" >&2
    teardown_test
    return 1
  fi
  teardown_test
}

test_renv_lock_has_r_version() {
  setup_test
  cd "$TEST_TEMP_DIR"
  scaffold_minimal || { teardown_test; return 1; }
  if ! command -v jq &>/dev/null; then
    echo "SKIP: jq not installed" >&2
    teardown_test
    return 0
  fi
  local r_ver
  r_ver=$(jq -r '.R.Version // empty' renv.lock 2>/dev/null)
  assert_not_empty "$r_ver" \
    "renv.lock should contain R version"
  teardown_test
}

##############################################################################
# TEST: A bare profile token does not silently switch an existing project (F4)
##############################################################################

test_bare_profile_refuses_to_switch_existing_project() {
  setup_test
  cd "$TEST_TEMP_DIR"
  mkdir proj && cd proj

  # Mock an initialized project configured with the 'analysis' profile,
  # plus sentinel files that the old silent-switch path used to overwrite.
  printf 'Package: proj\nVersion: 0.0.1\n' > DESCRIPTION
  printf 'docker:\n  default_profile: "analysis"\n' > zzcollab.yaml
  printf 'SENTINEL-RPROFILE\n' > .Rprofile
  printf 'SENTINEL-MAKEFILE\n' > Makefile
  local rp_before mk_before
  rp_before=$(cksum .Rprofile)
  mk_before=$(cksum Makefile)

  # A different-profile bare token must error rather than switch.
  local rc=0
  bash "$ZZCOLLAB_SH" rstudio >/dev/null 2>&1 || rc=$?
  assert_true "[ $rc -ne 0 ]" \
    "bare 'zzcollab rstudio' on an existing 'analysis' project should error" \
    || { teardown_test; return 1; }

  # ...and must not have touched .Rprofile or Makefile.
  assert_equals "$rp_before" "$(cksum .Rprofile)" \
    ".Rprofile must be left untouched by a refused switch" \
    || { teardown_test; return 1; }
  assert_equals "$mk_before" "$(cksum Makefile)" \
    "Makefile must be left untouched by a refused switch" \
    || { teardown_test; return 1; }

  teardown_test
}

##############################################################################
# RUN ALL TESTS
##############################################################################

run_test_suite
