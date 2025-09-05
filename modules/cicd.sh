#!/bin/bash
##############################################################################
# ZZCOLLAB CI/CD MODULE
##############################################################################
# 
# PURPOSE: Continuous Integration and Deployment workflows
#          - GitHub Actions workflows for R package testing
#          - Automated paper rendering and publishing
#          - Package validation and quality checks
#          - Deployment automation
#
# DEPENDENCIES: core.sh (logging), templates.sh (file creation)
#
# TRACKING: All created CI/CD files are tracked for uninstall capability
##############################################################################

# Validate required modules are loaded
require_module "core" "templates"

#=============================================================================
# GITHUB ACTIONS WORKFLOWS CREATION (extracted from lines 538-549)
#=============================================================================

# Function: create_github_workflows
# Purpose: Creates GitHub Actions workflows for automated CI/CD
# Creates:
#   - .github/workflows/r-package.yml (R package testing and validation)
#   - .github/workflows/render-paper.yml (automated paper rendering)
#
# Workflow Features:
#   - Automated R package checking with R CMD check
#   - Multi-platform testing (Ubuntu, macOS, Windows)
#   - Package dependency validation with renv
#   - Automated paper rendering on changes
#   - Artifact uploading for rendered papers
#   - Integration with GitHub Pages (optional)
#
# CI/CD Benefits:
#   - Continuous quality assurance
#   - Automated testing on pull requests
#   - Reproducible builds across platforms
#   - Automated documentation updates
#   - Version control integration
#
# Tracking: All created workflow files are tracked in manifest for uninstall
create_github_workflows() {
    log_info "Creating GitHub Actions workflows..."
    
    # Ensure .github/workflows directory exists
    # This directory is the standard location for GitHub Actions workflows
    local workflows_dir=".github/workflows"
    if ! safe_mkdir "$workflows_dir" "GitHub workflows directory"; then
        return 1
    fi
    
    # Create R package check workflow
    # Choose between full validation or minimal research-focused workflow
    local workflow_template="workflows/r-package.yml"
    # Choose workflow template based on build mode
    workflow_template=$(get_workflow_template)
    
    local workflow_description
    local output_filename
    
    # Determine workflow description and output filename based on paradigm
    if [[ -n "$PARADIGM" ]]; then
        case "$PARADIGM" in
            analysis)
                workflow_description="Data analysis workflow"
                output_filename="analysis-workflow.yml"
                ;;
            manuscript)
                workflow_description="Academic manuscript workflow"
                output_filename="manuscript-workflow.yml"
                ;;
            package)
                workflow_description="R package development workflow"
                output_filename="package-workflow.yml"
                ;;
            *)
                workflow_description="Standard research workflow"
                output_filename="r-package.yml"
                ;;
        esac
    else
        # Fallback to build mode logic
        case "$BUILD_MODE" in
            fast)
                workflow_description="Minimal research project workflow"
                output_filename="r-package.yml"
                ;;
            comprehensive)
                workflow_description="Comprehensive R package validation workflow"
                output_filename="r-package.yml"
                ;;
            *)
                workflow_description="Standard R package validation workflow"
                output_filename="r-package.yml"
                ;;
        esac
    fi
    
    if install_template "$workflow_template" ".github/workflows/$output_filename" "Primary workflow" "Created $workflow_description"; then
        log_info "  - Triggers: push/PR to main branch"
        case "$BUILD_MODE" in
            fast)
                log_info "  - Actions: renv sync, structure validation (minimal/fast)"
                ;;
            comprehensive)
                log_info "  - Actions: Full R CMD check, extensive testing, coverage analysis"
                ;;
            *)
                log_info "  - Actions: R CMD check, dependency validation, test execution"
                ;;
        esac
        log_info "  - Platforms: Ubuntu (primary), with optional multi-platform"
    else
        log_error "Failed to create R package workflow"
        return 1
    fi
    
    # Create paper rendering workflow
    # Automatically renders research paper when analysis files change
    # Uploads rendered PDFs as artifacts for easy access
    if install_template "workflows/render-report.yml" ".github/workflows/render-report.yml" "Report rendering workflow" "Created automated report rendering workflow"; then
        log_info "  - Triggers: changes to analysis/report/, R/ directories"
        log_info "  - Actions: render report.Rmd to PDF, upload artifacts"
        log_info "  - Output: downloadable PDF from GitHub Actions tab"
    else
        log_error "Failed to create report rendering workflow"
        return 1
    fi
    
    log_success "GitHub Actions workflows created successfully"
    log_info "Workflows will activate when repository is pushed to GitHub"
}

#=============================================================================
# CI/CD CONFIGURATION AND UTILITIES
#=============================================================================

# Function: create_github_templates
# Purpose: Create additional GitHub repository templates and configuration
# Optional: Adds issue templates, PR templates, and repository settings
create_github_templates() {
    log_info "Creating GitHub repository templates..."
    
    # Create pull request template
    local pr_template='## Description
Brief description of the changes in this pull request.

## Type of change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Analysis update (changes to research analysis or paper)

## Testing
- [ ] Tests pass locally with my changes
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes

## Analysis Impact
- [ ] This change affects data processing
- [ ] This change affects statistical analysis
- [ ] This change affects visualization
- [ ] This change affects manuscript/report output
- [ ] No impact on analysis results

## Checklist
- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] Any dependent changes have been merged and published in downstream modules

## Screenshots (if applicable)
Add screenshots to help explain your changes.

