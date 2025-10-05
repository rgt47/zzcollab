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
# Validate required modules are loaded
require_module "core"

#=============================================================================
# CONFIGURATION FILE PATHS AND CONSTANTS
#=============================================================================

# Configuration file locations (priority order)
# Use centralized constants if available
readonly CONFIG_PROJECT_FILE="${ZZCOLLAB_CONFIG_PROJECT:-./zzcollab.yaml}"
readonly CONFIG_USER_DIR="${ZZCOLLAB_CONFIG_USER_DIR:-$HOME/.zzcollab}"
readonly CONFIG_USER_FILE="${ZZCOLLAB_CONFIG_USER:-$CONFIG_USER_DIR/config.yaml}"
readonly CONFIG_SYSTEM_FILE="${ZZCOLLAB_CONFIG_SYSTEM:-/etc/zzcollab/config.yaml}"

# Configuration variables (will be populated from files)
# Using simple variables instead of associative arrays for compatibility
CONFIG_TEAM_NAME=""
CONFIG_GITHUB_ACCOUNT=""
CONFIG_BUILD_MODE="standard"
CONFIG_DOTFILES_DIR=""
CONFIG_DOTFILES_NODOT="false"
CONFIG_AUTO_GITHUB="false"
CONFIG_SKIP_CONFIRMATION="false"

# Package list cache (loaded from config files)
CONFIG_FAST_DOCKER_PACKAGES=""
CONFIG_FAST_RENV_PACKAGES=""
CONFIG_STANDARD_DOCKER_PACKAGES=""
CONFIG_STANDARD_RENV_PACKAGES=""
CONFIG_COMPREHENSIVE_DOCKER_PACKAGES=""
CONFIG_COMPREHENSIVE_RENV_PACKAGES=""

#=============================================================================
# YAML PARSING FUNCTIONS
#=============================================================================

##############################################################################
# FUNCTION: check_yq_dependency
# PURPOSE:  Verify that yq YAML parser is available for configuration processing
# USAGE:    check_yq_dependency
# ARGS:     
#   None
# RETURNS:  
#   0 - yq command is available in PATH
#   1 - yq command not found (provides installation instructions)
# GLOBALS:  
#   READ:  PATH (via command -v)
#   WRITE: None (outputs installation guidance to stderr)
# DESCRIPTION:
#   This function checks for the availability of the yq YAML processing tool,
#   which is required for full configuration file support. Without yq, the
#   configuration system falls back to basic grep-based parsing with limited
#   functionality.
# FALLBACK BEHAVIOR:
#   - Provides helpful installation instructions for common platforms
#   - Returns error code but doesn't terminate the program
#   - Configuration system continues with reduced functionality
# INSTALLATION GUIDANCE:
#   - macOS: brew install yq
#   - Ubuntu: snap install yq
#   - Other platforms: See https://github.com/mikefarah/yq#install
# EXAMPLE:
#   if check_yq_dependency; then
#       echo "Full YAML configuration support available"
#   else
#       echo "Using fallback configuration parsing"
#   fi
##############################################################################
check_yq_dependency() {
    if ! command -v yq >/dev/null 2>&1; then
        # Use echo instead of log functions which may not be loaded yet
        echo "⚠️  yq not found - config file features limited" >&2
        echo "⚠️  Install yq for full configuration support:" >&2
        echo "⚠️    macOS: brew install yq" >&2
        echo "⚠️    Ubuntu: snap install yq" >&2
        return 1
    fi
    return 0
}

