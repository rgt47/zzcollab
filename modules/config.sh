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
CONFIG_DOCKERHUB_ACCOUNT=""
CONFIG_PROFILE_NAME=""
CONFIG_LIBS_BUNDLE=""
CONFIG_PKGS_BUNDLE=""
CONFIG_R_VERSION=""
CONFIG_DOTFILES_DIR=""
CONFIG_DOTFILES_NODOT="false"
CONFIG_AUTO_GITHUB="false"
CONFIG_SKIP_CONFIRMATION="false"

# Package management: Dynamic via renv::install() (no pre-configured modes)

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
#   $2 - path: YAML path specification (e.g., "defaults.team_name", "profiles.minimal.packages")
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
# USAGE:    yaml_get_array "config.yaml" "profiles.minimal.packages"
# ARGS:     
#   $1 - file: Path to YAML configuration file
#   $2 - path: YAML path to array (e.g., "profiles.minimal.packages")
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
#   packages=$(yaml_get_array "config.yaml" "profiles.minimal.docker_packages")
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
#   yaml_set "config.yaml" "defaults.profile_name" "minimal"
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

# Function: load_custom_package_lists - REMOVED (deprecated with BUILD_MODE system)

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
#   WRITE: CONFIG_* variables (team_name, github_account, dockerhub_account, etc.)
# DESCRIPTION:
#   This function loads configuration values from a single YAML file and
#   populates the global CONFIG_* variables. It processes the 'defaults'
#   section of the configuration file.
# CONFIGURATION SECTIONS PROCESSED:
#   - defaults.team_name: Docker Hub team/organization name
#   - defaults.github_account: GitHub account for repository creation
#   - defaults.dockerhub_account: Docker Hub account (defaults to team_name if empty)
#   - defaults.profile_name: Default Docker profile
#   - defaults.libs_bundle: Default system libraries bundle
#   - defaults.pkgs_bundle: Default R packages bundle
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
#   echo "Team: $CONFIG_TEAM_NAME, DockerHub: $CONFIG_DOCKERHUB_ACCOUNT"
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
    local dockerhub_account=$(yaml_get "$config_file" "defaults.dockerhub_account")
    local profile_name=$(yaml_get "$config_file" "defaults.profile_name")
    local libs_bundle=$(yaml_get "$config_file" "defaults.libs_bundle")
    local pkgs_bundle=$(yaml_get "$config_file" "defaults.pkgs_bundle")
    local r_version=$(yaml_get "$config_file" "defaults.r_version")
    local dotfiles_dir=$(yaml_get "$config_file" "defaults.dotfiles_dir")
    local dotfiles_nodot=$(yaml_get "$config_file" "defaults.dotfiles_nodot")
    local auto_github=$(yaml_get "$config_file" "defaults.auto_github")
    local skip_confirmation=$(yaml_get "$config_file" "defaults.skip_confirmation")

    # Store in global config variables (only if not "null")
    [[ "$team_name" != "null" && -n "$team_name" ]] && CONFIG_TEAM_NAME="$team_name"
    [[ "$github_account" != "null" && -n "$github_account" ]] && CONFIG_GITHUB_ACCOUNT="$github_account"
    [[ "$dockerhub_account" != "null" && -n "$dockerhub_account" ]] && CONFIG_DOCKERHUB_ACCOUNT="$dockerhub_account"
    [[ "$profile_name" != "null" && -n "$profile_name" ]] && CONFIG_PROFILE_NAME="$profile_name"
    [[ "$libs_bundle" != "null" && -n "$libs_bundle" ]] && CONFIG_LIBS_BUNDLE="$libs_bundle"
    [[ "$pkgs_bundle" != "null" && -n "$pkgs_bundle" ]] && CONFIG_PKGS_BUNDLE="$pkgs_bundle"
    [[ "$r_version" != "null" && -n "$r_version" ]] && CONFIG_R_VERSION="$r_version"
    [[ "$dotfiles_dir" != "null" && -n "$dotfiles_dir" ]] && CONFIG_DOTFILES_DIR="$dotfiles_dir"
    [[ "$dotfiles_nodot" != "null" && -n "$dotfiles_nodot" ]] && CONFIG_DOTFILES_NODOT="$dotfiles_nodot"
    [[ "$auto_github" != "null" && -n "$auto_github" ]] && CONFIG_AUTO_GITHUB="$auto_github"
    [[ "$skip_confirmation" != "null" && -n "$skip_confirmation" ]] && CONFIG_SKIP_CONFIRMATION="$skip_confirmation"
    
    return 0
}

