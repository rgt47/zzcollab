#!/bin/bash
##############################################################################
# ZZCOLLAB INSTALLATION SCRIPT
##############################################################################

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

log_info() {
    printf "${GREEN}ℹ️  %s${NC}\n" "$*"
}

log_warn() {
    printf "${YELLOW}⚠️  %s${NC}\n" "$*"
}

log_error() {
    printf "${RED}❌ %s${NC}\n" "$*"
}

log_success() {
    printf "${GREEN}✅ %s${NC}\n" "$*"
}

show_help() {
    cat << EOF
${BLUE}ZZCOLLAB Installation Script${NC}

Installs zzcollab by copying all necessary files to the specified directory.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --prefix DIR, -p DIR    Install to specified directory (default: ~/bin)
    --help, -h              Show this help message

EXAMPLES:
    $0                      # Install to ~/bin
    $0 --prefix ~/.local    # Install to ~/.local/bin
    $0 -p /usr/local        # Install to /usr/local/bin (requires sudo)

INSTALLATION STRUCTURE:
    INSTALL_DIR/
    ├── zzcollab           # Main executable script (includes --init functionality)
    ├── zzcollab-support/  # Support files directory
    │   ├── modules/        # Module files
    │   └── templates/      # Template files
    └── README_zzcollab.md # Installation info

The installed zzcollab will be completely self-contained and work from any location.
EOF
}

# Default installation directory
INSTALL_PREFIX="$HOME"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix|-p)
            if [[ -z "${2:-}" ]]; then
                log_error "Error: --prefix requires a directory argument"
                exit 1
            fi
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            log_error "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set up installation paths
INSTALL_DIR="$INSTALL_PREFIX/bin"
ZZCOLLAB_SUPPORT_DIR="$INSTALL_DIR/zzcollab-support"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info "Installing zzcollab to $INSTALL_DIR"
log_info "Support files will be in $ZZCOLLAB_SUPPORT_DIR"

# Create installation directory if it doesn't exist
if [[ ! -d "$INSTALL_DIR" ]]; then
    log_info "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Check if required scripts exist
if [[ ! -f "$SCRIPT_DIR/zzcollab.sh" ]]; then
    log_error "zzcollab.sh not found in $SCRIPT_DIR"
    exit 1
fi


# Check required directories exist
for dir in "modules" "templates"; do
    if [[ ! -d "$SCRIPT_DIR/$dir" ]]; then
        log_error "Required directory '$dir' not found in $SCRIPT_DIR"
        exit 1
    fi
done

# Check for existing installation
if [[ -e "$INSTALL_DIR/zzcollab" ]]; then
    log_error "Installation target already exists: $INSTALL_DIR/zzcollab"
    log_error "Please remove it first or choose a different installation directory:"
    log_error "  rm -rf $INSTALL_DIR/zzcollab"
    log_error "  # OR"
    log_error "  $0 --prefix /different/path"
    exit 1
fi

if [[ -d "$ZZCOLLAB_SUPPORT_DIR" ]]; then
    log_info "Removing existing zzcollab support directory..."
    rm -rf "$ZZCOLLAB_SUPPORT_DIR"
fi

# Create support directory
log_info "Creating support directory structure..."
mkdir -p "$ZZCOLLAB_SUPPORT_DIR"

# Copy modules and templates
log_info "Copying modules directory..."
cp -r "$SCRIPT_DIR/modules" "$ZZCOLLAB_SUPPORT_DIR/"

log_info "Copying templates directory..."
cp -r "$SCRIPT_DIR/templates" "$ZZCOLLAB_SUPPORT_DIR/"

# Create the main zzcollab executable
log_info "Creating main executable..."
cat > "$INSTALL_DIR/zzcollab" << 'EOF'
#!/bin/bash
##############################################################################
# ZZCOLLAB MAIN EXECUTABLE (Installed Version)
##############################################################################

set -euo pipefail

# Determine the installation directory
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZZCOLLAB_SUPPORT_DIR="$INSTALL_DIR/zzcollab-support"

# Set up paths for the installed version
SCRIPT_DIR="$ZZCOLLAB_SUPPORT_DIR"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
MODULES_DIR="$SCRIPT_DIR/modules"

# Validate installation
if [[ ! -d "$MODULES_DIR" ]]; then
    echo "❌ Error: Modules directory not found: $MODULES_DIR"
    echo "❌ zzcollab installation may be corrupted"
    exit 1
fi

if [[ ! -d "$TEMPLATES_DIR" ]]; then
    echo "❌ Error: Templates directory not found: $TEMPLATES_DIR"
    echo "❌ zzcollab installation may be corrupted"
    exit 1
fi

# Source the main zzcollab script logic
EOF

# Append the main zzcollab.sh content (excluding the shebang and initial setup)
# Filter out duplicate readonly declarations that would conflict
tail -n +18 "$SCRIPT_DIR/zzcollab.sh" | grep -v "^readonly SCRIPT_DIR=" | grep -v "^readonly TEMPLATES_DIR=" | grep -v "^readonly MODULES_DIR=" >> "$INSTALL_DIR/zzcollab"

# Make the main executable
chmod +x "$INSTALL_DIR/zzcollab"


# Create installation info file
cat > "$INSTALL_DIR/README_zzcollab.md" << EOF
# ZZCOLLAB Installation

This directory contains a complete installation of zzcollab.

## Installation Details
- Installed on: $(date)
- Installed from: $SCRIPT_DIR
- Installation directory: $INSTALL_DIR
- Support files: $ZZCOLLAB_SUPPORT_DIR

## Files
- \`zzcollab\` - Main executable (includes --init for team setup)
- \`zzcollab-support/\` - Support files directory
- \`README_zzcollab.md\` - This file

## Usage
Run \`zzcollab --help\` for regular usage or \`zzcollab --init --help\` for team setup.

## Uninstall
To remove zzcollab:
\`\`\`bash
rm -f $INSTALL_DIR/zzcollab
rm -rf $ZZCOLLAB_SUPPORT_DIR
rm -f $INSTALL_DIR/README_zzcollab.md
\`\`\`
EOF

log_success "Installation complete!"
echo ""
log_info "📁 Installed files:"
log_info "   Main executable: $INSTALL_DIR/zzcollab"
log_info "   Support files: $ZZCOLLAB_SUPPORT_DIR"
log_info "   Documentation: $INSTALL_DIR/README_zzcollab.md"
echo ""

# Test the installation
log_info "🧪 Testing installation..."
if "$INSTALL_DIR/zzcollab" --help > /dev/null 2>&1; then
    log_success "Installation test passed!"
else
    log_error "Installation test failed - zzcollab may not work correctly"
fi

# Check if directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    log_warn "⚠️  $INSTALL_DIR is not in your PATH"
    log_warn "Add this to your shell config file (~/.bashrc, ~/.zshrc):"
    log_warn "export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
    log_info "Or run zzcollab with full path: $INSTALL_DIR/zzcollab"
else
    echo ""
    log_success "🚀 zzcollab is ready! Run 'zzcollab --help' to get started"
fi

echo ""
log_info "📖 See $INSTALL_DIR/README_zzcollab.md for installation details"