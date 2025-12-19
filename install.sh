#!/bin/bash
##############################################################################
# ZZCOLLAB INSTALLATION SCRIPT
##############################################################################
# Installs zzcollab to ~/.zzcollab/ with bin symlink
#
# Structure:
#   ~/.zzcollab/
#   ├── lib/           Core libraries
#   ├── modules/       Feature modules
#   ├── templates/     Project templates
#   └── zzcollab.sh    Main entry point
#
#   ~/bin/zzcollab → ~/.zzcollab/zzcollab.sh (symlink)
##############################################################################

set -euo pipefail

readonly VERSION="2.0.0"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info()    { printf "${BLUE}ℹ️  %s${NC}\n" "$*"; }
log_warn()    { printf "${YELLOW}⚠️  %s${NC}\n" "$*"; }
log_error()   { printf "${RED}❌ %s${NC}\n" "$*"; }
log_success() { printf "${GREEN}✅ %s${NC}\n" "$*"; }

show_help() {
    cat << EOF
${BLUE}ZZCOLLAB Installation Script v${VERSION}${NC}

Installs zzcollab framework to ~/.zzcollab with optional symlink.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --bin-dir DIR       Create symlink in DIR (default: ~/bin)
    --no-symlink        Don't create symlink
    --force             Overwrite existing installation
    --uninstall         Remove zzcollab installation
    --help, -h          Show this help

EXAMPLES:
    $0                          # Install to ~/.zzcollab, symlink in ~/bin
    $0 --bin-dir /usr/local/bin # Install, symlink in /usr/local/bin
    $0 --no-symlink             # Install only, no symlink
    $0 --uninstall              # Remove installation

INSTALLATION STRUCTURE:
    ~/.zzcollab/
    ├── lib/             Core libraries (constants, core, templates)
    ├── modules/         Feature modules (cli, docker, project, etc.)
    ├── templates/       Project templates
    └── zzcollab.sh      Main entry point

    ~/bin/zzcollab       Symlink to ~/.zzcollab/zzcollab.sh
EOF
}

# Configuration
ZZCOLLAB_HOME="$HOME/.zzcollab"
BIN_DIR="$HOME/bin"
CREATE_SYMLINK=true
FORCE=false
UNINSTALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --bin-dir)
            BIN_DIR="$2"
            shift 2
            ;;
        --no-symlink)
            CREATE_SYMLINK=false
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Get source directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#=============================================================================
# UNINSTALL
#=============================================================================

do_uninstall() {
    log_info "Uninstalling zzcollab..."

    if [[ -d "$ZZCOLLAB_HOME" ]]; then
        rm -rf "$ZZCOLLAB_HOME"
        log_success "Removed $ZZCOLLAB_HOME"
    else
        log_info "No installation found at $ZZCOLLAB_HOME"
    fi

    # Remove symlinks from common locations
    for bin_path in "$HOME/bin/zzcollab" "/usr/local/bin/zzcollab"; do
        if [[ -L "$bin_path" ]]; then
            rm -f "$bin_path"
            log_success "Removed symlink $bin_path"
        fi
    done

    log_success "Uninstall complete"
}

if [[ "$UNINSTALL" == "true" ]]; then
    do_uninstall
    exit 0
fi

#=============================================================================
# VALIDATION
#=============================================================================

# Check source directory has required files
for required in "zzcollab.sh" "lib" "modules" "templates"; do
    if [[ ! -e "$SCRIPT_DIR/$required" ]]; then
        log_error "Required file/directory not found: $SCRIPT_DIR/$required"
        log_error "Run this script from the zzcollab source directory"
        exit 1
    fi
done

# Check for existing installation
if [[ -d "$ZZCOLLAB_HOME" ]]; then
    if [[ "$FORCE" == "true" ]]; then
        log_warn "Removing existing installation (--force)"
        rm -rf "$ZZCOLLAB_HOME"
    else
        log_error "Installation already exists at $ZZCOLLAB_HOME"
        log_error "Use --force to overwrite or --uninstall to remove"
        exit 1
    fi
fi

#=============================================================================
# INSTALLATION
#=============================================================================

