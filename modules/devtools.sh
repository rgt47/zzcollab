#!/bin/bash
##############################################################################
# ZZCOLLAB DEVTOOLS MODULE
##############################################################################
# 
# PURPOSE: Development tools and configuration management
#          - Makefile for build automation
#          - Configuration files (.gitignore, .Rprofile)
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
    log_debug "Creating Makefile for development workflow automation..."

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
# RPROFILE COPY (simplified from dotfiles integration)
#=============================================================================

# Function: merge_rprofile
# Purpose: Merge user's .Rprofile with zzcollab template
# Strategy:
#   1. User's personal settings (from ~/.Rprofile)
#   2. renv activation
#   3. Critical reproducibility options
#   4. .Last function for auto-snapshot
merge_rprofile() {
    local rprofile_source="$HOME/.Rprofile"
    local rprofile_dest=".Rprofile"
    local template_source="${TEMPLATES_DIR}/.Rprofile"

    # Check if .Rprofile already exists in project
    if [[ -f "$rprofile_dest" ]]; then
        log_debug ".Rprofile already exists in project directory - skipping merge"
        return 0
    fi

    log_info "Creating .Rprofile with user settings + zzcollab template..."

    # Start with header
    cat > "$rprofile_dest" << 'EOF'
# ==========================================
# ZZCOLLAB .Rprofile - Three-Part Structure
# ==========================================
# Part 1: User Personal Settings (from ~/.Rprofile)
# Part 2: renv Activation + Reproducibility Options
# Part 3: Auto-Snapshot on Exit
# ==========================================

EOF

    # Part 1: Add user's personal .Rprofile if it exists
    if [[ -f "$rprofile_source" ]]; then
        log_info "  - Adding personal settings from ~/.Rprofile"
        cat >> "$rprofile_dest" << 'EOF'
# ==========================================
# Part 1: User Personal Settings
# ==========================================
EOF
        cat "$rprofile_source" >> "$rprofile_dest"
        echo "" >> "$rprofile_dest"
    else
        log_debug "  - No ~/.Rprofile found, skipping personal settings"
    fi

    # Part 2 & 3: Add zzcollab template (renv activation, options, .Last)
    if [[ -f "$template_source" ]]; then
        log_info "  - Adding zzcollab template (renv + auto-snapshot)"
        cat >> "$rprofile_dest" << 'EOF'
# ==========================================
# Part 2: ZZCOLLAB Template - renv + Options
# ==========================================
EOF
        # Skip the header from template (first 6 lines), keep the rest
        tail -n +7 "$template_source" >> "$rprofile_dest"
    else
        log_error "Template .Rprofile not found at $template_source"
        return 1
    fi

    track_file "$rprofile_dest"
    log_success "Created merged .Rprofile (user settings + zzcollab template)"
}

#=============================================================================
# CONFIGURATION FILES CREATION (extracted from lines 607-621)
#=============================================================================

# Function: create_config_files
# Purpose: Creates essential development configuration files
# Creates:
#   - .gitignore (comprehensive ignore patterns for R projects)
#   - .Rprofile (R session configuration and package loading)
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
    log_debug "Creating development configuration files..."

    # Create comprehensive .gitignore for R projects
    # Includes: R-specific files, Docker artifacts, IDE files, OS files, data files
    if install_template ".gitignore" ".gitignore" ".gitignore file" "Created comprehensive .gitignore for R projects"; then
        log_info "  - Ignores: R artifacts, Docker files, IDE configs, OS files"
        log_info "  - Protects: large data files, credentials, temporary files"
    else
        log_error "Failed to create .gitignore file"
        return 1
    fi

    # Merge user's .Rprofile with zzcollab template
    # Three-part structure: user settings + renv activation + auto-snapshot
    if merge_rprofile; then
        log_info "  - Part 1: User personal settings (from ~/.Rprofile)"
        log_info "  - Part 2: renv activation + reproducibility options"
        log_info "  - Part 3: Auto-snapshot on exit (.Last function)"
    else
        log_error "Failed to create merged .Rprofile file"
        return 1
    fi

    log_success "Development configuration files created successfully"
}

#=============================================================================
# DEVELOPMENT ENVIRONMENT UTILITIES
#=============================================================================

# Function: show_devtools_files_created
# Purpose: Display created development files
show_devtools_files_created() {
    cat << 'EOF'
🛠️ DEVELOPMENT TOOLS CREATED:

├── Makefile                     # Build automation and Docker workflows
├── .gitignore                   # Comprehensive ignore patterns
├── .Rprofile                    # R session configuration
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
   zzcollab -t TEAMNAME -p PROJECTNAME --profile-name analysis

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

#=============================================================================
# DEVTOOLS MODULE VALIDATION
#=============================================================================



