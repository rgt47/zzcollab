#!/bin/bash
##############################################################################
# ZZRRTOOLS INSTALLATION SCRIPT
##############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
${BLUE}ZZRRTOOLS Installation Script${NC}

Installs zzrrtools by copying all necessary files to the specified directory.

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
    ├── zzrrtools           # Main executable script
    ├── zzrrtools/          # Support files directory
    │   ├── modules/        # Module files
    │   └── templates/      # Template files
    └── README_zzrrtools.md # Installation info

The installed zzrrtools will be completely self-contained and work from any location.
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
ZZRRTOOLS_SUPPORT_DIR="$INSTALL_DIR/zzrrtools-support"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info "Installing zzrrtools to $INSTALL_DIR"
log_info "Support files will be in $ZZRRTOOLS_SUPPORT_DIR"

# Create installation directory if it doesn't exist
if [[ ! -d "$INSTALL_DIR" ]]; then
    log_info "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Check if zzrrtools.sh exists
if [[ ! -f "$SCRIPT_DIR/zzrrtools.sh" ]]; then
    log_error "zzrrtools.sh not found in $SCRIPT_DIR"
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
if [[ -e "$INSTALL_DIR/zzrrtools" ]]; then
    log_error "Installation target already exists: $INSTALL_DIR/zzrrtools"
    log_error "Please remove it first or choose a different installation directory:"
    log_error "  rm -rf $INSTALL_DIR/zzrrtools"
    log_error "  # OR"
    log_error "  $0 --prefix /different/path"
    exit 1
fi

if [[ -d "$ZZRRTOOLS_SUPPORT_DIR" ]]; then
    log_info "Removing existing zzrrtools support directory..."
    rm -rf "$ZZRRTOOLS_SUPPORT_DIR"
fi

# Create support directory
log_info "Creating support directory structure..."
mkdir -p "$ZZRRTOOLS_SUPPORT_DIR"

# Copy modules and templates
log_info "Copying modules directory..."
cp -r "$SCRIPT_DIR/modules" "$ZZRRTOOLS_SUPPORT_DIR/"

log_info "Copying templates directory..."
cp -r "$SCRIPT_DIR/templates" "$ZZRRTOOLS_SUPPORT_DIR/"

# Create the main zzrrtools executable
log_info "Creating main executable..."
cat > "$INSTALL_DIR/zzrrtools" << 'EOF'
#!/bin/bash
##############################################################################
# ZZRRTOOLS MAIN EXECUTABLE (Installed Version)
##############################################################################

set -euo pipefail

# Determine the installation directory
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZZRRTOOLS_SUPPORT_DIR="$INSTALL_DIR/zzrrtools-support"

# Set up paths for the installed version
readonly SCRIPT_DIR="$ZZRRTOOLS_SUPPORT_DIR"
readonly TEMPLATES_DIR="$SCRIPT_DIR/templates"
readonly MODULES_DIR="$SCRIPT_DIR/modules"

# Validate installation
if [[ ! -d "$MODULES_DIR" ]]; then
    echo "❌ Error: Modules directory not found: $MODULES_DIR"
    echo "❌ zzrrtools installation may be corrupted"
    exit 1
fi

if [[ ! -d "$TEMPLATES_DIR" ]]; then
    echo "❌ Error: Templates directory not found: $TEMPLATES_DIR"
    echo "❌ zzrrtools installation may be corrupted"
    exit 1
fi

# Source the main zzrrtools script logic
EOF

# Append the main zzrrtools.sh content (excluding the shebang and initial setup)
# Filter out duplicate readonly declarations that would conflict
tail -n +18 "$SCRIPT_DIR/zzrrtools.sh" | grep -v "^readonly SCRIPT_DIR=" | grep -v "^readonly TEMPLATES_DIR=" | grep -v "^readonly MODULES_DIR=" >> "$INSTALL_DIR/zzrrtools"

# Make the main executable
chmod +x "$INSTALL_DIR/zzrrtools"

# Create installation info file
cat > "$INSTALL_DIR/README_zzrrtools.md" << EOF
# ZZRRTOOLS Installation

This directory contains a complete installation of zzrrtools.

## Installation Details
- Installed on: $(date)
- Installed from: $SCRIPT_DIR
- Installation directory: $INSTALL_DIR
- Support files: $ZZRRTOOLS_SUPPORT_DIR

## Files
- \`zzrrtools\` - Main executable
- \`zzrrtools/\` - Support files directory
- \`README_zzrrtools.md\` - This file

## Usage
Run \`zzrrtools --help\` from anywhere to get started.

## Uninstall
To remove zzrrtools:
\`\`\`bash
rm -f $INSTALL_DIR/zzrrtools
rm -rf $ZZRRTOOLS_SUPPORT_DIR
rm -f $INSTALL_DIR/README_zzrrtools.md
\`\`\`
EOF

log_success "Installation complete!"
echo ""
log_info "📁 Installed files:"
log_info "   Main executable: $INSTALL_DIR/zzrrtools"
log_info "   Support files: $ZZRRTOOLS_SUPPORT_DIR"
log_info "   Documentation: $INSTALL_DIR/README_zzrrtools.md"
echo ""

# Test the installation
log_info "🧪 Testing installation..."
if "$INSTALL_DIR/zzrrtools" --help > /dev/null 2>&1; then
    log_success "Installation test passed!"
else
    log_error "Installation test failed - zzrrtools may not work correctly"
fi

# Check if directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    log_warn "⚠️  $INSTALL_DIR is not in your PATH"
    log_warn "Add this to your shell config file (~/.bashrc, ~/.zshrc):"
    log_warn "export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
    log_info "Or run zzrrtools with full path: $INSTALL_DIR/zzrrtools"
else
    echo ""
    log_success "🚀 zzrrtools is ready! Run 'zzrrtools --help' to get started"
fi

echo ""
log_info "📖 See $INSTALL_DIR/README_zzrrtools.md for installation details"