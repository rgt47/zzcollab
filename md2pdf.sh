#!/bin/bash

##############################################################################
# md2pdf.sh - Convert Markdown to PDF with Title and Date
##############################################################################
#
# PURPOSE: Add title and date to markdown file, then convert to PDF using pandoc
#
# USAGE: ./md2pdf.sh [OPTIONS] <markdown_file>
#
# OPTIONS:
#   -t, --title TITLE    Document title (optional)
#   -h, --help          Show this help message
#
# EXAMPLES:
#   ./md2pdf.sh workflow_mini.md
#   ./md2pdf.sh -t "ZZCOLLAB Workflow Guide" workflow_mini.md
#   ./md2pdf.sh --title "Team Collaboration Guide" ZZCOLLAB_USER_GUIDE.md
#
##############################################################################

set -euo pipefail

# Script constants
readonly SCRIPT_NAME="$(basename "$0")"
readonly TODAY="$(date '+%B %d, %Y')"

# Default values
TITLE=""
MARKDOWN_FILE=""

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Control emoji usage
readonly USE_EMOJI="${MD2PDF_USE_EMOJI:-true}"

# Function: get_icon
get_icon() {
    if [[ "$USE_EMOJI" == "true" ]]; then
        case "$1" in
            info) echo "ℹ️ " ;;
            success) echo "✅ " ;;
            error) echo "❌ " ;;
            *) echo "" ;;
        esac
    else
        case "$1" in
            info) echo "[INFO] " ;;
            success) echo "[SUCCESS] " ;;
            error) echo "[ERROR] " ;;
            *) echo "" ;;
        esac
    fi
}

# Function: print_help
print_help() {
    cat << EOF
$SCRIPT_NAME - Convert Markdown to PDF with Title and Date

USAGE:
    $SCRIPT_NAME [OPTIONS] <markdown_file>

OPTIONS:
    -t, --title TITLE    Document title (optional, defaults to filename)
    -h, --help          Show this help message

EXAMPLES:
    $SCRIPT_NAME workflow_mini.md
    $SCRIPT_NAME -t "ZZCOLLAB Workflow Guide" workflow_mini.md
    $SCRIPT_NAME --title "Team Collaboration Guide" ZZCOLLAB_USER_GUIDE.md

ENVIRONMENT VARIABLES:
    MD2PDF_USE_EMOJI    Set to 'false' to disable emoji icons (default: true)

REQUIREMENTS:
    - pandoc installed with XeLaTeX support
    - DejaVu fonts installed on system
    - Color emoji font (Apple Color Emoji, Noto Color Emoji, or Segoe UI Emoji) for emoji support

OUTPUT:
    Creates PDF file with same name as input markdown file

EMOJI CONTROL:
    # Use emoji icons (default)
    $SCRIPT_NAME workflow_mini.md
    
    # Disable emoji icons
    MD2PDF_USE_EMOJI=false $SCRIPT_NAME workflow_mini.md
EOF
}

# Function: log_info
log_info() {
    local icon
    icon="$(get_icon info)"
    printf "${BLUE}%s%s${NC}\n" "$icon" "$*" >&2
}

# Function: log_success
log_success() {
    local icon
    icon="$(get_icon success)"
    printf "${GREEN}%s%s${NC}\n" "$icon" "$*" >&2
}

# Function: log_error
log_error() {
    local icon
    icon="$(get_icon error)"
    printf "${RED}%s%s${NC}\n" "$icon" "$*" >&2
}

