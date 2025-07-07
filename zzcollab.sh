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
# COMMAND LINE ARGUMENT PARSING (preserved from original)
#=============================================================================

require_arg() {
    [[ -n "${2:-}" ]] || { echo "❌ Error: $1 requires an argument" >&2; exit 1; }
}

# Initialize variables for command line options with same defaults as original
BUILD_DOCKER=true
DOTFILES_DIR=""
DOTFILES_NODOT=false
BASE_IMAGE="rocker/r-ver"

# New user-friendly interface variables
TEAM_NAME=""
PROJECT_NAME=""
INTERFACE=""

# Process all command line arguments (identical to original zzcollab.sh)
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-docker)
            BUILD_DOCKER=false
            shift
            ;;
        --dotfiles)
            require_arg "$1" "$2"
            DOTFILES_DIR="$2"
            shift 2
            ;;
        --dotfiles-nodot)
            require_arg "$1" "$2"
            DOTFILES_DIR="$2"
            DOTFILES_NODOT=true
            shift 2
            ;;
        --base-image)
            require_arg "$1" "$2"
            BASE_IMAGE="$2"
            shift 2
            ;;
        --team)
            require_arg "$1" "$2"
            TEAM_NAME="$2"
            shift 2
            ;;
        --project-name|--project)
            require_arg "$1" "$2"
            PROJECT_NAME="$2"
            shift 2
            ;;
        --interface)
            require_arg "$1" "$2"
            INTERFACE="$2"
            shift 2
            ;;
        --next-steps)
            # We'll implement this after modules are loaded
            SHOW_NEXT_STEPS=true
            shift
            ;;
        --help|-h)
            # We'll implement this after modules are loaded
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "❌ Error: Unknown option '$1'" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

#=============================================================================
# USER-FRIENDLY INTERFACE PROCESSING
#=============================================================================

# Convert user-friendly flags to BASE_IMAGE if provided
if [[ -n "$TEAM_NAME" && -n "$PROJECT_NAME" && -n "$INTERFACE" ]]; then
    case "$INTERFACE" in
        shell)
            BASE_IMAGE="${TEAM_NAME}/${PROJECT_NAME}core-shell"
            ;;
        rstudio)
            BASE_IMAGE="${TEAM_NAME}/${PROJECT_NAME}core-rstudio"
            ;;
        *)
            echo "❌ Error: Unknown interface '$INTERFACE'" >&2
            echo "Valid interfaces: shell, rstudio" >&2
            exit 1
            ;;
    esac
    echo "ℹ️  Using team image: $BASE_IMAGE"
elif [[ -n "$TEAM_NAME" || -n "$PROJECT_NAME" || -n "$INTERFACE" ]]; then
    # If some team flags are provided but not all, show error
    echo "❌ Error: When using team interface, all flags are required:" >&2
    echo "  --team TEAM_NAME --project-name PROJECT_NAME --interface INTERFACE" >&2
    echo "  Valid interfaces: shell, rstudio" >&2
    exit 1
fi

#=============================================================================
# MODULE LOADING SYSTEM
#=============================================================================

# Basic logging before modules are loaded
log_info() {
    printf "ℹ️  %s\n" "$*" >&2
}

log_error() {
    printf "❌ %s\n" "$*" >&2
}

log_success() {
    printf "✅ %s\n" "$*" >&2
}

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
export PKG_NAME AUTHOR_NAME AUTHOR_EMAIL AUTHOR_INSTITUTE AUTHOR_INSTITUTE_FULL BASE_IMAGE

log_info "Package name determined: $PKG_NAME"

# Load remaining modules that depend on PKG_NAME being set
modules_to_load=("rpackage" "docker" "analysis" "cicd" "devtools")

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
# HELP AND NEXT STEPS (from original zzcollab.sh)
#=============================================================================

show_help() {
    cat << EOF
$0 - Complete Research Compendium Setup (Modular Implementation)

Creates a comprehensive research compendium with R package structure, Docker integration,
analysis templates, and reproducible workflows.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    User-friendly team interface:
    --team NAME              Team name (Docker Hub organization)
    --project-name NAME      Project name  
    --interface TYPE         Interface type: shell, rstudio
    --dotfiles DIR           Copy dotfiles from directory (files with leading dots)
    --dotfiles-nodot DIR     Copy dotfiles from directory (files without leading dots)
    
    Advanced options:
    --base-image NAME        Use custom Docker base image (default: rocker/r-ver)
    --no-docker              Skip Docker image build during setup
    --next-steps             Show development workflow and next steps
    --help, -h               Show this help message

EXAMPLES:
    # Team member joining existing project (recommended)
    $0 --team rgt47 --project-name png1 --interface shell --dotfiles ~/dotfiles
    $0 --team mylab --project study2024 --interface rstudio --dotfiles ~/dotfiles
    
    # Advanced usage with custom base images
    $0 --base-image rocker/tidyverse --dotfiles ~/dotfiles
    $0 --base-image myteam/mycustomimage --dotfiles-nodot ~/dotfiles
    
    # Basic setup for standalone projects
    $0 --dotfiles ~/dotfiles                        # Basic setup with dotfiles
    $0 --no-docker                                  # Setup without Docker build

MODULES INCLUDED:
    core         - Logging, validation, utilities
    templates    - Template processing and file creation
    structure    - Directory structure and navigation
    rpackage     - R package development framework
    docker       - Container integration and builds
    analysis     - Research report and analysis templates
    cicd         - GitHub Actions workflows
    devtools     - Makefile, configs, development tools

CREATED STRUCTURE:
    ├── R/                     # Package functions
    ├── analysis/              # Research workflow
    ├── data/                  # Data management
    ├── tests/                 # Unit tests
    ├── .github/workflows/     # CI/CD automation
    ├── Dockerfile             # Container definition
    ├── Makefile              # Build automation
    └── Symbolic links (a→data, n→analysis, etc.)

For detailed documentation, see ZZCOLLAB_USER_GUIDE.md after setup.
EOF
}

show_next_steps() {
    cat << 'EOF'
🚀 ZZCOLLAB NEXT STEPS

After running the modular setup script, here's how to get started:

📁 PROJECT STRUCTURE:
   Your project now has a complete research compendium with:
   - R package structure with functions and tests
   - Analysis workflow with report templates
   - Docker environment for reproducibility
   - CI/CD workflows for automation

🐳 DOCKER DEVELOPMENT:
   Start your development environment:
   
   make docker-build          # Build the Docker image
   make docker-rstudio        # → http://localhost:8787 (user: analyst, pass: analyst)
   make docker-r              # R console in container
   make docker-zsh            # Interactive shell with your dotfiles
   
📝 ANALYSIS WORKFLOW:
   1. Place raw data in data/raw_data/
   2. Develop analysis scripts in scripts/
   3. Write your report in analysis/report/report.Rmd
   4. Use 'make docker-render' to generate PDF

🔧 PACKAGE DEVELOPMENT:
   make check                 # R CMD check validation
   make test                  # Run testthat tests
   make document              # Generate documentation
   ./dev.sh setup             # Quick development setup

📊 DATA MANAGEMENT:
   - Document datasets in data/metadata/
   - Use analysis/templates/ for common patterns
   - Validate data with scripts in data/validation/

🤝 COLLABORATION:
   git init                   # Initialize version control
   git add .                  # Stage all files
   git commit -m "Initial zzcollab setup"
   # Push to GitHub to activate CI/CD workflows

🔄 AUTOMATION:
   - GitHub Actions will run package checks automatically
   - Papers render automatically when analysis/ changes
   - Use pre-commit hooks for code quality

📄 DOCUMENTATION:
   - See ZZCOLLAB_USER_GUIDE.md for comprehensive guide
   - Use make help for all available commands
   - Check .github/workflows/ for CI/CD documentation

🆘 GETTING HELP:
   make help                 # See all available commands
   ./zzcollab-uninstall.sh  # Remove created files if needed
   
🧹 UNINSTALL:
   All created files are tracked in .zzcollab_manifest.json
   Run './zzcollab-uninstall.sh' to remove everything cleanly

Happy researching! 🎉
EOF
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
  "modules_loaded": ["core", "templates", "structure", "rpackage", "docker", "analysis", "cicd", "devtools"],
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
            echo "# Modules: core, templates, structure, rpackage, docker, analysis, cicd, devtools"
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
# MAIN EXECUTION FUNCTION (identical workflow to original zzcollab.sh)
#=============================================================================

main() {
    # Handle help and next-steps options early
    if [[ "${SHOW_HELP:-false}" == "true" ]]; then
        show_help
        exit 0
    fi
    
    if [[ "${SHOW_NEXT_STEPS:-false}" == "true" ]]; then
        show_next_steps
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
    
    # Initialize manifest tracking
    init_manifest
    
    # Execute setup in same order as original zzcollab.sh
    log_info "📁 Creating project structure..."
    create_directory_structure || exit 1
    
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
    
    log_info "🔗 Creating symbolic links..."
    create_symbolic_links || exit 1
    
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
    main "$@"
fi