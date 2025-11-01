#!/bin/bash
# ZZCOLLAB Docker Entrypoint
# Automatically snapshots renv.lock on container exit
# This ensures reproducibility without requiring manual renv::snapshot() calls

set -e

# Configuration via environment variables
AUTO_SNAPSHOT="${ZZCOLLAB_AUTO_SNAPSHOT:-true}"
SNAPSHOT_TIMESTAMP_ADJUST="${ZZCOLLAB_SNAPSHOT_TIMESTAMP_ADJUST:-true}"
PROJECT_DIR="${ZZCOLLAB_PROJECT_DIR:-/home/analyst/project}"

# Exit cleanup handler
cleanup() {
    local exit_code=$?
    local snapshot_failed=0

    # Only proceed if auto-snapshot is enabled
    if [[ "$AUTO_SNAPSHOT" != "true" ]]; then
        exit $exit_code
    fi

    # Check if renv.lock exists in project
    if [[ ! -f "$PROJECT_DIR/renv.lock" ]]; then
        exit $exit_code
    fi

    # Check if renv is initialized
    if [[ ! -f "$PROJECT_DIR/renv/activate.R" ]]; then
        exit $exit_code
    fi

    echo "📸 Auto-snapshotting renv.lock before container exit..."

    # Use file locking to prevent race conditions when multiple containers exit simultaneously
    # File descriptor 200 is used for the lock to avoid conflicts with stdin/stdout/stderr
    {
        # Wait for exclusive lock (blocks if another container is snapshotting)
        flock -x 200 || {
            echo "⚠️  Failed to acquire lock on renv.lock (timeout)" >&2
            snapshot_failed=1
            # Don't exit yet - handle below to preserve original exit code if needed
        }

        if [[ $snapshot_failed -eq 0 ]]; then
            # Run renv::snapshot() to capture current package state
            # type = "explicit" means only packages explicitly used in code
            # prompt = FALSE means non-interactive (essential for automation)
            if Rscript -e "renv::snapshot(type = 'explicit', prompt = FALSE)" 2>/dev/null; then
                echo "✅ renv.lock updated successfully"

                # Adjust timestamp for RSPM binary package availability
                # RSPM needs 7-10 days to build binaries for new package versions
                # Setting timestamp to 7 days ago ensures binary packages are available
                # This provides 10-20x faster Docker builds (binaries vs source compilation)
                # Note: Makefile will restore timestamp to "now" after validation completes
                if [[ "$SNAPSHOT_TIMESTAMP_ADJUST" == "true" ]]; then
                    if touch -d "7 days ago" "$PROJECT_DIR/renv.lock" 2>/dev/null; then
                        echo "🕐 Adjusted renv.lock timestamp for RSPM (will be restored after validation)"
                    else
                        # macOS fallback (touch -d doesn't work on macOS)
                        if touch -t "$(date -v-7d +%Y%m%d%H%M.%S)" "$PROJECT_DIR/renv.lock" 2>/dev/null; then
                            echo "🕐 Adjusted renv.lock timestamp for RSPM (will be restored after validation)"
                        fi
                    fi
                fi
            else
                echo "❌ ERROR: renv::snapshot() failed" >&2
                snapshot_failed=1
            fi
        fi

        # Lock is automatically released when file descriptor 200 is closed (end of block)
    } 200>"$PROJECT_DIR/.renv.lock.lock"

    # If original command succeeded but snapshot failed, report snapshot error
    if [[ $exit_code -eq 0 ]] && [[ $snapshot_failed -eq 1 ]]; then
        echo "⚠️  Container command succeeded but renv snapshot failed" >&2
        echo "⚠️  Run 'make docker-r' and manually run 'renv::snapshot()' to fix" >&2
        exit 1  # Exit with error to signal snapshot failure
    fi

    # If original command failed, preserve that exit code (snapshot failure is secondary)
    exit $exit_code
}

# Register cleanup handler for all exit scenarios
# This runs on: normal exit, Ctrl+C, docker stop, errors, etc.
trap cleanup EXIT INT TERM