# Function: check_prerequisites
check_prerequisites() {
    # Check if pandoc is installed
    if ! command -v pandoc >/dev/null 2>&1; then
        log_error "pandoc is not installed"
        log_error "Install with: brew install pandoc (macOS) or apt-get install pandoc (Ubuntu)"
        exit 1
    fi
    
    # Check if XeLaTeX is available
    if ! command -v xelatex >/dev/null 2>&1; then
        log_error "XeLaTeX is not installed"
        log_error "Install with: brew install --cask mactex (macOS) or apt-get install texlive-xetex (Ubuntu)"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Function: parse_arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--title)
                if [[ -z "${2:-}" ]]; then
                    log_error "Title argument is required for $1"
                    exit 1
                fi
                TITLE="$2"
                shift 2
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                print_help
                exit 1
                ;;
            *)
                if [[ -z "$MARKDOWN_FILE" ]]; then
                    MARKDOWN_FILE="$1"
                else
                    log_error "Multiple files specified. Only one markdown file is supported."
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$MARKDOWN_FILE" ]]; then
        log_error "Markdown file is required"
        print_help
        exit 1
    fi
    
    # Check if file exists
    if [[ ! -f "$MARKDOWN_FILE" ]]; then
        log_error "File not found: $MARKDOWN_FILE"
        exit 1
    fi
    
    # Set default title if not provided
    if [[ -z "$TITLE" ]]; then
        TITLE="$(basename "$MARKDOWN_FILE" .md)"
        log_info "Using default title: $TITLE"
    fi
}

# Function: create_temp_file
create_temp_file() {
    local temp_file
    # Create temp file with .md extension for pandoc format detection
    if command -v mktemp >/dev/null 2>&1 && mktemp --help 2>&1 | grep -q -- '--suffix'; then
        temp_file="$(mktemp --suffix=.md)"
    else
        # Fallback for systems without --suffix support
        temp_file="$(mktemp).md"
    fi
    
    # Add title and date header
    cat > "$temp_file" << EOF
---
title: "$TITLE"
date: "$TODAY"
geometry: margin=1in
fontsize: 11pt
linestretch: 1.2
---

EOF
    
    # Append original markdown content
    cat "$MARKDOWN_FILE" >> "$temp_file"
    
    echo "$temp_file"
}

# Function: convert_to_pdf
convert_to_pdf() {
    local temp_file="$1"
    local output_file="${MARKDOWN_FILE%.*}.pdf"
    
    log_info "Converting $MARKDOWN_FILE to PDF..."
    log_info "Title: $TITLE"
    log_info "Date: $TODAY"
    
    # Create LaTeX header for emoji support
    local latex_header
    latex_header=$(mktemp)
    cat > "$latex_header" << 'EOF'
\usepackage{fontspec}
\usepackage{polyglossia}
\setmainfont{DejaVu Serif}
\setmonofont{DejaVu Sans Mono}

% Try different emoji fonts based on system
\IfFontExistsTF{Apple Color Emoji}{
  \newfontfamily\emojifont{Apple Color Emoji}[Renderer=Harfbuzz]
}{
  \IfFontExistsTF{Noto Color Emoji}{
    \newfontfamily\emojifont{Noto Color Emoji}[Renderer=Harfbuzz]
  }{
    \IfFontExistsTF{Segoe UI Emoji}{
      \newfontfamily\emojifont{Segoe UI Emoji}[Renderer=Harfbuzz]
    }{
      \newfontfamily\emojifont{DejaVu Sans}[Renderer=Harfbuzz]
    }
  }
}

% Enable emoji rendering
\DeclareTextFontCommand{\emoji}{\emojifont}
EOF

    # Run pandoc with emoji support
    pandoc "$temp_file" \
        --from=markdown \
        --pdf-engine=xelatex \
        --include-in-header="$latex_header" \
        -o "$output_file"
    
    # Clean up temp files
    rm "$temp_file" "$latex_header"
    
    log_success "PDF created: $output_file"
    
    # Show file size
    if command -v ls >/dev/null 2>&1; then
        local file_size
        file_size=$(ls -lh "$output_file" | awk '{print $5}')
        log_info "File size: $file_size"
    fi
}

# Main function
main() {
    parse_arguments "$@"
    check_prerequisites
    
    local temp_file
    temp_file=$(create_temp_file)
    
    convert_to_pdf "$temp_file"
    
    log_success "Conversion completed successfully!"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi