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

    # Success - no logging here, let calling function handle user messages
    return 0
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

    # Additional variables for manuscript paradigm
    export PACKAGE_NAME="$PKG_NAME"  # Alias for consistency
    export AUTHOR_LAST="${AUTHOR_LAST:-}"  # Author last name
    export AUTHOR_ORCID="${AUTHOR_ORCID:-}"  # ORCID identifier
    export MANUSCRIPT_TITLE="${MANUSCRIPT_TITLE:-Research Compendium Analysis}"  # Default manuscript title
    export DATE="$(date +%Y-%m-%d)"  # Current date
    export GITHUB_ACCOUNT="${GITHUB_ACCOUNT:-}"  # GitHub account name
    
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
# UNIFIED PARADIGM TEMPLATE FUNCTIONS
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

            # Create manuscript-specific files from templates
            copy_template_file "paradigms/manuscript/paper.Rmd" "manuscript/paper.Rmd" "Main manuscript"
            copy_template_file "paradigms/manuscript/supplementary.Rmd" "manuscript/supplementary.Rmd" "Supplementary materials"
            copy_template_file "paradigms/manuscript/references.bib" "manuscript/references.bib" "Bibliography"
            track_file "manuscript/paper.Rmd"
            track_file "manuscript/supplementary.Rmd"
            track_file "manuscript/references.bib"

            # Create analysis reproduction scripts from templates
            copy_template_file "paradigms/manuscript/01_data_preparation.R" "analysis/reproduce/01_data_preparation.R" "Data preparation script"
            copy_template_file "paradigms/manuscript/02_statistical_analysis.R" "analysis/reproduce/02_statistical_analysis.R" "Statistical analysis script"
            copy_template_file "paradigms/manuscript/03_figures_tables.R" "analysis/reproduce/03_figures_tables.R" "Figures and tables script"
            copy_template_file "paradigms/manuscript/04_manuscript_render.R" "analysis/reproduce/04_manuscript_render.R" "Manuscript rendering script"
            track_file "analysis/reproduce/01_data_preparation.R"
            track_file "analysis/reproduce/02_statistical_analysis.R"
            track_file "analysis/reproduce/03_figures_tables.R"
            track_file "analysis/reproduce/04_manuscript_render.R"

            # Create example R package functions
            copy_template_file "paradigms/manuscript/example_functions.R" "R/analysis_functions.R" "Example analysis functions"
            track_file "R/analysis_functions.R"

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
            # Create comprehensive analysis workflow from templates
            copy_template_file "paradigms/analysis/01_exploratory_analysis.R" "scripts/01_exploratory_analysis.R" "Exploratory data analysis script"
            copy_template_file "paradigms/analysis/02_statistical_modeling.R" "scripts/02_statistical_modeling.R" "Statistical modeling script"
            copy_template_file "paradigms/analysis/03_model_validation.R" "scripts/03_model_validation.R" "Model validation script"
            copy_template_file "paradigms/analysis/04_interactive_dashboard.Rmd" "scripts/04_interactive_dashboard.Rmd" "Interactive dashboard template"
            copy_template_file "paradigms/analysis/05_automated_report.Rmd" "scripts/05_automated_report.Rmd" "Automated report template"
            copy_template_file "paradigms/analysis/example_analysis_functions.R" "scripts/analysis_functions.R" "Example analysis utility functions"

            # Track all created files
            track_file "scripts/01_exploratory_analysis.R"
            track_file "scripts/02_statistical_modeling.R"
            track_file "scripts/03_model_validation.R"
            track_file "scripts/04_interactive_dashboard.Rmd"
            track_file "scripts/05_automated_report.Rmd"
            track_file "scripts/analysis_functions.R"

            # Create directory documentation files
            echo "# Analysis Scripts" > scripts/README.md
            echo "" >> scripts/README.md
            echo "This directory contains the complete analysis workflow templates:" >> scripts/README.md
            echo "- \`01_exploratory_analysis.R\`: Systematic EDA with quality assessment" >> scripts/README.md
            echo "- \`02_statistical_modeling.R\`: tidymodels pipeline for model training" >> scripts/README.md
            echo "- \`03_model_validation.R\`: Cross-validation and robustness testing" >> scripts/README.md
            echo "- \`04_interactive_dashboard.Rmd\`: Shiny dashboard for data exploration" >> scripts/README.md
            echo "- \`05_automated_report.Rmd\`: Parameterized reports with multiple formats" >> scripts/README.md
            echo "- \`analysis_functions.R\`: Reusable utility functions for analysis" >> scripts/README.md
            track_file "scripts/README.md"

            echo "# Exploratory Data Analysis" > analysis/exploratory/README.md
            echo "" >> analysis/exploratory/README.md
            echo "This directory contains outputs from exploratory data analysis:" >> analysis/exploratory/README.md
            echo "- Session logs and data quality reports generated by \`scripts/01_exploratory_analysis.R\`" >> analysis/exploratory/README.md
            echo "- EDA outputs and diagnostic files" >> analysis/exploratory/README.md
            track_file "analysis/exploratory/README.md"

            echo "# Statistical Modeling" > analysis/modeling/README.md
            echo "" >> analysis/modeling/README.md
            echo "This directory contains statistical modeling outputs:" >> analysis/modeling/README.md
            echo "- Model objects and performance metrics from \`scripts/02_statistical_modeling.R\`" >> analysis/modeling/README.md
            echo "- Saved models, hyperparameter tuning results, and training logs" >> analysis/modeling/README.md
            track_file "analysis/modeling/README.md"

            echo "# Model Validation" > analysis/validation/README.md
            echo "" >> analysis/validation/README.md
            echo "This directory contains model validation outputs:" >> analysis/validation/README.md
            echo "- Cross-validation results and robustness testing from \`scripts/03_model_validation.R\`" >> analysis/validation/README.md
            echo "- Bootstrap confidence intervals and sensitivity analysis results" >> analysis/validation/README.md
            track_file "analysis/validation/README.md"

            echo "# Generated Figures" > outputs/figures/README.md
            echo "" >> outputs/figures/README.md
            echo "This directory contains all generated figures from analysis workflows:" >> outputs/figures/README.md
            echo "- High-resolution PNG and PDF outputs" >> outputs/figures/README.md
            echo "- Figures generated with reproducible seeds and session logging" >> outputs/figures/README.md
            track_file "outputs/figures/README.md"

            echo "# Generated Tables" > outputs/tables/README.md
            echo "" >> outputs/tables/README.md
            echo "This directory contains all generated tables from analysis workflows:" >> outputs/tables/README.md
            echo "- CSV format for data interchange" >> outputs/tables/README.md
            echo "- Model performance metrics and statistical summaries" >> outputs/tables/README.md
            track_file "outputs/tables/README.md"

            echo "# Analysis Reports" > reports/README.md
            echo "" >> reports/README.md
            echo "This directory contains additional reporting templates:" >> reports/README.md
            echo "- \`dashboard/\`: Outputs from interactive dashboards" >> reports/README.md
            echo "- Generated HTML reports and visualizations" >> reports/README.md
            echo "- All reports are parameterized and reproducible" >> reports/README.md
            track_file "reports/README.md"


            log_info "Created comprehensive analysis workflow structure"
            ;;
        package)
            # Create comprehensive R package development environment from templates
            copy_template_file "paradigms/package/example_functions.R" "R/example_functions.R" "Example package functions with roxygen2 documentation"
            copy_template_file "paradigms/package/sample_dataset.R" "R/sample_dataset.R" "Sample dataset documentation"
            copy_template_file "paradigms/package/test-example-functions.R" "tests/testthat/test-example-functions.R" "Comprehensive function tests"
            copy_template_file "paradigms/package/test-helpers.R" "tests/testthat/helper-test-functions.R" "Testing helper functions"
            copy_template_file "paradigms/package/dev_workflow.R" "dev_workflow.R" "Package development workflow script"
            copy_template_file "paradigms/package/getting-started.Rmd" "vignettes/getting-started.Rmd" "Getting started vignette"
            copy_template_file "paradigms/package/advanced-usage.Rmd" "vignettes/advanced-usage.Rmd" "Advanced usage vignette"
            copy_template_file "paradigms/package/_pkgdown.yml" "_pkgdown.yml" "pkgdown website configuration"
            copy_template_file "paradigms/package/NAMESPACE_template" "NAMESPACE" "Package namespace file"

            # Track all created files
            track_file "R/example_functions.R"
            track_file "R/sample_dataset.R"
            track_file "tests/testthat/test-example-functions.R"
            track_file "tests/testthat/helper-test-functions.R"
            track_file "dev_workflow.R"
            track_file "vignettes/getting-started.Rmd"
            track_file "vignettes/advanced-usage.Rmd"
            track_file "_pkgdown.yml"
            track_file "NAMESPACE"

            # Create comprehensive directory documentation
            echo "# Package Functions" > R/README.md
            echo "" >> R/README.md
            echo "This directory contains the main package functions:" >> R/README.md
            echo "- \`example_functions.R\`: Comprehensive examples with roxygen2 documentation" >> R/README.md
            echo "- \`sample_dataset.R\`: Documentation for included datasets" >> R/README.md
            echo "" >> R/README.md
            echo "All functions include:" >> R/README.md
            echo "- Proper roxygen2 documentation" >> R/README.md
            echo "- Input validation and error handling" >> R/README.md
            echo "- Comprehensive examples" >> R/README.md
            echo "- Integration with other R packages" >> R/README.md
            track_file "R/README.md"

            echo "# Package Testing Framework" > tests/testthat/README.md
            echo "" >> tests/testthat/README.md
            echo "This directory contains comprehensive package tests:" >> tests/testthat/README.md
            echo "- \`test-example-functions.R\`: Complete test suite for package functions" >> tests/testthat/README.md
            echo "- \`helper-test-functions.R\`: Testing utilities and helper functions" >> tests/testthat/README.md
            echo "" >> tests/testthat/README.md
            echo "Testing best practices implemented:" >> tests/testthat/README.md
            echo "- Comprehensive coverage including edge cases" >> tests/testthat/README.md
            echo "- Clear test descriptions and error messages" >> tests/testthat/README.md
            echo "- Custom expectations for package-specific validations" >> tests/testthat/README.md
            echo "- Helper functions to reduce test code duplication" >> tests/testthat/README.md
            track_file "tests/testthat/README.md"

            echo "# Package Examples" > inst/examples/README.md
            echo "" >> inst/examples/README.md
            echo "This directory contains example scripts and data files:" >> inst/examples/README.md
            echo "- Example analysis workflows using package functions" >> inst/examples/README.md
            echo "- Sample data files for testing and demonstration" >> inst/examples/README.md
            echo "- Template scripts for common use cases" >> inst/examples/README.md
            echo "" >> inst/examples/README.md
            echo "Examples demonstrate:" >> inst/examples/README.md
            echo "- Best practices for package usage" >> inst/examples/README.md
            echo "- Integration with other R packages" >> inst/examples/README.md
            echo "- Real-world analysis scenarios" >> inst/examples/README.md
            track_file "inst/examples/README.md"

            echo "# Package Website Configuration" > pkgdown/README.md
            echo "" >> pkgdown/README.md
            echo "This directory contains pkgdown website configuration:" >> pkgdown/README.md
            echo "- Custom CSS and JavaScript for website styling" >> pkgdown/README.md
            echo "- Additional website assets and images" >> pkgdown/README.md
            echo "- Override templates for custom website structure" >> pkgdown/README.md
            echo "" >> pkgdown/README.md
            echo "Website features:" >> pkgdown/README.md
            echo "- Professional documentation site" >> pkgdown/README.md
            echo "- Interactive function reference" >> pkgdown/README.md
            echo "- Comprehensive vignette display" >> pkgdown/README.md
            echo "- Search functionality and navigation" >> pkgdown/README.md
            track_file "pkgdown/README.md"

            echo "# Package Vignettes" > vignettes/README.md
            echo "" >> vignettes/README.md
            echo "This directory contains comprehensive package documentation:" >> vignettes/README.md
            echo "- \`getting-started.Rmd\`: Introduction and basic usage" >> vignettes/README.md
            echo "- \`advanced-usage.Rmd\`: Advanced features and workflows" >> vignettes/README.md
            echo "" >> vignettes/README.md
            echo "Vignette features:" >> vignettes/README.md
            echo "- Executable code examples" >> vignettes/README.md
            echo "- Best practices and recommendations" >> vignettes/README.md
            echo "- Integration patterns with other packages" >> vignettes/README.md
            echo "- Performance tips and troubleshooting" >> vignettes/README.md
            track_file "vignettes/README.md"

            echo "# Package Data" > data/README.md
            echo "" >> data/README.md
            echo "This directory contains package datasets:" >> data/README.md
            echo "- \`sample_research_data.rda\`: Comprehensive research dataset (200 observations)" >> data/README.md
            echo "- \`small_test_data.rda\`: Minimal test dataset (20 observations)" >> data/README.md
            echo "" >> data/README.md
            echo "Dataset features:" >> data/README.md
            echo "- Realistic data patterns and structures" >> data/README.md
            echo "- Missing data for testing robustness" >> data/README.md
            echo "- Multiple variable types and groupings" >> data/README.md
            echo "- Comprehensive documentation with examples" >> data/README.md
            track_file "data/README.md"

            echo "# Raw Data Processing" > data-raw/README.md
            echo "" >> data-raw/README.md
            echo "This directory contains scripts for creating package datasets:" >> data-raw/README.md
            echo "- Data generation scripts with reproducible seeds" >> data-raw/README.md
            echo "- Data processing and cleaning workflows" >> data-raw/README.md
            echo "- Documentation of data creation procedures" >> data-raw/README.md
            echo "" >> data-raw/README.md
            echo "Best practices:" >> data-raw/README.md
            echo "- Reproducible data generation" >> data-raw/README.md
            echo "- Clear documentation of data sources" >> data-raw/README.md
            echo "- Version control of data creation scripts" >> data-raw/README.md
            track_file "data-raw/README.md"

            echo "# Manual Pages" > man/README.md
            echo "" >> man/README.md
            echo "This directory contains generated R documentation files:" >> man/README.md
            echo "- Generated automatically from roxygen2 comments" >> man/README.md
            echo "- Function documentation (.Rd files)" >> man/README.md
            echo "- Dataset documentation" >> man/README.md
            echo "- Package-level documentation" >> man/README.md
            echo "" >> man/README.md
            echo "⚠️  Do not edit files in this directory manually!" >> man/README.md
            echo "Documentation is generated from roxygen2 comments in R/ files" >> man/README.md
            track_file "man/README.md"

            log_info "Created comprehensive R package development environment"
            ;;
    esac
}

#=============================================================================
# TEMPLATES MODULE VALIDATION
#=============================================================================

# Set templates module loaded flag
readonly ZZCOLLAB_TEMPLATES_LOADED=true