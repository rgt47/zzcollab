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

test_no_config_flag() {
  # Configuration is a subcommand ('zzcollab config set ...'), not a flag.
  # Matches the removed '--config <subcommand>' invocation; the ADR prose
  # reference ("`--config` command") is followed by a backtick, not a subcommand.
  local matches
  matches=$(grep_active_docs "\-\-config [a-z]")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed --config flag (use the 'config' subcommand) in active docs:" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

# The following guard the removed monolithic-CLI flags. Project identity is the
# working directory and team/account identity is config; profiles are selected
# positionally ('zzcollab <profile>') or via 'docker -r/--profile'. Patterns are
# scoped to 'zzcollab' invocations so prose and config keys do not trip them.

test_no_profile_name_flag() {
  # Removed flag '--profile-name'; the live flag is '--profile' and the live
  # config key is 'profile-name' (no leading dashes).
  local matches
  matches=$(grep_active_docs "zzcollab.*\-\-profile-name")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed --profile-name flag (use 'zzcollab <profile>' or 'docker --profile'):" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_project_name_flag() {
  local matches
  matches=$(grep_active_docs "\-\-project-name")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed --project-name flag (the project name is the working directory):" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_team_flag() {
  # Removed '--team' / '--team-name'; team identity is 'config set dockerhub-account'.
  local matches
  matches=$(grep_active_docs "zzcollab.*\-\-team")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed --team flag (use 'zzcollab config set dockerhub-account'):" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_pkgs_libs_flag() {
  # Removed '--pkgs' / '--libs'; bundles are components of profiles.
  local matches
  matches=$(grep_active_docs "zzcollab.*\-\-pkgs\|zzcollab.*\-\-libs\|zzcollab.*\-\-list-pkgs\|zzcollab.*\-\-list-libs")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed --pkgs/--libs flag (packages come from the profile + renv):" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_next_steps_flag() {
  # Removed flag '--next-steps'; the live form is 'help next-steps'.
  local matches
  matches=$(grep_active_docs "zzcollab.*\-\-next-steps")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed --next-steps flag (use 'zzcollab help next-steps'):" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_team_init_flags() {
  # Removed 'zzcollab -t TEAM -p PROJECT' team-init invocation.
  local matches
  matches=$(grep_active_docs "zzcollab -t [a-z]")
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed 'zzcollab -t ...' team-init form (use config + 'zzcollab <profile>'):" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_no_removed_profiles() {
  # The profile set is minimal/analysis/rstudio. The removed profiles
  # (modeling, publishing, shiny, analysis_pdf, manuscript-package) must not
  # appear as a 'zzcollab <profile>' or '--profile <profile>' invocation.
  # Scoped to invocations, so bundle keys and base-image strings (rocker/shiny,
  # rocker/verse) do not trip it.
  local removed matches
  removed='modeling\|publishing\|shiny\|analysis_pdf\|manuscript-package'
  matches=$(grep_active_docs "zzc\(ollab\)\? \($removed\)")
  matches="$matches$(grep_active_docs "\-\-profile \($removed\)")"
  matches="$matches$(grep_active_docs "\-r \($removed\)")"
  if [[ -n "$matches" ]]; then
    echo "FAIL: Found removed profile in a 'zzcollab <profile>'/'--profile' invocation (live profiles: minimal, analysis, rstudio):" >&2
    echo "$matches" | head -5 >&2
    return 1
  fi
}

test_help_flags_documented() {
  # Every long flag advertised by 'zzcollab --help' must appear in the flag
  # reference of docs/CONFIGURATION.md, so the table cannot silently drift from
  # the CLI when flags are added or removed.
  local doc help_flags missing f
  doc="$DOCS_DIR/CONFIGURATION.md"
  help_flags=$(bash "$ZZCOLLAB_ROOT/zzcollab.sh" --help 2>&1 \
    | grep -oE '\-\-[a-z][a-z-]+' | sort -u)
  missing=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    grep -qF -- "$f" "$doc" || missing="$missing $f"
  done <<< "$help_flags"
  if [[ -n "$missing" ]]; then
    echo "FAIL: Flags in 'zzcollab --help' not documented in docs/CONFIGURATION.md:$missing" >&2
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