##############################################################################
# FUNCTION: yaml_get
# PURPOSE:  Extract a value from YAML configuration file with fallback parsing
# USAGE:    yaml_get "config.yaml" "defaults.team_name"
# ARGS:     
#   $1 - file: Path to YAML configuration file
#   $2 - path: YAML path specification (e.g., "defaults.team_name", "build_modes.fast.packages")
# RETURNS:  
#   0 - Always succeeds, outputs extracted value or "null"
# GLOBALS:  
#   READ:  None
#   WRITE: None (outputs extracted value to stdout)
# DESCRIPTION:
#   This function provides robust YAML value extraction with intelligent fallback.
#   When yq is available, it uses proper YAML parsing. When yq is not available,
#   it falls back to grep-based parsing for simple key-value pairs.
# PARSING METHODS:
#   - Primary: yq eval (full YAML specification support)
#   - Fallback: grep + sed (basic key-value parsing only)
# ERROR HANDLING:
#   - Returns "null" for missing files or keys
#   - Handles nested keys by extracting the final component
#   - Suppresses error output to avoid user confusion
# EXAMPLE:
#   team=$(yaml_get "zzcollab.yaml" "defaults.team_name")
#   if [[ "$team" != "null" ]]; then
#       echo "Team: $team"
#   fi
##############################################################################
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

##############################################################################
# FUNCTION: yaml_get_array
# PURPOSE:  Extract array values from YAML configuration file
# USAGE:    yaml_get_array "config.yaml" "build_modes.fast.packages"
# ARGS:     
#   $1 - file: Path to YAML configuration file
#   $2 - path: YAML path to array (e.g., "build_modes.fast.packages")
# RETURNS:  
#   0 - Always succeeds, outputs comma-separated array values or empty string
# GLOBALS:  
#   READ:  None
#   WRITE: None (outputs comma-separated values to stdout)
# DESCRIPTION:
#   This function extracts YAML array values and formats them as comma-separated
#   strings for easy processing by shell scripts. It requires yq for proper
#   array parsing and returns empty string when yq is not available.
# OUTPUT FORMAT:
#   - Comma-separated values: "item1,item2,item3"
#   - Empty string for missing arrays or when yq unavailable
#   - No trailing comma in output
# LIMITATIONS:
#   - Fallback parsing does not support arrays (returns empty string)
#   - Requires yq for full functionality
# EXAMPLE:
#   packages=$(yaml_get_array "config.yaml" "build_modes.fast.docker_packages")
#   IFS=',' read -ra PACKAGE_ARRAY <<< "$packages"
#   for pkg in "${PACKAGE_ARRAY[@]}"; do
#       echo "Package: $pkg"
#   done
##############################################################################
yaml_get_array() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    if check_yq_dependency; then
        yq eval ".${path}[]" "$file" 2>/dev/null | tr '\n' ',' | sed 's/,$//'
    else
        # Fallback: basic array parsing
        echo ""
    fi
}

##############################################################################
# FUNCTION: yaml_set
# PURPOSE:  Set a value in YAML configuration file with fallback editing
# USAGE:    yaml_set "config.yaml" "defaults.team_name" "myteam"
# ARGS:     
#   $1 - file: Path to YAML configuration file
#   $2 - path: YAML path specification (e.g., "defaults.team_name")
#   $3 - value: New value to set
# RETURNS:  
#   0 - Successfully updated the YAML file
#   1 - Failed to update (file not writable, yq not available, etc.)
# GLOBALS:  
#   READ:  None
#   WRITE: None (modifies the specified YAML file in place)
# DESCRIPTION:
#   This function provides automatic YAML value setting with intelligent 
#   fallback. When yq is available, it uses proper YAML modification. When yq
#   is not available, it falls back to sed-based editing for simple key-value
#   pairs.
# MODIFICATION METHODS:
#   - Primary: yq eval with in-place editing (full YAML specification support)
#   - Fallback: sed-based replacement (basic key-value editing only)
# ERROR HANDLING:
#   - Returns 1 for missing files or write permission issues
#   - Handles nested keys by updating the complete path
#   - Creates backup files during modification to prevent corruption
# EXAMPLE:
#   yaml_set "zzcollab.yaml" "defaults.team_name" "rgt47"
#   yaml_set "config.yaml" "defaults.build_mode" "fast"
##############################################################################
yaml_set() {
    local file="$1"
    local path="$2" 
    local value="$3"
    
    if [[ ! -f "$file" ]]; then
        log_error "Configuration file not found: $file"
        return 1
    fi
    
    if [[ ! -w "$file" ]]; then
        log_error "Configuration file not writable: $file"
        return 1
    fi
    
    if check_yq_dependency; then
        # Use yq for proper YAML modification
        if yq eval ".$path = \"$value\"" "$file" -i 2>/dev/null; then
            log_info "Updated $path = \"$value\" in $file"
            return 0
        else
            log_error "Failed to update YAML file with yq"
            return 1
        fi
    else
        # Fallback: sed-based editing for simple key-value pairs
        local key="${path##*.}"  # Get last part after dot
        local temp_file="${file}.tmp"
        
        # Use sed to replace the key value
        if sed "s/^[[:space:]]*${key}:[[:space:]]*.*/${key}: \"${value}\"/" "$file" > "$temp_file"; then
            if mv "$temp_file" "$file"; then
                log_info "Updated $key = \"$value\" in $file (fallback mode)"
                return 0
            else
                rm -f "$temp_file" 2>/dev/null
                log_error "Failed to update configuration file"
                return 1
            fi
        else
            rm -f "$temp_file" 2>/dev/null
            log_error "Failed to modify configuration with sed"
            return 1
        fi
    fi
}

