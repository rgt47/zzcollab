#!/bin/bash

##############################################################################
# md2pdf_simple.sh - Simple Markdown to PDF with basic emoji fallback
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

# Function: log_info
log_info() {
    printf "${BLUE}INFO: %s${NC}\n" "$*" >&2
}

# Function: log_success
log_success() {
    printf "${GREEN}SUCCESS: %s${NC}\n" "$*" >&2
}

# Function: log_error
log_error() {
    printf "${RED}ERROR: %s${NC}\n" "$*" >&2
}

# Function: print_help
print_help() {
    cat << EOF
$SCRIPT_NAME - Simple Markdown to PDF converter

USAGE:
    $SCRIPT_NAME [OPTIONS] <markdown_file>

OPTIONS:
    -t, --title TITLE    Document title (optional, defaults to filename)
    -h, --help          Show this help message

EXAMPLES:
    $SCRIPT_NAME workflow_mini.md
    $SCRIPT_NAME -t "ZZCOLLAB Guide" workflow_mini.md

NOTE:
    This script converts emoji to text equivalents for reliable PDF generation.
EOF
}

# Function: replace_emoji_with_text
replace_emoji_with_text() {
    local input_file="$1"
    local output_file="$2"
    
    # Replace common emoji with text equivalents
    sed -e 's/✅/[CHECKMARK]/g' \
        -e 's/❌/[X]/g' \
        -e 's/ℹ️/[INFO]/g' \
        -e 's/🚀/[ROCKET]/g' \
        -e 's/🐳/[WHALE]/g' \
        -e 's/🎉/[PARTY]/g' \
        -e 's/⚠️/[WARNING]/g' \
        -e 's/📝/[MEMO]/g' \
        -e 's/💡/[BULB]/g' \
        -e 's/🔧/[WRENCH]/g' \
        "$input_file" > "$output_file"
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
    # Create temp file with .md extension
    if command -v mktemp >/dev/null 2>&1 && mktemp --help 2>&1 | grep -q -- '--suffix'; then
        temp_file="$(mktemp --suffix=.md)"
    else
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
    
    # Create emoji-free version of the markdown
    local emoji_free_file
    emoji_free_file="$(mktemp)"
    replace_emoji_with_text "$MARKDOWN_FILE" "$emoji_free_file"
    
    # Append processed markdown content
    cat "$emoji_free_file" >> "$temp_file"
    
    # Clean up intermediate file
    rm "$emoji_free_file"
    
    echo "$temp_file"
}

# Function: convert_to_pdf
convert_to_pdf() {
    local temp_file="$1"
    local output_file="${MARKDOWN_FILE%.*}.pdf"
    
    log_info "Converting $MARKDOWN_FILE to PDF (emoji converted to text)..."
    log_info "Title: $TITLE"
    log_info "Date: $TODAY"
    
    # Use simple pandoc conversion
    pandoc "$temp_file" \
        --from=markdown \
        --pdf-engine=xelatex \
        -V mainfont="DejaVu Serif" \
        -V monofont="DejaVu Sans Mono" \
        -o "$output_file"
    
    # Clean up temp file
    rm "$temp_file"
    
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
    # Check if pandoc is installed
    if ! command -v pandoc >/dev/null 2>&1; then
        log_error "pandoc is not installed"
        log_error "Install with: brew install pandoc (macOS) or apt-get install pandoc (Ubuntu)"
        exit 1
    fi
    
    parse_arguments "$@"
    
    local temp_file
    temp_file=$(create_temp_file)
    
    convert_to_pdf "$temp_file"
    
    log_success "PDF conversion completed!"
    log_info "Note: Emoji characters were converted to text equivalents for reliable PDF generation"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi