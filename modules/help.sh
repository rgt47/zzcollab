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
    Team and project setup:
    -t, --team-name NAME         Team name (Docker Hub namespace for images)
    -p, --project-name NAME      Project name (directory and package name)
    -g, --github-account NAME    GitHub account (default: same as team-name)
    --use-team-image             Pull and use existing team Docker image from Docker Hub
                                 (for team members joining existing projects)

    Profile system (three usage patterns):
    --profile-name NAME          Use complete predefined profile (base-image + libs + pkgs)
                                 Examples: bioinformatics, geospatial, alpine_minimal
    --pkgs BUNDLE                Override package selection (can combine with --profile-name)
                                 If used alone, applies minimal profile as base
                                 Bundles: minimal, tidyverse, modeling, bioinfo, geospatial, publishing, shiny
    --libs BUNDLE                System dependency bundle (for custom composition with -b)
                                 Bundles: minimal, geospatial, bioinfo, modeling, publishing, alpine
    -b, --base-image NAME        Custom Docker base image (for manual composition)
    --tag TAG                    Docker image tag for selecting team image variants
    --list-profiles              List all available predefined profiles
    --list-libs                  List all available library bundles
    --list-pkgs                  List all available package bundles

    Common options:
    -d, --dotfiles DIR           Copy dotfiles from directory (files with leading dots)
    -D, --dotfiles-nodot DIR     Copy dotfiles from directory (files without leading dots)

    Advanced options:
    -b, --base-image NAME        Use custom Docker base image (for composition with --libs and --pkgs)
        --build-docker           Build Docker image automatically during setup
    -n, --no-docker              Skip Docker image build (default; build manually with 'make docker-build')
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
    Solo Developer - Three Profile Usage Patterns:

    Pattern 1: Complete Profile (no overrides)
    zzcollab --profile-name bioinformatics -G   # Uses: bioconductor base + bioinfo libs + bioinfo pkgs
    zzcollab --profile-name geospatial          # Uses: rocker/r-ver + geospatial libs + geospatial pkgs
    zzcollab --profile-name alpine_minimal      # Uses: alpine-r + alpine libs + minimal pkgs

    Pattern 2: Profile with Package Override
    zzcollab --profile-name bioinformatics --pkgs minimal   # Uses: bioconductor base + bioinfo libs + minimal pkgs (OVERRIDE)
    zzcollab --profile-name geospatial --pkgs tidyverse       # Uses: rocker/r-ver + geospatial libs + tidyverse pkgs (OVERRIDE)

    Pattern 3: Package-Only (uses minimal profile as base)
    zzcollab --pkgs modeling                    # Uses: rocker/r-ver + minimal libs + modeling pkgs
    zzcollab --pkgs tidyverse                   # Uses: rocker/r-ver + minimal libs + tidyverse pkgs

    Discovery Commands:
    zzcollab --list-profiles                    # See all available profiles with descriptions
    zzcollab --list-libs                        # See all library bundles
    zzcollab --list-pkgs                        # See all package bundles

    Solo Developer - Manual Composition (advanced):
    zzcollab -b rocker/r-ver --libs geospatial --pkgs geospatial    # Full manual control
    zzcollab -b bioconductor/bioconductor_docker --libs bioinfo --pkgs bioinfo

    Team Lead - Create Foundation and Push:
    zzcollab -t rgt47 -p study --profile-name bioinformatics -G
    make docker-build                           # Build team Docker image
    make docker-push-team                       # Push to Docker Hub (rgt47/study:latest)
    git add .
    git commit -m "Initial team project setup"
    git push -u origin main

    Team Lead - Custom Composition:
    zzcollab -t rgt47 -p study -b rocker/r-ver --libs modeling --pkgs modeling
    make docker-build
    make docker-push-team
    git add .
    git commit -m "Initial team setup with custom composition"
    git push -u origin main

    Team Members - Join Existing Project:
    git clone https://github.com/rgt47/study.git && cd study
    zzcollab --use-team-image                   # Pull and use team image (rgt47/study:latest)
    make docker-zsh                             # Start development (auto-pulls latest image)

    Note: Foundation flags (--profile-name, -b, --libs, --pkgs) are automatically
          blocked when Dockerfile exists. To change foundation: rm Dockerfile first.

    Simplified Build Modes:
    zzcollab --profile-name bioinformatics -M               # Minimal mode: ultra-fast (~30s)
    zzcollab --profile-name geospatial -F                   # Fast mode: essentials (2-3 min)
    zzcollab --profile-name modeling -S                     # Standard mode: balanced (4-6 min, default)
    zzcollab --profile-name publishing -C                   # Comprehensive mode: full (15-20 min)
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
    zzcollab -c set renv-mode fast                      # Set default build mode
    zzcollab -c list                                     # Show all current settings
    zzcollab -c reset                                    # Reset to defaults
    
    Configuration files:
    - User-level: ~/.config/zzcollab/config.yaml
    - Team-level: .zzcollab/config.yaml (if present)
    
    Settings: team-name, github-account, renv-mode, dotfiles-dir, 
              dotfiles-nodot, auto-github, skip-confirmation
