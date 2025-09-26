#!/bin/bash
##############################################################################
# ZZCOLLAB TEMPLATES MODULE
##############################################################################
# 
# PURPOSE: Template processing engine and file creation utilities
#          - Template copying with variable substitution
#          - Safe file creation functions
#          - Variable substitution system
#
# DEPENDENCIES: core.sh (for logging functions)
##############################################################################

# Validate core module is loaded
# Validate required modules are loaded
require_module "core"

#=============================================================================
# TEMPLATE FILE PROCESSING FUNCTIONS (extracted from lines 250-334)
#=============================================================================

# Function: copy_template_file
# Purpose: Copy a template file and substitute variables within it
# Arguments: 
#   $1 - template filename (relative to TEMPLATES_DIR)
#   $2 - destination path for the copied file
#   $3 - optional description for logging (defaults to destination path)
# Example: copy_template_file "Dockerfile" "Dockerfile" "Docker configuration"
copy_template_file() {
    # Declare local variables to avoid affecting global scope
    local template="$1"
    local dest="$2"
    local description="${3:-$dest}"  # Use $dest as default if $3 not provided
    
    # Input validation: ensure minimum required arguments are provided
    [[ $# -ge 2 ]] || { log_error "copy_template_file: need template and destination"; return 1; }
    
    # Check if the source template file exists
    if [[ ! -f "$TEMPLATES_DIR/$template" ]]; then
        log_error "Template not found: $TEMPLATES_DIR/$template"
        return 1
    fi
    
    # Skip copying if destination file already exists (don't overwrite existing work)
    if [[ -f "$dest" ]]; then
        log_info "$description already exists, skipping creation"
        return 0
    fi
    
    # Create destination directory if it doesn't exist
    local dest_dir
    dest_dir=$(dirname "$dest")  # Extract directory part of destination path
    # Check if we need to create a directory (not current dir) and it doesn't exist
    if [[ "$dest_dir" != "." ]] && [[ ! -d "$dest_dir" ]]; then
        # mkdir -p creates parent directories as needed
        if ! mkdir -p "$dest_dir"; then
            log_error "Failed to create directory: $dest_dir"
            return 1
        fi
    fi
    
    # Copy the template file to the destination
    if ! cp "$TEMPLATES_DIR/$template" "$dest"; then
        log_error "Failed to copy template: $template"
        return 1
    fi
    
    # Replace placeholder variables in the copied file with actual values
    if ! substitute_variables "$dest"; then
        log_error "Failed to substitute variables in: $dest"
        return 1
    fi
    
    log_info "Created $description from template"
}

# Function: substitute_variables
# Purpose: Replace template placeholders (${VAR_NAME}) with actual variable values
# Arguments: $1 - path to file that contains template variables
# Template variables used: ${PKG_NAME}, ${AUTHOR_NAME}, ${AUTHOR_EMAIL}, etc.
# Uses envsubst (environment variable substitution) tool for safe replacement
substitute_variables() {
    local file="$1"
    
    # Verify the file exists before attempting to process it
    [[ -f "$file" ]] || { log_error "File not found: $file"; return 1; }
    
    # Export all variables that templates might reference
    # envsubst only substitutes variables that are in the environment
    export PKG_NAME AUTHOR_NAME AUTHOR_EMAIL AUTHOR_INSTITUTE AUTHOR_INSTITUTE_FULL BASE_IMAGE
    export R_VERSION="${R_VERSION:-latest}"  # Provide default value if not set
    export USERNAME="${USERNAME:-analyst}"   # Default Docker user
    
    # Process the file: read it, substitute variables, write to temp file, then replace original
    # envsubst < "$file" - reads file and substitutes ${VAR} with environment variable values
    # > "$file.tmp" - writes output to temporary file
    # && mv "$file.tmp" "$file" - if substitution succeeds, replace original with processed version
    if ! (envsubst < "$file" > "$file.tmp" && mv "$file.tmp" "$file"); then
        log_error "Failed to substitute variables in file: $file"
        rm -f "$file.tmp"  # Clean up temporary file on failure
        return 1
    fi
}

#=============================================================================
# FILE CREATION UTILITIES (extracted from lines 336-384)
#=============================================================================

# Function: create_file_if_missing
# Purpose: Create a file with specified content only if it doesn't already exist
# Arguments:
#   $1 - file_path: where to create the file
#   $2 - content: what content to put in the file
#   $3 - description: optional description for logging (defaults to file_path)
# Behavior: Preserves existing files to avoid overwriting user modifications
create_file_if_missing() {
    local file_path="$1"
    local content="$2"
    local description="${3:-$file_path}"
    
    # Input validation
    [[ $# -ge 2 ]] || { log_error "create_file_if_missing: need file_path and content"; return 1; }
    
    # Skip if file already exists (preserve user work)
    if [[ -f "$file_path" ]]; then
        log_info "$description already exists, skipping creation"
        return 0
    fi
    
    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$file_path")
    if [[ "$parent_dir" != "." ]] && [[ ! -d "$parent_dir" ]]; then
        if ! mkdir -p "$parent_dir"; then
            log_error "Failed to create directory: $parent_dir"
            return 1
        fi
    fi
    
    # Create the file with the specified content
    # printf is safer than echo for handling content with special characters
    if ! printf '%s\n' "$content" > "$file_path"; then
        log_error "Failed to create file: $file_path"
        return 1
    fi
    
    log_info "Created $description"
}

# Function: install_template
# Purpose: Consolidated template installation with tracking and error handling
# Arguments: $1 - template file, $2 - destination, $3 - description, $4 - success message (optional)
# Returns: 0 on success, 1 on failure
install_template() {
    local template="$1"
    local dest="$2" 
    local description="$3"
    local success_msg="${4:-"Created $description"}"
    
    if copy_template_file "$template" "$dest" "$description"; then
        track_template_file "$template" "$dest"
        log_info "$success_msg"
        return 0
    else
        log_error "Failed to create $description"
        return 1
    fi
}

#=============================================================================
# PARADIGM-SPECIFIC TEMPLATE FUNCTIONS
#=============================================================================

# Function: install_paradigm_template
# Purpose: Install paradigm-specific template files (Makefile, DESCRIPTION)
# Arguments: $1 = paradigm (analysis, manuscript, package)
install_paradigm_template() {
    local paradigm="$1"
    
    [[ -n "$paradigm" ]] || { log_error "install_paradigm_template: paradigm required"; return 1; }
    
    log_info "Installing paradigm-specific templates: $paradigm"
    
    # Define paradigm template mappings
    local makefile_template="paradigms/${paradigm}/Makefile.${paradigm}"
    local description_template="paradigms/${paradigm}/DESCRIPTION.${paradigm}"
    
    # Install Makefile template if it exists
    if [[ -f "$TEMPLATES_DIR/$makefile_template" ]]; then
        if install_template "$makefile_template" "Makefile.${paradigm}" "Paradigm-specific Makefile" "Created ${paradigm} Makefile"; then
            log_info "Created paradigm Makefile: Makefile.${paradigm}"
        else
            log_error "Failed to create paradigm Makefile"
            return 1
        fi
    fi
    
    # Install DESCRIPTION template if it exists  
    if [[ -f "$TEMPLATES_DIR/$description_template" ]]; then
        if install_template "$description_template" "DESCRIPTION.${paradigm}" "Paradigm-specific DESCRIPTION" "Created ${paradigm} DESCRIPTION"; then
            log_info "Created paradigm DESCRIPTION: DESCRIPTION.${paradigm}"
        else
            log_error "Failed to create paradigm DESCRIPTION"
            return 1
        fi
    fi
    
    log_success "Paradigm templates installed: $paradigm"
}

# Function: copy_paradigm_structure
# Purpose: Copy additional paradigm-specific files and create structure
# Arguments: $1 = paradigm (analysis, manuscript, package)  
copy_paradigm_structure() {
    local paradigm="$1"
    
    [[ -n "$paradigm" ]] || { log_error "copy_paradigm_structure: paradigm required"; return 1; }
    
    log_info "Setting up paradigm-specific structure: $paradigm"
    
    case "$paradigm" in
        manuscript)
            # Create manuscript R package infrastructure
            # Copy DESCRIPTION template as DESCRIPTION (not DESCRIPTION.manuscript)
            if [[ -f "$TEMPLATES_DIR/paradigms/manuscript/DESCRIPTION.manuscript" ]]; then
                cp "$TEMPLATES_DIR/paradigms/manuscript/DESCRIPTION.manuscript" "DESCRIPTION"
                track_file "DESCRIPTION"
                log_info "Created DESCRIPTION file"
            fi

            # Create NAMESPACE file
            cat > "NAMESPACE" << 'EOF'
# Generated by roxygen2: do not edit by hand

# Default exports - will be updated by roxygen2 when functions are documented
export()
EOF
            track_file "NAMESPACE"
            log_info "Created NAMESPACE file"

            # Create .Rbuildignore to exclude manuscript files from package build
            cat > ".Rbuildignore" << 'EOF'
^.*\.Rproj$
^\.Rproj\.user$
^manuscript$
^analysis$
^submission$
^\.github$
^data/raw_data$
^\.git$
^\.gitignore$
^README\.md$
EOF
            track_file ".Rbuildignore"
            log_info "Created .Rbuildignore file"

            # Create manuscript-specific files
            echo "# Main Manuscript" > manuscript/paper.Rmd
            echo "# Supplementary Materials" > manuscript/supplementary.Rmd
            echo "@article{example2024," > manuscript/references.bib
            echo "  title={Example Article}," >> manuscript/references.bib
            echo "  author={Author, A.}," >> manuscript/references.bib
            echo "  journal={Journal Name}," >> manuscript/references.bib
            echo "  year={2024}" >> manuscript/references.bib
            echo "}" >> manuscript/references.bib
            track_file "manuscript/paper.Rmd"
            track_file "manuscript/supplementary.Rmd"
            track_file "manuscript/references.bib"

            # Create analysis reproduction scripts
            echo "# Data processing workflow" > analysis/reproduce/01_data_preparation.R
            echo "# Statistical analysis pipeline" > analysis/reproduce/02_statistical_analysis.R
            echo "# Generate all manuscript outputs" > analysis/reproduce/03_figures_tables.R
            echo "# Render all manuscript formats" > analysis/reproduce/04_manuscript_render.R
            track_file "analysis/reproduce/01_data_preparation.R"
            track_file "analysis/reproduce/02_statistical_analysis.R"
            track_file "analysis/reproduce/03_figures_tables.R"
            track_file "analysis/reproduce/04_manuscript_render.R"

            # Create data documentation
            echo "# Raw Data" > data/raw_data/README.md
            echo "# Derived Data" > data/derived_data/README.md
            track_file "data/raw_data/README.md"
            track_file "data/derived_data/README.md"

            # Create submission structure
            echo "# High-resolution figures for publication" > submission/figures/README.md
            echo "# Publication-ready tables" > submission/tables/README.md
            echo "# Supplementary files" > submission/supplementary/README.md
            echo "# Journal-specific manuscript versions" > submission/manuscript_versions/README.md
            track_file "submission/figures/README.md"
            track_file "submission/tables/README.md"
            track_file "submission/supplementary/README.md"
            track_file "submission/manuscript_versions/README.md"

            log_info "Created complete research compendium structure"
            ;;
        analysis)
            # Create analysis-specific files
            echo "# Data exploration" > analysis/exploratory/README.md
            echo "# Statistical modeling" > analysis/modeling/README.md
            echo "# Generated figures" > outputs/figures/README.md
            log_info "Created analysis structure files" 
            ;;
        package)
            # Create package-specific files  
            echo "# Package functions" > R/README.md
            echo "# Package examples" > inst/examples/README.md
            echo "# Package website configuration" > pkgdown/README.md
            log_info "Created package structure files"
            ;;
    esac
}

#=============================================================================
# TEMPLATES MODULE VALIDATION
#=============================================================================

# Set templates module loaded flag
readonly ZZCOLLAB_TEMPLATES_LOADED=true