## Additional context
Add any other context about the pull request here.'
    
    if create_file_if_missing ".github/pull_request_template.md" "$pr_template" "pull request template"; then
        track_file ".github/pull_request_template.md"
        log_info "Created pull request template"
    else
        log_warn "Failed to create pull request template"
    fi
    
    # Create issue templates directory
    local issue_templates_dir=".github/ISSUE_TEMPLATE"
    safe_mkdir "$issue_templates_dir" "GitHub issue templates directory"
    
    # Bug report template
    local bug_template='---
name: Bug report
about: Create a report to help us improve
title: "[BUG] "
labels: bug
assignees: ""
---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to ...
2. Click on ...
3. Scroll down to ...
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Environment (please complete the following information):**
 - OS: [e.g. macOS, Windows, Linux]
 - R Version: [e.g. 4.3.0]
 - Package Version: [e.g. 0.1.0]
 - Docker: [Yes/No]

**Session Info**
Please paste the output of `sessionInfo()`:

```r
# Paste sessionInfo() output here
```

**Additional context**
Add any other context about the problem here.

**Reproducible example**
If possible, provide a minimal reproducible example:

```r
# Your code here
```'
    
    if create_file_if_missing "$issue_templates_dir/bug_report.md" "$bug_template" "bug report template"; then
        track_file "$issue_templates_dir/bug_report.md"
        log_info "Created bug report template"
    else
        log_warn "Failed to create bug report template"
    fi
    
    # Feature request template
    local feature_template='---
name: Feature request
about: Suggest an idea for this project
title: "[FEATURE] "
labels: enhancement
assignees: ""
---

**Is your feature request related to a problem? Please describe.**
A clear and concise description of what the problem is. Ex. I'\''m always frustrated when [...]

**Describe the solution you'\''d like**
A clear and concise description of what you want to happen.

**Describe alternatives you'\''ve considered**
A clear and concise description of any alternative solutions or features you'\''ve considered.

**Use case**
Describe how this feature would be used in your research workflow.

**Implementation suggestions**
If you have ideas about how this could be implemented, please share them.

**Additional context**
Add any other context or screenshots about the feature request here.'
    
    if create_file_if_missing "$issue_templates_dir/feature_request.md" "$feature_template" "feature request template"; then
        track_file "$issue_templates_dir/feature_request.md"
        log_info "Created feature request template"
    else
        log_warn "Failed to create feature request template"
    fi
    
    log_success "GitHub repository templates created"
}

# Function: validate_cicd_structure
# Purpose: Verify that all required CI/CD files were created successfully
# Checks: GitHub Actions workflows, templates, directory structure
# Returns: 0 if all files exist, 1 if any are missing
validate_cicd_structure() {
    log_info "Validating CI/CD structure..."
    
    local -r required_files=(
        ".github/workflows/r-package.yml"
        ".github/workflows/render-paper.yml"
    )
    
    local -r optional_files=(
        ".github/pull_request_template.md"
        ".github/ISSUE_TEMPLATE/bug_report.md"
        ".github/ISSUE_TEMPLATE/feature_request.md"
    )
    
    local missing_files=()
    local missing_optional=()
    
    # Check required files
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    # Check optional files
    for file in "${optional_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_optional+=("$file")
        fi
    done
    
    # Report results
    if [[ ${#missing_files[@]} -eq 0 ]]; then
        log_success "All required CI/CD files exist"
        
        if [[ ${#missing_optional[@]} -gt 0 ]]; then
            log_info "Optional files missing: ${missing_optional[*]}"
            log_info "Run create_github_templates() to create them"
        else
            log_success "All optional CI/CD files exist"
        fi
        
        return 0
    else
        log_error "Missing required CI/CD files: ${missing_files[*]}"
        return 1
    fi
}

# Function: show_cicd_summary
# Purpose: Display CI/CD setup summary and usage instructions
show_cicd_summary() {
    log_info "CI/CD infrastructure summary:"
    cat << 'EOF'
🚀 CI/CD INFRASTRUCTURE CREATED:

├── .github/
│   ├── workflows/
│   │   ├── r-package.yml           # R package validation workflow
│   │   └── render-paper.yml        # Automated paper rendering
│   ├── pull_request_template.md    # PR template (optional)
│   └── ISSUE_TEMPLATE/             # Issue templates (optional)
│       ├── bug_report.md
│       └── feature_request.md

🔄 AUTOMATED WORKFLOWS:

📦 R Package Validation:
- Triggers: push/PR to main branch
- Actions: R CMD check, dependency validation, tests
- Platform: Ubuntu (configurable for multi-platform)
- Artifacts: test results and check logs

📄 Report Rendering:
- Triggers: changes to analysis/report/, R/ directories
- Actions: render report.Rmd to PDF
- Artifacts: downloadable PDF from Actions tab
- Integration: automatic on manuscript updates

🛠️ SETUP REQUIREMENTS:
1. Push repository to GitHub
2. Workflows activate automatically
3. Check "Actions" tab for workflow status
4. Download artifacts from completed runs

📋 WORKFLOW FEATURES:
- Automated quality assurance
- Multi-platform testing support
- Dependency validation with renv
- Reproducible build environments
- Integration with package development
- Automated documentation updates

🔧 CUSTOMIZATION:
- Edit .github/workflows/*.yml for custom actions
- Add secrets in repository settings for deployment
- Configure branch protection rules
- Set up GitHub Pages for documentation

📊 MONITORING:
- GitHub Actions tab shows workflow status
- Email notifications on workflow failures
- Badge integration for README files
- Integration with project management tools
EOF
}

#=============================================================================
# CICD MODULE VALIDATION
#=============================================================================

# Validate that .github directory structure can be created
if [[ ! -d ".github" ]] && ! mkdir -p ".github/workflows"; then
    log_warn "Cannot create .github directory - CI/CD setup may fail"
fi