#=============================================================================
# CONFIGURATION LOADING FUNCTIONS
#=============================================================================

##############################################################################
# FUNCTION: load_custom_package_lists
# PURPOSE:  Load custom package lists from configuration file build_modes section
# USAGE:    load_custom_package_lists "zzcollab.yaml"
# ARGS:     
#   $1 - config_file: Path to YAML configuration file
# RETURNS:  
#   0 - Successfully processed configuration file
#   1 - Configuration file not found or not readable
# GLOBALS:  
#   READ:  None
#   WRITE: CONFIG_*_DOCKER_PACKAGES, CONFIG_*_RENV_PACKAGES variables
# DESCRIPTION:
#   This function loads custom package lists for different build modes from
#   configuration files. It populates global variables that are used by the
#   Docker and R package management systems to install appropriate packages
#   for each build mode.
# CONFIGURATION STRUCTURE:
#   build_modes:
#     fast:
#       docker_packages: ["package1", "package2"]
#       renv_packages: ["pkg1", "pkg2"]
#     standard:
#       docker_packages: [...]
#       renv_packages: [...]
#     comprehensive:
#       docker_packages: [...]
#       renv_packages: [...]
# GLOBAL VARIABLES SET:
#   - CONFIG_FAST_DOCKER_PACKAGES
#   - CONFIG_FAST_RENV_PACKAGES
#   - CONFIG_STANDARD_DOCKER_PACKAGES
#   - CONFIG_STANDARD_RENV_PACKAGES
#   - CONFIG_COMPREHENSIVE_DOCKER_PACKAGES
#   - CONFIG_COMPREHENSIVE_RENV_PACKAGES
# EXAMPLE:
#   load_custom_package_lists "./zzcollab.yaml"
#   echo "Fast mode Docker packages: $CONFIG_FAST_DOCKER_PACKAGES"
##############################################################################
load_custom_package_lists() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # Load build mode package lists if they exist
    for mode in fast standard comprehensive; do
        if check_yq_dependency; then
            # Try to get docker and renv packages for this mode
            local docker_packages=$(yaml_get_array "$config_file" "build_modes.$mode.docker_packages")
            local renv_packages=$(yaml_get_array "$config_file" "build_modes.$mode.renv_packages")
            
            # Store in global variables if found
            if [[ -n "$docker_packages" && "$docker_packages" != "null" ]]; then
                case "$mode" in
                    fast) CONFIG_FAST_DOCKER_PACKAGES="$docker_packages" ;;
                    standard) CONFIG_STANDARD_DOCKER_PACKAGES="$docker_packages" ;;
                    comprehensive) CONFIG_COMPREHENSIVE_DOCKER_PACKAGES="$docker_packages" ;;
                esac
            fi
            
            if [[ -n "$renv_packages" && "$renv_packages" != "null" ]]; then
                case "$mode" in
                    fast) CONFIG_FAST_RENV_PACKAGES="$renv_packages" ;;
                    standard) CONFIG_STANDARD_RENV_PACKAGES="$renv_packages" ;;
                    comprehensive) CONFIG_COMPREHENSIVE_RENV_PACKAGES="$renv_packages" ;;
                esac
            fi
        fi
    done
}

