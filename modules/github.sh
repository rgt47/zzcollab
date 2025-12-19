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

require_module "core" "templates"

#=============================================================================
# GITHUB PREREQUISITES
#=============================================================================

validate_github_prerequisites() {
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI (gh) not installed. Install: brew install gh"
        return 1
    fi
    if ! gh auth status >/dev/null 2>&1; then
        log_error "GitHub CLI not authenticated. Run: gh auth login"
        return 1
    fi
    return 0
}

#=============================================================================
# REPOSITORY MANAGEMENT
#=============================================================================

prepare_github_repository() {
    local github_account="$1" project_name="$2"

    if gh repo view "${github_account}/${project_name}" >/dev/null 2>&1; then
        log_error "Repository ${github_account}/${project_name} already exists"
        log_info "Delete: gh repo delete ${github_account}/${project_name} --confirm"
        return 1
    fi

    [[ -d ".git" ]] || git init
    git add .
    if ! git diff --staged --quiet; then
        git commit -m "Initial zzcollab project setup

- Research compendium structure
- Docker containerization ready
- CI/CD workflows configured

Generated with zzcollab --github"
    fi
    return 0
}

create_and_push_repository() {
    local github_account="$1" project_name="$2"

    log_info "Creating private repository on GitHub..."
    gh repo create "${github_account}/${project_name}" \
        --private \
        --description "Research compendium for ${project_name}" \
        --clone=false

    git remote add origin "https://github.com/${github_account}/${project_name}.git"
    git branch -M main
    git push -u origin main
    return 0
}

show_collaboration_guidance() {
    local github_account="$1" project_name="$2"

    log_success "GitHub repository created: https://github.com/${github_account}/${project_name}"
    log_info "Team members can join with:"
    log_info "  git clone https://github.com/${github_account}/${project_name}.git"
    log_info "  cd ${project_name} && zzcollab"
}

create_github_repository_workflow() {
    validate_github_prerequisites || return 1

    local github_account="${GITHUB_ACCOUNT:-$TEAM_NAME}"
    [[ -z "$github_account" ]] && { log_error "GitHub account not specified"; return 1; }

    local project_name="${PROJECT_NAME:-$(basename "$(pwd)")}"
    log_info "Creating repository: ${github_account}/${project_name}"

    prepare_github_repository "$github_account" "$project_name" || return 1
    create_and_push_repository "$github_account" "$project_name" || return 1
    show_collaboration_guidance "$github_account" "$project_name"
}

#=============================================================================
# GITHUB ACTIONS WORKFLOWS (merged from cicd.sh)
#=============================================================================

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

create_github_templates() {
    log_debug "Creating GitHub repository templates..."

    local pr_template='## Description
Brief description of changes.

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Analysis update

## Checklist
- [ ] Tests pass locally
- [ ] Code follows style guidelines
- [ ] Documentation updated'

    if create_file_if_missing ".github/pull_request_template.md" "$pr_template" "PR template"; then
        track_file ".github/pull_request_template.md"
    fi

    local issue_dir=".github/ISSUE_TEMPLATE"
    safe_mkdir "$issue_dir" "issue templates directory"

    local bug_template='---
name: Bug report
about: Report a bug
title: "[BUG] "
labels: bug
---

**Describe the bug**
What happened?

**To Reproduce**
Steps to reproduce.

**Expected behavior**
What should happen.

**Environment**
- OS:
- R Version:
- Docker: Yes/No'

    if create_file_if_missing "$issue_dir/bug_report.md" "$bug_template" "bug template"; then
        track_file "$issue_dir/bug_report.md"
    fi

    local feature_template='---
name: Feature request
about: Suggest an idea
title: "[FEATURE] "
labels: enhancement
---

**Problem**
Describe the problem.

**Solution**
What you want.

**Alternatives**
Other options considered.'

    if create_file_if_missing "$issue_dir/feature_request.md" "$feature_template" "feature template"; then
        track_file "$issue_dir/feature_request.md"
    fi

    log_success "GitHub templates created"
}

show_cicd_summary() {
    log_info "CI/CD summary:"
    cat << 'EOF' >&2
GitHub Actions Workflows:
  .github/workflows/r-package.yml     - R package validation
  .github/workflows/render-report.yml - Report rendering

Push to GitHub to activate workflows.
EOF
}

#=============================================================================
# MODULE LOADED FLAG
#=============================================================================

readonly ZZCOLLAB_GITHUB_LOADED=true
readonly ZZCOLLAB_CICD_LOADED=true
