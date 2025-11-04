#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB GITHUB MODULE
##############################################################################
# 
# PURPOSE: GitHub integration and repository management
#          - Repository creation and initialization
#          - Git workflow automation
#          - Team collaboration setup
#          - GitHub CLI integration
#
# DEPENDENCIES: core.sh (logging)
##############################################################################

#=============================================================================
# GITHUB REPOSITORY CREATION
#=============================================================================

# Function: validate_github_prerequisites
# Purpose: Validate GitHub CLI and authentication prerequisites
# Returns: 0 on success, 1 on failure
validate_github_prerequisites() {
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI (gh) is not installed. Please install it:"
        log_error "  brew install gh  (macOS) or see https://cli.github.com/"
        return 1
    fi
    
    if ! gh auth status >/dev/null 2>&1; then
        log_error "GitHub CLI is not authenticated. Please run: gh auth login"
        return 1
    fi
    
    return 0
}

# Function: prepare_github_repository
# Purpose: Initialize git repository and commit project files
# Arguments: $1 - github_account, $2 - project_name
# Returns: 0 on success, 1 on failure
prepare_github_repository() {
    local github_account="$1"
    local project_name="$2"
    
    # Check if repository already exists
    if gh repo view "${github_account}/${project_name}" >/dev/null 2>&1; then
        log_error "Repository ${github_account}/${project_name} already exists on GitHub!"
        log_info "Options:"
        log_info "  1. Delete existing: gh repo delete ${github_account}/${project_name} --confirm"
        log_info "  2. Use different name: --project-name NEW_NAME"
        log_info "  3. Push manually: git remote add origin https://github.com/${github_account}/${project_name}.git"
        return 1
    fi
    
    # Initialize git if not already done
    if [[ ! -d ".git" ]]; then
        log_info "Initializing git repository..."
        git init
    fi
    
    # Stage and commit all files
    log_info "Staging and committing project files..."
    git add .
    if git diff --staged --quiet; then
        log_info "No changes to commit"
    else
        git commit -m "🎉 Initial zzcollab project setup

- Complete research compendium structure
- Docker containerization ready
- CI/CD workflows configured
- Private repository for collaborative development

🤖 Generated with [zzcollab](https://github.com/rgt47/zzcollab) --github

Co-Authored-By: zzcollab <noreply@zzcollab.dev>"
    fi
    
    return 0
}

# Function: create_and_push_repository
# Purpose: Create GitHub repository and push code
# Arguments: $1 - github_account, $2 - project_name
# Returns: 0 on success, 1 on failure
create_and_push_repository() {
    local github_account="$1"
    local project_name="$2"
    
    # Create private GitHub repository
    log_info "Creating private repository on GitHub..."
    gh repo create "${github_account}/${project_name}" \
        --private \
        --description "Research compendium for ${project_name} project" \
        --clone=false
    
    # Add remote and push
    log_info "Adding remote and pushing to GitHub..."
    git remote add origin "https://github.com/${github_account}/${project_name}.git"
    git branch -M main
    git push -u origin main
    
    return 0
}

# Function: show_collaboration_guidance
# Purpose: Display final success message and collaboration instructions
# Arguments: $1 - github_account, $2 - project_name
show_collaboration_guidance() {
    local github_account="$1"
    local project_name="$2"
    
    log_success "✅ GitHub repository created: https://github.com/${github_account}/${project_name}"
    log_info ""
    log_info "🎉 Team collaboration ready!"
    log_info ""
    log_info "Team members can now join with:"
    log_info "  git clone https://github.com/${github_account}/${project_name}.git"
    log_info "  cd ${project_name}"
    if [[ -n "$TEAM_NAME" ]]; then
        log_info "  zzcollab -t ${TEAM_NAME} -p ${project_name} --use-team-image"
    else
        log_info "  zzcollab"
    fi
}

# Function: create_github_repository_workflow
# Purpose: Create GitHub repository and push project (coordinating function)
# Returns: 0 on success, 1 on failure
# Globals: GITHUB_ACCOUNT, TEAM_NAME, PROJECT_NAME
create_github_repository_workflow() {
    # Validate GitHub CLI prerequisites
    if ! validate_github_prerequisites; then
        return 1
    fi
    
    # Set GitHub account (use team name if not specified)
    local github_account="${GITHUB_ACCOUNT:-$TEAM_NAME}"
    if [[ -z "$github_account" ]]; then
        log_error "GitHub account not specified. Use --github-account or --team flag"
        return 1
    fi
    
    # Determine project name (use current directory if not specified)
    local project_name="${PROJECT_NAME:-$(basename "$(pwd)")}"
    
    log_info "Creating GitHub repository: ${github_account}/${project_name}"
    
    # Prepare git repository and commit files
    if ! prepare_github_repository "$github_account" "$project_name"; then
        return 1
    fi
    
    # Create GitHub repository and push
    if ! create_and_push_repository "$github_account" "$project_name"; then
        return 1
    fi
    
    # Show collaboration guidance
    show_collaboration_guidance "$github_account" "$project_name"
    
    return 0
}

#=============================================================================
# GITHUB MODULE VALIDATION
#=============================================================================

# Set github module loaded flag
readonly ZZCOLLAB_GITHUB_LOADED=true