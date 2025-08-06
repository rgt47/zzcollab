#!/bin/bash
##############################################################################
# ZZCOLLAB VARIANT MANAGER
##############################################################################
# 
# PURPOSE: Interactive script to add variants to team config.yaml
# USAGE:   ./add_variant.sh
# 
# This script helps teams easily discover and add Docker variants from the
# variant library to their project's config.yaml file.
##############################################################################

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Files
readonly VARIANT_EXAMPLES="variant_examples.yaml"
readonly CONFIG_FILE="config.yaml"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log_info() { printf "${BLUE}ℹ️  %s${NC}\\n" "$*" >&2; }
log_success() { printf "${GREEN}✅ %s${NC}\\n" "$*" >&2; }
log_warning() { printf "${YELLOW}⚠️  %s${NC}\\n" "$*" >&2; }
log_error() { printf "${RED}❌ %s${NC}\\n" "$*" >&2; }

# Function: check_dependencies
# Purpose: Verify required tools are available
check_dependencies() {
    local missing_deps=()
    
    if ! command -v yq >/dev/null 2>&1; then
        missing_deps+=("yq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Install yq: https://github.com/mikefarah/yq/#install"
        exit 1
    fi
}

# Function: check_files
# Purpose: Verify required files exist
check_files() {
    if [[ ! -f "$VARIANT_EXAMPLES" ]]; then
        log_error "Variant examples file not found: $VARIANT_EXAMPLES"
        log_info "This script should be run from a zzcollab project directory"
        exit 1
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        log_info "This script should be run from a zzcollab project directory with config.yaml"
        exit 1
    fi
}

# Function: get_variant_list
# Purpose: Extract variant names and descriptions from variant_examples.yaml
get_variant_list() {
    yq eval 'keys' "$VARIANT_EXAMPLES" | grep -v "^-" | sort
}

# Function: show_variant_menu
# Purpose: Display interactive menu of available variants
show_variant_menu() {
    echo ""
    log_info "🐳 ZZCOLLAB VARIANT LIBRARY"
    echo ""
    
    local variants=()
    local categories=()
    local descriptions=()
    local sizes=()
    
    # Read variant information
    while IFS= read -r variant; do
        if [[ -n "$variant" ]]; then
            variants+=("$variant")
            local category=$(yq eval ".${variant}.category // \"unknown\"" "$VARIANT_EXAMPLES")
            local description=$(yq eval ".${variant}.description" "$VARIANT_EXAMPLES")
            local size=$(yq eval ".${variant}.size // \"~1GB\"" "$VARIANT_EXAMPLES")
            categories+=("$category")
            descriptions+=("$description")
            sizes+=("$size")
        fi
    done <<< "$(get_variant_list)"
    
    # Group by category and display
    local current_category=""
    local index=1
    
    for i in "${!variants[@]}"; do
        local variant="${variants[$i]}"
        local category="${categories[$i]}"
        local description="${descriptions[$i]}"
        local size="${sizes[$i]}"
        
        # Show category header
        if [[ "$category" != "$current_category" ]]; then
            current_category="$category"
            echo ""
            case "$category" in
                "standard") printf "${CYAN}📦 STANDARD RESEARCH ENVIRONMENTS${NC}\\n" ;;
                "specialized") printf "${PURPLE}🔬 SPECIALIZED DOMAINS${NC}\\n" ;;
                "alpine") printf "${GREEN}🏔️  LIGHTWEIGHT ALPINE VARIANTS${NC}\\n" ;;
                "rhub") printf "${YELLOW}🧪 R-HUB TESTING ENVIRONMENTS${NC}\\n" ;;
                *) printf "${BLUE}🔧 OTHER VARIANTS${NC}\\n" ;;
            esac
            echo ""
        fi
        
        printf "${BLUE}%2d)${NC} ${GREEN}%-20s${NC} ${size} - %s\\n" "$index" "$variant" "$description"
        ((index++))
    done
    
    echo ""
    printf "${BLUE}%2d)${NC} ${RED}Exit${NC}\\n" "$index"
    echo ""
}

# Function: get_variant_yaml
# Purpose: Extract full YAML definition for a variant
get_variant_yaml() {
    local variant_name="$1"
    local team_variant_name="${variant_name}_team"
    
    # Extract the variant definition and modify it for team use
    yq eval ".${variant_name}" "$VARIANT_EXAMPLES" | \
    sed "s/^/${team_variant_name}:/" | \
    sed '/^[[:space:]]*category:/d' | \
    sed '/^[[:space:]]*size:/d' | \
    sed '/^[[:space:]]*notes:/d' | \
    sed 's/enabled: .*/enabled: true/'
}

