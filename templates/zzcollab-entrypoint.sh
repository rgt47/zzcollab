#!/bin/bash
# ZZCOLLAB Docker Entrypoint
# Provides navigation shortcuts and project setup

set -e

PROJECT_DIR="${ZZCOLLAB_PROJECT_DIR:-/home/analyst/project}"

# Validate PROJECT_DIR exists and is readable
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "❌ ERROR: PROJECT_DIR does not exist: $PROJECT_DIR" >&2
    echo "   Set ZZCOLLAB_PROJECT_DIR to valid project directory" >&2
    exit 1
fi

if [[ ! -r "$PROJECT_DIR" ]]; then
    echo "❌ ERROR: PROJECT_DIR is not readable: $PROJECT_DIR" >&2
    echo "   Check directory permissions" >&2
    exit 1
fi

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
║ Auto-snapshot: renv.lock updates when you exit R              ║
║   • Automatically captures installed packages                 ║
║   • Uses .Last() function in .Rprofile                         ║
║   • Disable: Sys.setenv(ZZCOLLAB_AUTO_SNAPSHOT = "false")     ║
║                                                                ║
║ Install packages: install.packages("package")                 ║
║ GitHub packages: install.packages("remotes") then              ║
║                  remotes::install_github("user/package")       ║
║                                                                ║
║ Navigation: Type 'nav' to see one-letter shortcuts            ║
║   Examples: s (scripts), p (paper), d (data), r (root)        ║
╚════════════════════════════════════════════════════════════════╝

EOF
fi

# Execute the command passed to docker run
# This will be /bin/zsh, /bin/bash, R, etc.
exec "$@"
