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

    # Run renv::snapshot() to capture current package state
    # type = "explicit" means only packages explicitly used in code
    # prompt = FALSE means non-interactive (essential for automation)
    if Rscript -e "renv::snapshot(type = 'explicit', prompt = FALSE)" 2>/dev/null; then
        echo "✅ renv.lock updated successfully"

        # Adjust timestamp for RSPM binary package availability
        # RSPM needs 7-10 days to build binaries for new package versions
        # Setting timestamp to 7 days ago ensures binary packages are available
        # This provides 10-20x faster Docker builds (binaries vs source compilation)
        if [[ "$SNAPSHOT_TIMESTAMP_ADJUST" == "true" ]]; then
            if touch -d "7 days ago" "$PROJECT_DIR/renv.lock" 2>/dev/null; then
                echo "🕐 Adjusted renv.lock timestamp for RSPM binary package compatibility"
            else
                # macOS fallback (touch -d doesn't work on macOS)
                if touch -t "$(date -v-7d +%Y%m%d%H%M.%S)" "$PROJECT_DIR/renv.lock" 2>/dev/null; then
                    echo "🕐 Adjusted renv.lock timestamp for RSPM binary package compatibility"
                fi
            fi
        fi
    else
        echo "⚠️  renv::snapshot() failed (non-critical, continuing)" >&2
    fi

    exit $exit_code
}

# Register cleanup handler for all exit scenarios
# This runs on: normal exit, Ctrl+C, docker stop, errors, etc.
trap cleanup EXIT INT TERM

# Show helpful message on first run
if [[ -z "$ZZCOLLAB_ENTRYPOINT_QUIET" ]]; then
    cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║ ZZCOLLAB Docker Environment                                    ║
║                                                                ║
║ Auto-snapshot enabled: renv.lock will be updated on exit      ║
║                                                                ║
║ Install packages: renv::install("package")                    ║
║ Disable auto-snapshot: ZZCOLLAB_AUTO_SNAPSHOT=false           ║
╚════════════════════════════════════════════════════════════════╝

EOF
fi

# Execute the command passed to docker run
# This will be /bin/zsh, /bin/bash, R, etc.
exec "$@"
