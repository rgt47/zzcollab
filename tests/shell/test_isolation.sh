#!/bin/bash
##############################################################################
# ZZCOLLAB SHELL TEST ISOLATION
##############################################################################
# Sandboxes every shell test process away from the owner's real user state.
#
# USAGE: source test_isolation.sh
#   Sourced by test_helpers.sh (so every test-*.sh gets it when run on its own)
#   and by run_all_tests.sh. Must be sourced before any zzcollab module is
#   loaded: modules/config.sh and lib/constants.sh resolve the user config path
#   from HOME / ZZCOLLAB_CONFIG_USER* once, into readonly variables.
#
# EFFECT:
#   - Creates a private temp dir and points HOME, ZZCOLLAB_CONFIG_USER_DIR,
#     ZZCOLLAB_CONFIG_USER, XDG_{CONFIG,CACHE,DATA,STATE}_HOME and
#     GIT_CONFIG_GLOBAL into it (always overriding inherited values).
#   - Records a fingerprint (checksum + mtime) of the real user config and,
#     on exit, fails loudly if it changed.
#   - Removes the sandbox on exit, in the process that created it only.
#
# Nested use: a suite launched by run_all_tests.sh gets its own fresh sandbox;
# the real HOME / real config path are carried down through
# ZZCOLLAB_TEST_REAL_HOME / ZZCOLLAB_TEST_REAL_CONFIG so the guard always
# watches the real file, not the parent's sandbox.
##############################################################################

# Sourcing twice in one process is a no-op (the sentinel is not exported, so a
# child process always builds its own sandbox).
if [[ "${_ZZC_TEST_SANDBOX_OWNER:-}" == "$$" ]]; then
    return 0
fi

##############################################################################
# FUNCTION: zzc_test_fingerprint
# PURPOSE:  Print "<sha256> <mtime>" for a file, or "absent" if missing.
#           Portable across macOS (BSD stat, shasum) and Linux (GNU stat,
#           sha256sum) so the guard also runs in CI.
# ARGS:     $1 - file path
##############################################################################
zzc_test_fingerprint() {
    local file="$1" sum mtime
    if [[ ! -e "$file" ]]; then
        echo "absent"
        return 0
    fi
    if command -v sha256sum >/dev/null 2>&1; then
        sum=$(sha256sum "$file" | cut -d' ' -f1)
    else
        sum=$(shasum -a 256 "$file" | cut -d' ' -f1)
    fi
    # GNU first: on Linux `stat -f` means filesystem status and would print
    # disk-usage data to stdout before failing. BSD rejects -c silently.
    mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo "?")
    echo "$sum $mtime"
}

##############################################################################
# FUNCTION: zzc_test_check_real_config
# PURPOSE:  Compare the real config's fingerprint against the one recorded at
#           sandbox creation. Prints a loud error and returns 1 on change.
##############################################################################
zzc_test_check_real_config() {
    local now
    now=$(zzc_test_fingerprint "$ZZCOLLAB_TEST_REAL_CONFIG")
    if [[ "$now" != "$_ZZC_TEST_REAL_CONFIG_FP" ]]; then
        {
            echo ""
            echo "######################################################################"
            echo "ERROR: the real user config was modified during the test run:"
            echo "  file:   $ZZCOLLAB_TEST_REAL_CONFIG"
            echo "  before: $_ZZC_TEST_REAL_CONFIG_FP"
            echo "  after:  $now"
            echo "A test escaped the sandbox. Restore the file from backup."
            echo "######################################################################"
        } >&2
        return 1
    fi
}

##############################################################################
# FUNCTION: zzc_test_sandbox_exit
# PURPOSE:  EXIT trap: run the real-config guard, then remove the sandbox.
#           Preserves the original exit status unless the guard fails.
##############################################################################
zzc_test_sandbox_exit() {
    local rc=$?
    if ! zzc_test_check_real_config; then
        rc=3
    fi
    # Only the creating process cleans up, and only a path it created.
    if [[ "${_ZZC_TEST_SANDBOX_OWNER:-}" == "$$" \
          && -n "${_ZZC_TEST_SANDBOX:-}" \
          && "$_ZZC_TEST_SANDBOX" == */zzc-test-sandbox.* \
          && -d "$_ZZC_TEST_SANDBOX" ]]; then
        cd / 2>/dev/null || true
        rm -rf "$_ZZC_TEST_SANDBOX" 2>/dev/null || true
    fi
    exit "$rc"
}

# The real HOME and real config path, captured once at the outermost level.
if [[ -z "${ZZCOLLAB_TEST_REAL_HOME:-}" ]]; then
    export ZZCOLLAB_TEST_REAL_HOME="$HOME"
fi
if [[ -z "${ZZCOLLAB_TEST_REAL_CONFIG:-}" ]]; then
    export ZZCOLLAB_TEST_REAL_CONFIG="${ZZCOLLAB_CONFIG_USER:-${ZZCOLLAB_CONFIG_USER_DIR:-$ZZCOLLAB_TEST_REAL_HOME/.zzcollab}/config.yaml}"
fi
_ZZC_TEST_REAL_CONFIG_FP=$(zzc_test_fingerprint "$ZZCOLLAB_TEST_REAL_CONFIG")

_ZZC_TEST_SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/zzc-test-sandbox.XXXXXX")
_ZZC_TEST_SANDBOX_OWNER="$$"
trap zzc_test_sandbox_exit EXIT

export HOME="$_ZZC_TEST_SANDBOX/home"
export ZZCOLLAB_CONFIG_USER_DIR="$HOME/.zzcollab"
export ZZCOLLAB_CONFIG_USER="$ZZCOLLAB_CONFIG_USER_DIR/config.yaml"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
mkdir -p "$ZZCOLLAB_CONFIG_USER_DIR" "$XDG_CONFIG_HOME"

# A fixed test identity, so any git commit a test triggers works without the
# owner's ~/.gitconfig and never writes to it.
cat > "$GIT_CONFIG_GLOBAL" << 'EOF'
[user]
    name = zzcollab test
    email = zzcollab-test@example.com
[init]
    defaultBranch = main
EOF

# Second safeguard: refuse to run if any user-state path still resolves to the
# real HOME (for example if mktemp returned something unexpected).
if [[ "$HOME" == "$ZZCOLLAB_TEST_REAL_HOME" \
      || "$ZZCOLLAB_CONFIG_USER" == "$ZZCOLLAB_TEST_REAL_CONFIG" ]]; then
    echo "ERROR: test sandbox did not isolate HOME; refusing to run." >&2
    exit 3
fi
