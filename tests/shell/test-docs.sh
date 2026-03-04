#!/bin/bash
##############################################################################
# ZZCOLLAB DOCUMENTATION VALIDATION TESTS
##############################################################################
# Ensures documentation stays consistent with the codebase.
# Catches obsolete flags, stale terminology, and broken patterns.
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

DOCS_DIR="$ZZCOLLAB_ROOT/docs"
VIGNETTES_DIR="$ZZCOLLAB_ROOT/vignettes"
TEMPLATES_DIR="$ZZCOLLAB_ROOT/templates"

##############################################################################
# HELPER: grep active docs (excludes docs/archive/)
##############################################################################
grep_active_docs() {
  local pattern="$1"
  grep -rn "$pattern" \
    "$DOCS_DIR" "$VIGNETTES_DIR" "$TEMPLATES_DIR" \
    "$ZZCOLLAB_ROOT/README.md" \
    --include="*.md" --include="*.Rmd" \
    2>/dev/null \
    | grep -v "docs/archive/" \
    | grep -v "CHANGELOG" \
    | grep -v "changelog" \
    || true
}

##############################################################################
# TEST: No removed CLI flags in active docs
##############################################################################

test_no_obsolete_i_flag() {
  local matches
  matches=$(grep_active_docs "zzcollab -i ")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed -i flag in active docs:" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_obsolete_I_flag() {
  local matches
  matches=$(grep_active_docs "zzcollab.*-I ")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed -I flag in active docs:" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_obsolete_V_flag() {
  local matches
  matches=$(grep_active_docs "zzcollab -V ")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed -V flag in active docs:" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_profiles_config_flag() {
  local matches
  matches=$(grep_active_docs "\-\-profiles-config")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed --profiles-config in active docs:" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_config_file_flag() {
  local matches
  matches=$(grep_active_docs "\-\-config-file")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found non-existent --config-file in active docs:" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

##############################################################################
# TEST: No obsolete terminology in active docs
##############################################################################

test_no_renv_mode() {
  local matches
  matches=$(grep_active_docs "renv-mode")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found obsolete 'renv-mode' in active docs:" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_build_mode() {
  local matches
  matches=$(grep_active_docs "build-mode")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found obsolete 'build-mode' in active docs:" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

##############################################################################
# TEST: No active use of deprecated --use-team-image
##############################################################################

test_no_active_use_team_image() {
  local matches
  matches=$(grep_active_docs "zzcollab.*--use-team-image" \
    | grep -v "Deprecated" || true)
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found non-deprecated --use-team-image usage:" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

##############################################################################
# TEST: No removed function references
##############################################################################

test_no_interface_parameter() {
  local matches
  matches=$(grep_active_docs 'interface.*=.*"shell"\|interface.*=.*"rstudio"')
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed interface parameter in docs:" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_copy_paradigm() {
  local matches
  matches=$(grep_active_docs "copy_paradigm\|create_paradigm")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed paradigm functions in docs:" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_team_init_module() {
  local matches
  matches=$(grep -rn "team_init\.sh" \
    "$DOCS_DIR" "$TEMPLATES_DIR" \
    --include="*.md" 2>/dev/null \
    | grep -v "docs/archive/" \
    | grep -v "REMOVED" \
    || true)
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found active reference to removed team_init.sh:" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

##############################################################################
# TEST: CLI help matches documented flags
##############################################################################

test_help_no_removed_config_flag() {
  local help_output
  help_output=$(bash "$ZZCOLLAB_ROOT/zzcollab.sh" --help 2>&1 || true)
  if echo "$help_output" | grep -q "\-\-config "; then
    echo "FAIL: Help output references removed --config flag" >&2
    return 1
  fi
}

test_help_mentions_profile_name() {
  local help_output
  help_output=$(bash "$ZZCOLLAB_ROOT/zzcollab.sh" --help 2>&1 || true)
  if ! echo "$help_output" | grep -qi "profile"; then
    echo "FAIL: Help output should mention profiles" >&2
    return 1
  fi
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