##############################################################################
# FUNCTION: load_config_file
# PURPOSE:  Load configuration values from a specific YAML configuration file
# USAGE:    load_config_file "~/.zzcollab/config.yaml"
# ARGS:     
#   $1 - config_file: Path to YAML configuration file to load
# RETURNS:  
#   0 - Successfully loaded configuration from file
#   1 - Configuration file not found or not readable
# GLOBALS:  
#   READ:  None
#   WRITE: CONFIG_* variables (team_name, github_account, build_mode, etc.)
# DESCRIPTION:
#   This function loads configuration values from a single YAML file and
#   populates the global CONFIG_* variables. It processes the 'defaults'
#   section of the configuration file and handles custom package lists.
# CONFIGURATION SECTIONS PROCESSED:
#   - defaults.team_name: Docker Hub team/organization name
#   - defaults.github_account: GitHub account for repository creation
#   - defaults.build_mode: Default build mode (fast/standard/comprehensive)
#   - defaults.dotfiles_dir: Path to personal dotfiles directory
#   - defaults.dotfiles_nodot: Whether dotfiles need leading dots added
#   - defaults.auto_github: Automatically create GitHub repositories
#   - defaults.skip_confirmation: Skip confirmation prompts
# VALIDATION:
#   - Only sets CONFIG_* variables if values are not "null" and non-empty
#   - Preserves existing values if new file doesn't contain a key
#   - Gracefully handles missing files without error
# EXAMPLE:
#   load_config_file "./zzcollab.yaml"
#   echo "Team: $CONFIG_TEAM_NAME, Mode: $CONFIG_BUILD_MODE"
##############################################################################
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

    # Store in global config variables (only if not "null")
    [[ "$team_name" != "null" && -n "$team_name" ]] && CONFIG_TEAM_NAME="$team_name"
    [[ "$github_account" != "null" && -n "$github_account" ]] && CONFIG_GITHUB_ACCOUNT="$github_account"
    [[ "$build_mode" != "null" && -n "$build_mode" ]] && CONFIG_BUILD_MODE="$build_mode"
    [[ "$dotfiles_dir" != "null" && -n "$dotfiles_dir" ]] && CONFIG_DOTFILES_DIR="$dotfiles_dir"
    [[ "$dotfiles_nodot" != "null" && -n "$dotfiles_nodot" ]] && CONFIG_DOTFILES_NODOT="$dotfiles_nodot"
    [[ "$auto_github" != "null" && -n "$auto_github" ]] && CONFIG_AUTO_GITHUB="$auto_github"
    [[ "$skip_confirmation" != "null" && -n "$skip_confirmation" ]] && CONFIG_SKIP_CONFIRMATION="$skip_confirmation"
    
    # Load custom package lists from build_modes section
    load_custom_package_lists "$config_file"
    
    return 0
}

