#!/bin/bash
##############################################################################
# ZZCOLLAB HELP MODULE
##############################################################################
# 
# PURPOSE: Help system and user guidance
#          - Main help documentation
#          - Team initialization help
#          - Next steps guidance
#          - Usage examples and workflows
#
# DEPENDENCIES: core.sh (logging)
#
# TRACKING: No file creation - pure documentation
##############################################################################

# Validate required modules are loaded
require_module "core"

#=============================================================================
# MAIN HELP FUNCTION
#=============================================================================

# Function: show_help
# Purpose: Display comprehensive help for main zzcollab usage
show_help() {
    show_help_header
    show_help_examples  
    show_help_config
    show_help_footer
}

# Original large function preserved for reference (can be removed later)
_original_show_help() {
    cat << EOF
$0 - Complete Research Compendium Setup (Modular Implementation)

Creates a comprehensive research compendium with R package structure, Docker integration,
analysis templates, and reproducible workflows.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    Team initialization (Developer 1 - Team Lead):
    -i, --init                   Initialize new team project with Docker images and GitHub repo
    -t, --team-name NAME         Team name (Docker Hub organization) [required with --init]
    -p, --project-name NAME      Project name [required with --init]
    -g, --github-account NAME    GitHub account (default: same as team-name)
    -B, --init-base-image TYPE   Base image for team setup: r-ver, rstudio, verse, all (default: r-ver - shell only)
        --variants-config FILE   Use config.yaml for unlimited custom variants (supersedes -B)
    
    Team collaboration (Developer 2+ - Team Members):
    -t, --team NAME              Team name (Docker Hub organization)
    -p, --project-name NAME      Project name  
    -I, --interface TYPE         Interface type: shell, rstudio, verse
    
    Common options:
    -d, --dotfiles DIR           Copy dotfiles from directory (files with leading dots)
    -D, --dotfiles-nodot DIR     Copy dotfiles from directory (files without leading dots)
    
    Advanced options:
    -b, --base-image NAME        Use custom Docker base image (default: rocker/r-ver)
    -n, --no-docker              Skip Docker image build during setup
    -V, --build-variant TYPE     Build additional team image variant: r-ver, rstudio, verse
    -G, --github                 Automatically create private GitHub repository and push
        --next-steps             Show development workflow and next steps
    
    Build modes (simplified control):
    -F, --fast                 Fast mode: minimal Docker + lightweight packages (fastest setup)
                              → 9 packages: renv, here, usethis, devtools, testthat, knitr, rmarkdown, targets
    -S, --standard             Standard mode: balanced Docker + standard packages (default)
                              → 17 packages: renv, here, usethis, devtools, dplyr, ggplot2, tidyr,
                                testthat, palmerpenguins, broom, knitr, rmarkdown, targets, janitor, DT, conflicted
    -C, --comprehensive        Comprehensive mode: extended Docker + full packages (kitchen sink)
                              → 47 packages: includes tidymodels, shiny, plotly, quarto, flexdashboard,
                                survival, lme4, database connectors, parallel processing, and more
    
    -y, --yes                   Skip confirmation prompt (for automation)
        --force                 Skip directory validation (advanced users - use with caution)
    
    -h, --help                   Show this help message

EXAMPLES:
    # Team Lead - Initialize new team project (Developer 1)
    $0 -i -t rgt47 -p research-study -d ~/dotfiles
    $0 --init --team-name mylab --project-name study2024 --github-account myorg
    $0 -i -t rgt47 -p research-study -y -d ~/dotfiles                          # Skip confirmation (automation)
    
    # Alternative: Create directory first, then run in it (project name auto-detected)
    mkdir png1 && cd png1 && $0 -i -t rgt47 -d ~/dotfiles
    
    # NEW: Initialize with specific base image only
    $0 -i -t rgt47 -p study -B r-ver -d ~/dotfiles                         # Build only shell variant
    $0 -i -t rgt47 -p study -B rstudio -d ~/dotfiles                       # Build only RStudio variant  
    $0 -i -t rgt47 -p study -B verse -d ~/dotfiles                         # Build only verse variant
    
    # Team Members - Join existing project (Developer 2+)
    $0 -t rgt47 -p research-study -I shell -d ~/dotfiles
    $0 --team mylab --project-name study2024 --interface rstudio --dotfiles ~/dotfiles
    $0 -t rgt47 -p research-study -I verse -d ~/dotfiles                   # Use verse for publishing
    
    # Advanced usage with custom base images
    $0 -b rocker/tidyverse -d ~/dotfiles
    $0 --base-image myteam/mycustomimage --dotfiles-nodot ~/dotfiles
    
    # Basic setup for standalone projects
    $0 -d ~/dotfiles                                # Basic setup with dotfiles
    $0 -d ~/dotfiles -G                             # Setup with automatic GitHub repository creation
    
    # NEW: Simplified build modes (recommended)
    $0 -i -t rgt47 -p study -F -d ~/dotfiles                      # Fast mode: minimal Docker + lightweight packages
    $0 -i -t rgt47 -p study -S -d ~/dotfiles                      # Standard mode: balanced setup (default)
    $0 -i -t rgt47 -p study -C -d ~/dotfiles                      # Comprehensive mode: extended Docker + full packages
    $0 -n                                                          # Setup without Docker build
    
    # Build additional team image variants after initialization
    $0 -V rstudio                                                 # Build RStudio variant after r-ver-only init
    $0 -V verse                                                   # Build verse variant
    $0 -V r-ver -t rgt47                                          # Build shell variant (with explicit team name)

MODULES INCLUDED:
    core         - Logging, validation, utilities
    templates    - Template processing and file creation
    structure    - Directory structure and navigation
    rpackage     - R package development framework
    docker       - Container integration and builds
    analysis     - Research report and analysis templates
    cicd         - GitHub Actions workflows
    devtools     - Makefile, configs, development tools
    team_init    - Team setup and initialization workflows

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

#=============================================================================
# TEAM INITIALIZATION HELP FUNCTION
#=============================================================================

# Function: show_init_usage_and_options
# Purpose: Display init command usage and options
show_init_usage_and_options() {
    cat << EOF
\$0 --init - Team initialization for ZZCOLLAB research collaboration

USAGE:
    \$0 --init --team-name TEAM --project-name PROJECT [OPTIONS]

REQUIRED:
    -t, --team-name NAME        Docker Hub team/organization name
    -p, --project-name NAME     Project name (will be used for directories and images)

OPTIONAL:
    -g, --github-account NAME   GitHub account name (default: same as team-name)
    -d, --dotfiles PATH         Path to dotfiles directory (files already have dots)
    -D, --dotfiles-nodot PATH   Path to dotfiles directory (files need dots added)
    -f, --dockerfile PATH       Custom Dockerfile path (default: templates/Dockerfile)
    -P, --prepare-dockerfile    Set up project and Dockerfile for editing, then exit
    
    # Build modes (simplified control):
    -F, --fast                 Fast mode: minimal Docker + lightweight packages (fastest setup)
                              → 9 packages: renv, here, usethis, devtools, testthat, knitr, rmarkdown, targets
    -S, --standard             Standard mode: balanced Docker + standard packages (default)
                              → 17 packages: renv, here, usethis, devtools, dplyr, ggplot2, tidyr,
                                testthat, palmerpenguins, broom, knitr, rmarkdown, targets, janitor, DT, conflicted
    -C, --comprehensive        Comprehensive mode: extended Docker + full packages (kitchen sink)
                              → 47 packages: includes tidymodels, shiny, plotly, quarto, flexdashboard,
                                survival, lme4, database connectors, parallel processing, and more
    
    -y, --yes                  Skip confirmation prompt (for automation)
        --force                Skip directory validation (advanced users - use with caution)
    
    -h, --help                 Show this help message
EOF
}

# Function: show_init_examples
# Purpose: Display team initialization examples
show_init_examples() {
    cat << EOF

EXAMPLES:
    # Prepare project for Dockerfile editing (Developer 1 workflow)
    \$0 -i -t rgt47 -p research-study -P
    # Edit research-study/Dockerfile.teamcore as needed, then run:
    \$0 -i -t rgt47 -p research-study

    # Direct setup with standard Dockerfile
    \$0 -i -t rgt47 -p research-study -d ~/dotfiles
    
    # Fast mode: minimal Docker + lightweight packages
    \$0 -i -t rgt47 -p research-study -F -d ~/dotfiles
    
    # Standard mode: balanced setup (default)
    \$0 -i -t rgt47 -p research-study -S -d ~/dotfiles
    
    # Comprehensive mode: extended Docker + full packages
    \$0 -i -t rgt47 -p research-study -C -d ~/dotfiles
    
    # Config-based variants: unlimited custom environments
    \$0 -i -t rgt47 -p research-study --variants-config config.yaml
    
    # Or enable by default in config.yaml (set use_config_variants: true):
    \$0 -i -t rgt47 -p research-study    # Uses config.yaml automatically
    
    # Specialized examples (edit config.yaml to enable):
    # - Alpine Linux variants (~200MB vs ~1GB, ideal for CI/CD)  
    # - R-hub testing environments (CRAN-compatible package testing)
    # - Domain-specific: bioinformatics, geospatial, HPC, etc.
    
    # Alternative: Create directory first, then auto-detect project name
    mkdir png1 && cd png1 && \$0 -i -t rgt47 -d ~/dotfiles

    # With custom GitHub account
    \$0 --init --team-name rgt47 --project-name research-study --github-account mylab

    # With dotfiles (files already have dots: .bashrc, .vimrc, etc.)
    \$0 --init --team-name rgt47 --project-name research-study --dotfiles ~/dotfiles

    # With dotfiles that need dots added (files like: bashrc, vimrc, etc.)
    \$0 -i -t rgt47 -p research-study -D ~/Dropbox/dotfiles
EOF
}

# Function: show_init_workflow_and_prerequisites
# Purpose: Display workflow steps and prerequisites
show_init_workflow_and_prerequisites() {
    cat << EOF

WORKFLOW:
    1. Create project directory
    2. Copy and customize Dockerfile.teamcore
    3. Build shell and RStudio core images
    4. Push images to Docker Hub
    5. Initialize zzcollab project
    6. Create private GitHub repository
    7. Push initial commit

PREREQUISITES:
    - Docker installed and running
    - Docker Hub account and logged in (docker login)
    - GitHub CLI installed and authenticated (gh auth login)
    - zzcollab installed and available in PATH
EOF
}

# Function: show_init_help
# Purpose: Display help specifically for team initialization mode (coordinating function)
show_init_help() {
    show_init_usage_and_options
    show_init_examples
    show_init_workflow_and_prerequisites
}

#=============================================================================
# NEXT STEPS GUIDANCE FUNCTION
#=============================================================================

# Function: show_project_structure_overview
# Purpose: Display project structure information
show_project_structure_overview() {
    cat << 'EOF'
🚀 ZZCOLLAB NEXT STEPS

After running the modular setup script, here's how to get started:

📁 PROJECT STRUCTURE:
   Your project now has a complete research compendium with:
   - R package structure with functions and tests
   - Analysis workflow with report templates
   - Docker environment for reproducibility
   - CI/CD workflows for automation
EOF
}

# Function: show_development_workflows
# Purpose: Display Docker and development workflow information
show_development_workflows() {
    cat << 'EOF'

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
EOF
}

# Function: show_collaboration_and_automation
# Purpose: Display collaboration and automation information
show_collaboration_and_automation() {
    cat << 'EOF'

🤝 COLLABORATION:
   git init                   # Initialize version control
   git add .                  # Stage all files
   git commit -m "Initial zzcollab setup"
   # Push to GitHub to activate CI/CD workflows

🔄 AUTOMATION:
   - GitHub Actions will run package checks automatically
   - Papers render automatically when analysis/ changes
   - Use pre-commit hooks for code quality
EOF
}

# Function: show_help_and_cleanup_info
# Purpose: Display help and cleanup information
show_help_and_cleanup_info() {
    cat << 'EOF'

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

# Function: show_next_steps
# Purpose: Display comprehensive guidance for next steps after setup (coordinating function)
show_next_steps() {
    show_project_structure_overview
    show_development_workflows
    show_collaboration_and_automation
    show_help_and_cleanup_info
}

#=============================================================================
# HELPER FUNCTIONS FOR MODULAR HELP DISPLAY
#=============================================================================

# Function: show_help_header
# Purpose: Display main usage and options section
show_help_header() {
    cat << EOF
\$0 - Complete Research Compendium Setup (Modular Implementation)

Creates a comprehensive research compendium with R package structure, Docker integration,
analysis templates, and reproducible workflows.

USAGE:
    \$0 [OPTIONS]

OPTIONS:
    Team initialization (Developer 1 - Team Lead):
    -i, --init                   Initialize new team project with Docker images and GitHub repo
    -t, --team-name NAME         Team name (Docker Hub organization) [required with --init]
    -p, --project-name NAME      Project name [required with --init]
    -g, --github-account NAME    GitHub account (default: same as team-name)
    -B, --init-base-image TYPE   Base image for team setup: r-ver, rstudio, verse, all (default: r-ver - shell only)
        --variants-config FILE   Use config.yaml for unlimited custom variants (supersedes -B)
    
    Team collaboration (Developer 2+ - Team Members):
    -t, --team NAME              Team name (Docker Hub organization)
    -p, --project-name NAME      Project name  
    -I, --interface TYPE         Interface type: shell, rstudio, verse
    
    Common options:
    -d, --dotfiles DIR           Copy dotfiles from directory (files with leading dots)
    -D, --dotfiles-nodot DIR     Copy dotfiles from directory (files without leading dots)
    
    Advanced options:
    -b, --base-image NAME        Use custom Docker base image (default: rocker/r-ver)
    -n, --no-docker              Skip Docker image build during setup
    -V, --build-variant TYPE     Build additional team image variant: r-ver, rstudio, verse
    -G, --github                 Automatically create private GitHub repository and push
        --next-steps             Show development workflow and next steps
    
    Simplified build modes:
    -F, --fast                   Fast mode: minimal Docker (8 packages)
    -S, --standard               Standard mode: balanced packages (15 packages) [default]
    -C, --comprehensive          Comprehensive mode: full ecosystem (27+ packages)
    
    Utilities:
    -h, --help                   Show this help message
        --help-init              Show team initialization help specifically
    -c, --config CMD             Configuration management (get, set, list, reset)
EOF
}

# Function: show_help_examples  
# Purpose: Display usage examples section
show_help_examples() {
    cat << EOF
    
EXAMPLES:
    Team Lead - Create new team project (runs once per team):
    \$0 -i -t rgt47 -p research-study -d ~/dotfiles         # Team init with all 3 image variants
    # Alternative: Create directory first, then run in it (project name auto-detected)
    mkdir png1 && cd png1 && \$0 -i -t rgt47 -d ~/dotfiles
    
    # NEW: Initialize with specific base image only
    \$0 -i -t rgt47 -p study -B r-ver -d ~/dotfiles                         # Build only shell variant
    \$0 -i -t rgt47 -p study -B rstudio -d ~/dotfiles                       # Build only RStudio variant  
    \$0 -i -t rgt47 -p study -B verse -d ~/dotfiles                         # Build only verse variant
    
    # Team Members - Join existing project (Developer 2+)
    \$0 -t rgt47 -p research-study -I shell -d ~/dotfiles
    \$0 --team mylab --project-name study2024 --interface rstudio --dotfiles ~/dotfiles
    \$0 -t rgt47 -p research-study -I verse -d ~/dotfiles                   # Use verse for publishing
    
    # Advanced usage with custom base images
    \$0 -b rocker/tidyverse -d ~/dotfiles
    \$0 --base-image myteam/mycustomimage --dotfiles-nodot ~/dotfiles
    
    # Basic setup for standalone projects
    \$0 -d ~/dotfiles                                # Basic setup with dotfiles
    \$0 -d ~/dotfiles -G                             # Setup with automatic GitHub repository creation
    
    # NEW: Simplified build modes (recommended)
    \$0 -i -t rgt47 -p study -F -d ~/dotfiles                      # Fast mode: minimal Docker + lightweight packages
    \$0 -i -t rgt47 -p study -S -d ~/dotfiles                      # Standard mode: balanced setup (default)
    \$0 -i -t rgt47 -p study -C -d ~/dotfiles                      # Comprehensive mode: extended Docker + full packages
    \$0 -n                                                          # Setup without Docker build
    
    # Build additional team image variants after initialization
    \$0 -V rstudio                                                 # Build RStudio variant after r-ver-only init
    \$0 -V verse                                                   # Build verse variant
EOF
}

# Function: show_help_config
# Purpose: Display configuration system section  
show_help_config() {
    cat << EOF
    
CONFIGURATION SYSTEM:
    zzcollab supports configuration files for common settings.
    
    \$0 -c get team-name                            # Get current team name
    \$0 -c set team-name mylab                      # Set default team name
    \$0 -c set build-mode fast                      # Set default build mode
    \$0 -c list                                     # Show all current settings
    \$0 -c reset                                    # Reset to defaults
    
    Configuration files:
    - User-level: ~/.config/zzcollab/config.yaml
    - Team-level: .zzcollab/config.yaml (if present)
    
    Settings: team-name, github-account, build-mode, dotfiles-dir, 
              dotfiles-nodot, auto-github, skip-confirmation
EOF
}

# Function: show_help_footer
# Purpose: Display footer with additional resources
show_help_footer() {
    cat << EOF

For more specific help with team initialization, run: \$0 --help-init
For development workflow guidance, run: \$0 --next-steps

Project website: https://github.com/rgt47/zzcollab
EOF
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================


