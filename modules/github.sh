#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB GITHUB MODULE
##############################################################################
#
# PURPOSE: GitHub integration, repository management, and CI/CD workflows
#          - Repository creation and initialization
#          - Git workflow automation
#          - GitHub Actions workflows for CI/CD
#          - Team collaboration setup
#
# DEPENDENCIES: core.sh, templates.sh
##############################################################################


#=============================================================================
# GITHUB ACTIONS WORKFLOWS (merged from cicd.sh)
#
# Repository creation is handled inline by cmd_github in zzcollab.sh; this
# module now provides only the workflow installer below.
#=============================================================================

# Install CI for the configured forge (CONFIG_FORGE, default github). GitHub
# gets the two Actions workflows; GitLab gets the single .gitlab-ci.yml. Called
# at init time from setup_project.
create_ci_workflows() {
    load_config 2>/dev/null || true
    if [[ "${CONFIG_FORGE:-github}" == gitlab ]]; then
        create_gitlab_ci
    else
        create_github_workflows
    fi
}

create_gitlab_ci() {
    log_debug "Creating GitLab CI pipeline..."
    if install_template "gitlab/.gitlab-ci.yml" ".gitlab-ci.yml" \
        "GitLab CI pipeline" "Created GitLab CI pipeline"; then
        log_info "  - Stages: check, render"
        log_info "  - Triggers: merge requests and default branch"
    else
        log_error "Failed to create GitLab CI pipeline"
        return 1
    fi
    log_success "GitLab CI pipeline created"
}

create_github_workflows() {
    log_debug "Creating GitHub Actions workflows..."

    local workflows_dir=".github/workflows"
    safe_mkdir "$workflows_dir" "GitHub workflows directory" || return 1

    if install_template "workflows/r-package.yml" ".github/workflows/r-package.yml" \
        "R package validation workflow" "Created R package workflow"; then
        log_info "  - Triggers: push/PR to main"
        log_info "  - Actions: R CMD check, tests"
    else
        log_error "Failed to create R package workflow"
        return 1
    fi

    local paper_workflow_template
    paper_workflow_template=$(get_workflow_template 2>/dev/null || echo "workflows/render-report.yml")
    if install_template "$paper_workflow_template" ".github/workflows/render-report.yml" \
        "Report rendering workflow" "Created report rendering workflow"; then
        log_info "  - Triggers: changes to analysis/, R/"
        log_info "  - Output: PDF artifacts"
    else
        log_error "Failed to create report workflow"
        return 1
    fi

    log_success "GitHub Actions workflows created"
}

