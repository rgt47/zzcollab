#!/bin/bash
set -euo pipefail
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
# Function: show_help_brief
# Purpose: Show brief overview (git-like) with common workflows and topics
show_help_brief() {
    cat << 'EOF'
usage: zzc <command> [options]
   or: zzc help <topic>

zzcollab - Complete Research Compendium Setup
Creates reproducible research projects with R package structure,
Docker integration, and collaborative workflows.

Common workflows:

  start a new project (solo developer)
    mkdir myproject && cd myproject
    zzc analysis                              # Full setup with tidyverse
    make docker-build && make r               # Build and start dev

  start a new project (team lead)
    zzc config set dockerhub-account mylab    # One-time config
    mkdir study && cd study
    zzc analysis                              # Full setup
    zzc dockerhub                             # Push image to Docker Hub
    zzc github                                # Create GitHub repo + push

  join an existing project (team member)
    git clone https://github.com/mylab/study.git
    cd study && make docker-build             # Build from Dockerfile
    make r                                    # Start development

  development workflow
    make r                                    # Enter container
    # ... work in R ...
    q()                                       # Exit (auto-snapshots)
    make docker-test                          # Run tests
    git add . && git commit -m "..." && git push

See 'zzc help <topic>' for detailed information:

  Guides
    quickstart    Quick start for solo developers
    workflow      Daily development workflow
    team          Team collaboration setup

  Configuration
    config        Configuration system
    profiles      Docker profile selection

  Technical
    docker        Docker architecture
    renv          Package management
    cicd          CI/CD automation

  Maintenance
    doctor Detect outdated template files in workspaces

  Other
    options       Complete list of all command-line options
    troubleshoot  Common issues and solutions

'zzc help --all' lists all help topics
EOF
}

show_help() {
    local topic="${1:-}"

    case "$topic" in
        "")
            # No topic - show brief overview
            show_help_brief
            ;;
        --all|-a)
            # List all available topics
            show_help_topics_list
            ;;
        quickstart)
            show_help_quickstart
            ;;
        workflow)
            show_help_workflow
            ;;
        team)
            show_help_team
            ;;
        config)
            show_help_config_topic
            ;;
        profiles)
            show_help_profiles
            ;;
        examples)
            show_help_examples_topic
            ;;
        docker)
            show_help_docker
            ;;
        github)
            show_github_help
            ;;
        renv)
            show_help_renv
            ;;
        cicd)
            show_help_cicd
            ;;
        options)
            # Show full options list (original help)
            show_help_full
            ;;
        doctor)
            show_help_doctor
            ;;
        troubleshoot|troubleshooting)
            show_help_troubleshooting
            ;;
        rm|remove)
            show_help_rm
            ;;
        *)
            echo "Unknown help topic: $topic"
            echo "See 'zzc help --all' for list of all topics"
            return 1
            ;;
    esac
}

