#!/bin/bash
##############################################################################
# ZZCOLLAB COMPLETE MODULAR IMPLEMENTATION
##############################################################################
# 
# PURPOSE: Complete modular implementation of zzcollab functionality
#          - All 7 modules: core, templates, structure, rpackage, docker, analysis, cicd, devtools
#          - 100% functionality preservation from original zzcollab.sh
#          - Comprehensive manifest tracking for uninstall
#          - Modular architecture with dependency management
#
# USAGE:   ./zzcollab.sh [OPTIONS]
#
# OPTIONS: All original zzcollab.sh options preserved:
#          --no-docker, --dotfiles DIR, --dotfiles-nodot DIR, --base-image NAME
##############################################################################

set -euo pipefail

#=============================================================================
# SCRIPT CONSTANTS AND SETUP
#=============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMPLATES_DIR="$SCRIPT_DIR/templates"
readonly MODULES_DIR="$SCRIPT_DIR/modules"

# Manifest tracking for uninstall functionality
readonly MANIFEST_FILE=".zzcollab_manifest.json"
readonly MANIFEST_TXT=".zzcollab_manifest.txt"

#=============================================================================
# CLI MODULE LOADING AND PROCESSING
#=============================================================================

# Load CLI module first (before other modules)
if [[ -f "$MODULES_DIR/cli.sh" ]]; then
    # shellcheck source=modules/cli.sh
    source "$MODULES_DIR/cli.sh"
else
    log_error "CLI module not found: $MODULES_DIR/cli.sh"
    exit 1
fi

# Process all CLI arguments using CLI module
process_cli "$@"

#=============================================================================
# HANDLE CONFIG COMMANDS (before loading heavy modules)
#=============================================================================

