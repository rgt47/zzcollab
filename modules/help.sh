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
    # Check if output is being redirected or if we're in a non-interactive terminal
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        # Direct output for redirects, scripts, or when PAGER=cat
        show_help_header
        show_help_examples  
        show_help_config
        show_help_footer
    else
        # Interactive terminal - use pager for long help output
        {
            show_help_header
            show_help_examples  
            show_help_config
            show_help_footer
        } | "${PAGER:-less}" -R
    fi
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
zzcollab - Complete Research Compendium Setup (Modular Implementation)

Creates a comprehensive research compendium with R package structure, Docker integration,
analysis templates, and reproducible workflows.

USAGE:
    zzcollab [OPTIONS]

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
    --paradigm TYPE, -P TYPE     Research paradigm: analysis, manuscript, package (default: analysis)
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
        --help-variants          Show Docker variants configuration help with examples
    -c, --config CMD             Configuration management (get, set, list, reset)
EOF
}

# Function: show_help_examples  
# Purpose: Display usage examples section
show_help_examples() {
    cat << EOF
    
EXAMPLES:
    Team Lead - Create new team project (runs once per team):
    zzcollab -i -t rgt47 -p research-study -d ~/dotfiles         # Team init with all 3 image variants
    # Alternative: Create directory first, then run in it (project name auto-detected)
    mkdir png1 && cd png1 && zzcollab -i -t rgt47 -d ~/dotfiles
    
    # NEW: Initialize with specific base image only
    zzcollab -i -t rgt47 -p study -B r-ver -d ~/dotfiles                         # Build only shell variant
    zzcollab -i -t rgt47 -p study -B rstudio -d ~/dotfiles                       # Build only RStudio variant  
    zzcollab -i -t rgt47 -p study -B verse -d ~/dotfiles                         # Build only verse variant
    
    # Team Members - Join existing project (Developer 2+)
    zzcollab -t rgt47 -p research-study -I shell -d ~/dotfiles
    zzcollab --team mylab --project-name study2024 --interface rstudio --dotfiles ~/dotfiles
    zzcollab -t rgt47 -p research-study -I verse -d ~/dotfiles                   # Use verse for publishing
    
    # Advanced usage with custom base images
    zzcollab -b rocker/tidyverse -d ~/dotfiles
    zzcollab --base-image myteam/mycustomimage --dotfiles-nodot ~/dotfiles
    
    # Basic setup for standalone projects
    zzcollab -d ~/dotfiles                                # Basic setup with dotfiles
    zzcollab -d ~/dotfiles -G                             # Setup with automatic GitHub repository creation
    
    # NEW: Simplified build modes (recommended)
    zzcollab -i -t rgt47 -p study -F -d ~/dotfiles                      # Fast mode: minimal Docker + lightweight packages
    zzcollab -i -t rgt47 -p study -S -d ~/dotfiles                      # Standard mode: balanced setup (default)
    zzcollab -i -t rgt47 -p study -C -d ~/dotfiles                      # Comprehensive mode: extended Docker + full packages
    zzcollab -n                                                          # Setup without Docker build
    
    # Build additional team image variants after initialization
    zzcollab -V rstudio                                                 # Build RStudio variant after r-ver-only init
    zzcollab -V verse                                                   # Build verse variant
EOF
}

# Function: show_help_config
# Purpose: Display configuration system section  
show_help_config() {
    cat << EOF
    
CONFIGURATION SYSTEM:
    zzcollab supports configuration files for common settings.
    
    zzcollab -c get team-name                            # Get current team name
    zzcollab -c set team-name mylab                      # Set default team name
    zzcollab -c set build-mode fast                      # Set default build mode
    zzcollab -c list                                     # Show all current settings
    zzcollab -c reset                                    # Reset to defaults
    
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

For more specific help with team initialization, run: zzcollab --help-init
For Docker variants configuration help, run: zzcollab --help-variants
For development workflow guidance, run: zzcollab --next-steps

📋 PARADIGM GUIDANCE:
After project creation, see PARADIGM_GUIDE.md for detailed information about:
- When to use each research paradigm (analysis, manuscript, package)
- Project structure explanations and best practices
- Workflow examples and decision guidelines

Project website: https://github.com/rgt47/zzcollab
EOF
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================