log_info "Installing zzcollab v${VERSION} to $ZZCOLLAB_HOME"

# Create installation directory
mkdir -p "$ZZCOLLAB_HOME"

# Copy directories
log_info "Copying lib/..."
cp -r "$SCRIPT_DIR/lib" "$ZZCOLLAB_HOME/"

log_info "Copying modules/..."
cp -r "$SCRIPT_DIR/modules" "$ZZCOLLAB_HOME/"

log_info "Copying templates/..."
cp -r "$SCRIPT_DIR/templates" "$ZZCOLLAB_HOME/"

# Copy main entry point
log_info "Copying zzcollab.sh..."
cp "$SCRIPT_DIR/zzcollab.sh" "$ZZCOLLAB_HOME/"
chmod +x "$ZZCOLLAB_HOME/zzcollab.sh"

# Copy navigation scripts (user utility for shell navigation functions)
if [[ -f "$SCRIPT_DIR/navigation_scripts.sh" ]]; then
    log_info "Copying navigation_scripts.sh..."
    cp "$SCRIPT_DIR/navigation_scripts.sh" "$ZZCOLLAB_HOME/"
    chmod +x "$ZZCOLLAB_HOME/navigation_scripts.sh"
fi

# Update version in constants
if [[ -f "$ZZCOLLAB_HOME/lib/constants.sh" ]]; then
    sed -i.bak "s/ZZCOLLAB_VERSION=.*/ZZCOLLAB_VERSION=\"$VERSION\"/" \
        "$ZZCOLLAB_HOME/lib/constants.sh" 2>/dev/null || true
    rm -f "$ZZCOLLAB_HOME/lib/constants.sh.bak"
fi

log_success "Installed to $ZZCOLLAB_HOME"

#=============================================================================
# SYMLINK
#=============================================================================

if [[ "$CREATE_SYMLINK" == "true" ]]; then
    # Create bin directory if needed
    if [[ ! -d "$BIN_DIR" ]]; then
        log_info "Creating $BIN_DIR"
        mkdir -p "$BIN_DIR"
    fi

    # Remove existing symlink or file
    if [[ -e "$BIN_DIR/zzcollab" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            rm -f "$BIN_DIR/zzcollab"
        else
            log_warn "$BIN_DIR/zzcollab already exists"
            log_warn "Use --force to overwrite"
        fi
    fi

    # Create symlink
    if [[ ! -e "$BIN_DIR/zzcollab" ]]; then
        ln -s "$ZZCOLLAB_HOME/zzcollab.sh" "$BIN_DIR/zzcollab"
        log_success "Created symlink: $BIN_DIR/zzcollab"
    fi

    # Check PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo ""
        log_warn "$BIN_DIR is not in your PATH"
        log_warn "Add to your shell config (~/.bashrc or ~/.zshrc):"
        echo ""
        echo "    export PATH=\"$BIN_DIR:\$PATH\""
        echo ""
    fi
fi

#=============================================================================
# VERIFICATION
#=============================================================================

log_info "Verifying installation..."

# Test that it can be sourced
if bash -n "$ZZCOLLAB_HOME/zzcollab.sh" 2>/dev/null; then
    log_success "Syntax check passed"
else
    log_error "Syntax errors in zzcollab.sh"
    exit 1
fi

# Count files
lib_count=$(find "$ZZCOLLAB_HOME/lib" -name "*.sh" | wc -l | tr -d ' ')
mod_count=$(find "$ZZCOLLAB_HOME/modules" -name "*.sh" | wc -l | tr -d ' ')
tmpl_count=$(find "$ZZCOLLAB_HOME/templates" -type f | wc -l | tr -d ' ')

log_success "Installation complete!"
echo ""
echo "Installed:"
echo "  - $lib_count library files"
echo "  - $mod_count module files"
echo "  - $tmpl_count template files"
echo ""

if [[ "$CREATE_SYMLINK" == "true" ]] && [[ -L "$BIN_DIR/zzcollab" ]]; then
    echo "Run: zzcollab --help"
else
    echo "Run: $ZZCOLLAB_HOME/zzcollab.sh --help"
fi