# Function: load_all_configs
# Purpose: Load configuration from all available files in priority order
load_all_configs() {
    # Start with hard-coded defaults (already set in variable declarations)
    CONFIG_TEAM_NAME=""
    CONFIG_GITHUB_ACCOUNT=""
    CONFIG_BUILD_MODE="standard"
    CONFIG_DOTFILES_DIR=""
    CONFIG_DOTFILES_NODOT="false"
    CONFIG_AUTO_GITHUB="false"
    CONFIG_SKIP_CONFIRMATION="false"
    
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
    [[ -z "$TEAM_NAME" && -n "$CONFIG_TEAM_NAME" ]] && TEAM_NAME="$CONFIG_TEAM_NAME"
    [[ -z "$GITHUB_ACCOUNT" && -n "$CONFIG_GITHUB_ACCOUNT" ]] && GITHUB_ACCOUNT="$CONFIG_GITHUB_ACCOUNT"
    [[ "$BUILD_MODE" == "standard" && -n "$CONFIG_BUILD_MODE" ]] && BUILD_MODE="$CONFIG_BUILD_MODE"
    [[ -z "$DOTFILES_DIR" && -n "$CONFIG_DOTFILES_DIR" ]] && DOTFILES_DIR="$CONFIG_DOTFILES_DIR"
    
    # Handle boolean flags
    if [[ "$CONFIG_DOTFILES_NODOT" == "true" ]]; then
        DOTFILES_NODOT=true
    fi
    if [[ "$CONFIG_AUTO_GITHUB" == "true" ]]; then
        CREATE_GITHUB_REPO=true
    fi
    if [[ "$CONFIG_SKIP_CONFIRMATION" == "true" ]]; then
        SKIP_CONFIRMATION=true
    fi
    
    log_info "Applied configuration defaults to CLI variables"
}

# Function: get_config_value
# Purpose: Get a configuration value by key
# Arguments: $1 = key (e.g., "team_name")
get_config_value() {
    local key="$1"
    case "$key" in
        team_name) echo "$CONFIG_TEAM_NAME" ;;
        github_account) echo "$CONFIG_GITHUB_ACCOUNT" ;;
        build_mode) echo "$CONFIG_BUILD_MODE" ;;
        dotfiles_dir) echo "$CONFIG_DOTFILES_DIR" ;;
        dotfiles_nodot) echo "$CONFIG_DOTFILES_NODOT" ;;
        auto_github) echo "$CONFIG_AUTO_GITHUB" ;;
        skip_confirmation) echo "$CONFIG_SKIP_CONFIRMATION" ;;
        init_base_image) 
            # Try to get from constants module, fallback to hard-coded default
            if [[ -n "${ZZCOLLAB_DEFAULT_INIT_BASE_IMAGE:-}" ]]; then
                echo "$ZZCOLLAB_DEFAULT_INIT_BASE_IMAGE"
            else
                echo "r-ver"
            fi
            ;;
        *) echo "" ;;
    esac
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
    
    # Convert key format (handle both underscore and dash formats)
    local yaml_key="$key"
    case "$key" in
        team-name|team_name) yaml_key="team_name" ;;
        github-account|github_account) yaml_key="github_account" ;;
        build-mode|build_mode) yaml_key="build_mode" ;;
        dotfiles-dir|dotfiles_dir) yaml_key="dotfiles_dir" ;;
        dotfiles-nodot|dotfiles_nodot) yaml_key="dotfiles_nodot" ;;
        auto-github|auto_github) yaml_key="auto_github" ;;
        skip-confirmation|skip_confirmation) yaml_key="skip_confirmation" ;;
    esac
    
    # Automatically update the YAML file
    if yaml_set "$CONFIG_USER_FILE" "defaults.$yaml_key" "$value"; then
        log_success "✅ Configuration updated: $yaml_key = \"$value\""
        
        # Reload configuration to update global variables
        load_config_file "$CONFIG_USER_FILE"
        
        return 0
    else
        log_error "❌ Failed to update configuration"
        log_info "💡 Manual fallback:"
        log_info "    Edit: $CONFIG_USER_FILE"
        log_info "    Set: defaults.$yaml_key: \"$value\""
        return 1
    fi
}

# Function: config_get
# Purpose: Get a configuration value
# Arguments: $1 = key
config_get() {
    local key="$1"
    local value=$(get_config_value "$key")
    
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "(not set)"
    fi
}