# Setup navigation functions in shell
# These are available for zsh and bash sessions
setup_navigation() {
    local shell_rc=""

    # Determine which shell config to use
    if [[ "$1" == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ "$1" == *"bash"* ]]; then
        shell_rc="$HOME/.bashrc"
    else
        # Not a shell we can configure
        return 0
    fi

    # Only add if not already present
    if [[ -f "$shell_rc" ]] && grep -q "_zzcollab_root" "$shell_rc" 2>/dev/null; then
        return 0
    fi

    # Append navigation functions to shell config
    cat >> "$shell_rc" <<'NAVFUNC'

# ZZCOLLAB Navigation Functions (added by entrypoint)
# Find project root (looks for DESCRIPTION file)
_zzcollab_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/DESCRIPTION" ]] || [[ -f "$dir/.zzcollab_project" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Navigation shortcuts - work from any subdirectory
a() { local root=$(_zzcollab_root); [[ -n "$root" ]] && cd "$root/analysis" || echo "Not in ZZCOLLAB project"; }
d() { local root=$(_zzcollab_root); [[ -n "$root" ]] && cd "$root/data" || echo "Not in ZZCOLLAB project"; }
n() { local root=$(_zzcollab_root); [[ -n "$root" ]] && cd "$root/analysis" || echo "Not in ZZCOLLAB project"; }
f() { local root=$(_zzcollab_root); [[ -n "$root" ]] && cd "$root/analysis/figures" || echo "Not in ZZCOLLAB project"; }
t() { local root=$(_zzcollab_root); [[ -n "$root" ]] && cd "$root/analysis/tables" || echo "Not in ZZCOLLAB project"; }
s() { local root=$(_zzcollab_root); [[ -n "$root" ]] && cd "$root/analysis/scripts" || echo "Not in ZZCOLLAB project"; }
p() { local root=$(_zzcollab_root); [[ -n "$root" ]] && cd "$root/analysis/paper" || echo "Not in ZZCOLLAB project"; }
r() { local root=$(_zzcollab_root); [[ -n "$root" ]] && cd "$root" || echo "Not in ZZCOLLAB project"; }
m() { local root=$(_zzcollab_root); [[ -n "$root" ]] && cd "$root/man" || echo "Not in ZZCOLLAB project"; }
e() { local root=$(_zzcollab_root); [[ -n "$root" ]] && cd "$root/tests" || echo "Not in ZZCOLLAB project"; }
o() { local root=$(_zzcollab_root); [[ -n "$root" ]] && cd "$root/docs" || echo "Not in ZZCOLLAB project"; }
c() { local root=$(_zzcollab_root); [[ -n "$root" ]] && cd "$root/archive" || echo "Not in ZZCOLLAB project"; }

# List navigation shortcuts
nav() {
    echo "ZZCOLLAB Navigation Shortcuts:"
    echo "  r → project root"
    echo "  d → data/"
    echo "  a/n → analysis/"
    echo "  s → analysis/scripts/"
    echo "  p → analysis/paper/"
    echo "  f → analysis/figures/"
    echo "  t → analysis/tables/"
    echo "  m → man/"
    echo "  e → tests/"
    echo "  o → docs/"
    echo "  c → archive/"
}
NAVFUNC
}

# Setup navigation for shell sessions
setup_navigation "$@"

# Show helpful message on first run
if [[ -z "$ZZCOLLAB_ENTRYPOINT_QUIET" ]]; then
    cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║ ZZCOLLAB Docker Environment                                    ║
║                                                                ║
║ Auto-snapshot enabled: renv.lock will be updated on exit      ║
║                                                                ║
║ Install packages: install.packages("package")                 ║
║ GitHub packages: install.packages("remotes") then              ║
║                  remotes::install_github("user/package")       ║
║                                                                ║
║ Navigation: Type 'nav' to see one-letter shortcuts            ║
║   Examples: s (scripts), p (paper), d (data), r (root)        ║
║                                                                ║
║ Disable auto-snapshot: ZZCOLLAB_AUTO_SNAPSHOT=false           ║
╚════════════════════════════════════════════════════════════════╝

EOF
fi

# Execute the command passed to docker run
# This will be /bin/zsh, /bin/bash, R, etc.
exec "$@"
