#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB HELP CORE MODULE
##############################################################################
#
# PURPOSE: Core help system and dispatcher
#          - Main entry point (show_help function)
#          - Brief help overview
#          - Topic listing
#
# DEPENDENCIES: core.sh (logging)
#
# FUNCTIONS:
#   show_help() - Main dispatcher for all help topics
#   show_help_brief() - Brief overview
#   show_help_topics_list() - List all available topics
#
##############################################################################

# Validate required modules are loaded
require_module "core"

#=============================================================================
# HELP FUNCTION DISPATCHER
#=============================================================================

# Function: show_help
# Purpose: Display help for main zzcollab usage (main dispatcher)
# Arguments: $1 = topic (optional)
# Returns: 0 on success, 1 on unknown topic
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
            # Load and show quickstart help
            require_module "help_guides"
            show_help_quickstart
            ;;
        workflow)
            # Load and show workflow help
            require_module "help_guides"
            show_help_workflow
            ;;
        team)
            # Load and show team help
            require_module "help_guides"
            show_help_team
            ;;
        config)
            # Load and show config help
            require_module "help_config"
            show_help_config_topic
            ;;
        profiles)
            # Load and show profiles help
            require_module "help_config"
            show_help_profiles
            ;;
        examples)
            # Load and show examples help
            require_module "help_config"
            show_help_examples_topic
            ;;
        docker)
            # Load and show docker help
            require_module "help_technical"
            show_help_docker
            ;;
        renv)
            # Load and show renv help
            require_module "help_technical"
            show_help_renv
            ;;
        cicd)
            # Load and show cicd help
            require_module "help_technical"
            show_help_cicd
            ;;
        options)
            # Show full options list (original help)
            require_module "help_options"
            show_help_full
            ;;
        troubleshoot|troubleshooting)
            # Load and show troubleshooting help
            require_module "help_advanced"
            show_help_troubleshooting
            ;;
        github)
            # Load and show github help
            require_module "help_advanced"
            show_github_help
            ;;
        next-steps)
            # Load and show next steps
            require_module "help_next_steps"
            show_next_steps
            ;;
        *)
            echo "Unknown help topic: $topic"
            echo "See 'zzcollab help --all' for list of all topics"
            return 1
            ;;
    esac
}

#=============================================================================
# BRIEF HELP DISPLAY
#=============================================================================

# Function: show_help_brief
# Purpose: Show brief overview (git-like) with common workflows and topics
# Displays: Main usage, common workflows, and list of help topics
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
    make docker-zsh                           # Start development

  start a new project (team lead)
    zzcollab -t mylab -p study -r analysis    # Initialize team project
    make docker-build && make docker-push-team # Build and share image
    git add . && git commit -m "init" && git push

  join an existing project (team member)
    git clone https://github.com/team/project.git
    cd project && zzcollab -u                 # Pull team Docker image
    make docker-zsh                           # Start development

  development workflow
    make docker-zsh        # Enter container
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

  Other
    options       Complete list of all command-line options
    github        GitHub integration and automation
    troubleshoot  Common issues and solutions
    next-steps    Post-setup development workflow

'zzcollab help --all' lists all help topics
'zzcollab --help' shows complete options (old format)
EOF
}

#=============================================================================
# HELP TOPICS LIST
#=============================================================================

# Function: show_help_topics_list
# Purpose: List all available help topics with descriptions
# Displays: Organized list of all help topics
show_help_topics_list() {
    cat << 'EOF'
zzcollab help topics:

Guides:
  quickstart      Quick start guide for solo developers
  workflow        Daily development workflow and common tasks
  team            Team collaboration setup and workflows

Configuration:
  config          Configuration system (config files, defaults)
  profiles        Docker profile selection and customization
  examples        Example files and templates (--with-examples)

Technical:
  docker          Docker architecture and container usage
  renv            Package management with renv
  cicd            CI/CD automation with GitHub Actions

Integration:
  github          GitHub integration and automation

Other:
  options         Complete list of all command-line options
  troubleshoot    Common issues and solutions
  next-steps      Post-setup development workflow guidance

Usage:
  zzcollab help <topic>       Show help for specific topic
  zzcollab help --all         Show this list
  zzcollab --help             Show complete options (legacy format)
EOF
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================

# This module is the core dispatcher. Dependent modules are loaded on-demand.
# This keeps the help system modular and efficient.