# Function: load_all_configs
# Purpose: Load configuration from all available files in priority order
load_all_configs() {
    # Start with hard-coded defaults (already set in variable declarations)
    CONFIG_TEAM_NAME=""
    CONFIG_GITHUB_ACCOUNT=""
    CONFIG_DOCKERHUB_ACCOUNT=""
    CONFIG_PROFILE_NAME=""
    CONFIG_LIBS_BUNDLE=""
    CONFIG_PKGS_BUNDLE=""
    CONFIG_R_VERSION=""
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
    [[ -z "${TEAM_NAME:-}" && -n "$CONFIG_TEAM_NAME" ]] && TEAM_NAME="$CONFIG_TEAM_NAME"
    [[ -z "${GITHUB_ACCOUNT:-}" && -n "$CONFIG_GITHUB_ACCOUNT" ]] && GITHUB_ACCOUNT="$CONFIG_GITHUB_ACCOUNT"
    [[ -z "${DOCKERHUB_ACCOUNT:-}" && -n "$CONFIG_DOCKERHUB_ACCOUNT" ]] && DOCKERHUB_ACCOUNT="$CONFIG_DOCKERHUB_ACCOUNT"
    [[ -z "${PROFILE_NAME:-}" && -n "$CONFIG_PROFILE_NAME" ]] && PROFILE_NAME="$CONFIG_PROFILE_NAME"
    [[ -z "${LIBS_BUNDLE:-}" && -n "$CONFIG_LIBS_BUNDLE" ]] && LIBS_BUNDLE="$CONFIG_LIBS_BUNDLE"
    [[ -z "${PKGS_BUNDLE:-}" && -n "$CONFIG_PKGS_BUNDLE" ]] && PKGS_BUNDLE="$CONFIG_PKGS_BUNDLE"
    [[ -z "${DOTFILES_DIR:-}" && -n "$CONFIG_DOTFILES_DIR" ]] && DOTFILES_DIR="$CONFIG_DOTFILES_DIR"

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
        dockerhub_account) echo "$CONFIG_DOCKERHUB_ACCOUNT" ;;
        profile_name) echo "$CONFIG_PROFILE_NAME" ;;
        libs_bundle) echo "$CONFIG_LIBS_BUNDLE" ;;
        pkgs_bundle) echo "$CONFIG_PKGS_BUNDLE" ;;
        r_version) echo "$CONFIG_R_VERSION" ;;
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

# Function: get_default_value
# Purpose: Get the system default value for a configuration key
# Arguments: $1 = key (e.g., "team_name")
# Returns: The default value (may be empty string for truly unset keys)
get_default_value() {
    local key="$1"
    case "$key" in
        team_name) echo "" ;;
        github_account) echo "" ;;
        dockerhub_account) echo "" ;;
        profile_name) echo "minimal" ;;
        libs_bundle) echo "minimal" ;;
        pkgs_bundle) echo "minimal" ;;
        dotfiles_dir) echo "$HOME/dotfiles" ;;
        dotfiles_nodot) echo "true" ;;
        auto_github) echo "false" ;;
        skip_confirmation) echo "false" ;;
        init_base_image)
            if [[ -n "${ZZCOLLAB_DEFAULT_INIT_BASE_IMAGE:-}" ]]; then
                echo "$ZZCOLLAB_DEFAULT_INIT_BASE_IMAGE"
            else
                echo "r-ver"
            fi
            ;;
        *) echo "" ;;
    esac
}

