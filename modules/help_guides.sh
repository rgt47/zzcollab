#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB PRACTICAL GUIDES MODULE
##############################################################################
#
# PURPOSE: Practical how-to guides and workflows
#          Documentation content now stored in markdown files (docs/guides/)
#
# DEPENDENCIES: core.sh (logging), constants.sh (paths)
#
# TRACKING: No file creation - pure documentation display
##############################################################################

# Validate required modules are loaded
require_module "core"

#=============================================================================
# MARKDOWN HELPER FUNCTION
#=============================================================================

# Function: read_guide_markdown
# Purpose: Read and display markdown guide from docs/guides/
# Args: $1 - guide name (e.g., "workflow", "troubleshooting")
read_guide_markdown() {
    local guide_name="$1"
    local guide_file="${ZZCOLLAB_SCRIPT_DIR}/docs/guides/${guide_name}.md"

    if [[ ! -f "$guide_file" ]]; then
        log_error "Guide not found: ${guide_file}"
        echo "Documentation file missing: ${guide_name}.md"
        echo "Please reinstall zzcollab or check your installation."
        return 1
    fi

    cat "$guide_file"
}

#=============================================================================
# DAILY WORKFLOW GUIDE
#=============================================================================

# Function: show_workflow_help
# Purpose: Daily development workflow for students/beginners
show_workflow_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_workflow_help_content
    else
        show_workflow_help_content | "${PAGER:-less}" -R
    fi
}

show_workflow_help_content() {
    read_guide_markdown "workflow"
}

#=============================================================================
# TROUBLESHOOTING GUIDE
#=============================================================================

# Function: show_troubleshooting_help
# Purpose: Common issues and solutions
show_troubleshooting_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_troubleshooting_help_content
    else
        show_troubleshooting_help_content | "${PAGER:-less}" -R
    fi
}

show_troubleshooting_help_content() {
    read_guide_markdown "troubleshooting"
}

#=============================================================================
# CONFIGURATION GUIDE
#=============================================================================

# Function: show_config_help
# Purpose: Configuration system guide
show_config_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_config_help_content
    else
        show_config_help_content | "${PAGER:-less}" -R
    fi
}

show_config_help_content() {
    read_guide_markdown "config"
}

#=============================================================================
# DOTFILES GUIDE
#=============================================================================

# Function: show_dotfiles_help
# Purpose: Dotfiles setup and management
show_dotfiles_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_dotfiles_help_content
    else
        show_dotfiles_help_content | "${PAGER:-less}" -R
    fi
}

show_dotfiles_help_content() {
    read_guide_markdown "dotfiles"
}

#=============================================================================
# RENV/PACKAGE MANAGEMENT GUIDE
#=============================================================================

# Function: show_renv_help
# Purpose: Package management with renv
show_renv_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_renv_help_content
    else
        show_renv_help_content | "${PAGER:-less}" -R
    fi
}

show_renv_help_content() {
    read_guide_markdown "renv"
}

#=============================================================================
# DOCKER GUIDE
#=============================================================================

# Function: show_docker_help
# Purpose: Docker essentials and container management
show_docker_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_docker_help_content
    else
        show_docker_help_content | "${PAGER:-less}" -R
    fi
}

show_docker_help_content() {
    read_guide_markdown "docker"
}

#=============================================================================
# CI/CD GUIDE
#=============================================================================

# Function: show_cicd_help
# Purpose: Continuous integration and deployment
show_cicd_help() {
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then
        show_cicd_help_content
    else
        show_cicd_help_content | "${PAGER:-less}" -R
    fi
}

show_cicd_help_content() {
    read_guide_markdown "cicd"
}

##############################################################################
# END OF HELP GUIDES MODULE
##############################################################################
#
# NOTE: This file was refactored from 3,596 lines to 169 lines (95% reduction)
#       All documentation content migrated to markdown files in docs/guides/
#       Original heredoc-based implementation: October 2024
#       Markdown-based implementation: October 2025
#
##############################################################################