# Function: config_list
# Purpose: List all configuration values
config_list() {
    # Make sure config is loaded
    load_all_configs
    
    echo "Current zzcollab configuration:"
    echo ""
    echo "Defaults:"
    echo "  team_name: $(get_config_value team_name)"
    echo "  github_account: $(get_config_value github_account)"
    echo "  build_mode: $(get_config_value build_mode)"
    echo "  init_base_image: $(get_config_value init_base_image) (system default)"
    echo "  dotfiles_dir: $(get_config_value dotfiles_dir)"
    echo "  dotfiles_nodot: $(get_config_value dotfiles_nodot)"
    echo "  auto_github: $(get_config_value auto_github)"
    echo "  skip_confirmation: $(get_config_value skip_confirmation)"
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
# PACKAGE LIST FUNCTIONS
#=============================================================================

# Function: get_docker_packages_for_mode
# Purpose: Get Docker packages for a specific build mode (custom or default)
# Arguments: $1 = build mode (fast, standard, comprehensive)
get_docker_packages_for_mode() {
    local mode="$1"

    case "$mode" in
        minimal)
            if [[ -n "$CONFIG_MINIMAL_DOCKER_PACKAGES" ]]; then
                echo "$CONFIG_MINIMAL_DOCKER_PACKAGES"
            else
                # Return default minimal mode packages (3 packages)
                echo "renv,remotes,here"
            fi
            ;;
        fast)
            if [[ -n "$CONFIG_FAST_DOCKER_PACKAGES" ]]; then
                echo "$CONFIG_FAST_DOCKER_PACKAGES"
            else
                # Return default fast mode packages
                echo "renv,remotes,here,usethis,devtools"
            fi
            ;;
        standard)
            if [[ -n "$CONFIG_STANDARD_DOCKER_PACKAGES" ]]; then
                echo "$CONFIG_STANDARD_DOCKER_PACKAGES"
            else
                # Return default standard mode packages
                echo "renv,remotes,tidyverse,here,usethis,devtools"
            fi
            ;;
        comprehensive)
            if [[ -n "$CONFIG_COMPREHENSIVE_DOCKER_PACKAGES" ]]; then
                echo "$CONFIG_COMPREHENSIVE_DOCKER_PACKAGES"
            else
                # Comprehensive: includes all packages from old paradigms (analysis + manuscript + package)
                # Analysis: tidyverse, targets, plotly, DT, shiny
                # Manuscript: rmarkdown, bookdown
                # Package: devtools, usethis, roxygen2, testthat, pkgdown, covr
                echo "renv,remotes,tidyverse,targets,usethis,devtools,plotly,DT,shiny,bookdown,roxygen2,testthat,pkgdown,covr"
            fi
            ;;
        *)
            log_error "Unknown build mode: $mode"
            return 1
            ;;
    esac
}