# Function: is_value_from_config
# Purpose: Check if a configuration value comes from a config file or is using default
# Arguments: $1 = key (e.g., "team_name")
# Returns: 0 if from config file, 1 if using default
is_value_from_config() {
    local key="$1"
    local current_value=""

    # Get the current CONFIG_* variable value
    case "$key" in
        team_name) current_value="$CONFIG_TEAM_NAME" ;;
        github_account) current_value="$CONFIG_GITHUB_ACCOUNT" ;;
        dockerhub_account) current_value="$CONFIG_DOCKERHUB_ACCOUNT" ;;
        profile_name) current_value="$CONFIG_PROFILE_NAME" ;;
        libs_bundle) current_value="$CONFIG_LIBS_BUNDLE" ;;
        pkgs_bundle) current_value="$CONFIG_PKGS_BUNDLE" ;;
        dotfiles_dir) current_value="$CONFIG_DOTFILES_DIR" ;;
        dotfiles_nodot) current_value="$CONFIG_DOTFILES_NODOT" ;;
        auto_github) current_value="$CONFIG_AUTO_GITHUB" ;;
        skip_confirmation) current_value="$CONFIG_SKIP_CONFIRMATION" ;;
        init_base_image) return 1 ;; # Always from system default
        *) return 1 ;;
    esac

    # Check if any config file exists and contains this value
    local found_in_config=false
    for config_file in "$CONFIG_PROJECT_FILE" "$CONFIG_USER_FILE" "$CONFIG_SYSTEM_FILE"; do
        if [[ -f "$config_file" ]]; then
            local file_value=$(yaml_get "$config_file" "defaults.$key" 2>/dev/null)
            if [[ "$file_value" != "null" && -n "$file_value" ]]; then
                found_in_config=true
                break
            fi
        fi
    done

    if [[ "$found_in_config" == "true" ]]; then
        return 0  # Value is from config file
    else
        return 1  # Value is default
    fi
}

# Function: format_config_value_with_indicator
# Purpose: Format a config value with appropriate indicator (default) or <not set>
# Arguments: $1 = key (e.g., "team_name")
# Returns: Formatted string with value and indicator
format_config_value_with_indicator() {
    local key="$1"
    local current_value=$(get_config_value "$key")
    local default_value=$(get_default_value "$key")

    # Special handling for init_base_image which is always system default
    if [[ "$key" == "init_base_image" ]]; then
        echo "$current_value (system default)"
        return 0
    fi

    # Check if value is from config file or is default
    if is_value_from_config "$key"; then
        # Value is explicitly set in a config file
        echo "$current_value"
    else
        # Value is not from config file - check if set via environment/CLI
        if [[ -n "$current_value" ]]; then
            # Set via environment variable or CLI argument
            echo "$current_value"
        elif [[ -z "$default_value" ]]; then
            # No value set and no default available
            echo "<not set>"
        else
            # Using built-in default
            echo "$default_value (default)"
        fi
    fi
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

    # Check if config file already exists
    if [[ -f "$CONFIG_USER_FILE" ]]; then
        log_warning "Configuration file already exists: $CONFIG_USER_FILE"
        echo ""
        echo "Options:"
        echo "  1. Keep existing config (recommended)"
        echo "  2. Create backup and overwrite"
        echo "  3. Overwrite without backup (dangerous!)"
        echo ""
        read -p "Choose option [1/2/3]: " choice

        case "$choice" in
            1)
                log_info "Keeping existing configuration file"
                log_info "Use 'zzcollab config list' to view current settings"
                log_info "Use 'zzcollab config set KEY VALUE' to modify settings"
                return 0
                ;;
            2)
                local backup_file="${CONFIG_USER_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
                cp "$CONFIG_USER_FILE" "$backup_file"
                log_success "Created backup: $backup_file"
                log_info "Creating new configuration file..."
                ;;
            3)
                log_warning "Overwriting configuration without backup..."
                ;;
            *)
                log_error "Invalid choice. Keeping existing configuration."
                return 1
                ;;
        esac
    fi

    cat > "$CONFIG_USER_FILE" << 'EOF'
# ZZCOLLAB Configuration File
# This file contains default settings for zzcollab projects
# Values here will be used as defaults unless overridden by CLI flags

defaults:
  # Team and GitHub settings (user-specific, set these for your projects)
  team_name: ""                    # Your Docker Hub team/organization name
  github_account: ""               # Your GitHub account (defaults to team_name if empty)
  dockerhub_account: ""            # Your Docker Hub account (defaults to team_name if empty)

  # Docker profile settings (system defaults shown)
  profile_name: "minimal"          # Docker profile (minimal, rstudio, analysis, bioinformatics, geospatial, etc.)
  libs_bundle: "minimal"           # System libraries bundle
  pkgs_bundle: "minimal"           # R packages bundle (pre-installed in Docker)

  # Dotfiles integration (common defaults shown)
  dotfiles_dir: "~/dotfiles"       # Path to your dotfiles directory
  dotfiles_nodot: true             # Files stored without leading dots (vimrc not .vimrc)

  # Automation settings (system defaults shown)
  auto_github: false               # Automatically create GitHub repository
  skip_confirmation: false         # Skip confirmation prompts

# Package Management
# Packages are added dynamically as needed using renv::install() inside containers
# Docker profiles (profile_name) control the base Docker environment and pre-installed packages
# Example workflow:
#   make docker-zsh
#   renv::install("tidyverse")
#   renv::snapshot()
#   exit
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
        dockerhub-account|dockerhub_account) yaml_key="dockerhub_account" ;;
        profile-name|profile_name) yaml_key="profile_name" ;;
        libs-bundle|libs_bundle) yaml_key="libs_bundle" ;;
        pkgs-bundle|pkgs_bundle) yaml_key="pkgs_bundle" ;;
        r-version|r_version)
            yaml_key="r_version"
            # Validate R version format before setting
            if [[ ! "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "$value" =~ ^[0-9]+\.[0-9]+$ ]]; then
                log_error "Invalid R version format: '$value'"
                log_error "Expected format: X.Y.Z (e.g., 4.4.0)"
                log_info "Common versions: 4.4.0, 4.3.1, 4.2.3"
                return 1
            fi
            ;;
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
# Purpose: List all configuration values with indicators for defaults and unset values
config_list() {
    echo "Current zzcollab configuration:"
    echo ""
    echo "Defaults:"
    echo "  team_name: $(format_config_value_with_indicator team_name)"
    echo "  github_account: $(format_config_value_with_indicator github_account)"
    echo "  dockerhub_account: $(format_config_value_with_indicator dockerhub_account)"
    echo "  profile_name: $(format_config_value_with_indicator profile_name)"
    echo "  libs_bundle: $(format_config_value_with_indicator libs_bundle)"
    echo "  pkgs_bundle: $(format_config_value_with_indicator pkgs_bundle)"
    echo "  r_version: $(format_config_value_with_indicator r_version)"
    echo "  init_base_image: $(format_config_value_with_indicator init_base_image)"
    echo "  dotfiles_dir: $(format_config_value_with_indicator dotfiles_dir)"
    echo "  dotfiles_nodot: $(format_config_value_with_indicator dotfiles_nodot)"
    echo "  auto_github: $(format_config_value_with_indicator auto_github)"
    echo "  skip_confirmation: $(format_config_value_with_indicator skip_confirmation)"
    echo ""
    echo "Configuration files (in priority order):"
    [[ -f "$CONFIG_PROJECT_FILE" ]] && echo "  ✓ $CONFIG_PROJECT_FILE" || echo "  ✗ $CONFIG_PROJECT_FILE"
    [[ -f "$CONFIG_USER_FILE" ]] && echo "  ✓ $CONFIG_USER_FILE" || echo "  ✗ $CONFIG_USER_FILE"
    [[ -f "$CONFIG_SYSTEM_FILE" ]] && echo "  ✓ $CONFIG_SYSTEM_FILE (system-wide)" || echo "  ✗ $CONFIG_SYSTEM_FILE (system-wide)"
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
        echo "❌ Error: Configuration validation failed ($errors errors)"
        return 1
    fi
}

#=============================================================================
# PROJECT-LEVEL CONFIG FUNCTIONS
#=============================================================================

##############################################################################
# FUNCTION: config_set_local
# PURPOSE:  Set a configuration value in project-level config (./zzcollab.yaml)
# USAGE:    config_set_local "team-name" "temp"
# ARGS:
#   $1 - key: Configuration key (use dash-separated format like "team-name")
#   $2 - value: Value to set
# RETURNS:
#   0 - Successfully set configuration value
#   1 - Error (invalid key, write permission issues, etc.)
# BEHAVIOR:
#   - If ./zzcollab.yaml doesn't exist, copies ~/.zzcollab/config.yaml as template
#   - Then updates the specific key in ./zzcollab.yaml
#   - Preserves all other settings from user config
# EXAMPLE:
#   config_set_local "team-name" "myteam"
#   config_set_local "profile-name" "analysis"
##############################################################################
config_set_local() {
    local key="$1"
    local value="$2"

    # Convert dash-separated key to underscore (team-name → team_name)
    local yaml_key="${key//-/_}"

    # Check if project config exists
    if [[ ! -f "$CONFIG_PROJECT_FILE" ]]; then
        log_info "Creating project-level config from user template..."

        # Check if user config exists
        if [[ ! -f "$CONFIG_USER_FILE" ]]; then
            log_error "❌ User config not found: $CONFIG_USER_FILE"
            log_info "💡 Run 'zzcollab --config init' first to create user config"
            return 1
        fi

        # Copy user config as template
        if cp "$CONFIG_USER_FILE" "$CONFIG_PROJECT_FILE"; then
            log_success "✅ Created $CONFIG_PROJECT_FILE from user config template"
            log_info "💡 This file will override your user defaults for this project"
        else
            log_error "❌ Failed to create $CONFIG_PROJECT_FILE"
            return 1
        fi
    fi

    # Now update the specific key
    if yaml_set "$CONFIG_PROJECT_FILE" "defaults.$yaml_key" "$value"; then
        log_success "✅ Project config updated: $yaml_key = \"$value\""
        log_info "📍 Location: $CONFIG_PROJECT_FILE"

        # Reload configuration to update global variables
        load_config_file "$CONFIG_PROJECT_FILE"

        return 0
    else
        log_error "❌ Failed to update project configuration"
        log_info "💡 Manual fallback:"
        log_info "   Edit $CONFIG_PROJECT_FILE"
        log_info "   Update: defaults.$yaml_key: \"$value\""
        return 1
    fi
}

##############################################################################
# FUNCTION: config_get_local
# PURPOSE:  Get a configuration value from project-level config only
# USAGE:    config_get_local "team-name"
# ARGS:
#   $1 - key: Configuration key (dash-separated format)
# RETURNS:
#   0 - Successfully retrieved value
#   1 - Key not found or file doesn't exist
# OUTPUTS:
#   Prints the value to stdout
# EXAMPLE:
#   team=$(config_get_local "team-name")
##############################################################################
config_get_local() {
    local key="$1"

    # Convert dash-separated key to underscore
    local yaml_key="${key//-/_}"

    if [[ ! -f "$CONFIG_PROJECT_FILE" ]]; then
        log_error "❌ Project config not found: $CONFIG_PROJECT_FILE"
        log_info "💡 Use 'zzcollab --config set-local KEY VALUE' to create it"
        return 1
    fi

    local value
    value=$(yaml_get "$CONFIG_PROJECT_FILE" "defaults.$yaml_key")

    if [[ "$value" == "null" || -z "$value" ]]; then
        log_error "❌ Key '$key' not found in project config"
        return 1
    fi

    echo "$value"
    return 0
}

##############################################################################
# FUNCTION: config_list_local
# PURPOSE:  List all configuration values from project-level config
# USAGE:    config_list_local
# OUTPUTS:
#   Formatted list of all project-level configuration settings
# EXAMPLE:
#   config_list_local
##############################################################################
config_list_local() {
    if [[ ! -f "$CONFIG_PROJECT_FILE" ]]; then
        echo "ℹ️  No project-level config found"
        echo "📍 Location would be: $CONFIG_PROJECT_FILE"
        echo "💡 Use 'zzcollab --config set-local KEY VALUE' to create one"
        echo ""
        echo "Project-level config allows you to override user defaults"
        echo "for this specific project. For example:"
        echo ""
        echo "  zzcollab --config set-local team-name myteam"
        echo "  zzcollab --config set-local profile-name analysis"
        return 0
    fi

    echo "Project-level configuration ($CONFIG_PROJECT_FILE):"
    echo ""

    # Load values from project config only
    local temp_team temp_github temp_dockerhub temp_profile temp_libs temp_pkgs
    local temp_dotfiles temp_nodot temp_auto_github temp_skip_confirm

    temp_team=$(yaml_get "$CONFIG_PROJECT_FILE" "defaults.team_name")
    temp_github=$(yaml_get "$CONFIG_PROJECT_FILE" "defaults.github_account")
    temp_dockerhub=$(yaml_get "$CONFIG_PROJECT_FILE" "defaults.dockerhub_account")
    temp_profile=$(yaml_get "$CONFIG_PROJECT_FILE" "defaults.profile_name")
    temp_libs=$(yaml_get "$CONFIG_PROJECT_FILE" "defaults.libs_bundle")
    temp_pkgs=$(yaml_get "$CONFIG_PROJECT_FILE" "defaults.pkgs_bundle")
    temp_dotfiles=$(yaml_get "$CONFIG_PROJECT_FILE" "defaults.dotfiles_dir")
    temp_nodot=$(yaml_get "$CONFIG_PROJECT_FILE" "defaults.dotfiles_nodot")
    temp_auto_github=$(yaml_get "$CONFIG_PROJECT_FILE" "defaults.auto_github")
    temp_skip_confirm=$(yaml_get "$CONFIG_PROJECT_FILE" "defaults.skip_confirmation")

    echo "Settings (overriding user defaults):"
    echo "  team_name: ${temp_team}"
    echo "  github_account: ${temp_github}"
    echo "  dockerhub_account: ${temp_dockerhub}"
    echo "  profile_name: ${temp_profile}"
    echo "  libs_bundle: ${temp_libs}"
    echo "  pkgs_bundle: ${temp_pkgs}"
    echo "  dotfiles_dir: ${temp_dotfiles}"
    echo "  dotfiles_nodot: ${temp_nodot}"
    echo "  auto_github: ${temp_auto_github}"
    echo "  skip_confirmation: ${temp_skip_confirm}"
    echo ""
    echo "💡 To modify: zzcollab --config set-local KEY VALUE"
    echo "💡 To see merged config (user + project): zzcollab --config list"
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
        set-local)
            if [[ $# -ne 2 ]]; then
                echo "Usage: zzcollab config set-local KEY VALUE"
                echo ""
                echo "Sets a project-level configuration value in ./zzcollab.yaml"
                echo "If ./zzcollab.yaml doesn't exist, it will be created from your user config."
                echo ""
                echo "Examples:"
                echo "  zzcollab config set-local team-name myteam"
                echo "  zzcollab config set-local profile-name analysis"
                exit 1
            fi
            config_set_local "$1" "$2"
            ;;
        get-local)
            if [[ $# -ne 1 ]]; then
                echo "Usage: zzcollab config get-local KEY"
                echo ""
                echo "Gets a value from project-level config (./zzcollab.yaml) only"
                exit 1
            fi
            config_get_local "$1"
            ;;
        list-local)
            config_list_local
            ;;
        validate)
            config_validate
            ;;
        init)
            create_default_config
            ;;
        *)
            echo "❌ Error: Unknown config subcommand '$subcommand'"
            echo ""
            echo "Valid subcommands:"
            echo "  User-level config (affects all projects):"
            echo "    init           - Create user config file"
            echo "    set KEY VALUE  - Set user-level config value"
            echo "    get KEY        - Get merged config value (user + project)"
            echo "    list           - List merged configuration"
            echo ""
            echo "  Project-level config (affects current project only):"
            echo "    set-local KEY VALUE  - Set project-level override"
            echo "    get-local KEY        - Get project-level value only"
            echo "    list-local           - List project-level overrides"
            echo ""
            echo "  Validation:"
            echo "    validate       - Validate config file syntax"
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
# PACKAGE LIST FUNCTIONS - REMOVED (deprecated with BUILD_MODE system)
#=============================================================================

# Function: get_docker_packages_for_mode - REMOVED (deprecated with BUILD_MODE system)
# Function: get_renv_packages_for_mode - REMOVED (deprecated with BUILD_MODE system)
# Function: generate_description_content - REMOVED (deprecated with BUILD_MODE system)

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================

# Set config module loaded flag
readonly ZZCOLLAB_CONFIG_LOADED=true