# Handle config commands early (they need minimal dependencies)
if [[ "${CONFIG_COMMAND:-false}" == "true" ]]; then
    echo "DEBUG: Config command detected: $CONFIG_SUBCOMMAND" >&2
    # Load core module for logging
    if [[ -f "$MODULES_DIR/core.sh" ]]; then
        source "$MODULES_DIR/core.sh" >/dev/null 2>&1
        echo "DEBUG: Core module loaded" >&2
    fi
    
    # Load config module
    if [[ -f "$MODULES_DIR/config.sh" ]]; then
        source "$MODULES_DIR/config.sh" >/dev/null 2>&1
        echo "DEBUG: Config module loaded" >&2
        if [[ ${#CONFIG_ARGS[@]} -gt 0 ]]; then
            echo "DEBUG: Calling with args: ${CONFIG_ARGS[*]}" >&2
            handle_config_command "$CONFIG_SUBCOMMAND" "${CONFIG_ARGS[@]}"
        else
            echo "DEBUG: Calling without args" >&2
            handle_config_command "$CONFIG_SUBCOMMAND"
        fi
        echo "DEBUG: About to exit" >&2
        exit 0
    else
        echo "❌ Error: Config module not found: $MODULES_DIR/config.sh"
        exit 1
    fi
fi

#=============================================================================
# EARLY EXIT FOR HELP AND NEXT STEPS (before loading heavy modules)
#=============================================================================

# For init mode help, we need team_init and help modules loaded
# For regular help and next-steps, we can show immediately
if [[ "$INIT_MODE" != "true" ]]; then
    if [[ "${SHOW_HELP:-false}" == "true" ]] || [[ "${SHOW_NEXT_STEPS:-false}" == "true" ]]; then
        # Load core module first (required by help module)
        if [[ -f "$MODULES_DIR/core.sh" ]]; then
            source "$MODULES_DIR/core.sh" >/dev/null 2>&1
        fi
        
        # Load help module
        if [[ -f "$MODULES_DIR/help.sh" ]]; then
            source "$MODULES_DIR/help.sh" >/dev/null 2>&1
            
            if [[ "${SHOW_HELP:-false}" == "true" ]]; then
                show_help
                exit 0
            fi
            
            if [[ "${SHOW_NEXT_STEPS:-false}" == "true" ]]; then
                show_next_steps
                exit 0
            fi
        fi
    fi
fi

#=============================================================================
# MODULE LOADING SYSTEM
#=============================================================================

# Basic logging before modules are loaded (will be replaced by core.sh functions)
log_info() { printf "ℹ️  %s\n" "$*" >&2; }
log_error() { printf "❌ %s\n" "$*" >&2; }
log_success() { printf "✅ %s\n" "$*" >&2; }
log_warning() { printf "⚠️  %s\n" "$*" >&2; }

# Validate modules directory exists
if [[ ! -d "$MODULES_DIR" ]]; then
    log_error "Modules directory not found: $MODULES_DIR"
    log_error "Please ensure you're running this script from the zzcollab directory"
    exit 1
fi

# Load modules in dependency order
log_info "Loading all zzcollab modules..."

# Load core module first (required by all others)
if [[ -f "$MODULES_DIR/core.sh" ]]; then
    log_info "Loading core module..."
    # shellcheck source=modules/core.sh
    source "$MODULES_DIR/core.sh"
else
    log_error "Core module not found: $MODULES_DIR/core.sh"
    exit 1
fi

# Load config module (depends on core, provides defaults for CLI)
if [[ -f "$MODULES_DIR/config.sh" ]]; then
    log_info "Loading config module..."
    # shellcheck source=modules/config.sh
    source "$MODULES_DIR/config.sh"
    # Initialize config system and apply defaults
    init_config_system
else
    log_info "Config module not found - using hard-coded defaults"
fi

# Load templates module (depends on core)
if [[ -f "$MODULES_DIR/templates.sh" ]]; then
    log_info "Loading templates module..."
    # shellcheck source=modules/templates.sh
    source "$MODULES_DIR/templates.sh"
else
    log_error "Templates module not found: $MODULES_DIR/templates.sh"
    exit 1
fi

# Load structure module (depends on core)
if [[ -f "$MODULES_DIR/structure.sh" ]]; then
    log_info "Loading structure module..."
    # shellcheck source=modules/structure.sh
    source "$MODULES_DIR/structure.sh"
else
    log_error "Structure module not found: $MODULES_DIR/structure.sh"
    exit 1
fi

#=============================================================================
# PACKAGE NAME VALIDATION (must be done before rpackage module)
#=============================================================================

# Validate package name using extracted function
PKG_NAME=$(validate_package_name)
readonly PKG_NAME

# Export variables for template substitution
USERNAME="${USERNAME:-analyst}"  # Default Docker user
export PKG_NAME AUTHOR_NAME AUTHOR_EMAIL AUTHOR_INSTITUTE AUTHOR_INSTITUTE_FULL BASE_IMAGE USERNAME MINIMAL_PACKAGES EXTRA_PACKAGES MINIMAL_DOCKER EXTRA_DOCKER MINIMAL_PACKAGES_ONLY

log_info "Package name determined: $PKG_NAME"

# Load remaining modules that depend on PKG_NAME being set
# Note: analysis module is loaded later after directory structure is created
modules_to_load=("utils" "rpackage" "docker" "cicd" "devtools" "team_init" "help")

for module in "${modules_to_load[@]}"; do
    if [[ -f "$MODULES_DIR/${module}.sh" ]]; then
        log_info "Loading ${module} module..."
        # shellcheck source=/dev/null
        source "$MODULES_DIR/${module}.sh"
    else
        log_error "${module^} module not found: $MODULES_DIR/${module}.sh"
        exit 1
    fi
done

#=============================================================================
# HELP AND NEXT STEPS (extracted to modules/help.sh)
#=============================================================================

# Help functions now loaded from modules/help.sh:
# - show_help()
# - show_init_help() 
# - show_next_steps()

#=============================================================================
# GITHUB REPOSITORY CREATION
#=============================================================================

# Function: create_github_repository_workflow
# Purpose: Create GitHub repository and push project
create_github_repository_workflow() {
    # Validate prerequisites
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI (gh) is not installed. Please install it:"
        log_error "  brew install gh  (macOS) or see https://cli.github.com/"
        return 1
    fi
    
    if ! gh auth status >/dev/null 2>&1; then
        log_error "GitHub CLI is not authenticated. Please run: gh auth login"
        return 1
    fi
    
    # Set GitHub account (use team name if not specified)
    local github_account="${GITHUB_ACCOUNT:-$TEAM_NAME}"
    if [[ -z "$github_account" ]]; then
        log_error "GitHub account not specified. Use --github-account or --team flag"
        return 1
    fi
    
    # Determine project name (use current directory if not specified)
    local project_name="${PROJECT_NAME:-$(basename "$(pwd)")}"
    
    log_info "Creating GitHub repository: ${github_account}/${project_name}"
    
    # Check if repository already exists
    if gh repo view "${github_account}/${project_name}" >/dev/null 2>&1; then
        log_error "Repository ${github_account}/${project_name} already exists on GitHub!"
        log_info "Options:"
        log_info "  1. Delete existing: gh repo delete ${github_account}/${project_name} --confirm"
        log_info "  2. Use different name: --project-name NEW_NAME"
        log_info "  3. Push manually: git remote add origin https://github.com/${github_account}/${project_name}.git"
        return 1
    fi
    
    # Initialize git if not already done
    if [[ ! -d ".git" ]]; then
        log_info "Initializing git repository..."
        git init
    fi
    
    # Stage and commit all files
    log_info "Staging and committing project files..."
    git add .
    if git diff --staged --quiet; then
        log_info "No changes to commit"
    else
        git commit -m "🎉 Initial zzcollab project setup

- Complete research compendium structure
- Docker containerization ready
- CI/CD workflows configured
- Private repository for collaborative development

🤖 Generated with [zzcollab](https://github.com/rgt47/zzcollab) --github

Co-Authored-By: zzcollab <noreply@zzcollab.dev>"
    fi
    
    # Create private GitHub repository
    log_info "Creating private repository on GitHub..."
    gh repo create "${github_account}/${project_name}" \
        --private \
        --description "Research compendium for ${project_name} project" \
        --clone=false
    
    # Add remote and push
    log_info "Adding remote and pushing to GitHub..."
    git remote add origin "https://github.com/${github_account}/${project_name}.git"
    git branch -M main
    git push -u origin main
    
    log_success "✅ GitHub repository created: https://github.com/${github_account}/${project_name}"
    log_info ""
    log_info "🎉 Team collaboration ready!"
    log_info ""
    log_info "Team members can now join with:"
    log_info "  git clone https://github.com/${github_account}/${project_name}.git"
    log_info "  cd ${project_name}"
    if [[ -n "$TEAM_NAME" ]]; then
        log_info "  zzcollab -t ${TEAM_NAME} -p ${project_name} -I shell -d ~/dotfiles"
    else
        log_info "  zzcollab -d ~/dotfiles"
    fi
    
    return 0
}

#=============================================================================
# MANIFEST INITIALIZATION
#=============================================================================

init_manifest() {
    if command -v jq >/dev/null 2>&1; then
        cat > "$MANIFEST_FILE" <<EOF
{
  "version": "1.0",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "package_name": "$PKG_NAME",
  "modules_loaded": ["core", "templates", "structure", "rpackage", "docker", "analysis", "cicd", "devtools", "team_init"],
  "command_line_options": {
    "build_docker": $BUILD_DOCKER,
    "dotfiles_dir": "${DOTFILES_DIR}",
    "dotfiles_nodot": $DOTFILES_NODOT,
    "base_image": "$BASE_IMAGE"
  },
  "directories": [],
  "files": [],
  "template_files": [],
  "symlinks": [],
  "dotfiles": [],
  "docker_image": null
}
EOF
        log_success "Initialized JSON manifest file: $MANIFEST_FILE"
    else
        {
            echo "# ZZCOLLAB MANIFEST - Created $(date)"
            echo "# Package: $PKG_NAME"
            echo "# Modules: core, templates, structure, rpackage, docker, analysis, cicd, devtools, team_init"
            echo "# Build Docker: $BUILD_DOCKER"
            echo "# Dotfiles: $DOTFILES_DIR"
            echo "# Base Image: $BASE_IMAGE"
            echo "# Format: type:path"
        } > "$MANIFEST_TXT"
        log_success "Initialized text manifest file: $MANIFEST_TXT (jq not available)"
    fi
}

install_uninstall_script() {
    local uninstall_script="zzcollab-uninstall.sh"
    if [[ -f "$TEMPLATES_DIR/$uninstall_script" ]]; then
        cp "$TEMPLATES_DIR/$uninstall_script" "./$uninstall_script"
        chmod +x "./$uninstall_script"
        track_file "$uninstall_script"
        log_success "Uninstall script installed: ./$uninstall_script"
    else
        log_warning "Uninstall script template not found"
    fi
}

#=============================================================================
# DIRECTORY VALIDATION FUNCTION
#=============================================================================

validate_directory_for_setup() {
    local current_dir
    current_dir=$(basename "$PWD")
    
    # Skip validation for certain directories that are expected to be non-empty
    if [[ "$current_dir" == "zzcollab" ]]; then
        log_warning "Running zzcollab setup in the zzcollab source directory"
        log_warning "This will create project files alongside the zzcollab source code"
        read -p "Are you sure you want to continue? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled by user"
            exit 0
        fi
        return 0
    fi
    
    # Check if directory is empty or contains only basic files
    local file_count
    file_count=$(find . -maxdepth 1 -type f | wc -l)
    
    if [[ $file_count -le 3 ]]; then
        log_info "Directory validation passed ($file_count files found)"
        return 0
    fi
    
    # If more than 3 files, show warning and ask for confirmation
    log_warning "Current directory contains $file_count files"
    log_warning "Running zzcollab setup here may overwrite existing files"
    
    # Show some of the files that would be affected
    log_info "Files in current directory:"
    ls -la | head -10
    if [[ $file_count -gt 7 ]]; then
        log_info "... and $(($file_count - 7)) more files"
    fi
    
    echo ""
    log_warning "zzcollab will create many files and directories in this location"
    log_warning "Consider running in an empty directory or using a subdirectory"
    echo ""
    
    read -p "Continue with setup in this directory? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled by user"
        log_info "To run zzcollab safely:"
        log_info "  1. Create a new directory: mkdir my-project && cd my-project"
        log_info "  2. Run zzcollab there: zzcollab [options]"
        exit 0
    fi
    
    log_info "Proceeding with setup as requested"
    return 0
}

#=============================================================================
# MAIN EXECUTION FUNCTION (identical workflow to original zzcollab.sh)
#=============================================================================

main() {
    # Handle initialization mode first
    if [[ "$INIT_MODE" == "true" ]]; then
        # Handle help for init mode
        if [[ "${SHOW_HELP:-false}" == "true" ]]; then
            show_init_help
            exit 0
        fi
        
        # Validate init parameters and prerequisites
        validate_init_parameters
        validate_init_prerequisites
        
        # Run team initialization
        run_team_initialization
        exit 0
    fi
    
    # Handle build variant mode
    if [[ "${BUILD_VARIANT_MODE:-false}" == "true" ]]; then
        # Note: All modules including team_init are loaded in the main loading section below
        # We just need to call the build variant function after modules are loaded
        BUILD_VARIANT_DEFERRED=true
    fi
    
    # Handle help and next-steps options for normal mode
    if [[ "${SHOW_HELP:-false}" == "true" ]]; then
        show_help
        exit 0
    fi
    
    if [[ "${SHOW_NEXT_STEPS:-false}" == "true" ]]; then
        show_next_steps
        exit 0
    fi
    
    # Handle deferred build variant execution (after all modules loaded)
    if [[ "${BUILD_VARIANT_DEFERRED:-false}" == "true" ]]; then
        # All modules are now loaded, call build variant function
        build_additional_variant "$BUILD_VARIANT"
        exit 0
    fi
    
    log_info "🚀 Starting modular rrtools project setup..."
    log_info "📦 Package name: '$PKG_NAME'"
    log_info "🔧 All modules loaded successfully"
    echo ""
    
    # Validate templates directory
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        log_error "Templates directory not found: $TEMPLATES_DIR"
        log_error "Please ensure you're running this script from the zzcollab directory"
        exit 1
    fi
    
    # Validate directory is safe for setup
    validate_directory_for_setup
    
    # Initialize manifest tracking
    init_manifest
    
    # Execute setup in same order as original zzcollab.sh
    log_info "📁 Creating project structure..."
    create_directory_structure || exit 1
    
    # Load analysis module after directory structure is created
    if [[ -f "$MODULES_DIR/analysis.sh" ]]; then
        log_info "Loading analysis module..."
        # shellcheck source=modules/analysis.sh
        source "$MODULES_DIR/analysis.sh"
    else
        log_error "Analysis module not found: $MODULES_DIR/analysis.sh"
        exit 1
    fi
    
    log_info "📦 Creating R package files..."
    create_core_files || exit 1
    create_renv_setup || exit 1
    
    log_info "⚙️ Creating configuration files..."
    create_config_files || exit 1
    
    log_info "🐳 Creating Docker files..."
    create_docker_files || exit 1
    
    log_info "📝 Creating analysis files..."
    create_analysis_files || exit 1
    
    log_info "📜 Creating research scripts..."
    create_scripts_directory || exit 1
    
    log_info "🚀 Creating GitHub workflows..."
    create_github_workflows || exit 1
    
    log_info "🛠️ Creating development tools..."
    create_makefile || exit 1
    
    log_info "🔗 Creating navigation scripts..."
    create_navigation_scripts || exit 1
    
    # Extract R version for Docker build
    log_info "🔍 Detecting R version..."
    R_VERSION=$(extract_r_version_from_lockfile)
    export R_VERSION
    log_info "Using R version: $R_VERSION"
    
    # Install uninstall script
    install_uninstall_script
    
    # Conditional Docker build (same logic as original)
    if [[ "$BUILD_DOCKER" == "true" ]]; then
        log_info "🐳 Building Docker image..."
        if build_docker_image; then
            log_success "Docker image built successfully"
        else
            log_warning "Docker build failed - you can build manually later with 'make docker-build'"
        fi
    else
        log_info "⏭️ Skipping Docker image build (--no-docker specified)"
    fi
    
    # Initialize renv with snapshot of current environment
    log_info "📦 Creating renv.lock file..."
    if command -v R >/dev/null 2>&1; then
        if R --slave -e "renv::init(bare = TRUE, restart = FALSE); renv::snapshot(prompt = FALSE)" 2>/dev/null; then
            log_success "Created renv.lock with current package environment"
        else
            log_warning "Failed to create renv.lock - run 'renv::init(); renv::snapshot()' manually"
        fi
    else
        log_warning "R not found - run 'renv::init(); renv::snapshot()' after installing R"
    fi
    
    # Create GitHub repository if requested
    if [[ "$CREATE_GITHUB_REPO" == "true" ]]; then
        log_info "🐙 Creating GitHub repository..."
        create_github_repository_workflow
    fi
    
    # Final success message and summary
    echo ""
    log_success "🎉 Modular project setup completed successfully!"
    echo ""
    
    # Show created items count
    local dir_count file_count symlink_count
    dir_count=$(find . -type d | wc -l)
    file_count=$(find . -type f \( ! -path "./.git/*" \) | wc -l)
    symlink_count=$(find . -type l | wc -l)
    
    log_info "📊 Created: $dir_count directories, $file_count files, $symlink_count symlinks"
    log_info "📄 Manifest: $([[ -f "$MANIFEST_FILE" ]] && echo "$MANIFEST_FILE" || echo "$MANIFEST_TXT")"
    
    # Show module summaries
    echo ""
    show_structure_summary
    echo ""
    show_rpackage_summary
    echo ""
    show_docker_summary
    echo ""
    show_analysis_summary
    echo ""
    show_cicd_summary
    echo ""
    show_devtools_summary
    
    echo ""
    log_info "📚 Run '$0 --next-steps' for development workflow guidance"
    log_info "🆘 Run './zzcollab-uninstall.sh' if you need to remove created files"
    log_info "📖 See ZZCOLLAB_USER_GUIDE.md for comprehensive documentation"
    echo ""
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi