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

# Original large function preserved for reference (can be removed later)
_original_show_help() {
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
    zzcollab -i -t rgt47 -p research-study -d ~/dotfiles
    zzcollab --init --team-name mylab --project-name study2024 --github-account myorg
    zzcollab -i -t rgt47 -p research-study -y -d ~/dotfiles                          # Skip confirmation (automation)
    
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
    zzcollab -V r-ver -t rgt47                                          # Build shell variant (with explicit team name)

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
zzcollab --init - Team initialization for ZZCOLLAB research collaboration

USAGE:
    zzcollab --init --team-name TEAM --project-name PROJECT [OPTIONS]

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
    zzcollab -i -t rgt47 -p research-study -P
    # Edit research-study/Dockerfile.teamcore as needed, then run:
    zzcollab -i -t rgt47 -p research-study

    # Direct setup with standard Dockerfile
    zzcollab -i -t rgt47 -p research-study -d ~/dotfiles
    
    # Fast mode: minimal Docker + lightweight packages
    zzcollab -i -t rgt47 -p research-study -F -d ~/dotfiles
    
    # Standard mode: balanced setup (default)
    zzcollab -i -t rgt47 -p research-study -S -d ~/dotfiles
    
    # Comprehensive mode: extended Docker + full packages
    zzcollab -i -t rgt47 -p research-study -C -d ~/dotfiles
    
    # Config-based variants: unlimited custom environments
    zzcollab -i -t rgt47 -p research-study --variants-config config.yaml
    
    # Or enable by default in config.yaml (set use_config_variants: true):
    zzcollab -i -t rgt47 -p research-study    # Uses config.yaml automatically
    
    # Specialized examples (edit config.yaml to enable):
    # - Alpine Linux variants (~200MB vs ~1GB, ideal for CI/CD)  
    # - R-hub testing environments (CRAN-compatible package testing)
    # - Domain-specific: bioinformatics, geospatial, HPC, etc.
    
    # Alternative: Create directory first, then auto-detect project name
    mkdir png1 && cd png1 && zzcollab -i -t rgt47 -d ~/dotfiles

    # With custom GitHub account
    zzcollab --init --team-name rgt47 --project-name research-study --github-account mylab

    # With dotfiles (files already have dots: .bashrc, .vimrc, etc.)
    zzcollab --init --team-name rgt47 --project-name research-study --dotfiles ~/dotfiles

    # With dotfiles that need dots added (files like: bashrc, vimrc, etc.)
    zzcollab -i -t rgt47 -p research-study -D ~/Dropbox/dotfiles
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
    # Check if output is being redirected or if we're in a non-interactive terminal
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        # Direct output for redirects, scripts, or when PAGER=cat
        show_init_usage_and_options
        show_init_examples
        show_init_workflow_and_prerequisites
    else
        # Interactive terminal - use pager for long help output
        {
            show_init_usage_and_options
            show_init_examples
            show_init_workflow_and_prerequisites
        } | "${PAGER:-less}" -R
    fi
}

#=============================================================================
# VARIANTS CONFIGURATION HELP
#=============================================================================

# Function: show_variants_help
# Purpose: Display comprehensive help for --variants-config option with examples
show_variants_help() {
    # Check if output is being redirected or if we're in a non-interactive terminal
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        # Direct output for redirects, scripts, or when PAGER=cat
        show_variants_help_content
    else
        # Interactive terminal - use pager for long help output
        show_variants_help_content | "${PAGER:-less}" -R
    fi
}

