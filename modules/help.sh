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
    -M, --minimal                Minimal mode: ultra-fast (3 packages: renv, remotes, here) ~30s
    -F, --fast                   Fast mode: development essentials (9 packages) 2-3 min
    -S, --standard               Standard mode: balanced packages (17 packages) 4-6 min [default]
    -C, --comprehensive          Comprehensive mode: full ecosystem (47+ packages) 15-20 min
    
    Utilities:
    -h, --help                   Show this help message
        --help-init              Show team initialization help specifically
        --help-variants          Show Docker variants configuration help with examples
        --help-github            Show GitHub integration help with examples
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
    zzcollab -i -t rgt47 -p study -M -d ~/dotfiles                      # Minimal mode: ultra-fast (~30s)
    zzcollab -i -t rgt47 -p study -F -d ~/dotfiles                      # Fast mode: development essentials (2-3 min)
    zzcollab -i -t rgt47 -p study -S -d ~/dotfiles                      # Standard mode: balanced setup (4-6 min, default)
    zzcollab -i -t rgt47 -p study -C -d ~/dotfiles                      # Comprehensive mode: full ecosystem (15-20 min)
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
For GitHub integration help, run: zzcollab --help-github
For development workflow guidance, run: zzcollab --next-steps

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
🐙 GITHUB INTEGRATION HELP

═══════════════════════════════════════════════════════════════════════════
OVERVIEW
═══════════════════════════════════════════════════════════════════════════

zzcollab can automatically create GitHub repositories and push your project,
streamlining the workflow from local development to remote collaboration.

Key Features:
• Automatic private repository creation
• Git initialization and initial commit
• Remote setup and push
• Collaboration-ready project structure

═══════════════════════════════════════════════════════════════════════════
REQUIREMENTS
═══════════════════════════════════════════════════════════════════════════

Before using GitHub integration (-G flag), ensure:

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
FLAGS AND OPTIONS
═══════════════════════════════════════════════════════════════════════════

-G, --github
    Automatically create private GitHub repository and push project

    Example:
    zzcollab -t myteam -p myproject -G -d ~/dotfiles

-g, --github-account NAME
    Specify GitHub account for repository creation
    Default: Uses team name (-t) if not specified

    Example:
    zzcollab -t dockerteam -g githubuser -p project -G -d ~/dotfiles

═══════════════════════════════════════════════════════════════════════════
TEAM NAME vs GITHUB ACCOUNT (CRITICAL CONCEPT)
═══════════════════════════════════════════════════════════════════════════

zzcollab separates Docker Hub namespace from GitHub account:

TEAM NAME (-t):
• Used for Docker Hub image namespace
• Creates images like: myteam/projectcore-rstudio:latest
• Can be organization or personal Docker Hub account

GITHUB ACCOUNT (-g):
• Used for GitHub repository creation
• Creates repos like: https://github.com/username/project
• Can be different from team name
• Defaults to team name if not specified

═══════════════════════════════════════════════════════════════════════════
USAGE EXAMPLES
═══════════════════════════════════════════════════════════════════════════

Example 1: Same name for Docker Hub and GitHub (simplest)
──────────────────────────────────────────────────────────────────────────
zzcollab -t myname -p study -B rstudio -S -G -d ~/dotfiles

Creates:
  Docker:  myname/studycore-rstudio:latest
  GitHub:  https://github.com/myname/study
  (both use "myname")

Example 2: Different Docker Hub and GitHub accounts
──────────────────────────────────────────────────────────────────────────
zzcollab -t labteam -g johndoe -p analysis -B rstudio -S -G -d ~/dotfiles

Creates:
  Docker:  labteam/analysiscore-rstudio:latest (team Docker images)
  GitHub:  https://github.com/johndoe/analysis (personal GitHub)

Example 3: Personal Docker Hub, Organization GitHub
──────────────────────────────────────────────────────────────────────────
zzcollab -t myname -g mycompany -p project -B rstudio -S -G -d ~/dotfiles

Creates:
  Docker:  myname/projectcore-rstudio:latest (personal Docker Hub)
  GitHub:  https://github.com/mycompany/project (company GitHub)

