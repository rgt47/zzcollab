#!/bin/bash
# zzrrtools One-Line Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/rgt47/zzrrtools/main/install.sh | bash
# Or: wget -qO- https://raw.githubusercontent.com/rgt47/zzrrtools/main/install.sh | bash

set -euo pipefail

# Configuration
readonly REPO_URL="https://raw.githubusercontent.com/rgt47/zzrrtools/main"
readonly INSTALL_DIR="${HOME}/.local/bin"
readonly SCRIPT_NAME="rrtools.sh"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}" >&2
}

log_warn() {
    echo -e "${YELLOW}⚠️  $*${NC}" >&2
}

log_error() {
    echo -e "${RED}❌ $*${NC}" >&2
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Main installation function
install_zzrrtools() {
    log_info "Installing zzrrtools framework..."
    
    # Check prerequisites
    if ! command_exists curl && ! command_exists wget; then
        log_error "Either curl or wget is required for installation"
        exit 1
    fi
    
    # Create install directory
    if [[ ! -d "$INSTALL_DIR" ]]; then
        log_info "Creating install directory: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
    fi
    
    # Download main script
    local script_path="$INSTALL_DIR/$SCRIPT_NAME"
    log_info "Downloading $SCRIPT_NAME..."
    
    if command_exists curl; then
        curl -fsSL "$REPO_URL/$SCRIPT_NAME" -o "$script_path"
    elif command_exists wget; then
        wget -qO "$script_path" "$REPO_URL/$SCRIPT_NAME"
    fi
    
    # Make executable
    chmod +x "$script_path"
    log_success "Downloaded and installed $SCRIPT_NAME"
    
    # Download supporting files
    local support_files=(
        "RRTOOLS_USER_GUIDE.md"
        "check_renv_for_commit.R"
        ".zshrc_docker"
    )
    
    for file in "${support_files[@]}"; do
        log_info "Downloading $file..."
        local file_path="$INSTALL_DIR/$file"
        
        if command_exists curl; then
            curl -fsSL "$REPO_URL/$file" -o "$file_path" 2>/dev/null || log_warn "Could not download $file (optional)"
        elif command_exists wget; then
            wget -qO "$file_path" "$REPO_URL/$file" 2>/dev/null || log_warn "Could not download $file (optional)"
        fi
    done
    
    # Check PATH and provide instructions
    if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
        log_success "Installation complete! You can now use 'rrtools.sh' from anywhere."
    else
        log_warn "Installation complete, but $INSTALL_DIR is not in your PATH"
        echo
        echo "To use rrtools.sh from anywhere, add this line to your shell config:"
        echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
        echo
        echo "For bash: echo 'export PATH=\"\$PATH:$INSTALL_DIR\"' >> ~/.bashrc"
        echo "For zsh:  echo 'export PATH=\"\$PATH:$INSTALL_DIR\"' >> ~/.zshrc"
        echo
        echo "Then restart your terminal or run: source ~/.bashrc (or ~/.zshrc)"
        echo
        echo "Alternatively, you can run it directly: $script_path"
    fi
    
    # Show next steps
    echo
    log_info "Next steps:"
    echo "1. cd to your project directory"
    echo "2. Run: rrtools.sh"
    echo "3. Follow the setup prompts"
    echo "4. Start developing with: make docker-rstudio"
    echo
    log_info "For help: rrtools.sh --help"
    log_info "Documentation: cat $INSTALL_DIR/RRTOOLS_USER_GUIDE.md"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        cat << 'EOF'
zzrrtools One-Line Installer

USAGE:
  curl -fsSL https://raw.githubusercontent.com/rgt47/zzrrtools/main/install.sh | bash
  wget -qO- https://raw.githubusercontent.com/rgt47/zzrrtools/main/install.sh | bash

WHAT IT DOES:
  1. Downloads rrtools.sh and supporting files
  2. Installs them to ~/.local/bin
  3. Makes rrtools.sh executable
  4. Provides PATH setup instructions

REQUIREMENTS:
  - curl or wget
  - bash
  - Internet connection

AFTER INSTALLATION:
  cd your-project-directory
  rrtools.sh

For more information: https://github.com/rgt47/zzrrtools
EOF
        exit 0
        ;;
    --uninstall)
        log_info "Uninstalling zzrrtools..."
        rm -f "$INSTALL_DIR/rrtools.sh"
        rm -f "$INSTALL_DIR/RRTOOLS_USER_GUIDE.md"
        rm -f "$INSTALL_DIR/check_renv_for_commit.R"
        rm -f "$INSTALL_DIR/.zshrc_docker"
        log_success "zzrrtools uninstalled successfully"
        exit 0
        ;;
    "")
        # No arguments, proceed with installation
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

# Run installation
install_zzrrtools