#!/bin/bash
##############################################################################
# ZZCOLLAB CONFIGURATION MODULE
##############################################################################
# 
# PURPOSE: Configuration file system for zzcollab
#          - Load configuration from YAML files
#          - Manage user defaults and custom package lists
#          - Support global, user, and project-specific configs
#          - Provide config management commands
#
# DEPENDENCIES: core.sh (logging), yq (YAML parsing)
#
# CONFIGURATION HIERARCHY (highest priority first):
#   1. ./zzcollab.yaml (project-specific)
#   2. ~/.zzcollab/config.yaml (user global)
#   3. Hard-coded defaults (fallback)
##############################################################################

# Validate required modules are loaded
if [[ "${ZZCOLLAB_CORE_LOADED:-}" != "true" ]]; then
    echo "❌ Error: config.sh requires core.sh to be loaded first" >&2
    exit 1
fi

#=============================================================================
# CONFIGURATION FILE PATHS AND CONSTANTS
#=============================================================================

# Configuration file locations (priority order)
readonly CONFIG_PROJECT_FILE="./zzcollab.yaml"
readonly CONFIG_USER_DIR="$HOME/.zzcollab"
readonly CONFIG_USER_FILE="$CONFIG_USER_DIR/config.yaml"
readonly CONFIG_SYSTEM_FILE="/etc/zzcollab/config.yaml"

# Configuration variables (will be populated from files)
declare -A CONFIG_DEFAULTS
declare -A CONFIG_BUILD_MODES
declare -A CONFIG_CUSTOM_MODES

#=============================================================================
# YAML PARSING FUNCTIONS
#=============================================================================

# Function: check_yq_dependency
# Purpose: Check if yq is available for YAML parsing
check_yq_dependency() {
    if ! command -v yq >/dev/null 2>&1; then
        log_warning "yq not found - config file features limited"
        log_warning "Install yq for full configuration support:"
        log_warning "  macOS: brew install yq"
        log_warning "  Ubuntu: snap install yq"
        return 1
    fi
    return 0
}

# Function: yaml_get
# Purpose: Get value from YAML file using yq
# Arguments: $1 = file path, $2 = yaml path (e.g., "defaults.team_name")
yaml_get() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    if check_yq_dependency; then
        yq eval ".$path" "$file" 2>/dev/null || echo "null"
    else
        # Fallback: simple grep-based parsing for basic key-value pairs
        local key="${path##*.}"  # Get last part after dot
        grep "^[[:space:]]*${key}:" "$file" 2>/dev/null | sed 's/.*:[[:space:]]*//' | sed 's/["\047]//g' || echo "null"
    fi
}

# Function: yaml_get_array
# Purpose: Get array values from YAML file
# Arguments: $1 = file path, $2 = yaml path
yaml_get_array() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    if check_yq_dependency; then
        yq eval ".$path[]" "$file" 2>/dev/null | tr '\n' ',' | sed 's/,$//'
    else
        # Fallback: basic array parsing
        echo ""
    fi
}

#=============================================================================
# CONFIGURATION LOADING FUNCTIONS
#=============================================================================

# Function: load_config_file
# Purpose: Load configuration from a specific file
# Arguments: $1 = config file path
load_config_file() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    log_info "Loading configuration from: $config_file"
    
    # Load defaults section
    local team_name=$(yaml_get "$config_file" "defaults.team_name")
    local github_account=$(yaml_get "$config_file" "defaults.github_account")
    local build_mode=$(yaml_get "$config_file" "defaults.build_mode")
    local dotfiles_dir=$(yaml_get "$config_file" "defaults.dotfiles_dir")
    local dotfiles_nodot=$(yaml_get "$config_file" "defaults.dotfiles_nodot")
    local auto_github=$(yaml_get "$config_file" "defaults.auto_github")
    local skip_confirmation=$(yaml_get "$config_file" "defaults.skip_confirmation")
    
    # Store in global config arrays (only if not "null")
    [[ "$team_name" != "null" && -n "$team_name" ]] && CONFIG_DEFAULTS[team_name]="$team_name"
    [[ "$github_account" != "null" && -n "$github_account" ]] && CONFIG_DEFAULTS[github_account]="$github_account"
    [[ "$build_mode" != "null" && -n "$build_mode" ]] && CONFIG_DEFAULTS[build_mode]="$build_mode"
    [[ "$dotfiles_dir" != "null" && -n "$dotfiles_dir" ]] && CONFIG_DEFAULTS[dotfiles_dir]="$dotfiles_dir"
    [[ "$dotfiles_nodot" != "null" && -n "$dotfiles_nodot" ]] && CONFIG_DEFAULTS[dotfiles_nodot]="$dotfiles_nodot"
    [[ "$auto_github" != "null" && -n "$auto_github" ]] && CONFIG_DEFAULTS[auto_github]="$auto_github"
    [[ "$skip_confirmation" != "null" && -n "$skip_confirmation" ]] && CONFIG_DEFAULTS[skip_confirmation]="$skip_confirmation"
    
    return 0
}

# Function: load_all_configs
# Purpose: Load configuration from all available files in priority order
load_all_configs() {
    # Start with hard-coded defaults
    CONFIG_DEFAULTS[team_name]=""
    CONFIG_DEFAULTS[github_account]=""
    CONFIG_DEFAULTS[build_mode]="standard"
    CONFIG_DEFAULTS[dotfiles_dir]=""
    CONFIG_DEFAULTS[dotfiles_nodot]="false"
    CONFIG_DEFAULTS[auto_github]="false"
    CONFIG_DEFAULTS[skip_confirmation]="false"
    
    # Load configs in reverse priority order (later files override earlier ones)
    load_config_file "$CONFIG_SYSTEM_FILE" 2>/dev/null || true
    load_config_file "$CONFIG_USER_FILE" 2>/dev/null || true
    load_config_file "$CONFIG_PROJECT_FILE" 2>/dev/null || true
    
    log_info "Configuration loading complete"
}

#=============================================================================
# CONFIGURATION APPLICATION FUNCTIONS
#=============================================================================

# Function: apply_config_defaults
# Purpose: Apply configuration defaults to CLI variables if they're not already set
apply_config_defaults() {
    # Only set values if they haven't been set by CLI arguments
    [[ -z "$TEAM_NAME" && -n "${CONFIG_DEFAULTS[team_name]}" ]] && TEAM_NAME="${CONFIG_DEFAULTS[team_name]}"
    [[ -z "$GITHUB_ACCOUNT" && -n "${CONFIG_DEFAULTS[github_account]}" ]] && GITHUB_ACCOUNT="${CONFIG_DEFAULTS[github_account]}"
    [[ "$BUILD_MODE" == "standard" && -n "${CONFIG_DEFAULTS[build_mode]}" ]] && BUILD_MODE="${CONFIG_DEFAULTS[build_mode]}"
    [[ -z "$DOTFILES_DIR" && -n "${CONFIG_DEFAULTS[dotfiles_dir]}" ]] && DOTFILES_DIR="${CONFIG_DEFAULTS[dotfiles_dir]}"
    
    # Handle boolean flags
    if [[ "${CONFIG_DEFAULTS[dotfiles_nodot]}" == "true" ]]; then
        DOTFILES_NODOT=true
    fi
    if [[ "${CONFIG_DEFAULTS[auto_github]}" == "true" ]]; then
        CREATE_GITHUB_REPO=true
    fi
    if [[ "${CONFIG_DEFAULTS[skip_confirmation]}" == "true" ]]; then
        SKIP_CONFIRMATION=true
    fi
    
    log_info "Applied configuration defaults to CLI variables"
}

# Function: get_config_value
# Purpose: Get a configuration value by key
# Arguments: $1 = key (e.g., "team_name")
get_config_value() {
    local key="$1"
    echo "${CONFIG_DEFAULTS[$key]:-}"
}