# Function: show_variants_help_content
# Purpose: Display the actual variants configuration help content
show_variants_help_content() {
    cat << 'EOF'
zzcollab --variants-config - Docker Variant Configuration System

OVERVIEW:
    The --variants-config option enables unlimited custom Docker environments beyond
    the standard 3-variant system (r-ver, rstudio, verse). Define specialized
    environments for bioinformatics, geospatial analysis, Alpine Linux, R-hub testing,
    and more using YAML configuration files.

USAGE:
    zzcollab --variants-config FILE         # Use specified config file
    zzcollab -i -t TEAM -p PROJECT --variants-config config.yaml    # Team init with custom variants

QUICK START:
    1. Browse available variants interactively:
       ./add_variant.sh

    2. Build selected variants:
       zzcollab --variants-config config.yaml

    3. Team members join with standard interface options:
       zzcollab -t TEAM -p PROJECT -I shell

CONFIGURATION FILE STRUCTURE:
    
    # config.yaml
    build:
      use_config_variants: true              # Use this file automatically
      variant_library: "variant_examples.yaml"   # Source of variant definitions
    
    variants:
      minimal:
        enabled: true                        # Essential R packages (~800MB)
        # Full definition in variant_examples.yaml
      
      bioinformatics:
        enabled: true                        # Bioconductor genomics packages (~2GB)
        # Full definition in variant_examples.yaml
      
      alpine_minimal:
        enabled: false                       # Ultra-lightweight CI/CD (~200MB)
        # Full definition in variant_examples.yaml

AVAILABLE VARIANT CATEGORIES:

📦 STANDARD RESEARCH ENVIRONMENTS:
    minimal          ~800MB   - Essential R packages only
    analysis         ~1.2GB   - Tidyverse + data analysis tools
    modeling         ~1.5GB   - Machine learning with tidymodels
    publishing       ~3GB     - LaTeX, Quarto, bookdown, blogdown
    shiny            ~1.8GB   - Interactive web applications
    shiny_verse      ~3.5GB   - Shiny with tidyverse + publishing

🔬 SPECIALIZED DOMAINS:
    bioinformatics   ~2GB     - Bioconductor genomics packages
    geospatial       ~2.5GB   - sf, terra, leaflet mapping tools

🏔️ LIGHTWEIGHT ALPINE VARIANTS:
    alpine_minimal   ~200MB   - Ultra-lightweight for CI/CD
    alpine_analysis  ~400MB   - Essential analysis in tiny container
    hpc_alpine       ~600MB   - High-performance parallel processing

🧪 R-HUB TESTING ENVIRONMENTS:
    rhub_ubuntu      ~1GB     - CRAN-compatible package testing
    rhub_fedora      ~1.2GB   - Test against R-devel
    rhub_windows     ~1.5GB   - Windows compatibility testing

WORKFLOW EXAMPLES:

1. Interactive Variant Selection:
   ./add_variant.sh                         # Browse 14+ variants with descriptions
   # Select variants from categorized menu
   # Automatically updates config.yaml

2. Team Setup with Custom Variants:
   # Team lead creates specialized environment
   zzcollab -i -t mylab -p genomics-study --variants-config config.yaml
   
   # Team members join with any available interface
   zzcollab -t mylab -p genomics-study -I shell      # Command line
   zzcollab -t mylab -p genomics-study -I rstudio    # RStudio Server

3. Automatic Configuration Usage:
   # Set use_config_variants: true in config.yaml
   zzcollab -i -t mylab -p study            # Uses config.yaml automatically

4. Custom Domain-Specific Setup:
   # Bioinformatics team
   ./add_variant.sh                         # Select: bioinformatics, rhub_ubuntu
   zzcollab --variants-config config.yaml
   
   # Geospatial analysis team  
   ./add_variant.sh                         # Select: geospatial, publishing
   zzcollab --variants-config config.yaml
   
   # CI/CD optimized team
   ./add_variant.sh                         # Select: alpine_minimal, hpc_alpine
   zzcollab --variants-config config.yaml

5. Legacy vs Modern Comparison:
   # Legacy approach (limited to 3 variants)
   zzcollab -i -t mylab -p study -B rstudio,verse
   
   # Modern approach (unlimited variants)
   zzcollab -i -t mylab -p study --variants-config config.yaml

VARIANT DEFINITION STRUCTURE:
    
    Each variant in variant_examples.yaml includes:
    - base_image: Docker base image (rocker/r-ver, bioconductor/devel, etc.)
    - packages: R packages to install
    - system_deps: System dependencies (apt packages)
    - description: Human-readable description
    - category: Organization category
    - size: Estimated image size

CONFIGURATION HIERARCHY:
    
    1. Command line: --variants-config FILE (highest priority)
    2. Project config: use_config_variants: true in config.yaml
    3. Legacy flags: -B r-ver,rstudio,verse (lowest priority)

BENEFITS:

✅ Single source of truth - variant definitions centralized in variant_examples.yaml
✅ 14+ specialized environments - from 200MB Alpine to 3.5GB full-featured
✅ Domain-specific variants - bioinformatics, geospatial, HPC, web apps
✅ Professional testing - R-hub environments match CRAN infrastructure  
✅ Interactive discovery - browse variants with ./add_variant.sh
✅ Backward compatibility - legacy full definitions still supported
✅ Easy maintenance - update variant in one place, propagates everywhere

TROUBLESHOOTING:

Q: How do I see available variants?
A: Run ./add_variant.sh to browse all 14+ variants with descriptions

Q: Can I customize a variant?
A: Yes, copy the definition from variant_examples.yaml to config.yaml and modify

Q: How do team members know which variants are available?
A: Available Docker images are listed when joining fails, with helpful guidance

Q: Can I use both --variants-config and -B flags?
A: --variants-config supersedes -B flags (modern approach recommended)

For more help: zzcollab -h, zzcollab --help-init
EOF
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

Project website: https://github.com/rgt47/zzcollab
EOF
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================