# Function: show_help_full
# Purpose: Show complete options list (original comprehensive help)
show_help_full() {
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
# HELP TOPIC FUNCTIONS
#=============================================================================

# Function: show_help_topics_list
# Purpose: List all available help topics with descriptions
show_help_topics_list() {
    cat << 'EOF'
zzcollab help topics:

Guides:
  quickstart      Quick start guide (recommended starting point)
  workflow        Daily development workflow
  team            Team collaboration setup
  profiles        Docker profiles and switching

Commands:
  build           Build Docker image (cached)
  github          GitHub repository integration
  docker          Docker architecture and usage
  renv            Package management with renv
  rm              Remove zzcollab features or artifacts
  doctor   Detect outdated template files

Configuration:
  config          Configuration system
  examples        Example files and templates

Other:
  options         Complete list of all command-line options
  troubleshoot    Common issues and solutions

Usage:
  zzc help <topic>       Show help for specific topic
  zzc help --all         Show this list
EOF
}

# Function: show_help_quickstart
# Purpose: Quick start guide for solo developers
show_help_quickstart() {
    cat << 'EOF'
ZZCOLLAB QUICK START

New Project (recommended):
   mkdir myproject && cd myproject
   zzcollab analysis          # Creates init + renv + docker, prompts to build

   # This sets up:
   #   - rrtools structure (DESCRIPTION, R/, analysis/, tests/)
   #   - renv.lock for package reproducibility
   #   - Dockerfile with analysis profile (tidyverse)

Available Profiles:
   zzcollab analysis          # Tidyverse (~1.5GB) - recommended
   zzcollab minimal           # Base R only (~300MB)
   zzcollab publishing        # LaTeX + pandoc (~3GB)

After Setup:
   make r                     # Enter container, start R
   install.packages("pkg")    # Add packages as needed
   q()                        # Exit R (auto-snapshots to renv.lock)

Switch Profile (existing project):
   zzcollab publishing        # Regenerates Dockerfile with new profile

Add GitHub:
   zzcollab github            # Initialize git + create private GitHub repo
   zzcollab github --public   # Create public repo

See also:
   zzcollab help workflow     Daily development patterns
   zzcollab help profiles     Available Docker profiles
   zzcollab help docker       Docker details
EOF
}

# Function: show_help_workflow
# Purpose: Daily development workflow
show_help_workflow() {
    cat << 'EOF'
DAILY DEVELOPMENT WORKFLOW

Basic Cycle:
   make r          # Enter development container
   # ... work in R ...
   q()                      # Exit (auto-snapshots packages)
   make docker-test         # Run tests
   git add . && git commit && git push

Common Tasks:
   make docker-rstudio      # RStudio Server (localhost:8787)
   make docker-build        # Rebuild Docker image
   make check-renv          # Validate package dependencies
   make docker-push-team    # Share team Docker image

Adding Packages:
   make r
   install.packages("tidyverse")
   q()                      # Automatically captured in renv.lock

Navigation Shortcuts (optional):
   zzc nav install
   r → project root
   a → analysis/
   s → analysis/scripts/
   p → analysis/report/

Troubleshooting:
   make docker-build 2>&1 | tee build.log

See also:
  zzc help quickstart    Getting started
  zzc help renv          Package management
  zzc help docker        Docker usage
EOF
}

# Function: show_help_team
# Purpose: Team collaboration setup
show_help_team() {
    cat << 'EOF'
TEAM COLLABORATION

Team Lead Setup:
   1. One-time configuration:
      zzc config set dockerhub-account mylab
      zzc config set github-account mylab

   2. Create the project:
      mkdir study && cd study
      zzc analysis                     # Full setup with tidyverse

   3. Share Docker image:
      zzc dockerhub                    # Push to Docker Hub (mylab/study)

   4. Create GitHub repository:
      zzc github                       # Create repo + push

Team Member Join:
   1. Clone and build locally:
      git clone https://github.com/mylab/study.git
      cd study
      make docker-build                # Build image from Dockerfile

   2. Start development:
      make r

Workflow:
   - Team members work independently in containers
   - Packages added by anyone appear in shared renv.lock
   - Members build their image locally from the Dockerfile
   - Team lead can push updated images via: zzc dockerhub

See also:
  zzc help workflow      Daily development
  zzc help docker        Docker architecture
  zzc help config        Team configuration
EOF
}

# Function: show_help_config_topic
# Purpose: Configuration system help
show_help_config_topic() {
    cat << 'EOF'
CONFIGURATION SYSTEM

Configuration Files (priority order):
  1. ./zzcollab.yaml          Project-specific (local)
  2. ~/.zzcollab/config.yaml  User defaults (global)
  3. Built-in defaults

Global Commands:
  zzc config init              Create global config file
  zzc config set KEY VALUE     Set global configuration
  zzc config get KEY           Get global configuration
  zzc config list              List global config
  zzc config path              Show config file paths
  zzc config validate          Validate config file

Local Commands (project-specific):
  zzc config set-local KEY VALUE   Set project config
  zzc config get-local KEY         Get project config
  zzc config list-local            List project config

Config Keys (kebab-case):
  dockerhub-account    Docker Hub organization/account
  github-account       GitHub account
  profile-name         Default Docker profile
  author-name          Author name for DESCRIPTION
  author-email         Author email
  author-orcid         Author ORCID
  r-version            R version for Docker builds
  license-type         License type (e.g., MIT)

Example:
  zzc config init
  zzc config set dockerhub-account "mylab"
  zzc config set profile-name "analysis"
  zzc config set github-account "mylab"

See also:
  zzc help profiles     Docker profiles
  zzc help team         Team collaboration
EOF
}

# Function: show_help_profiles
# Purpose: Docker profile selection
show_help_profiles() {
    cat << 'EOF'
DOCKER PROFILES

Profile commands are smart:
  - New project:      Creates init + renv + docker, prompts to build
  - Existing project: Switches profile, regenerates Dockerfile

Standard Research:
  minimal          Lightweight R environment (~300MB)
  analysis         Data analysis (tidyverse, ~1.5GB) - recommended
  analysis_pdf     Data analysis + tinytex for PDF (~1.5GB)
  modeling         Statistical modeling (~2GB)
  publishing       LaTeX + knitr for papers (~3GB)
  shiny            Interactive applications
  shiny_verse      Shiny + tidyverse
  rstudio          RStudio Server

Usage:
  zzcollab analysis               # New project: full setup
  zzcollab analysis               # Existing: switch to analysis profile
  zzcollab list profiles          # List all available profiles

See also:
  zzcollab help quickstart   Quick start guide
  zzcollab help docker       Docker details
EOF
}

# Function: show_help_examples_topic
# Purpose: Example files and templates
show_help_examples_topic() {
    cat << 'EOF'
EXAMPLE FILES

By default, zzcollab creates a clean workspace without example files.

The example templates are available in the zzcollab source at:
  templates/examples/

Example Files Include:
  analysis/report/report.Rmd        Academic manuscript template
  analysis/report/references.bib    Bibliography file
  analysis/scripts/*.R              Data validation, parallel computing
  analysis/templates/*.R            Analysis and figure templates

Note: The --with-examples and --add-examples flags from the old CLI
are not currently wired into the subcommand router. To add example
files, copy them from the templates directory above.

See also:
  zzc help workflow     Development workflow
  zzc help config       Configuration
EOF
}

# Function: show_help_docker
# Purpose: Docker architecture and usage
show_help_docker() {
    cat << 'EOF'
DOCKER ARCHITECTURE

Usage:
  zzcollab docker                    # Generate Dockerfile (interactive)
  zzcollab docker --build            # Generate and build image
  zzcollab docker --profile analysis # Use specific profile

Note: Automatically creates rrtools workspace if DESCRIPTION not found.

Two-Layer System:
  1. Docker Image (base environment, shared by team)
  2. renv.lock (R packages, personal additions)

Common Commands:
  make docker-build        Build Docker image
  make r                   Interactive R session
  make docker-rstudio      RStudio Server (localhost:8787)
  make docker-test         Run tests in container
  zzc dockerhub            Push image to Docker Hub

Logs:
  docker-build.log         Build output

Platform Compatibility:
  ARM64: r-ver, rstudio profiles
  AMD64: verse, tidyverse, shiny

Custom Images:
  zzc docker --base-image rocker/verse

See also:
  zzc help profiles     Profile selection
  zzc help renv         Package management
  zzc help team         Team collaboration
EOF
}

# Function: show_help_renv
# Purpose: Package management with renv
show_help_renv() {
    cat << 'EOF'
PACKAGE MANAGEMENT (renv)

Usage:
  zzcollab renv                      # Set up renv without Docker
  zzcollab renv --r-version 4.4.2    # Specify R version

Note: Automatically creates rrtools workspace if DESCRIPTION not found.

Auto-Snapshot Workflow (with Docker):
  make r
  install.packages("tidyverse")
  q()                       # Automatic snapshot on exit

Standalone renv (without Docker):
  zzcollab renv             # Creates renv.lock, .Rprofile, renv/
  R                         # Start R (auto-restores packages)
  install.packages("pkg")   # Add packages
  q()                       # Auto-snapshot on exit

Validation:
  make check-renv           # Validate + auto-fix
  make check-renv-no-fix    # Validation only
  make check-renv-no-strict # Skip tests/ and vignettes/

Auto-Fix Pipeline:
  1. Detects packages used in code
  2. Adds to DESCRIPTION
  3. Adds to renv.lock (via CRAN API)
  4. Pure shell (no R required on host!)

Files:
  renv.lock                 Package versions (source of truth)
  DESCRIPTION               Package metadata
  .Rprofile                 R session configuration

See also:
  zzcollab help workflow     Development workflow
  zzcollab help docker       Docker architecture
EOF
}

# Function: show_help_cicd
# Purpose: CI/CD automation
show_help_cicd() {
    cat << 'EOF'
CI/CD AUTOMATION

GitHub Actions:
  .github/workflows/        Automation workflows
  R CMD check               Runs on every push
  Docker image builds       Automated builds

Workflow Triggers:
  - Push to main branch
  - Pull requests
  - Manual workflow dispatch

Validation:
  - R package structure
  - Tests (testthat)
  - DESCRIPTION ↔ renv.lock consistency
  - Docker builds

Logs:
  GitHub Actions tab        View workflow runs
  Build artifacts           Download logs

See also:
  zzcollab help workflow     Development workflow
  zzcollab help docker       Docker builds
EOF
}

# Function: show_help_troubleshooting
# Purpose: Common issues and solutions
show_help_troubleshooting() {
    cat << 'EOF'
TROUBLESHOOTING

Common Issues:

1. Docker build fails:
   make docker-build 2>&1 | tee build.log
   cat docker-build.log
   # Check for network issues, CRAN package availability

2. Package validation fails:
   make check-renv          # Auto-fixes most issues

3. Tests fail:
   make docker-test
   # Check test output for specific failures

4. Navigation shortcuts don't work:
   zzc nav install
   source ~/.zshrc          # or ~/.bashrc

5. Team image not found:
   # Team lead must push first:
   make docker-build && zzc dockerhub

Debug Mode:
   zzc -v ...               # Verbose output

Get Help:
   zzc help --all           # List all topics
   GitHub Issues            # Report bugs

See also:
  zzc help workflow     Common workflows
  zzc help docker       Docker troubleshooting
EOF
}

#=============================================================================
# CHECK-UPDATES HELP
#=============================================================================

# Function: show_help_doctor
# Purpose: Help for the doctor command
show_help_doctor() {
    cat << 'EOF'
CHECK-UPDATES - Detect Outdated Template Files

Usage:
  zzc doctor                  # Check current directory
  zzc doctor DIR [DIR ...]    # Check specific workspaces
  zzc doctor --scan DIR       # Recursively find and check all
                                     #   zzcollab workspaces under DIR

What it does:
  Reads version stamps embedded in Makefile, .Rprofile, and Dockerfile
  by zzcollab during workspace creation. Compares each stamp against
  the current template version and reports status.

Output:
  Checking: ~/prj/res/08-project/
    Makefile      v2.0.0 -> v2.1.0  (outdated)
    .Rprofile     v2.0.0 -> v2.1.0  (outdated)
    Dockerfile    v2.1.0             (current)

  Files created before version stamping show (no stamp).

Exit codes:
  0   All checked files are current
  1   One or more files are outdated or unstamped

Examples:
  zzc doctor                  # Check workspace in current dir
  zzc doctor ~/prj/res/study  # Check a specific workspace
  zzc doctor --scan ~/prj/res # Scan all workspaces under ~/prj/res

See also:
  zzcollab help workflow     Daily development workflow
  zzcollab help docker       Docker architecture
EOF
}

# Function: show_help_rm
# Purpose: Help for the rm (remove) command
show_help_rm() {
    cat << 'EOF'
RM - Remove zzcollab Features or Artifacts

Usage:
  zzc rm <feature> [-f|--force]

Features:
  docker    Remove Dockerfile and .dockerignore
  renv      Remove renv.lock and renv/ directory
  git       Remove .git/ directory (deletes all history)
  github    Remove GitHub remote origin
  cicd      Remove .github/workflows/ directory
  all       Remove all zzcollab artifacts (calls uninstall)

Options:
  -f, --force    Skip confirmation prompts

What 'rm all' preserves:
  - .git/ directory (use 'zzc rm git' separately)
  - Data files and directories not created by zzcollab
  - Files you added that aren't in the manifest
  - Non-empty directories (manifest-based removal only)

Removal modes:
  Manifest-based (preferred):
    Projects with .zzcollab/manifest.json use precise tracking.
    Only files recorded during setup are removed.

  Legacy fallback:
    Projects without a manifest use a hardcoded file list:
    Dirs:  R/, analysis/, tests/, man/, vignettes/, docs/, .github/, renv/
    Files: Dockerfile, Makefile, DESCRIPTION, NAMESPACE, LICENSE,
           renv.lock, .Rprofile, .Rbuildignore, .gitignore, *.Rproj

Examples:
  zzc rm docker              # Remove Docker files only
  zzc rm renv -f             # Remove renv without confirmation
  zzc rm all                 # Remove all zzcollab artifacts
  zzc rm git                 # Remove git repository

Preview removal:
  zzc uninstall --dry-run    # See what 'rm all' would remove

See also:
  zzc help uninstall         # Detailed uninstall options
  zzc help doctor     # Detect outdated templates
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
   make r            # Interactive shell in container
   
📝 ANALYSIS WORKFLOW:
   1. Place raw data in data/raw_data/
   2. Develop analysis scripts in analysis/scripts/
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
   make help                    # See all available commands
   ./.zzcollab/uninstall.sh    # Remove created files if needed

🧹 UNINSTALL:
   All created files are tracked in .zzcollab/manifest.json
   Run './.zzcollab/uninstall.sh' to remove everything cleanly

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
    cat << 'EOF'
zzcollab - Complete Research Compendium Setup

Creates a comprehensive research compendium with R package structure,
Docker integration, analysis templates, and reproducible workflows.

USAGE:
    zzc <command> [options]

COMMANDS:
    Profile shortcuts (create or switch project profile):
      minimal              Lightweight R environment (~300MB)
      analysis             Data analysis / tidyverse (~1.5GB)
      analysis_pdf         Data analysis + PDF (tinytex, ~1.5GB)
      publishing           LaTeX + pandoc (~3GB)
      shiny                Interactive applications
      rstudio              RStudio Server

    Setup commands:
      init                 Create rrtools workspace only
      renv                 Set up renv without Docker
      docker [opts]        Generate Dockerfile (--build to also build)

    Sharing:
      github [--public]    Create GitHub repo and push
      dockerhub [--tag T]  Push Docker image to Docker Hub

    Maintenance:
      build [opts]         Build Docker image (content-addressable cache)
      config <sub> ...     Configuration (init|set|get|list|...)
      validate             Check project structure and dependencies
      doctor        Detect outdated template files
      nav <sub>            Navigation shortcuts (install|uninstall)
      rm <feature> [-f]    Remove a feature (docker|renv|git|...)
      uninstall            Remove all zzcollab artifacts
      list profiles        List available Docker profiles

    Help:
      help [topic]         Show help (see topics below)

GLOBAL OPTIONS:
    -v, --verbose          Verbose output
    -q, --quiet            Errors only
    -y, --yes              Accept default prompts
    -Y, --yes-all          Accept all prompts
    --no-build             Skip Docker build prompt
    --version              Show version
    -h, --help             Show brief usage

PER-COMMAND OPTIONS:
    build:
      --no-cache           Skip cache; force full rebuild
      --log                Save build output to docker-build.log

    docker:
      -r, --profile NAME   Docker profile
      -b, --build          Build image after generating Dockerfile
      --r-version VER      R version for Docker build
      --base-image IMG     Custom base image

    github:
      --public             Create public repository (default: private)
      --private            Create private repository

    dockerhub:
      --tag, -t TAG        Image tag (default: latest)
EOF
}

# Function: show_help_examples  
# Purpose: Display usage examples section
show_help_examples() {
    cat << 'EOF'

EXAMPLES:
    Solo Developer:
      mkdir myproject && cd myproject
      zzc analysis                        # Full setup with tidyverse profile
      make docker-build && make r         # Build image and start R

      zzc publishing                      # Switch to publishing profile
      zzc minimal                         # Switch to minimal profile

    Modular Setup (step by step):
      mkdir myproject && cd myproject
      zzc init                            # Create rrtools workspace
      zzc renv                            # Set up renv
      zzc docker --profile analysis       # Generate Dockerfile
      make docker-build                   # Build image

    Team Lead:
      zzc config set dockerhub-account mylab
      mkdir study && cd study
      zzc analysis                        # Full setup
      zzc dockerhub                       # Push image to Docker Hub
      zzc github                          # Create GitHub repo + push

    Team Member:
      git clone https://github.com/mylab/study.git && cd study
      make docker-build                   # Build from Dockerfile
      make r                              # Start development

    Configuration:
      zzc config set profile-name analysis
      zzc config set github-account mylab
      zzc config list                     # Show all settings

    Discovery:
      zzc list profiles                   # Available Docker profiles
      zzc help --all                      # All help topics

    Removal:
      zzc rm docker                       # Remove Docker artifacts
      zzc rm renv                         # Remove renv artifacts
      zzc uninstall                       # Remove everything
EOF
}

# Function: show_help_config
# Purpose: Display configuration system section  
show_help_config() {
    cat << 'EOF'

CONFIGURATION SYSTEM:
    zzcollab supports configuration files for common settings.

    zzc config get dockerhub-account             # Get current account
    zzc config set dockerhub-account mylab       # Set Docker Hub account
    zzc config set profile-name analysis         # Set default profile
    zzc config list                              # Show all settings

    Configuration files:
    - Global:  ~/.zzcollab/config.yaml
    - Local:   ./zzcollab.yaml (project-specific)

    Settings: dockerhub-account, github-account, profile-name,
              author-name, author-email, author-orcid,
              r-version, license-type
EOF
}

# Function: show_help_footer
# Purpose: Display footer with additional resources
show_help_footer() {
    cat << 'EOF'

SPECIALIZED HELP PAGES:

Getting Started:
  zzc help quickstart      Individual researcher quick start guide
  zzc help workflow        Daily development workflow

Configuration:
  zzc help config          Configuration system guide
  zzc help renv            Package management with renv

Technical Details:
  zzc help docker          Docker essentials for researchers
  zzc help cicd            CI/CD and GitHub Actions

Integration:
  zzc help github          GitHub integration and automation
  zzc help team            Team collaboration setup

Other:
  zzc help troubleshoot    Common issues and solutions
  zzc help doctor   Detect outdated template files

RESEARCH COMPENDIUM GUIDE:
After project creation, see README.md for comprehensive information about:
- Unified research compendium structure (based on Marwick et al. 2018)
- Complete research lifecycle support (data -> analysis -> paper -> package)
- Tutorial examples: https://github.com/rgt47/zzcollab/tree/main/examples
- Unified paradigm documentation: docs/UNIFIED_PARADIGM_GUIDE.md

Project website: https://github.com/rgt47/zzcollab
EOF
}

#=============================================================================
# GITHUB INTEGRATION HELP
#=============================================================================

# Function: show_github_help
# Purpose: Display comprehensive GitHub integration documentation
show_github_help() {
    # Check if output is being redirected or if we're in a non-interactive terminal
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        # Direct output for redirects, scripts, or when PAGER=cat
        show_github_help_content
    else
        # Interactive terminal - use pager for long help output
        show_github_help_content | "${PAGER:-less}" -R
    fi
}

# Function: show_github_help_content
# Purpose: GitHub help content
show_github_help_content() {
    cat << 'EOF'
GITHUB INTEGRATION

═══════════════════════════════════════════════════════════════════════════
USAGE
═══════════════════════════════════════════════════════════════════════════

zzcollab github              # Initialize git + create private GitHub repo
zzcollab github --public     # Create public repository
zzcollab github --private    # Create private repository (default)

Works independently - no need to run init, renv, or docker first.
Can be used in any directory, with or without zzcollab structure.

What it does:
  1. Initializes git repository (if not already)
  2. Creates .gitignore (if not already)
  3. Creates GitHub repository via gh CLI
  4. Pushes current directory to GitHub

═══════════════════════════════════════════════════════════════════════════
REQUIREMENTS
═══════════════════════════════════════════════════════════════════════════

Before using github command, ensure:

1. GitHub CLI Installed:
   macOS:    brew install gh
   Ubuntu:   sudo apt install gh
   Windows:  winget install GitHub.cli

2. Authenticated with GitHub:
   gh auth login

   Follow the prompts to authenticate via:
   • Web browser (recommended)
   • Authentication token

3. Verify Authentication:
   gh auth status

   Should show:
   ✓ Logged in to github.com as YOUR_USERNAME

═══════════════════════════════════════════════════════════════════════════
OPTIONS
═══════════════════════════════════════════════════════════════════════════

--private       Create private repository (default)
--public        Create public repository

═══════════════════════════════════════════════════════════════════════════
EXAMPLES
═══════════════════════════════════════════════════════════════════════════

Example 1: New project with GitHub
──────────────────────────────────────────────────────────────────────────
mkdir myproject && cd myproject
zzcollab analysis            # Create project structure
zzcollab github              # Create private GitHub repo + push

Example 2: Any directory
──────────────────────────────────────────────────────────────────────────
cd existing-code
zzcollab github --public     # Works without zzcollab structure

Example 3: Full workflow
──────────────────────────────────────────────────────────────────────────
mkdir study && cd study
zzcollab analysis            # Init + renv + docker
zzcollab github              # Create GitHub repo
make docker-build            # Build image
make r                       # Start development

═══════════════════════════════════════════════════════════════════════════
TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════════════

Issue: "gh: command not found"
  Solution: Install GitHub CLI
    macOS:    brew install gh
    Ubuntu:   sudo apt install gh

Issue: "authentication required"
  Solution: gh auth login

Issue: "repository already exists"
  Solution: Use different name or delete existing:
    gh repo delete USERNAME/REPO --confirm

Issue: Remote already configured
  Solution: Already set up - nothing to do
    git remote -v    # View current remotes
EOF
}


#=============================================================================
# MODULE LOADED
#=============================================================================

readonly ZZCOLLAB_HELP_LOADED=true
