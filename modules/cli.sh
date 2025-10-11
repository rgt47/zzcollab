#!/bin/bash
##############################################################################
# ZZCOLLAB CLI MODULE
##############################################################################
# 
# PURPOSE: Command line interface parsing and validation
#          - Command line argument parsing
#          - Flag variable initialization
#          - User-friendly interface processing
#          - Argument validation
#
# DEPENDENCIES: None (loaded before other modules)
#
# EXPORTS: All CLI variables and functions for use by main script
##############################################################################

#=============================================================================
# CLI ARGUMENT VALIDATION FUNCTIONS
#=============================================================================

##############################################################################
# FUNCTION: require_arg
# PURPOSE:  Validate that a command line flag has a required argument
# USAGE:    require_arg "--flag-name" "$argument_value"
# ARGS:     
#   $1 - flag_name: Name of the command line flag for error reporting
#   $2 - argument_value: The argument value to validate (may be empty)
# RETURNS:  
#   0 - Argument is present and non-empty
#   1 - Argument is missing or empty (exits with error message)
# GLOBALS:  
#   READ:  None
#   WRITE: None (outputs error to stderr, then exits)
# DESCRIPTION:
#   This function provides standardized validation for command line arguments
#   that are required for specific flags. It prevents silent failures when
#   users provide flags without their required arguments.
# ERROR BEHAVIOR:
#   - Exits immediately with code 1 if argument is missing
#   - Provides clear error message identifying the problematic flag
#   - Uses stderr for error output to avoid interfering with normal output
# EXAMPLE:
#   require_arg "--team-name" "$team_name_value"
#   require_arg "--dotfiles" "$dotfiles_path"
##############################################################################
require_arg() {
    [[ -n "${2:-}" ]] || { echo "❌ Error: $1 requires an argument" >&2; exit 1; }
}

##############################################################################
# FUNCTION: parse_base_image_list
# PURPOSE:  Parse and validate comma-separated base image list
# USAGE:    parse_base_image_list "r-ver,rstudio"
# ARGS:     
#   $1 - input: Comma-separated list of base images or "all"
# RETURNS:  
#   0 - All images in list are valid
#   1 - One or more invalid images (exits with error message)
# DESCRIPTION:
#   Parses comma-separated base image lists and validates each image.
#   Supports both single values and comma-separated lists.
#   Special handling for "all" keyword.
# EXAMPLE:
#   parse_base_image_list "r-ver,rstudio,verse"
#   parse_base_image_list "all"
##############################################################################
parse_base_image_list() {
    local input="$1"
    
    # Handle special "all" case
    if [[ "$input" == "all" ]]; then
        return 0
    fi
    
    # Split comma-separated values and validate each
    IFS=',' read -ra images <<< "$input"
    for image in "${images[@]}"; do
        # Trim whitespace
        image=$(echo "$image" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Validate each image
        case "$image" in
            r-ver|rstudio|verse)
                ;;
            *)
                echo "❌ Error: Invalid base image '$image'. Valid options: r-ver, rstudio, verse, all" >&2
                echo "💡 Use comma-separated list for multiple images: r-ver,rstudio,verse" >&2
                exit 1
                ;;
        esac
    done
}

##############################################################################
# FUNCTION: parse_profile_list
# PURPOSE:  Parse comma-separated variant list for -V flag
# USAGE:    parse_profile_list "minimal,rstudio,analysis"
# ARGS:
#   $1 - input: Comma-separated list of variant names
# RETURNS:
#   Outputs cleaned variant names, one per line
# DESCRIPTION:
#   Splits comma-separated variants and trims whitespace.
#   Does not validate variant names (allows any variant from library).
# EXAMPLE:
#   parse_profile_list "minimal, rstudio, analysis"
##############################################################################
parse_profile_list() {
    local input="$1"

    # Split by comma and clean each variant name
    IFS=',' read -ra variants <<< "$input"
    for variant in "${variants[@]}"; do
        variant=$(echo "$variant" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')  # Trim whitespace
        [[ -n "$variant" ]] && echo "$variant"
    done
}

##############################################################################
# FUNCTION: validate_enum
# PURPOSE:  Validate that a command line argument value is from allowed set
# USAGE:    validate_enum "--flag" "value" "description" "option1" "option2" ...
# ARGS:     
#   $1 - flag: Command line flag name for error reporting
#   $2 - value: The value to validate against allowed options
#   $3 - description: Human-readable description of what the value represents
#   $4+ - valid_options: List of allowed values for this parameter
# RETURNS:  
#   0 - Value matches one of the valid options
#   1 - Value is not in allowed set (exits with error message)
# GLOBALS:  
#   READ:  None
#   WRITE: None (outputs error to stderr, then exits)
# DESCRIPTION:
#   This function provides standardized validation for enumerated command line
#   arguments, ensuring users provide only valid values and giving helpful
#   error messages when invalid values are provided.
# VALIDATION LOGIC:
#   - Iterates through all valid options
#   - Performs exact string match comparison
#   - Case-sensitive matching ("Fast" != "fast")
# ERROR BEHAVIOR:
#   - Exits immediately with code 1 if value is invalid
#   - Shows the invalid value and lists all valid options
#   - Uses stderr to avoid interfering with normal program output
# EXAMPLE:
#   validate_enum "--renv-mode" "$mode" "build mode" "fast" "standard" "comprehensive"
#   validate_enum "--interface" "$interface" "interface type" "shell" "rstudio" "verse"
##############################################################################
validate_enum() {
    local flag="$1"
    local value="$2"
    local description="$3"
    shift 3
    local valid_options=("$@")
    
    for option in "${valid_options[@]}"; do
        if [[ "$value" == "$option" ]]; then
            return 0
        fi
    done
    
    echo "❌ Error: Invalid $description '$value'. Valid options: ${valid_options[*]}" >&2
    exit 1
}

#=============================================================================
# CLI VARIABLE INITIALIZATION
#=============================================================================

# Initialize variables for command line options
# Note: BUILD_DOCKER=false by default - users run 'make docker-build' manually
BUILD_DOCKER=false
DOTFILES_DIR=""
DOTFILES_NODOT=false
# Use centralized constants if available
readonly DEFAULT_BASE_IMAGE="${ZZCOLLAB_DEFAULT_BASE_IMAGE:-rocker/r-ver}"
BASE_IMAGE="$DEFAULT_BASE_IMAGE"

# Multi-architecture support configuration
MULTIARCH_VERSE_IMAGE="${MULTIARCH_VERSE_IMAGE:-rocker/verse}"
FORCE_PLATFORM="${FORCE_PLATFORM:-auto}"
export MULTIARCH_VERSE_IMAGE FORCE_PLATFORM

# New user-friendly interface variables
TEAM_NAME=""
PROJECT_NAME=""
GITHUB_ACCOUNT=""
DOCKERHUB_ACCOUNT=""
DOCKERFILE_PATH=""

# Base image selection for team initialization
readonly DEFAULT_INIT_BASE_IMAGE="${ZZCOLLAB_DEFAULT_INIT_BASE_IMAGE:-r-ver}"
INIT_BASE_IMAGE="$DEFAULT_INIT_BASE_IMAGE"    # Options: r-ver, rstudio, verse, all

# Initialization mode variables
USE_DOTFILES=false
PREPARE_DOCKERFILE=false
SKIP_CONFIRMATION=false
CREATE_GITHUB_REPO=false
FORCE_DIRECTORY=false    # Skip directory validation (advanced users)
USE_CONFIG_PROFILES=false    # Use config.yaml for variant definitions
PROFILES_CONFIG=""           # Path to variants config file

# Simplified build mode system (replaces complex flag system)
readonly DEFAULT_RENV_MODE="${ZZCOLLAB_DEFAULT_RENV_MODE:-standard}"
RENV_MODE="$DEFAULT_RENV_MODE"    # Options: minimal, fast, standard, comprehensive
# minimal     = bare essentials (renv, remotes, here) - ~30 seconds
# fast        = minimal Docker + minimal packages - 2-3 minutes
# standard    = standard Docker + standard packages (balanced) - 4-6 minutes
# comprehensive = extended Docker + full packages (kitchen sink) - 15-20 minutes

# Profile bundle variables (system libraries and R packages)
LIBS_BUNDLE=""    # System library bundle (e.g., alpine, bioinfo, geospatial)
PKGS_BUNDLE=""    # R package bundle (e.g., tidyverse, shiny, modeling)

# Track whether user explicitly provided these flags (for team member validation)
USER_PROVIDED_BASE_IMAGE=false
USER_PROVIDED_LIBS=false
USER_PROVIDED_PKGS=false
USER_PROVIDED_PROFILE=false
USE_TEAM_IMAGE=false    # Team member flag to pull and use team image

# Show flags (processed after modules are loaded)
SHOW_HELP=false
SHOW_NEXT_STEPS=false

# Config command variables
CONFIG_COMMAND=false
CONFIG_SUBCOMMAND=""
CONFIG_ARGS=()

#=============================================================================
# CLI ARGUMENT PARSING FUNCTION
#=============================================================================

# Function: parse_cli_arguments
# Purpose: Parse all command line arguments and set global variables
# Arguments: All command line arguments passed to script
parse_cli_arguments() {
    # Process all command line arguments (identical to original zzcollab.sh)
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build-docker)
                BUILD_DOCKER=true
                shift
                ;;
            --no-docker|-n)
                BUILD_DOCKER=false
                shift
                ;;
            --dotfiles|-d)
                require_arg "$1" "$2"
                DOTFILES_DIR="$2"
                shift 2
                ;;
            --dotfiles-nodot|-D)
                require_arg "$1" "$2"
                DOTFILES_DIR="$2"
                DOTFILES_NODOT=true
                shift 2
                ;;
            --base-image|-b)
                require_arg "$1" "$2"
                BASE_IMAGE="$2"
                USER_PROVIDED_BASE_IMAGE=true
                shift 2
                ;;
            --team|-t)
                require_arg "$1" "$2"
                TEAM_NAME="$2"
                shift 2
                ;;
            --project-name|--project|-p)
                require_arg "$1" "$2"
                PROJECT_NAME="$2"
                shift 2
                ;;
            --team-name)
                require_arg "$1" "$2"
                TEAM_NAME="$2"
                shift 2
                ;;
            --github-account|-g)
                require_arg "$1" "$2"
                GITHUB_ACCOUNT="$2"
                shift 2
                ;;
            --dockerfile|-f)
                require_arg "$1" "$2"
                DOCKERFILE_PATH="$2"
                shift 2
                ;;
            --prepare-dockerfile|-P)
                PREPARE_DOCKERFILE=true
                shift
                ;;
            --minimal|-M)
                RENV_MODE="minimal"
                shift
                ;;
            --fast|-F)
                RENV_MODE="fast"
                shift
                ;;
            --standard|-S)
                RENV_MODE="standard"
                shift
                ;;
            --comprehensive|-C)
                RENV_MODE="comprehensive"
                shift
                ;;
            --next-steps)
                # Will be processed after modules are loaded
                SHOW_NEXT_STEPS=true
                shift
                ;;
            --help|-h)
                # Will be processed after modules are loaded
                SHOW_HELP=true
                shift
                ;;
            --help-init)
                # Will be processed after modules are loaded
                SHOW_HELP_INIT=true
                shift
                ;;
            --help-variants)
                # Will be processed after modules are loaded
                SHOW_HELP_VARIANTS=true
                shift
                ;;
            --profile-name)
                require_arg "$1" "$2"
                PROFILE_NAME="$2"
                USER_PROVIDED_PROFILE=true
                shift 2
                ;;
            --libs)
                require_arg "$1" "$2"
                LIBS_BUNDLE="$2"
                USER_PROVIDED_LIBS=true
                shift 2
                ;;
            --pkgs)
                require_arg "$1" "$2"
                PKGS_BUNDLE="$2"
                USER_PROVIDED_PKGS=true
                shift 2
                ;;
            --tag)
                require_arg "$1" "$2"
                IMAGE_TAG="$2"
                shift 2
                ;;
            --list-profiles)
                LIST_PROFILES=true
                shift
                ;;
            --list-libs)
                LIST_LIBS=true
                shift
                ;;
            --list-pkgs)
                LIST_PKGS=true
                shift
                ;;
            --help-github)
                # Will be processed after modules are loaded
                SHOW_HELP_GITHUB=true
                shift
                ;;
            --help-quickstart)
                # Will be processed after modules are loaded
                SHOW_HELP_QUICKSTART=true
                shift
                ;;
            --help-workflow)
                # Will be processed after modules are loaded
                SHOW_HELP_WORKFLOW=true
                shift
                ;;
            --help-troubleshooting)
                # Will be processed after modules are loaded
                SHOW_HELP_TROUBLESHOOTING=true
                shift
                ;;
            --help-config)
                # Will be processed after modules are loaded
                SHOW_HELP_CONFIG=true
                shift
                ;;
            --help-dotfiles)
                # Will be processed after modules are loaded
                SHOW_HELP_DOTFILES=true
                shift
                ;;
            --help-renv)
                # Will be processed after modules are loaded
                SHOW_HELP_RENV=true
                shift
                ;;
            --help-renv-modes)
                # Will be processed after modules are loaded
                SHOW_HELP_RENV_MODES=true
                shift
                ;;
            --help-docker)
                # Will be processed after modules are loaded
                SHOW_HELP_DOCKER=true
                shift
                ;;
            --help-cicd)
                # Will be processed after modules are loaded
                SHOW_HELP_CICD=true
                shift
                ;;
            --yes|-y)
                SKIP_CONFIRMATION=true
                shift
                ;;
            --use-team-image)
                USE_TEAM_IMAGE=true
                shift
                ;;
            --github|-G)
                CREATE_GITHUB_REPO=true
                shift
                ;;
            --force)
                FORCE_DIRECTORY=true
                shift
                ;;
            --variants-config)
                require_arg "$1" "$2"
                PROFILES_CONFIG="$2"
                USE_CONFIG_PROFILES=true
                shift 2
                ;;
            --config|-c|config)
                # Handle config subcommands
                CONFIG_COMMAND=true
                shift
                if [[ $# -gt 0 ]]; then
                    CONFIG_SUBCOMMAND="$1"
                    shift
                    CONFIG_ARGS=("$@")
                else
                    CONFIG_SUBCOMMAND=""
                fi
                break  # Stop processing other arguments
                ;;
            *)
                echo "❌ Error: Unknown option '$1'" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

#=============================================================================
# USER-FRIENDLY INTERFACE PROCESSING
#=============================================================================

# Function: process_user_friendly_interface
# Purpose: Placeholder for future team interface processing
# Note: Deprecated -I flag logic removed. Team images now handled via config system.
process_user_friendly_interface() {
    # No-op: Legacy interface flag (-I) removed in favor of Dockerfile-based approach
    :
}

#=============================================================================
# TEAM IMAGE AVAILABILITY CHECKING
#=============================================================================

# Function: check_team_image_availability
# Purpose: Verify that required team image exists, provide helpful error if not
# Arguments: $1 = base_image, $2 = team_name, $3 = project_name, $4 = interface
check_team_image_availability() {
    local base_image="$1"
    local team_name="$2"
    local project_name="$3"
    local requested_variant="$4"

    # Try to check if image exists on Docker Hub
    if ! docker manifest inspect "$base_image:latest" >/dev/null 2>&1; then
        echo ""
        echo "❌ Error: Team image '$base_image:latest' not found"
        echo ""

        # Check what team images are available
        echo "ℹ️  Checking available variants for this project..."
        local available_images=()

        # Check config-based variants (new naming)
        for variant in minimal rstudio analysis publishing modeling bioinformatics geospatial alpine_minimal; do
            local image_name="${team_name}/${project_name}_core-${variant}:latest"
            if docker manifest inspect "$image_name" >/dev/null 2>&1; then
                available_images+=("$variant")
            fi
        done

        # Also check legacy naming for backward compatibility
        for variant in shell rstudio verse; do
            local image_name="${team_name}/${project_name}core-${variant}:latest"
            if docker manifest inspect "$image_name" >/dev/null 2>&1; then
                available_images+=("$variant (legacy)")
            fi
        done

        if [[ ${#available_images[@]} -gt 0 ]]; then
            echo "✅ Available variants for this project:"
            for variant in "${available_images[@]}"; do
                local profile_name="${variant% (legacy)}"
                if [[ "$variant" == *"(legacy)"* ]]; then
                    echo "    - ${team_name}/${project_name}core-${profile_name}:latest (legacy)"
                else
                    echo "    - ${team_name}/${project_name}_core-${variant}:latest"
                fi
            done
            echo ""
            echo "💡 Solutions:"
            echo "   1. Use available variant:"
            for variant in "${available_images[@]}"; do
                local profile_name="${variant% (legacy)}"
                echo "      zzcollab -t $team_name -p $project_name -I $profile_name"
            done
            echo "   2. Ask team lead to build $requested_variant variant:"
            echo "      cd $project_name && zzcollab -V $requested_variant"
        else
            echo "⚠️  No team images found for $team_name/$project_name"
            echo ""
            echo "💡 Solutions:"
            echo "   1. Check if team lead has run initial setup:"
            echo "      zzcollab -i -p $project_name"
            echo "   2. Verify team and project names are correct"
            echo "   3. Check Docker Hub for available images:"
            echo "      docker search ${team_name}/${project_name}"
        fi
        echo ""
        exit 1
    fi
}

#=============================================================================
# CLI VARIABLE EXPORT FUNCTION
#=============================================================================

# Function: export_cli_variables
# Purpose: Export all CLI variables for use by other modules
export_cli_variables() {
    # Core build options
    export BUILD_DOCKER DOTFILES_DIR DOTFILES_NODOT BASE_IMAGE

    # Team interface variables
    export TEAM_NAME PROJECT_NAME GITHUB_ACCOUNT DOCKERHUB_ACCOUNT DOCKERFILE_PATH

    # Mode and behavior flags
    export USE_DOTFILES PREPARE_DOCKERFILE RENV_MODE USE_TEAM_IMAGE

    # GitHub integration flags
    export CREATE_GITHUB_REPO SKIP_CONFIRMATION

    # Show/display flags
    export SHOW_HELP SHOW_NEXT_STEPS
}

#=============================================================================
# CLI VALIDATION FUNCTIONS
#=============================================================================

# Function: validate_cli_arguments
# Purpose: Validate CLI argument combinations and required values
validate_cli_arguments() {
    # Validate RENV_MODE is valid
    if [[ "$RENV_MODE" != "minimal" && "$RENV_MODE" != "fast" && "$RENV_MODE" != "standard" && "$RENV_MODE" != "comprehensive" ]]; then
        echo "❌ Error: Invalid build mode '$RENV_MODE'" >&2
        echo "   Valid modes: minimal, fast, standard, comprehensive" >&2
        exit 1
    fi
    
}

#=============================================================================
# MAIN CLI PROCESSING FUNCTION
#=============================================================================

# Function: process_cli
# Purpose: Main function to process all CLI arguments and setup
# Arguments: All command line arguments
process_cli() {
    # Parse command line arguments
    parse_cli_arguments "$@"
    
    # Process user-friendly interface options
    process_user_friendly_interface
    
    # Validate argument combinations
    validate_cli_arguments
    
    # Export variables for other modules
    export_cli_variables
}

#=============================================================================
# CLI DEBUGGING FUNCTIONS
#=============================================================================

# Function: show_cli_debug
# Purpose: Display current CLI variable values for debugging
show_cli_debug() {
    echo "🔧 CLI Debug Information:"
    echo "  BUILD_DOCKER: $BUILD_DOCKER"
    echo "  RENV_MODE: $RENV_MODE"
    echo "  DOTFILES_DIR: $DOTFILES_DIR"
    echo "  DOTFILES_NODOT: $DOTFILES_NODOT"
    echo "  BASE_IMAGE: $BASE_IMAGE"
    echo "  TEAM_NAME: $TEAM_NAME"
    echo "  PROJECT_NAME: $PROJECT_NAME"
    echo "  GITHUB_ACCOUNT: $GITHUB_ACCOUNT"
    echo "  SHOW_HELP: $SHOW_HELP"
    echo "  SHOW_NEXT_STEPS: $SHOW_NEXT_STEPS"
}

# Helper functions for modules to use simplified build modes
# Note: Modules can directly check $RENV_MODE instead of using helper functions

# Helper functions for template selection
get_template() {
    local template_type="$1"
    case "$template_type" in
        Dockerfile)
            # Use personal Dockerfile when building from team base images
            if [[ "$BASE_IMAGE" == *"core-"* ]]; then
                echo "Dockerfile.personal"
            else
                # Use unified Dockerfile for standard rocker base images
                echo "Dockerfile.unified"
            fi
            ;;
        *)
            # For other templates, use original logic
            case "$RENV_MODE" in
                fast) echo "${template_type}.minimal" ;;
                comprehensive) echo "${template_type}.pluspackages" ;;
                *) echo "$template_type" ;;
            esac
            ;;
    esac
}

# Legacy wrapper functions for backward compatibility
# Note: get_dockerfile_template() removed - use docker.sh version instead
get_description_template() { get_template "DESCRIPTION"; }
get_workflow_template() {
    # Unified paradigm uses single workflow template from unified/ directory
    echo "unified/.github/workflows/render-paper.yml"
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================


# Note: No logging here since core.sh may not be loaded yet