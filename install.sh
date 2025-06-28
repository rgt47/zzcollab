#!/bin/bash
##############################################################################
# ZZRRTOOLS INSTALLATION SCRIPT
##############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Determine installation directory
if [[ -d "$HOME/bin" ]]; then
    INSTALL_DIR="$HOME/bin"
elif [[ -d "/usr/local/bin" ]] && [[ -w "/usr/local/bin" ]]; then
    INSTALL_DIR="/usr/local/bin"
else
    INSTALL_DIR="$HOME/bin"
    mkdir -p "$INSTALL_DIR"
    log_warn "Created $INSTALL_DIR - add it to your PATH in ~/.bashrc or ~/.zshrc"
    log_warn "Add this line: export PATH=\"\$HOME/bin:\$PATH\""
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK_PATH="$INSTALL_DIR/zzrrtools"

# Check if zzrrtools.sh exists
if [[ ! -f "$SCRIPT_DIR/zzrrtools.sh" ]]; then
    log_error "zzrrtools.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Remove existing installation
if [[ -L "$LINK_PATH" ]]; then
    log_info "Removing existing installation..."
    rm "$LINK_PATH"
fi

# Create symlink
log_info "Installing zzrrtools to $INSTALL_DIR..."
ln -s "$SCRIPT_DIR/zzrrtools.sh" "$LINK_PATH"

# Make sure it's executable
chmod +x "$SCRIPT_DIR/zzrrtools.sh"

log_info "✅ Installation complete!"
log_info "Run 'zzrrtools --help' to get started"

# Check if directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    log_warn "⚠️  $INSTALL_DIR is not in your PATH"
    log_warn "Add this to your shell config file (~/.bashrc, ~/.zshrc):"
    log_warn "export PATH=\"$INSTALL_DIR:\$PATH\""
fi