#=============================================================================
# CONFIG FILE MANAGEMENT FUNCTIONS
#=============================================================================

# Function: create_user_config_dir
# Purpose: Create user configuration directory if it doesn't exist
create_user_config_dir() {
    if [[ ! -d "$CONFIG_USER_DIR" ]]; then
        mkdir -p "$CONFIG_USER_DIR"
        log_info "Created configuration directory: $CONFIG_USER_DIR"
    fi
}

# Function: create_default_config
# Purpose: Create a default configuration file
create_default_config() {
    create_user_config_dir
    
    cat > "$CONFIG_USER_FILE" << 'EOF'
# ZZCOLLAB Configuration File
# This file contains default settings for zzcollab projects
# Values here will be used as defaults unless overridden by CLI flags

defaults:
  # Team and GitHub settings
  team_name: ""                    # Docker Hub team/organization name
  github_account: ""               # GitHub account (defaults to team_name if empty)
  
  # Build and environment settings  
  build_mode: "standard"           # Default build mode: fast, standard, comprehensive
  dotfiles_dir: ""                 # Path to dotfiles directory (e.g., "~/dotfiles")
  dotfiles_nodot: false            # Whether dotfiles need dots added
  
  # Automation settings
  auto_github: false               # Automatically create GitHub repository
  skip_confirmation: false         # Skip confirmation prompts

# Custom package lists for build modes (optional)
# Uncomment and customize to override default package sets
#
# build_modes:
#   fast:
#     description: "Quick development setup"
#     docker_packages: [renv, remotes, here, usethis, devtools]
#     renv_packages: [renv, here, usethis, devtools, testthat, knitr, rmarkdown, targets]
#   
#   standard:
#     description: "Balanced research workflow"
#     docker_packages: [renv, remotes, tidyverse, here, usethis, devtools]
#     renv_packages: [renv, here, usethis, devtools, dplyr, ggplot2, tidyr, testthat, palmerpenguins, broom, janitor, DT, conflicted]
#   
#   comprehensive:
#     description: "Full research ecosystem"
#     docker_packages: [renv, remotes, tidyverse, targets, usethis, devtools, conflicted, ggthemes]
#     renv_packages: [renv, here, usethis, devtools, dplyr, ggplot2, tidyr, tidymodels, shiny, plotly, quarto, flexdashboard, survival, lme4, testthat, knitr, rmarkdown, targets, janitor, DT, conflicted, palmerpenguins, broom, kableExtra, bookdown, naniar, skimr, visdat, pkgdown, rcmdcheck, jsonlite, DBI, RSQLite, car, digest, doParallel, foreach, furrr, future, odbc, readr, RMySQL, RPostgres, sessioninfo, covr]

# Custom build modes (optional)
# Add your own build modes with custom package sets
#
# custom_modes:
#   bioinformatics:
#     description: "Bioinformatics research workflow"
#     docker_packages: [renv, remotes, tidyverse, bioconductor]
#     renv_packages: [Biostrings, GenomicRanges, DESeq2, edgeR, limma]
#   
#   geospatial:
#     description: "Geospatial analysis workflow"  
#     docker_packages: [renv, remotes, tidyverse, sf, terra]
#     renv_packages: [sf, terra, raster, leaflet, tmap, mapview]
EOF

    log_success "Created default configuration file: $CONFIG_USER_FILE"
    log_info "Edit this file to customize your zzcollab defaults"
}

#=============================================================================
# CONFIG COMMAND FUNCTIONS  
#=============================================================================

# Function: config_set
# Purpose: Set a configuration value
# Arguments: $1 = key, $2 = value
config_set() {
    local key="$1"
    local value="$2"
    
    if [[ ! -f "$CONFIG_USER_FILE" ]]; then
        create_default_config
    fi
    
    # For now, provide instructions for manual editing
    log_info "To set $key = $value:"
    log_info "Edit: $CONFIG_USER_FILE"
    log_info "Set: defaults.$key: \"$value\""
}

# Function: config_get
# Purpose: Get a configuration value
# Arguments: $1 = key
config_get() {
    local key="$1"
    local value="${CONFIG_DEFAULTS[$key]:-}"
    
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "(not set)"
    fi
}

# Function: config_list
# Purpose: List all configuration values
config_list() {
    echo "Current zzcollab configuration:"
    echo ""
    echo "Defaults:"
    echo "  team_name: $(config_get team_name)"
    echo "  github_account: $(config_get github_account)"
    echo "  build_mode: $(config_get build_mode)"
    echo "  dotfiles_dir: $(config_get dotfiles_dir)"
    echo "  dotfiles_nodot: $(config_get dotfiles_nodot)"
    echo "  auto_github: $(config_get auto_github)"
    echo "  skip_confirmation: $(config_get skip_confirmation)"
    echo ""
    echo "Configuration files (in priority order):"
    [[ -f "$CONFIG_PROJECT_FILE" ]] && echo "  ✓ $CONFIG_PROJECT_FILE" || echo "  ✗ $CONFIG_PROJECT_FILE"
    [[ -f "$CONFIG_USER_FILE" ]] && echo "  ✓ $CONFIG_USER_FILE" || echo "  ✗ $CONFIG_USER_FILE"
    [[ -f "$CONFIG_SYSTEM_FILE" ]] && echo "  ✗ $CONFIG_SYSTEM_FILE (system-wide)"
}

# Function: config_validate
# Purpose: Validate configuration files
config_validate() {
    local errors=0
    
    echo "Validating zzcollab configuration..."
    echo ""
    
    for config_file in "$CONFIG_PROJECT_FILE" "$CONFIG_USER_FILE"; do
        if [[ -f "$config_file" ]]; then
            echo "Checking: $config_file"
            if check_yq_dependency; then
                if yq eval '.' "$config_file" >/dev/null 2>&1; then
                    echo "  ✓ Valid YAML syntax"
                else
                    echo "  ❌ Invalid YAML syntax"
                    ((errors++))
                fi
            else
                echo "  ⚠️  Cannot validate (yq not available)"
            fi
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        echo ""
        echo "✓ Configuration validation passed"
        return 0
    else
        echo ""
        echo "❌ Configuration validation failed ($errors errors)"
        return 1
    fi
}

#=============================================================================
# CONFIG COMMAND DISPATCHER
#=============================================================================

# Function: handle_config_command
# Purpose: Handle config subcommands
# Arguments: $1 = subcommand, $2+ = arguments
handle_config_command() {
    local subcommand="$1"
    shift
    
    case "$subcommand" in
        set)
            if [[ $# -ne 2 ]]; then
                echo "Usage: zzcollab config set KEY VALUE"
                exit 1
            fi
            config_set "$1" "$2"
            ;;
        get)
            if [[ $# -ne 1 ]]; then
                echo "Usage: zzcollab config get KEY"
                exit 1
            fi
            config_get "$1"
            ;;
        list)
            config_list
            ;;
        validate)
            config_validate
            ;;
        init)
            create_default_config
            ;;
        *)
            echo "❌ Error: Unknown config subcommand '$subcommand'"
            echo "Valid subcommands: set, get, list, validate, init"
            exit 1
            ;;
    esac
}

#=============================================================================
# MODULE INITIALIZATION
#=============================================================================

# Function: init_config_system
# Purpose: Initialize the configuration system
init_config_system() {
    # Load all configuration files
    load_all_configs
    
    # Apply defaults to CLI variables (only if not already set)
    apply_config_defaults
    
    log_info "Configuration system initialized"
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================

# Set config module loaded flag
readonly ZZCOLLAB_CONFIG_LOADED=true

log_info "Configuration module loaded successfully"