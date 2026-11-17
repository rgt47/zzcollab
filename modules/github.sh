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

    local archetype="${ZZCOLLAB_ARCHETYPE:-${CONFIG_ARCHETYPE:-analysis}}"

    # One workflow set per archetype (zzc_workflow_pairs): a book gets
    # render-book.yml, a blog post blog-render.yml, and every other
    # compendium r-package.yml (omitted for --bare, which has no package)
    # plus render-report.yml when it has a report (zzc_has_report). The
    # report scaffold runs before this (create_analysis_files precedes
    # create_ci_workflows in setup_project), so a scaffolded report counts.
    local pairs
    pairs=$(zzc_workflow_pairs "$archetype" .)
    if [[ -z "$pairs" ]]; then
        log_info "No GitHub workflows apply (no R package and no report)"
        return 0
    fi

    local workflows_dir=".github/workflows"
    safe_mkdir "$workflows_dir" "GitHub workflows directory" || return 1

    local pair tmpl dest
    while IFS= read -r pair; do
        tmpl="${pair%%|*}"; dest="${pair##*|}"
        if ! install_template "$tmpl" "$dest" \
            "$(basename "$dest") workflow" "Created $(basename "$dest")"; then
            log_error "Failed to create $dest"
            return 1
        fi
    done <<< "$pairs"

    log_success "GitHub Actions workflows created"
}