Example 4: Using configuration (recommended for solo developers)
──────────────────────────────────────────────────────────────────────────
# One-time setup:
zzcollab --config set team-name "myname"
zzcollab --config set github-account "myname"
zzcollab --config set auto-github true

# Then simply:
zzcollab -p newproject -d ~/dotfiles

Creates GitHub repo automatically using configured settings

═══════════════════════════════════════════════════════════════════════════
CONFIGURATION OPTIONS
═══════════════════════════════════════════════════════════════════════════

Set defaults to avoid typing them repeatedly:

github-account:
    zzcollab --config set github-account "yourusername"
    Sets default GitHub account for all projects

auto-github:
    zzcollab --config set auto-github true
    Automatically creates GitHub repo without needing -G flag

    zzcollab --config set auto-github false
    Disables automatic GitHub repo creation (default)

View current settings:
    zzcollab --config list

Example workflow with configuration:
    # Setup once:
    zzcollab --config set team-name "rgt47"
    zzcollab --config set github-account "rgt47"
    zzcollab --config set auto-github true
    zzcollab --config set build-mode "standard"
    zzcollab --config set dotfiles-dir "~/dotfiles"

    # Then all new projects are simple:
    zzcollab -p myproject    # GitHub repo created automatically!

═══════════════════════════════════════════════════════════════════════════
PUBLIC vs PRIVATE REPOSITORIES
═══════════════════════════════════════════════════════════════════════════

Current Behavior:
• All repositories created with -G flag are PRIVATE by default
• This is the recommended setting for research projects

To Make a Repository Public:
After creation, change visibility manually:
    gh repo edit USERNAME/PROJECTNAME --visibility public

Or create without -G and use gh directly:
    zzcollab -t myteam -p project -d ~/dotfiles    # No -G flag
    gh repo create USERNAME/PROJECTNAME --public --source=. --push

Future Enhancement:
A --public flag may be added in future versions for direct public repo creation.

═══════════════════════════════════════════════════════════════════════════
WHEN TO USE DIFFERENT NAMES
═══════════════════════════════════════════════════════════════════════════

Use different team name and GitHub account when:

1. Personal/Professional Split:
   • Docker Hub: Professional organization account
   • GitHub: Personal account

2. Open Source Collaboration:
   • Docker Hub: Project team shared images
   • GitHub: Your fork or personal contribution repo

3. Multi-Organization Work:
   • Docker Hub: Lab/team shared computational environments
   • GitHub: University or institutional account

4. Docker Hub Pricing Workaround:
   • Docker Hub: Paid organization (unlimited private images)
   • GitHub: Free account (unlimited private repos)

═══════════════════════════════════════════════════════════════════════════
WHAT HAPPENS DURING GITHUB INTEGRATION
═══════════════════════════════════════════════════════════════════════════

When you use the -G flag, zzcollab performs these steps:

1. Validates GitHub CLI prerequisites
   • Checks gh is installed
   • Verifies authentication status

2. Checks for repository conflicts
   • Ensures repository doesn't already exist
   • Prevents accidental overwrites

3. Initializes local git repository
   • Creates .git directory
   • Stages all project files
   • Creates initial commit

4. Creates GitHub repository
   • Creates private repository on GitHub
   • Sets description: "Research compendium for PROJECT project"

5. Pushes to GitHub
   • Adds GitHub as remote origin
   • Sets main branch
   • Pushes initial commit

═══════════════════════════════════════════════════════════════════════════
TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════════════

Issue: "gh: command not found"
────────────────────────────────────────────────────────────────────────
Problem: GitHub CLI not installed
Solution:
    macOS:    brew install gh
    Ubuntu:   sudo apt install gh
    Windows:  winget install GitHub.cli

Issue: "authentication required"
────────────────────────────────────────────────────────────────────────
Problem: Not logged in to GitHub CLI
Solution:
    gh auth login
    # Follow prompts to authenticate

Verify with:
    gh auth status

