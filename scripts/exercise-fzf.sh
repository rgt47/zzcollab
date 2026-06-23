#!/usr/bin/env bash
# exercise-fzf.sh - manually exercise zzcollab's fzf TUI wrappers in a
# throwaway dummy workspace. Sources the real lib/core.sh and drives both
# wrappers with dummy data, isolated from the config and apply logic, so the
# fzf machinery can be observed end to end without touching a real project.
#
# This is a manual harness, not an automated test: fzf draws on the
# controlling terminal, so it cannot run under the non-interactive suite in
# tests/shell. Run it by hand in a terminal.
#
# Usage:    bash scripts/exercise-fzf.sh
# Requires: an interactive terminal and fzf on PATH.

set -euo pipefail

# Resolve the repo root from this script's own location so it runs from any
# working directory.
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)

# shellcheck source=../lib/core.sh
source "$repo_root/lib/core.sh"

# Preconditions. The wrappers need fzf and a real terminal; the same guards
# the real callers apply (has_fzf plus a tty check) are enforced here so the
# failure mode is a clear message rather than a blank screen.
if ! has_fzf; then
    echo "fzf not found on PATH. Install with: brew install fzf" >&2
    exit 1
fi
if [[ ! -t 0 || ! -t 1 ]]; then
    echo "This harness is interactive; run it in a terminal (stdin/stdout" \
         "must be a tty)." >&2
    exit 1
fi

# A throwaway 'dummy repo' working area, removed on every exit path.
workdir=$(mktemp -d "${TMPDIR:-/tmp}/zzc-fzf-demo.XXXXXX")
trap 'rm -rf "$workdir"' EXIT

# --- Exercise 1: single-select chooser with a live preview -------------
# Mirrors _toggle_choose_backend: one info file per item, named exactly as
# the item, written before the call. The first item is highlighted first.
echo "== Exercise 1: fzf_choose_preview (single-select) =="
echo "   Up/Down to move, Enter to choose, Esc to cancel."
info_dir="$workdir/info"
mkdir -p "$info_dir"
printf 'Fruit: apple\nCrisp and common.\n'  > "$info_dir/apple"
printf 'Fruit: banana\nSoft and sweet.\n'   > "$info_dir/banana"
printf 'Fruit: cherry\nSmall and tart.\n'   > "$info_dir/cherry"
if choice=$(fzf_choose_preview "Pick a fruit" "$info_dir" \
        apple banana cherry); then
    echo "  -> chose: $choice"
else
    echo "  -> cancelled (no choice)"
fi
echo ""

# --- Exercise 2: stateful multi-toggle checklist -----------------------
# Mirrors _toggle_choose_features: an info file per item and a state file of
# '<name> on|off' lines that the wrapper edits in place. Read it back only on
# a zero return (commit); a non-zero return (Esc) leaves it untouched.
echo "== Exercise 2: fzf_checklist_preview (multi-toggle) =="
echo "   Tab/Space toggles the highlighted item, Enter applies, Esc cancels."
info_dir2="$workdir/info2"
state="$workdir/state"
mkdir -p "$info_dir2"
printf 'Feature: alpha\nFirst toggle, starts on.\n'  > "$info_dir2/alpha"
printf 'Feature: beta\nSecond toggle, starts off.\n' > "$info_dir2/beta"
printf 'Feature: gamma\nThird toggle, starts on.\n'  > "$info_dir2/gamma"
printf 'alpha on\nbeta off\ngamma on\n' > "$state"
if fzf_checklist_preview "Toggle features" "$info_dir2" "$state"; then
    echo "  -> committed; on features:"
    awk '$2 == "on" { print "       - " $1 }' "$state"
else
    echo "  -> cancelled (state unchanged)"
fi
