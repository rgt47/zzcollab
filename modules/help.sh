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
usage: zzcollab [OPTIONS]
   or: zzcollab help <topic>

zzcollab - Complete Research Compendium Setup
Creates reproducible research projects with R package structure,
Docker integration, and collaborative workflows.

Common workflows:

  start a new project (solo developer)
    zzcollab -p myproject                     # Initialize new project
    cd myproject && make docker-build         # Build Docker environment
    make r                           # Start development

  start a new project (team lead)
    zzcollab -t mylab -p study -r analysis    # Initialize team project
    make docker-build && make docker-push-team # Build and share image
    git add . && git commit -m "init" && git push

  join an existing project (team member)
    git clone https://github.com/team/project.git
    cd project && zzcollab -u                 # Pull team Docker image
    make r                           # Start development

  development workflow
    make r        # Enter container
    # ... work in R ...
    q()                    # Exit (auto-snapshots packages)
    make docker-test       # Run tests
    git add . && git commit -m "..." && git push

See 'zzcollab help <topic>' for detailed information:

  Guides
    quickstart    Quick start for solo developers
    workflow      Daily development workflow
    team          Team collaboration setup

  Configuration
    config        Configuration system
    profiles      Docker profile selection
    examples      Example files and templates

  Technical
    docker        Docker architecture
    renv          Package management
    cicd          CI/CD automation

  Maintenance
    check-updates Detect outdated template files in workspaces

  Other
    options       Complete list of all command-line options
    troubleshoot  Common issues and solutions

'zzcollab help --all' lists all help topics
'zzcollab --help' shows complete options (old format)
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
        check-updates)
            show_help_check_updates
            ;;
        troubleshoot|troubleshooting)
            show_help_troubleshooting
            ;;
        *)
            echo "Unknown help topic: $topic"
            echo "See 'zzcollab help --all' for list of all topics"
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
  profiles        Docker profiles and switching

Commands:
  github          GitHub repository integration
  docker          Docker architecture and usage
  renv            Package management with renv
  check-updates   Detect outdated template files

Configuration:
  config          Configuration system
  examples        Example files (--with-examples)

Other:
  troubleshoot    Common issues and solutions

Usage:
  zzcollab help <topic>       Show help for specific topic
  zzcollab help --all         Show this list
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
   ./navigation_scripts.sh --install
   r → project root
   a → analysis/
   s → analysis/scripts/
   p → analysis/report/

Troubleshooting:
   make docker-build 2>&1 | tee build.log
   cat .zzcollab.log        # Debug log (if using -vv)

See also:
  zzcollab help quickstart    Getting started
  zzcollab help renv          Package management
  zzcollab help docker        Docker usage
EOF
}

# Function: show_help_team
# Purpose: Team collaboration setup
show_help_team() {
    cat << 'EOF'
TEAM COLLABORATION

Team Lead Setup:
   1. Initialize project:
      zzcollab -t mylab -p study -r analysis

   2. Build and share Docker image:
      make docker-build
      make docker-push-team

   3. Push to GitHub:
      git add .
      git commit -m "Initial project setup"
      git push -u origin main

Team Member Join:
   1. Clone repository:
      git clone https://github.com/mylab/study.git
      cd study

   2. Pull team Docker image:
      zzcollab -u

   3. Start development:
      make r

Workflow:
   - Team members work independently in containers
   - Packages added by anyone appear in shared renv.lock
   - Docker image rebuilt/pushed by team lead when needed
   - Everyone pulls updated image: zzcollab -u

See also:
  zzcollab help workflow      Daily development
  zzcollab help docker        Docker architecture
  zzcollab help config        Team configuration
EOF
}