# Function: add_variant_to_config
# Purpose: Add selected variant to config.yaml
add_variant_to_config() {
    local variant_name="$1"
    local team_variant_name="${variant_name}_team"
    
    log_info "Adding variant '$variant_name' as '$team_variant_name' to $CONFIG_FILE..."
    
    # Check if variant already exists
    if yq eval ".variants.${team_variant_name}" "$CONFIG_FILE" >/dev/null 2>&1; then
        log_warning "Variant '$team_variant_name' already exists in $CONFIG_FILE"
        read -p "Overwrite existing variant? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping variant addition"
            return 0
        fi
    fi
    
    # Get the variant YAML
    local variant_yaml
    variant_yaml=$(get_variant_yaml "$variant_name")
    
    # Create a temporary file with the new variant
    local temp_file=$(mktemp)
    {
        echo ""
        echo "  # Added by add_variant.sh - $(date)"
        echo "  $variant_yaml" | sed 's/^/  /'
    } > "$temp_file"
    
    # Add to config.yaml in the variants section
    if grep -q "^variants:" "$CONFIG_FILE"; then
        # Insert after the last variant
        local last_variant_line=$(grep -n "^  [a-zA-Z].*:" "$CONFIG_FILE" | tail -1 | cut -d: -f1)
        if [[ -n "$last_variant_line" ]]; then
            # Find the end of the last variant (next section or end of file)
            local insert_line=$last_variant_line
            while [[ $insert_line -lt $(wc -l < "$CONFIG_FILE") ]]; do
                ((insert_line++))
                local line=$(sed -n "${insert_line}p" "$CONFIG_FILE")
                if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^#.*$ ]]; then
                    continue
                elif [[ "$line" =~ ^[a-zA-Z].*: ]] || [[ "$line" =~ ^#=+ ]]; then
                    ((insert_line--))
                    break
                fi
            done
            
            # Insert the variant
            {
                head -n "$insert_line" "$CONFIG_FILE"
                cat "$temp_file"
                tail -n +$((insert_line + 1)) "$CONFIG_FILE"
            } > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        fi
    else
        log_error "No 'variants:' section found in $CONFIG_FILE"
        rm "$temp_file"
        return 1
    fi
    
    rm "$temp_file"
    log_success "Added variant '$team_variant_name' to $CONFIG_FILE"
    
    # Show next steps
    echo ""
    log_info "🚀 NEXT STEPS:"
    log_info "1. Review the variant configuration in $CONFIG_FILE"
    log_info "2. Customize packages or system dependencies if needed"
    log_info "3. Build the team images:"
    log_info "   zzcollab --variants-config $CONFIG_FILE"
    log_info "4. Or if use_config_variants: true is set:"
    log_info "   zzcollab -i -t TEAM -p PROJECT"
}

# Function: main
# Purpose: Main interactive loop
main() {
    echo ""
    log_info "🔧 ZZCOLLAB Variant Manager"
    echo ""
    
    check_dependencies
    check_files
    
    local variants=()
    while IFS= read -r variant; do
        if [[ -n "$variant" ]]; then
            variants+=("$variant")
        fi
    done <<< "$(get_variant_list)"
    
    while true; do
        show_variant_menu
        
        read -p "Enter variant number (1-$((${#variants[@]} + 1))): " choice
        
        # Validate input
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt $((${#variants[@]} + 1)) ]]; then
            log_error "Invalid selection. Please enter a number between 1 and $((${#variants[@]} + 1))"
            continue
        fi
        
        # Handle exit
        if [[ "$choice" -eq $((${#variants[@]} + 1)) ]]; then
            log_info "Exiting variant manager"
            break
        fi
        
        # Get selected variant
        local selected_variant="${variants[$((choice - 1))]}"
        
        # Show variant details
        echo ""
        log_info "Selected variant: $selected_variant"
        local description=$(yq eval ".${selected_variant}.description" "$VARIANT_EXAMPLES")
        local category=$(yq eval ".${selected_variant}.category // \"unknown\"" "$VARIANT_EXAMPLES")
        local size=$(yq eval ".${selected_variant}.size // \"~1GB\"" "$VARIANT_EXAMPLES")
        
        printf "Description: %s\\n" "$description"
        printf "Category: %s\\n" "$category"
        printf "Size: %s\\n" "$size"
        
        if yq eval ".${selected_variant}.notes" "$VARIANT_EXAMPLES" >/dev/null 2>&1; then
            local notes=$(yq eval ".${selected_variant}.notes" "$VARIANT_EXAMPLES")
            printf "Notes: %s\\n" "$notes"
        fi
        
        echo ""
        read -p "Add this variant to your team config? [Y/n] " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_info "Skipping variant addition"
            continue
        fi
        
        add_variant_to_config "$selected_variant"
        
        echo ""
        read -p "Add another variant? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            break
        fi
    done
    
    log_success "Variant management complete!"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi