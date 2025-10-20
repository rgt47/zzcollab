#!/bin/bash
##############################################################################
# ZZCOLLAB DEVTOOLS MODULE
##############################################################################
# 
# PURPOSE: Development tools and configuration management
#          - Makefile for build automation
#          - Configuration files (.gitignore, .Rprofile)
#          - Personal dotfiles integration
#          - Development environment setup
#
# DEPENDENCIES: core.sh (logging), templates.sh (file creation)
#
# TRACKING: All created development files are tracked for uninstall capability
##############################################################################

# Validate required modules are loaded
require_module "core" "templates"

#=============================================================================
# MANIFEST TRACKING FUNCTIONS
#=============================================================================

# Tracking functions are now provided by core.sh

#=============================================================================
# MAKEFILE CREATION (extracted from lines 561-569)
#=============================================================================

# Function: create_makefile
# Purpose: Creates comprehensive Makefile for development workflow automation
# Creates:
#   - Makefile with Docker and native R targets
#   - Build automation for package development
#   - Container management commands
#   - Paper rendering and testing targets
#
# Makefile Features:
#   - Native R targets (require local R installation)
#   - Docker targets (work without local R)
#   - Platform detection and compatibility
#   - Comprehensive help documentation
#   - Integration with renv and package development
#
# Target Categories:
#   - Package development (build, check, test, document)
#   - Docker operations (build, run, shell access)
#   - Analysis workflow (render paper, run scripts)
#   - Cleanup and maintenance (clean, docker-clean)
#
# Tracking: Makefile is tracked in manifest for uninstall
create_makefile() {
    log_info "Creating Makefile for development workflow automation..."

    # Copy comprehensive Makefile from template
    # Template includes: Docker targets, R package targets, help system, platform detection
    if install_template "Makefile" "Makefile" "Makefile for Docker workflow" "Created Makefile with development automation"; then
        # Modify Makefile for team member workflow if --use-team-image was specified
        if [[ "${USE_TEAM_IMAGE:-false}" == "true" ]]; then
            log_info "Modifying Makefile for team image workflow..."

            # Replace local image references with team image in docker-* targets
            # Add auto-pull with update detection before each docker run
            sed -i.bak '
                /^docker-zsh:$/,/^$/ {
                    s|docker run --rm -it -v \$\$(pwd):/home/analyst/project \$(PACKAGE_NAME)|@docker pull \$(DOCKERHUB_ACCOUNT)/\$(PROJECT_NAME):latest \| grep -q "Downloaded" \&\& echo "✓ Updated team image" \|\| true\n\tdocker run --rm -it -v \$\$(pwd):/home/analyst/project \$(DOCKERHUB_ACCOUNT)/\$(PROJECT_NAME):latest|
                }
                /^docker-rstudio:$/,/^$/ {
                    s|docker run --rm -p 8787:8787 -v \$\$(pwd):/home/analyst/project -e USER=analyst -e PASSWORD=analyst \$(PACKAGE_NAME)|@docker pull \$(DOCKERHUB_ACCOUNT)/\$(PROJECT_NAME):latest \| grep -q "Downloaded" \&\& echo "✓ Updated team image" \|\| true\n\tdocker run --rm -p 8787:8787 -v \$\$(pwd):/home/analyst/project -e USER=analyst -e PASSWORD=analyst \$(DOCKERHUB_ACCOUNT)/\$(PROJECT_NAME):latest|
                }
                /^docker-r:$/,/^$/ {
                    s|docker run --rm -it -v \$\$(pwd):/home/analyst/project \$(PACKAGE_NAME)|@docker pull \$(DOCKERHUB_ACCOUNT)/\$(PROJECT_NAME):latest \| grep -q "Downloaded" \&\& echo "✓ Updated team image" \|\| true\n\tdocker run --rm -it -v \$\$(pwd):/home/analyst/project \$(DOCKERHUB_ACCOUNT)/\$(PROJECT_NAME):latest|
                }
                /^docker-bash:$/,/^$/ {
                    s|docker run --rm -it -v \$\$(pwd):/home/analyst/project \$(PACKAGE_NAME)|@docker pull \$(DOCKERHUB_ACCOUNT)/\$(PROJECT_NAME):latest \| grep -q "Downloaded" \&\& echo "✓ Updated team image" \|\| true\n\tdocker run --rm -it -v \$\$(pwd):/home/analyst/project \$(DOCKERHUB_ACCOUNT)/\$(PROJECT_NAME):latest|
                }
            ' Makefile
            rm -f Makefile.bak

            log_info "Makefile configured for team image: \$(DOCKERHUB_ACCOUNT)/\$(PROJECT_NAME):latest"
        fi

        log_info "Available targets:"
        log_info "  - Docker: make docker-build, make docker-rstudio, make docker-r"
        log_info "  - Package: make check, make test, make document"
        log_info "  - Analysis: make docker-render, make docker-check-renv"
        log_info "  - Help: make help (shows all available targets)"
    else
        log_error "Failed to create Makefile"
        return 1
    fi
}

#=============================================================================
# DOTFILES INTEGRATION (extracted from lines 571-605)
#=============================================================================

# Function: copy_dotfiles
# Purpose: Copy personal development configuration files (dotfiles)
# Supports: Two modes for dotfile naming conventions
#   - Standard mode: files with leading dots (.vimrc, .tmux.conf)
#   - No-dot mode: files without leading dots (vimrc, tmux.conf)
#
# Dotfiles Supported:
#   - Editor configs: .vimrc, .editorconfig
#   - Shell configs: .bashrc, .profile, .aliases, .functions, .exports
#   - Development tools: .tmux.conf, .gitconfig, .inputrc
#   - Search tools: .ctags, .ackrc, .ripgreprc
#
# Integration: Copied dotfiles are automatically available in Docker containers
# Tracking: All copied dotfiles are tracked in manifest for uninstall
copy_dotfiles() {
    # Only copy dotfiles if DOTFILES_DIR is specified
    if [[ -z "${DOTFILES_DIR:-}" ]]; then
        log_info "No dotfiles directory specified - skipping dotfiles copy"
        return 0
    fi

    # Expand tilde in DOTFILES_DIR
    local expanded_dotfiles_dir="${DOTFILES_DIR/#\~/$HOME}"

    log_info "Copying dotfiles from $expanded_dotfiles_dir..."

    # Validate dotfiles directory exists
    if [[ ! -d "$expanded_dotfiles_dir" ]]; then
        log_error "Dotfiles directory not found: $DOTFILES_DIR (expanded: $expanded_dotfiles_dir)"
        return 1
    fi
    
    local copied_count=0
    
    # Handle two different dotfile naming conventions
    if [[ "${DOTFILES_NODOT:-false}" = "true" ]]; then
        # Mode 1: Files without leading dots (e.g., vimrc -> .vimrc)
        log_info "Copying dotfiles without leading dots (adding dots during copy)"
        
        local dotfiles_nodot=(
            "vimrc" "tmux.conf" "gitconfig" "inputrc" "bashrc" 
            "profile" "aliases" "functions" "exports" "editorconfig" 
            "ctags" "ackrc" "ripgreprc"
        )
        
        for dotfile in "${dotfiles_nodot[@]}"; do
            local source_file="$expanded_dotfiles_dir/$dotfile"
            local dest_file=".$dotfile"

            if [[ -f "$source_file" ]]; then
                if cp "$source_file" "$dest_file"; then
                    track_dotfile "$dest_file"
                    log_info "Copied $dotfile -> $dest_file"
                    ((copied_count++))
                else
                    log_warn "Failed to copy $dotfile"
                fi
            fi
        done
    else
        # Mode 2: Files with leading dots (e.g., .vimrc -> .vimrc)
        log_info "Copying dotfiles with leading dots (preserving names)"

        local dotfiles_withdot=(
            ".vimrc" ".tmux.conf" ".gitconfig" ".inputrc" ".bashrc"
            ".profile" ".aliases" ".functions" ".exports" ".editorconfig"
            ".ctags" ".ackrc" ".ripgreprc"
        )

        for dotfile in "${dotfiles_withdot[@]}"; do
            local source_file="$expanded_dotfiles_dir/$dotfile"
            local dest_file="$dotfile"

            if [[ -f "$source_file" ]]; then
                if cp "$source_file" "$dest_file"; then
                    track_dotfile "$dest_file"
                    log_info "Copied $dotfile"
                    ((copied_count++))
                else
                    log_warn "Failed to copy $dotfile"
                fi
            fi
        done
    fi
    
    # Special handling for .zshrc - copy directly (no filtering)
    local zshrc_source=""
    local zshrc_dest=""
    if [[ "${DOTFILES_NODOT:-false}" = "true" ]]; then
        # Look for zshrc without dot
        zshrc_source="$expanded_dotfiles_dir/zshrc"
        zshrc_dest=".zshrc"
    else
        # Look for .zshrc with dot
        zshrc_source="$expanded_dotfiles_dir/.zshrc"
        zshrc_dest=".zshrc"
    fi

    if [[ -f "$zshrc_source" ]]; then
        log_info "Copying .zshrc directly (no filtering)"
        if cp "$zshrc_source" "$zshrc_dest"; then
            track_dotfile "$zshrc_dest"
            log_info "Copied .zshrc"
            ((copied_count++))
        else
            log_warn "Failed to copy .zshrc"
        fi
    fi

    if [[ $copied_count -gt 0 ]]; then
        log_success "Copied $copied_count dotfiles successfully"
        log_info "Dotfiles will be available in Docker containers"
    else
        log_warn "No dotfiles found in $expanded_dotfiles_dir"
    fi
}

##############################################################################
# FUNCTION: cleanup_dotfiles_from_workdir
# PURPOSE:  Remove dotfiles from working directory after Docker build
# USAGE:    cleanup_dotfiles_from_workdir
# ARGS:     None
# RETURNS:  
#   0 - Successfully cleaned up dotfiles
#   1 - No dotfiles to clean up
# GLOBALS:  
#   READ:  None
#   WRITE: None (removes dotfiles from current directory)
# DESCRIPTION:
#   This function removes dotfiles from the working directory after they have
#   been successfully copied into the Docker image. This prevents clutter in
#   the project directory while maintaining the functionality of having
#   dotfiles available in containers.
# CLEANUP STRATEGY:
#   - Only removes files that are typically dotfiles (not project files)
#   - Preserves project-specific configurations (.gitignore, etc.)
#   - Updates manifest tracking to reflect removed files
#   - Provides user feedback about cleanup actions
# SAFETY:
#   - Only removes known dotfile patterns to avoid accidental deletion
#   - Checks file existence before attempting removal
#   - Logs all cleanup actions for transparency
# EXAMPLE:
#   cleanup_dotfiles_from_workdir  # Called after successful Docker build
##############################################################################
cleanup_dotfiles_from_workdir() {
    log_info "🧹 Cleaning up dotfiles from working directory (they're now in Docker image)"
    
    local cleanup_count=0
    
    # List of dotfiles to clean up (those copied during dotfiles setup)
    local dotfiles_to_cleanup=(
        ".vimrc" ".tmux.conf" ".gitconfig" ".inputrc" ".bashrc"
        ".profile" ".aliases" ".functions" ".exports" ".editorconfig"
        ".ctags" ".ackrc" ".ripgreprc" ".zshrc"
    )
    
    for dotfile in "${dotfiles_to_cleanup[@]}"; do
        if [[ -f "$dotfile" ]]; then
            if rm "$dotfile" 2>/dev/null; then
                log_info "Removed: $dotfile"
                ((cleanup_count++))
                
                # Update manifest tracking if available
                if command -v remove_from_manifest >/dev/null 2>&1; then
                    remove_from_manifest "$dotfile" 2>/dev/null || true
                fi
            else
                log_warn "Failed to remove: $dotfile"
            fi
        fi
    done
    
    if [[ $cleanup_count -gt 0 ]]; then
        log_success "Cleaned up $cleanup_count dotfiles from working directory"
        log_info "💡 Dotfiles are preserved in Docker image at /home/analyst/"
    else
        log_info "No dotfiles found to clean up"
        return 1
    fi
    
    return 0
}

#=============================================================================
# CONFIGURATION FILES CREATION (extracted from lines 607-621)
#=============================================================================

# Function: create_config_files
# Purpose: Creates essential development configuration files
# Creates:
#   - .gitignore (comprehensive ignore patterns for R projects)
#   - .Rprofile (R session configuration and package loading)
#   - Integration with personal dotfiles (if specified)
#
# Configuration Features:
#   - Git ignore patterns for R, Docker, IDE files
#   - R session optimization and package management
#   - Development tool integration
#   - Container-aware configurations
#
# Integration: Configurations work with both native and Docker development
# Tracking: All created config files are tracked in manifest for uninstall
create_config_files() {
    log_info "Creating development configuration files..."
    
    # Copy personal dotfiles first (if specified via command line options)
    # This allows personal configurations to be available before creating project configs
    copy_dotfiles
    
    # Create comprehensive .gitignore for R projects
    # Includes: R-specific files, Docker artifacts, IDE files, OS files, data files
    if install_template ".gitignore" ".gitignore" ".gitignore file" "Created comprehensive .gitignore for R projects"; then
        log_info "  - Ignores: R artifacts, Docker files, IDE configs, OS files"
        log_info "  - Protects: large data files, credentials, temporary files"
    else
        log_error "Failed to create .gitignore file"
        return 1
    fi

    # Create R session configuration file
    # Includes: renv activation, CRAN mirror, development package loading
    if install_template ".Rprofile" ".Rprofile" ".Rprofile file" "Created .Rprofile for R session configuration"; then
        log_info "  - Activates renv for package management"
        log_info "  - Sets CRAN mirror for package downloads"
        log_info "  - Loads development tools in interactive sessions"
    else
        log_error "Failed to create .Rprofile file"
        return 1
    fi
    
    log_success "Development configuration files created successfully"
}

#=============================================================================
# DEVELOPMENT ENVIRONMENT UTILITIES
#=============================================================================

# Function: validate_devtools_structure
# Purpose: Verify that all required development files were created successfully
# Checks: Makefile, .gitignore, .Rprofile, dotfiles (if specified)
# Returns: 0 if all files exist, 1 if any are missing
validate_devtools_structure() {
    log_info "Validating development tools structure..."
    
    local -r required_files=(
        "Makefile"
        ".gitignore"
        ".Rprofile"
    )
    
    local missing_files=()
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        log_success "All required development files exist"
        
        # Check for dotfiles if DOTFILES_DIR was specified
        if [[ -n "${DOTFILES_DIR:-}" ]]; then
            local dotfile_count
            dotfile_count=$(find . -maxdepth 1 -name ".*" -type f | wc -l)
            log_info "Found $dotfile_count dotfiles in project directory"
        fi
        
        return 0
    else
        log_error "Missing development files: ${missing_files[*]}"
        return 1
    fi
}

# Function: show_devtools_files_created
# Purpose: Display created development files
show_devtools_files_created() {
    cat << 'EOF'
🛠️ DEVELOPMENT TOOLS CREATED:

├── Makefile                     # Build automation and Docker workflows
├── .gitignore                   # Comprehensive ignore patterns
├── .Rprofile                    # R session configuration
└── Personal dotfiles (optional) # Development environment configs
EOF
}

# Function: show_makefile_targets
# Purpose: Display Makefile target documentation
show_makefile_targets() {
    cat << 'EOF'

⚡ MAKEFILE TARGETS:

🐳 Docker Development:
- make docker-build          # Build Docker image
- make docker-rstudio        # Start RStudio Server (http://localhost:8787)
- make docker-r              # Interactive R console in container
- make docker-bash           # Bash shell in container
- make docker-zsh            # Zsh shell in container (if available)

📦 Package Development:
- make document              # Generate documentation (roxygen2)
- make build                 # Build package tarball
- make check                 # R CMD check --as-cran
- make test                  # Run testthat tests
- make install               # Install package locally

📄 Analysis Workflow:
- make docker-render         # Render research paper in container
- make docker-check-renv     # Validate package dependencies
- make docker-check-renv-fix # Fix package dependencies

🧹 Maintenance:
- make clean                 # Remove build artifacts
- make docker-clean          # Remove Docker image and containers
- make help                  # Show all available targets
EOF
}

# Function: show_configuration_files_info
# Purpose: Display configuration files documentation
show_configuration_files_info() {
    cat << 'EOF'

🔧 CONFIGURATION FILES:

📝 .gitignore Features:
- R-specific ignore patterns (*.Rproj.user, .RData, .Rhistory)
- Docker artifacts (containers, images, build cache)
- IDE files (.vscode/, .idea/, RStudio files)
- OS files (.DS_Store, Thumbs.db)
- Data files (configurable for large datasets)

⚙️ .Rprofile Features:
- Automatic renv activation for package management
- CRAN mirror configuration for faster downloads
- Development package loading (devtools, usethis)
- Interactive session optimizations

💻 Personal Dotfiles:
- Editor configurations (.vimrc, .editorconfig)
- Shell configurations (.bashrc, .aliases, .functions)
- Development tools (.tmux.conf, .gitconfig)
- Available in both native and Docker environments
EOF
}

# Function: show_getting_started_guide
# Purpose: Display getting started instructions
show_getting_started_guide() {
    cat << 'EOF'

🚀 GETTING STARTED:

IMPORTANT: You must create a zzcollab PROJECT first (not use this source repo).

1. Navigate to your projects directory:
   cd ~/projects   # Or wherever you keep your work

2. Create a new zzcollab project:
   mkdir PROJECTNAME && cd PROJECTNAME
   zzcollab -t TEAMNAME -p PROJECTNAME --profile-name analysis -d ~/dotfiles

3. Build Docker image:
   make docker-build

4. Start development in your PROJECT directory:
   make docker-rstudio    # RStudio at localhost:8787
   make docker-zsh        # Command-line environment
   make help              # See all available commands

Note: Make targets (docker-rstudio, docker-zsh, etc.) only work in zzcollab
      project directories, NOT in the zzcollab source repository.
EOF
}

# Function: show_devtools_summary
# Purpose: Display development tools summary and usage instructions (coordinating function)
show_devtools_summary() {
    log_info "Development tools summary:"
    show_devtools_files_created
    show_makefile_targets
    show_configuration_files_info
    show_getting_started_guide
}

# Function: create_development_scripts
# Purpose: Create additional development utility scripts
# Optional: Provides common development tasks as standalone scripts
create_development_scripts() {
    log_info "Creating development utility scripts..."
    
    # Create package development helper script
    local dev_script='#!/bin/bash
# Development Helper Script
# Common tasks for R package development

set -euo pipefail

# Logging functions are provided by core.sh

# Function: quick setup for new development session
dev_setup() {
    log_info "Setting up development environment..."
    
    # Load renv if available
    if [[ -f "renv/activate.R" ]]; then
        log_info "Activating renv..."
        Rscript -e "source('\''renv/activate.R'\'')"
    fi
    
    # Check package status
    log_info "Checking package structure..."
    Rscript -e "devtools::check_built()" || log_warn "Package check issues found"
    
    # Load package for development
    log_info "Loading package for development..."
    Rscript -e "devtools::load_all()" || log_error "Failed to load package"
    
    log_info "Development environment ready!"
}

# Function: quick test and check
dev_test() {
    log_info "Running development tests..."
    
    # Run tests
    log_info "Running testthat tests..."
    Rscript -e "devtools::test()" || log_error "Tests failed"
    
    # Generate documentation
    log_info "Updating documentation..."
    Rscript -e "devtools::document()" || log_error "Documentation generation failed"
    
    # Quick check
    log_info "Running package check..."
    Rscript -e "devtools::check()" || log_error "Package check failed"
    
    log_info "Development testing complete!"
}

# Function: render report
dev_render() {
    log_info "Rendering research report..."
    
    if [[ -f "analysis/paper/report.Rmd" ]]; then
        Rscript -e "rmarkdown::render('\''analysis/paper/report.Rmd'\'')" || log_error "Report rendering failed"
        log_info "Report rendered successfully!"
    else
        log_error "No report.Rmd found in analysis/paper/"
    fi
}

# Main command dispatcher
case "${1:-}" in
    setup)
        dev_setup
        ;;
    test)
        dev_test
        ;;
    render)
        dev_render
        ;;
    *)
        echo "Development Helper Script"
        echo "Usage: $0 {setup|test|render}"
        echo ""
        echo "Commands:"
        echo "  setup  - Set up development environment"
        echo "  test   - Run tests and checks"
        echo "  render - Render research paper"
        exit 1
        ;;
esac'
    
    if create_file_if_missing "dev.sh" "$dev_script" "development helper script"; then
        chmod +x "dev.sh"
        track_file "dev.sh"
        log_info "Created development helper script: ./dev.sh"
        log_info "Usage: ./dev.sh {setup|test|render}"
    else
        log_warn "Failed to create development helper script"
    fi
    
    log_success "Development utility scripts created"
}

#=============================================================================
# DEVTOOLS MODULE VALIDATION
#=============================================================================

# Validate that required variables are available for dotfiles
if [[ -n "${DOTFILES_DIR:-}" ]]; then
    # Expand tilde in DOTFILES_DIR for validation
    expanded_dotfiles_dir="${DOTFILES_DIR/#\~/$HOME}"
    if [[ ! -d "$expanded_dotfiles_dir" ]]; then
        log_warn "DOTFILES_DIR specified but directory not found: $DOTFILES_DIR (expanded: $expanded_dotfiles_dir)"
    fi
fi