Issue: "repository already exists"
────────────────────────────────────────────────────────────────────────
Problem: Repository with same name already exists on GitHub
Solutions:
    Option 1: Delete existing repository
    gh repo delete USERNAME/PROJECTNAME --confirm

    Option 2: Use different project name
    zzcollab -t team -p different-name -G -d ~/dotfiles

    Option 3: Skip GitHub creation, push manually
    zzcollab -t team -p project -d ~/dotfiles  # No -G
    git remote add origin https://github.com/USERNAME/PROJECTNAME.git
    git push -u origin main

Issue: "GitHub account not specified"
────────────────────────────────────────────────────────────────────────
Problem: No team name or GitHub account provided
Solution:
    Specify team name (used as GitHub account by default):
    zzcollab -t USERNAME -p project -G -d ~/dotfiles

    Or specify GitHub account explicitly:
    zzcollab -t dockerteam -g githubuser -p project -G -d ~/dotfiles

    Or set in configuration:
    zzcollab --config set github-account "yourusername"

Issue: Permission denied (publickey)
────────────────────────────────────────────────────────────────────────
Problem: SSH key not configured for GitHub
Solution:
    GitHub CLI uses HTTPS by default, not SSH
    If you encounter this:

    1. Check authentication:
       gh auth status

    2. Re-authenticate if needed:
       gh auth login

    3. Select HTTPS (not SSH) when prompted

Issue: Rate limit exceeded
────────────────────────────────────────────────────────────────────────
Problem: Too many API requests to GitHub
Solution:
    Wait 1 hour for rate limit reset
    Or authenticate to increase limit:
    gh auth login

═══════════════════════════════════════════════════════════════════════════
TEAM COLLABORATION WORKFLOWS
═══════════════════════════════════════════════════════════════════════════

Scenario 1: Team Lead Creates Shared Project
──────────────────────────────────────────────────────────────────────────
Team lead:
    zzcollab -i -t labteam -p study -B rstudio -S -G -d ~/dotfiles

    Creates:
    • Docker: labteam/studycore-rstudio:latest (pushed to Docker Hub)
    • GitHub: https://github.com/labteam/study (private repo)

Team members:
    git clone https://github.com/labteam/study.git
    cd study
    zzcollab -t labteam -p study -I rstudio -d ~/dotfiles
    make docker-rstudio

Scenario 2: Solo Researcher, Personal Accounts
──────────────────────────────────────────────────────────────────────────
# Setup once:
zzcollab --config set team-name "myname"
zzcollab --config set github-account "myname"

# Each new project:
zzcollab -p analysis1 -G -d ~/dotfiles
zzcollab -p analysis2 -G -d ~/dotfiles
zzcollab -p paper3 -G -d ~/dotfiles

Each creates private GitHub repo automatically

Scenario 3: Personal Docker, Organization GitHub
──────────────────────────────────────────────────────────────────────────
Contribute to organization but maintain personal Docker images:

zzcollab -t myname -g myorg -p project -B rstudio -S -G -d ~/dotfiles

Creates:
• Docker: myname/projectcore-rstudio:latest (your Docker Hub)
• GitHub: https://github.com/myorg/project (org GitHub)

═══════════════════════════════════════════════════════════════════════════
ADDITIONAL RESOURCES
═══════════════════════════════════════════════════════════════════════════

zzcollab Documentation:
    zzcollab --help              # Main help
    zzcollab --help-init         # Team initialization help
    zzcollab --help-variants     # Docker variants help
    zzcollab --next-steps        # Development workflow guidance

GitHub CLI Documentation:
    gh --help                    # GitHub CLI help
    gh repo --help               # Repository commands
    gh auth --help               # Authentication commands

Project Resources:
    Website: https://github.com/rgt47/zzcollab
    Examples: https://github.com/rgt47/zzcollab/tree/main/examples

Configuration Guide:
    Run: zzcollab --config list
    See: ~/.zzcollab/config.yaml for your configuration file

═══════════════════════════════════════════════════════════════════════════

For general zzcollab help: zzcollab --help
For more information: https://github.com/rgt47/zzcollab
EOF
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================