# Function: get_renv_packages_for_mode
# Purpose: Get renv packages for a specific build mode (custom or default)
# Arguments: $1 = build mode (fast, standard, comprehensive)
get_renv_packages_for_mode() {
    local mode="$1"

    case "$mode" in
        minimal)
            if [[ -n "$CONFIG_MINIMAL_RENV_PACKAGES" ]]; then
                echo "$CONFIG_MINIMAL_RENV_PACKAGES"
            else
                # Return default minimal mode packages (3 packages)
                echo "renv,remotes,here"
            fi
            ;;
        fast)
            if [[ -n "$CONFIG_FAST_RENV_PACKAGES" ]]; then
                echo "$CONFIG_FAST_RENV_PACKAGES"
            else
                # Return default fast mode packages (9 packages)
                echo "renv,here,usethis,devtools,testthat,knitr,rmarkdown,targets,palmerpenguins"
            fi
            ;;
        standard)
            if [[ -n "$CONFIG_STANDARD_RENV_PACKAGES" ]]; then
                echo "$CONFIG_STANDARD_RENV_PACKAGES"
            else
                # Return default standard mode packages (17 packages)
                echo "renv,here,usethis,devtools,dplyr,ggplot2,tidyr,testthat,palmerpenguins,broom,janitor,DT,conflicted,knitr,rmarkdown,targets,pkgdown"
            fi
            ;;
        comprehensive)
            if [[ -n "$CONFIG_COMPREHENSIVE_RENV_PACKAGES" ]]; then
                echo "$CONFIG_COMPREHENSIVE_RENV_PACKAGES"
            else
                # Comprehensive: ALL packages from old paradigms unified
                # Core workflow: renv, here, usethis, devtools, testthat, knitr, rmarkdown, targets
                # Analysis paradigm: tidyverse (dplyr, ggplot2, tidyr, readr), tidymodels, plotly, DT, flexdashboard, janitor, skimr, broom
                # Manuscript paradigm: bookdown, papaja, RefManageR, citr
                # Package paradigm: roxygen2, pkgdown, covr, lintr, goodpractice, spelling
                # Additional utilities: palmerpenguins, conflicted, kableExtra, naniar, visdat
                # Advanced: shiny, quarto, survival, lme4, DBI, RSQLite, doParallel, foreach, future
                echo "renv,here,usethis,devtools,dplyr,ggplot2,tidyr,readr,tidymodels,shiny,plotly,quarto,flexdashboard,survival,lme4,testthat,knitr,rmarkdown,targets,janitor,DT,conflicted,palmerpenguins,broom,kableExtra,bookdown,papaja,RefManageR,citr,naniar,skimr,visdat,pkgdown,rcmdcheck,roxygen2,covr,lintr,goodpractice,spelling,jsonlite,DBI,RSQLite,car,digest,doParallel,foreach,furrr,future,sessioninfo,ggthemes,datapasta"
            fi
            ;;
        *)
            log_error "Unknown build mode: $mode"
            return 1
            ;;
    esac
}

# Paradigm-specific package functions removed - unified paradigm uses build modes only

# Function: generate_description_content
# Purpose: Generate DESCRIPTION file content with custom or default packages
# Arguments: $1 = build mode, $2 = package name, $3 = author name, $4 = author email
generate_description_content() {
    local mode="$1"
    local pkg_name="$2"
    local author_name="$3"
    local author_email="$4"
    
    # Get package lists for the mode
    local renv_packages=$(get_renv_packages_for_mode "$mode")
    
    # Convert comma-separated list to arrays for processing
    IFS=',' read -ra packages <<< "$renv_packages"
    
    # Separate into Imports and Suggests
    # Core packages go to Imports, others to Suggests
    local imports=()
    local suggests=()
    
    for pkg in "${packages[@]}"; do
        case "$pkg" in
            renv|here|usethis|devtools|dplyr|ggplot2|tidyr)
                imports+=("$pkg")
                ;;
            *)
                suggests+=("$pkg")
                ;;
        esac
    done
    
    # Generate DESCRIPTION content
    cat << EOF
Package: ${pkg_name}
Title: Research Compendium for ${pkg_name}
Version: 0.0.0.9000
Authors@R: 
    person("${author_name}", email = "${author_email}", role = c("aut", "cre"))
Description: This is a research compendium for the ${pkg_name} project.
License: GPL-3
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.2.0
EOF

    # Add Imports section if we have imports
    if [[ ${#imports[@]} -gt 0 ]]; then
        echo "Imports:"
        for pkg in "${imports[@]}"; do
            echo "    ${pkg},"
        done | sed '$ s/,$//'  # Remove comma from last item
    fi
    
    # Add Suggests section if we have suggests
    if [[ ${#suggests[@]} -gt 0 ]]; then
        echo "Suggests:"
        for pkg in "${suggests[@]}"; do
            if [[ "$pkg" == "testthat" ]]; then
                echo "    testthat (>= 3.0.0),"
            else
                echo "    ${pkg},"
            fi
        done | sed '$ s/,$//'  # Remove comma from last item
    fi
    
    # Add standard footer
    cat << EOF
Config/testthat/edition: 3
VignetteBuilder: knitr
EOF
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================

# Set config module loaded flag
readonly ZZCOLLAB_CONFIG_LOADED=true

