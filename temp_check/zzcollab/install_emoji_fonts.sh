#!/bin/bash

##############################################################################
# install_emoji_fonts.sh - Install fonts for better emoji support in PDFs
##############################################################################

set -euo pipefail

log_info() { printf "\033[0;34mℹ️  %s\033[0m\n" "$*" >&2; }
log_success() { printf "\033[0;32m✅ %s\033[0m\n" "$*" >&2; }
log_error() { printf "\033[0;31m❌ %s\033[0m\n" "$*" >&2; }

install_noto_fonts() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew >/dev/null 2>&1; then
            log_info "Installing Noto fonts on macOS..."
            brew tap homebrew/cask-fonts
            brew install --cask font-noto-serif font-noto-sans-mono font-noto-color-emoji
            log_success "Noto fonts installed successfully"
        else
            log_error "Homebrew not found. Please install Homebrew first."
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get >/dev/null 2>&1; then
            log_info "Installing Noto fonts on Ubuntu/Debian..."
            sudo apt-get update
            sudo apt-get install -y fonts-noto fonts-noto-color-emoji
            log_success "Noto fonts installed successfully"
        elif command -v yum >/dev/null 2>&1; then
            log_info "Installing Noto fonts on RedHat/CentOS..."
            sudo yum install -y google-noto-serif-fonts google-noto-sans-mono-fonts google-noto-emoji-color-fonts
            log_success "Noto fonts installed successfully"
        else
            log_error "Package manager not supported. Please install Noto fonts manually."
            exit 1
        fi
    else
        log_error "OS not supported for automatic installation"
        exit 1
    fi
}

main() {
    log_info "This script will install Noto fonts for better emoji support in PDFs"
    echo "Current system: $OSTYPE"
    echo
    
    # Check if fonts are already installed
    if fc-list | grep -i "noto serif" >/dev/null 2>&1; then
        log_success "Noto fonts are already installed"
        fc-list | grep -i noto | head -5
        exit 0
    fi
    
    read -p "Install Noto fonts for better emoji support? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_noto_fonts
        log_info "Please restart your terminal and try md2pdf.sh again"
    else
        log_info "Installation cancelled"
    fi
}

main "$@"