EOF
}

# Function: show_help_footer
# Purpose: Display footer with additional resources
show_help_footer() {
    cat << EOF

SPECIALIZED HELP PAGES:

Getting Started:
  zzcollab --help-quickstart      Individual researcher quick start guide
  zzcollab --help-workflow        Daily development workflow

Configuration:
  zzcollab --help-config          Configuration system guide
  zzcollab --help-dotfiles        Dotfiles setup and management
  zzcollab --help-renv-modes     Build mode selection guide

Technical Details:
  zzcollab --help-init            Team initialization process
  zzcollab --help-variants        Docker variants configuration
  zzcollab --help-docker          Docker essentials for researchers
  zzcollab --help-renv            Package management with renv
  zzcollab --help-cicd            CI/CD and GitHub Actions

Integration:
  zzcollab --help-github          GitHub integration and automation
  zzcollab --help-troubleshooting Common issues and solutions

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
zzcollab -t myname -p study --profile-name modeling -G -d ~/dotfiles
make docker-build
make docker-push-team
git add .
git commit -m "Initial project setup"
git push -u origin main

Creates:
  Docker:  myname/study:latest
  GitHub:  https://github.com/myname/study
  (both use "myname")

Example 2: Different Docker Hub and GitHub accounts
──────────────────────────────────────────────────────────────────────────
zzcollab -t labteam -g johndoe -p analysis --profile-name modeling -G -d ~/dotfiles
make docker-build
make docker-push-team
git add .
git commit -m "Initial team analysis setup"
git push -u origin main

Creates:
  Docker:  labteam/analysis:latest (team Docker images)
  GitHub:  https://github.com/johndoe/analysis (personal GitHub)

Example 3: Personal Docker Hub, Organization GitHub
──────────────────────────────────────────────────────────────────────────
zzcollab -t myname -g mycompany -p project --profile-name modeling -G -d ~/dotfiles
make docker-build
make docker-push-team
git add .
git commit -m "Initial organization project setup"
git push -u origin main

Creates:
  Docker:  myname/project:latest (personal Docker Hub)
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
    zzcollab --config set renv-mode "standard"
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
Team lead - Step 1: Create foundation and GitHub repo
    zzcollab -t labteam -p study --profile-name modeling -G -d ~/dotfiles

Team lead - Step 2: Build and push team image
    make docker-build                       # Build labteam/study:latest
    make docker-push-team                   # Push to Docker Hub
    git add .
    git commit -m "Initial team project setup"
    git push -u origin main

    Creates:
    • Docker: labteam/study:latest (pushed to Docker Hub)
    • GitHub: https://github.com/labteam/study (private repo)
    • Dockerfile: Locked foundation (team members cannot change)

Team members - Join existing project:
    git clone https://github.com/labteam/study.git
    cd study
    zzcollab --use-team-image               # Pull team image from Docker Hub
    make docker-zsh                         # Start development

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

zzcollab -t myname -g myorg -p project --profile-name modeling -G -d ~/dotfiles
make docker-build
make docker-push-team
git add .
git commit -m "Initial organization project setup"
git push -u origin main

Creates:
• Docker: myname/project:latest (your Docker Hub)
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

    zzcollab --config set team-name "yourname"
    zzcollab --config set renv-mode "standard"

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
   zzcollab --config set team-name "jsmith"
   zzcollab --config set renv-mode "standard"

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
   Then update your project:
     renv::snapshot()

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

Q: "Which build mode should I choose?"
A: Standard mode (default) - has tidyverse, ggplot2, dplyr
   That's perfect for most coursework.

Q: "My laptop is slow - can I use a faster mode?"
A: Yes! Use Fast mode:
     zzcollab --config set renv-mode "fast"
   Only 9 packages, builds in 2-3 minutes.

Q: "I need packages not in Standard mode"
A: Either:
   1. Use Comprehensive mode (47 packages): --config set renv-mode "comprehensive"
   2. Just install them as you need them in RStudio

═══════════════════════════════════════════════════════════════════════════
INDIVIDUAL RESEARCHER COMPLETE COMMAND REFERENCE
═══════════════════════════════════════════════════════════════════════════

One-Time Setup:
──────────────────────────────────────────────────────────────────────────
zzcollab --config set team-name "yourname"
zzcollab --config set renv-mode "standard"

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
make docker-zsh              # Command-line interface
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
   zzcollab --config set team-name "yourname"
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
zzcollab --config set team-name "jsmith"
zzcollab --config set renv-mode "standard"

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
  make docker-zsh           # Command-line for advanced users
  make docker-r             # Just R console

Learn more about:
  zzcollab --help-workflow        # Daily development patterns
  zzcollab --help-renv            # Package management
  zzcollab --help-troubleshooting # Fix common issues

═══════════════════════════════════════════════════════════════════════════
QUICK REFERENCE CARD (PRINT THIS!)
═══════════════════════════════════════════════════════════════════════════

ONE-TIME SETUP:
  zzcollab --config set team-name "yourname"
  zzcollab --config set renv-mode "standard"

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
    renv::snapshot()

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
# MODULE VALIDATION AND LOADING
#=============================================================================