# Function: show_help_config_topic
# Purpose: Configuration system help
show_help_config_topic() {
    cat << 'EOF'
CONFIGURATION SYSTEM

Configuration Files (priority order):
  1. ./zzcollab.yaml          Project-specific
  2. ~/.zzcollab/config.yaml  User defaults
  3. Built-in defaults

Commands:
  zzcollab -c init                 Create config file
  zzcollab -c set KEY VALUE        Set configuration
  zzcollab -c get KEY              Get configuration
  zzcollab -c list                 List all config

Common Settings:
  team-name          Your Docker Hub organization
  github-account     Your GitHub account
  profile-name       Default Docker profile
  with-examples      Include example files (true/false)

Example:
  zzcollab -c init
  zzcollab -c set team-name "mylab"
  zzcollab -c set profile-name "analysis"
  zzcollab -c set with-examples true

See also:
  zzcollab help profiles     Docker profiles
  zzcollab help examples     Example files
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

By default, zzcollab creates a clean workspace.
Use --with-examples to include example files.

During Initialization:
  zzcollab -p myproject -x
  # or
  zzcollab -p myproject --with-examples

After Initialization:
  cd myproject
  zzcollab --add-examples

Example Files Include:
  analysis/report/report.Rmd        Academic manuscript template
  analysis/report/references.bib    Bibliography file
  analysis/scripts/*.R              Data validation, parallel computing
  analysis/templates/*.R            Analysis and figure templates

Configuration:
  zzcollab -c set with-examples true    # Always include examples

See also:
  zzcollab help workflow     Development workflow
  zzcollab help config       Configuration
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
  make docker-push-team    Share team image

Logs:
  docker-build.log         Build output
  .zzcollab.log            Framework log (with -vv)

Platform Compatibility:
  ARM64: r-ver, rstudio profiles
  AMD64: verse, tidyverse, shiny

Custom Images:
  zzcollab docker --base-image rocker/verse

See also:
  zzcollab help profiles     Profile selection
  zzcollab help renv         Package management
  zzcollab help team         Team collaboration
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
   cat .zzcollab.log        # If using -vv flag

3. Tests fail:
   make docker-test
   # Check test output for specific failures

4. Navigation shortcuts don't work:
   ./navigation_scripts.sh --install
   source ~/.zshrc          # or ~/.bashrc

5. Team image not found:
   # Team lead must push first:
   make docker-build && make docker-push-team

Debug Mode:
   zzcollab -vv ...         # Creates .zzcollab.log
   cat .zzcollab.log        # Review detailed logs

Get Help:
   zzcollab help --all      # List all topics
   GitHub Issues            # Report bugs

See also:
  zzcollab help workflow     Common workflows
  zzcollab help docker       Docker troubleshooting
EOF
}

#=============================================================================
# CHECK-UPDATES HELP
#=============================================================================

# Function: show_help_check_updates
# Purpose: Help for the check-updates command
show_help_check_updates() {
    cat << 'EOF'
CHECK-UPDATES - Detect Outdated Template Files

Usage:
  zzc check-updates                  # Check current directory
  zzc check-updates DIR [DIR ...]    # Check specific workspaces
  zzc check-updates --scan DIR       # Recursively find and check all
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
  zzc check-updates                  # Check workspace in current dir
  zzc check-updates ~/prj/res/study  # Check a specific workspace
  zzc check-updates --scan ~/prj/res # Scan all workspaces under ~/prj/res

See also:
  zzcollab help workflow     Daily development workflow
  zzcollab help docker       Docker architecture
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
    cat << EOF
zzcollab - Complete Research Compendium Setup (Modular Implementation)

Creates a comprehensive research compendium with R package structure, Docker integration,
analysis templates, and reproducible workflows.

USAGE:
    zzcollab [OPTIONS]

OPTIONS:
    Team and project setup:
    -t, --team NAME              Team name (Docker Hub namespace for images)
    -p, --project-name NAME      Project name (directory and package name)
    -g, --github-account NAME    GitHub account (default: same as team)
    -u, --use-team-image         Pull and use existing team Docker image from Docker Hub
                                 (for team members joining existing projects)

    Profile system (three usage patterns):
    -r, --profile-name NAME      Use complete predefined profile (base-image + libs + pkgs)
                                 Examples: minimal, analysis, publishing
    -k, --pkgs BUNDLE            Override package selection (can combine with --profile-name)
                                 If used alone, applies minimal profile as base
                                 Bundles: minimal, tidyverse, modeling, publishing, shiny
    -l, --libs BUNDLE            System dependency bundle (for custom composition with -b)
                                 Bundles: minimal, modeling, publishing, gui
    -b, --base-image NAME        Custom Docker base image (for manual composition)
    -a, --tag TAG                Docker image tag for selecting team image variants
    --list-profiles              List all available predefined profiles
    --list-libs                  List all available library bundles
    --list-pkgs                  List all available package bundles

    Common options:

    Advanced options:
    -b, --base-image NAME        Use custom Docker base image (for composition with --libs and --pkgs)
        --r-version VERSION      Specify R version for Docker build (e.g., 4.4.0)
                                 Required if renv.lock is missing; overrides renv.lock if present
        --build-docker           Build Docker image automatically during setup
    -n, --no-docker              Skip Docker image build (default; build manually with 'make docker-build')
    -G, --github                 Automatically create private GitHub repository and push
    -x, --with-examples          Include example files (report.Rmd, analysis scripts, vignettes)
                                 Default: skip examples (create clean workspace)
                                 Can also set via: zzcollab -c set with-examples true
        --add-examples           Add example files to existing project (run from project root)
                                 Use this after initialization if you initially skipped examples
        --force                  Skip file conflict confirmation prompts (for CI/CD and automation)
        --next-steps             Show development workflow and next steps

    Output control:
    -q, --quiet                  Quiet mode (errors only, ~0 lines)
    -v, --verbose                Verbose mode (show progress, ~25 lines)
    -vv, --debug                 Debug mode (show everything, ~400 lines + log file)
    -w, --log-file               Enable detailed logging to .zzcollab.log

    Utilities:
    -h, --help [TOPIC]           Show help (general or specific topic)
                                 Topics: init, github, quickstart, workflow, troubleshooting,
                                         config, renv, docker, cicd
EOF
}

# Function: show_help_examples  
# Purpose: Display usage examples section
show_help_examples() {
    cat << EOF
    
EXAMPLES:
    Solo Developer - Three Profile Usage Patterns:

    Pattern 1: Complete Profile (no overrides)
    zzcollab -r analysis -G                     # Uses: rocker/tidyverse + minimal libs + tidyverse pkgs
    zzcollab -r publishing                      # Uses: rocker/verse + publishing libs + publishing pkgs
    zzcollab -r minimal                         # Uses: rocker/r-ver + minimal libs + minimal pkgs

    Pattern 2: Profile with Package Override
    zzcollab -r publishing -k minimal           # Uses: rocker/verse + publishing libs + minimal pkgs (OVERRIDE)
    zzcollab -r analysis -k modeling            # Uses: rocker/tidyverse + minimal libs + modeling pkgs (OVERRIDE)

    Pattern 3: Package-Only (uses minimal profile as base)
    zzcollab -k modeling                        # Uses: rocker/r-ver + minimal libs + modeling pkgs
    zzcollab -k tidyverse                       # Uses: rocker/r-ver + minimal libs + tidyverse pkgs

    Discovery Commands:
    zzcollab --list-profiles                    # See all available profiles with descriptions
    zzcollab --list-libs                        # See all library bundles
    zzcollab --list-pkgs                        # See all package bundles

    Solo Developer - Manual Composition (advanced):
    zzcollab -b rocker/verse -l publishing -k tidyverse             # Full manual control
    zzcollab -b rocker/tidyverse -l modeling -k modeling

    Team Lead - Create Foundation and Push:
    zzcollab -t mylab -p study -r analysis -G   # Initialize with profile
    make docker-build                           # Build team Docker image
    make docker-push-team                       # Push to Docker Hub (mylab/study:latest)
    git add .
    git commit -m "Initial team project setup"
    git push -u origin main

    Team Lead - Custom Composition:
    zzcollab -t mylab -p study -b rocker/r-ver -l modeling -k modeling
    make docker-build
    make docker-push-team
    git add .
    git commit -m "Initial team setup with custom composition"
    git push -u origin main

    Team Members - Join Existing Project:
    git clone https://github.com/mylab/study.git && cd study
    zzcollab -u                                 # Pull and use team image (mylab/study:latest)
    make r                             # Start development (auto-pulls latest image)

    Output Control:
    zzcollab -t team -p project                 # Default: concise output (~8 lines)
    zzcollab -t team -p project -q              # Quiet: errors only (for CI/CD)
    zzcollab -t team -p project -v              # Verbose: show progress (~25 lines)
    zzcollab -t team -p project -vv             # Debug: everything + log file (~400 lines)
    zzcollab -t team -p project -w              # Enable log file without debug verbosity

    Note: Foundation flags (-r/--profile-name, -b, -l/--libs, -k/--pkgs) are
          automatically blocked when Dockerfile exists. To change: rm Dockerfile first.
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
    zzcollab -c set profile-name analysis                # Set default Docker profile
    zzcollab -c list                                     # Show all current settings
    zzcollab -c reset                                    # Reset to defaults

    Configuration files:
    - User-level: ~/.config/zzcollab/config.yaml
    - Team-level: .zzcollab/config.yaml (if present)

    Settings: team-name, github-account, profile-name,
              auto-github, skip-confirmation
EOF
}

# Function: show_help_footer
# Purpose: Display footer with additional resources
show_help_footer() {
    cat << EOF

SPECIALIZED HELP PAGES:

Getting Started:
  zzcollab --help quickstart      Individual researcher quick start guide
  zzcollab --help workflow        Daily development workflow

Configuration:
  zzcollab --help config          Configuration system guide
  zzcollab --help renv            Package management with renv

Technical Details:
  zzcollab --help init            Team initialization process
  zzcollab --help docker          Docker essentials for researchers
  zzcollab --help cicd            CI/CD and GitHub Actions

Integration:
  zzcollab --help github          GitHub integration and automation
  zzcollab --help troubleshooting Common issues and solutions

Development:
  zzcollab --next-steps           Development workflow guidance

📋 RESEARCH COMPENDIUM GUIDE:
After project creation, see README.md for comprehensive information about:
- Unified research compendium structure (based on Marwick et al. 2018)
- Complete research lifecycle support (data → analysis → paper → package)
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
# QUICK START GUIDES
#=============================================================================

# Function: show_quickstart_help
# Purpose: Quick start guide for individual researchers
show_quickstart_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_quickstart_help_content
    else
        show_quickstart_help_content | "${PAGER:-less}" -R
    fi
}

show_quickstart_help_content() {
    cat << 'EOF'
🚀 QUICK START GUIDE - INDIVIDUAL RESEARCHERS

═══════════════════════════════════════════════════════════════════════════
YOU'RE NOT ON A TEAM - SIMPLIFIED WORKFLOW
═══════════════════════════════════════════════════════════════════════════

This guide is for individual researchers who want to:
• Work on personal research projects
• Create reproducible analysis environments
• Get started quickly without team collaboration setup

Key Point: You don't need a "team" - just use your name as the team name!

═══════════════════════════════════════════════════════════════════════════
SIMPLEST POSSIBLE SETUP (5 MINUTES)
═══════════════════════════════════════════════════════════════════════════

Step 1: One-Time Configuration
──────────────────────────────────────────────────────────────────────────
Set your defaults so you never have to type them again:

    zzcollab config set team-name "yourname"
    zzcollab config set profile-name "analysis"

Replace "yourname" with your actual name or username (e.g., "jsmith")
This becomes your Docker Hub namespace (like jsmith/project-rstudio:latest)

Step 2: Create Your First Project
──────────────────────────────────────────────────────────────────────────
    cd ~/projects  # Or wherever you keep your work
    mkdir analysis1 && cd analysis1
    zzcollab -p analysis1

That's it! Your project is ready.

Step 3: Start Working
──────────────────────────────────────────────────────────────────────────
    make docker-rstudio

Opens RStudio at http://localhost:8787
Login: analyst / analyst

You're now working in a reproducible environment!

═══════════════════════════════════════════════════════════════════════════
COMPLETE FIRST PROJECT WALKTHROUGH
═══════════════════════════════════════════════════════════════════════════

Scenario: You need to complete a data analysis analysis assignment

1. Set up configuration (one time ever):
   ──────────────────────────────────────────────────────────────────────
   zzcollab config set team-name "jsmith"
   zzcollab config set profile-name "analysis"

2. Create project directory:
   ──────────────────────────────────────────────────────────────────────
   mkdir ~/stat545-hw1 && cd ~/stat545-hw1

3. Initialize zzcollab project:
   ──────────────────────────────────────────────────────────────────────
   zzcollab -p stat545-hw1

   This takes 4-6 minutes (downloads R packages)
   Grab coffee, this only happens once!

4. Start RStudio:
   ──────────────────────────────────────────────────────────────────────
   make docker-rstudio

   Opens at http://localhost:8787
   Username: analyst
   Password: analyst

5. Do your analysis:
   ──────────────────────────────────────────────────────────────────────
   In RStudio:
   • Create new R Markdown: File → New → R Markdown
   • Save as: analysis/scripts/analysis1.Rmd
   • Put data in: analysis/data/raw_data/
   • Write your analysis
   • Knit to HTML

6. When finished:
   ──────────────────────────────────────────────────────────────────────
   Close browser tab (RStudio)
   In terminal: Ctrl+C to stop container

7. Next time:
   ──────────────────────────────────────────────────────────────────────
   cd ~/stat545-hw1
   make docker-rstudio

   Everything exactly as you left it!

═══════════════════════════════════════════════════════════════════════════
INDIVIDUAL RESEARCHER FAQS
═══════════════════════════════════════════════════════════════════════════

Q: "Why does it ask for a team name if I'm working alone?"
A: Think of it as YOUR namespace. Use your name. It keeps your Docker
   images organized (like folders on your computer).

Q: "Do I need to know Docker?"
A: No! Just run 'make docker-rstudio' and use RStudio normally.
   Docker runs in the background.

Q: "Can I use my regular R instead?"
A: Yes, but you lose reproducibility. The whole point is that your
   analysis will work exactly the same way 3 years from now.

Q: "What if I need to install a package?"
A: In RStudio console:
     install.packages("packagename")
   Exit container - packages automatically captured!
   (Auto-snapshot runs when you close RStudio or terminal)

Q: "Where do I put my analysis files?"
A: Follow this structure:
   • Data: analysis/data/raw_data/
   • Scripts: analysis/scripts/
   • Output: analysis/figures/

Q: "Can I switch from solo to team later?"
A: Yes! Your project structure is already team-ready. Just share the
   GitHub repo and collaborators can join.

Q: "Do I need a GitHub account?"
A: Not required for solo work. But recommended for:
   • Backing up your analysis
   • Showing work to professors
   • Building your portfolio

Q: "Which Docker profile should I choose?"
A: Use 'analysis' profile - has tidyverse, ggplot2, dplyr in Docker image.
   Additional packages are added dynamically as needed with install.packages().
   That's perfect for most coursework.

Q: "My laptop is slow - can I use a lighter profile?"
A: Yes! Use minimal profile:
     zzcollab config set profile-name "minimal"
   Lightweight base, add packages as you need them.

Q: "How do I add packages I need?"
A: Inside RStudio/container:
     install.packages("package_name")
   Exit container (close RStudio or terminal)
   Packages automatically tracked in renv.lock and shared with team!
   For GitHub packages: install.packages("remotes"), then remotes::install_github("user/package")

═══════════════════════════════════════════════════════════════════════════
INDIVIDUAL RESEARCHER COMPLETE COMMAND REFERENCE
═══════════════════════════════════════════════════════════════════════════

One-Time Setup:
──────────────────────────────────────────────────────────────────────────
zzcollab config set team-name "yourname"
zzcollab config set profile-name "analysis"

Per-Project (First Time):
──────────────────────────────────────────────────────────────────────────
mkdir projectname && cd projectname
zzcollab -p projectname

Daily Work:
──────────────────────────────────────────────────────────────────────────
cd projectname
make docker-rstudio          # Start RStudio
# Do your work in browser
# Ctrl+C in terminal when done

Common Tasks:
──────────────────────────────────────────────────────────────────────────
make docker-rstudio          # RStudio interface
make r              # Command-line interface
make docker-test             # Run tests
make help                    # See all available commands

═══════════════════════════════════════════════════════════════════════════
AVOIDING COMMON INDIVIDUAL RESEARCHER MISTAKES
═══════════════════════════════════════════════════════════════════════════

❌ DON'T: Create projects in your home directory
   cd ~ && zzcollab -p analysis  # BAD!

✅ DO: Create a projects folder
   mkdir ~/projects && cd ~/projects
   mkdir analysis && cd analysis
   zzcollab -p analysis

❌ DON'T: Use different team names for each project
   zzcollab -t proj1 -p analysis1
   zzcollab -t proj2 -p analysis2  # Confusing!

✅ DO: Use one team name (yours) for everything
   zzcollab config set team-name "yourname"
   Then just: zzcollab -p analysis1, zzcollab -p analysis2

❌ DON'T: Forget to save your work in the right place
   Files outside /project won't persist!

✅ DO: Always work in the mounted directory
   RStudio starts in /home/analyst/project (correct location)

❌ DON'T: Run zzcollab multiple times in same directory
   mkdir proj && cd proj
   zzcollab -p proj
   zzcollab -p proj  # Don't do this again!

✅ DO: Only run zzcollab once per project
   It sets everything up the first time

═══════════════════════════════════════════════════════════════════════════
EXAMPLE: TYPICAL SEMESTER WORKFLOW
═══════════════════════════════════════════════════════════════════════════

Week 1: Setup
──────────────────────────────────────────────────────────────────────────
zzcollab config set team-name "jsmith"
zzcollab config set profile-name "analysis"

Week 2-3: Analysis 1
──────────────────────────────────────────────────────────────────────────
mkdir ~/stat545/hw1 && cd ~/stat545/hw1
zzcollab -p hw1
make docker-rstudio
# Complete analysis in RStudio
# Close browser, Ctrl+C in terminal

Week 4-5: Analysis 2
──────────────────────────────────────────────────────────────────────────
mkdir ~/stat545/hw2 && cd ~/stat545/hw2
zzcollab -p hw2  # Uses your saved config!
make docker-rstudio
# Complete analysis

Week 6-10: Final Project
──────────────────────────────────────────────────────────────────────────
mkdir ~/stat545/final-project && cd ~/stat545/final-project
zzcollab -p final-project
make docker-rstudio

# Work on project multiple times:
cd ~/stat545/final-project
make docker-rstudio  # Day 1
# Close when done

cd ~/stat545/final-project
make docker-rstudio  # Day 2
# Close when done

# All your work is saved between sessions!

═══════════════════════════════════════════════════════════════════════════
WHEN YOU'RE READY FOR MORE
═══════════════════════════════════════════════════════════════════════════

Once comfortable with basics, explore:

Add version control:
  zzcollab -p project -G    # Automatically creates GitHub repo

Share with professor/TA:
  1. Use -G flag to create GitHub repo
  2. Share GitHub link
  3. They can reproduce your exact environment!

Try different interfaces:
  make r           # Command-line for advanced users
  make docker-r             # Just R console

Learn more about:
  zzcollab --help-workflow        # Daily development patterns
  zzcollab --help-renv            # Package management
  zzcollab --help-troubleshooting # Fix common issues

═══════════════════════════════════════════════════════════════════════════
QUICK REFERENCE CARD (PRINT THIS!)
═══════════════════════════════════════════════════════════════════════════

ONE-TIME SETUP:
  zzcollab config set team-name "yourname"
  zzcollab config set profile-name "analysis"

NEW PROJECT:
  mkdir ~/projects/projectname && cd ~/projects/projectname
  zzcollab -p projectname
  make docker-rstudio

DAILY WORK:
  cd ~/projects/projectname
  make docker-rstudio
  # Work in browser at localhost:8787
  # Login: analyst / analyst
  # When done: close browser, Ctrl+C in terminal

FILE LOCATIONS:
  Data:    analysis/data/raw_data/
  Scripts: analysis/scripts/
  Figures: analysis/figures/

INSTALL PACKAGE:
  In RStudio console:
    install.packages("packagename")
  Exit container - automatically captured!
  (For GitHub: install.packages("remotes") then remotes::install_github("user/package"))

HELP:
  zzcollab --help-workflow
  zzcollab --help-troubleshooting
  zzcollab --help-renv

═══════════════════════════════════════════════════════════════════════════

For complete documentation: zzcollab --help
For troubleshooting: zzcollab --help-troubleshooting
For daily workflow: zzcollab --help-workflow
EOF
}

#=============================================================================
# MODULE LOADED
#=============================================================================

readonly ZZCOLLAB_HELP_LOADED=true
