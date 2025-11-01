#!/usr/bin/env bash
set -euo pipefail
# Profile Validation Module
# Validates compatibility between base images, library bundles, and package bundles

# Load bundles configuration
BUNDLES_FILE="${TEMPLATES_DIR}/bundles.yaml"

#-----------------------------------------------------------------------------
# FUNCTION: list_available_profiles
# PURPOSE:  List all available Docker profiles by scanning template files
# DESCRIPTION:
#   Discovers all available Docker profiles by finding Dockerfile templates
#   in the templates directory. Profiles are defined by the presence of a
#   corresponding Dockerfile template file. Excludes internal/backup files.
#   Returns a sorted list of profile names for user selection.
# ARGS:
#   None
# RETURNS:
#   0 - Always succeeds
# OUTPUTS:
#   Profile names to stdout, one per line, sorted alphabetically
# FILES READ:
#   ${TEMPLATES_DIR}/Dockerfile.* - All Dockerfile template files
# EXCLUSIONS:
#   - *.bak - Backup files
#   - *.template - Base templates (not user-selectable profiles)
#   - Dockerfile.base.template - Base template for generation
#   - Dockerfile.unified - Internal unified template
#   - Dockerfile.personal.team - Internal team member template
# PROFILE NAME EXTRACTION:
#   Dockerfile.ubuntu_standard_minimal → ubuntu_standard_minimal
#   Dockerfile.alpine_minimal → alpine_minimal
#   Basename extraction removes "Dockerfile." prefix
# GLOBALS READ:
#   TEMPLATES_DIR - Path to templates directory (from constants.sh)
# USE CASES:
#   - Display available profiles to users
#   - Validate user-provided profile names
#   - Generate help/documentation
# EXAMPLE OUTPUT:
#   alpine_standard_analysis
#   alpine_standard_minimal
#   alpine_x11_analysis
#   bioinformatics
#   geospatial
#   ubuntu_standard_minimal
#   ...
#-----------------------------------------------------------------------------
list_available_profiles() {
    find "${TEMPLATES_DIR}" -name "Dockerfile.*" -type f \
        ! -name "*.bak" \
        ! -name "*.template" \
        ! -name "Dockerfile.base.template" \
        ! -name "Dockerfile.unified" \
        ! -name "Dockerfile.personal.team" \
        -exec basename {} \; \
        | sed 's/^Dockerfile\.//' \
        | sort
}

# Function: expand_profile_name
# Purpose: Validate profile name and check if Dockerfile exists
# Note: Profiles are defined by existing Dockerfile templates
expand_profile_name() {
    local profile_name="$1"

    if [[ -z "$profile_name" ]]; then
        return 0
    fi

    # Check if Dockerfile template exists for this profile
    local dockerfile="${TEMPLATES_DIR}/Dockerfile.${profile_name}"

    if [[ ! -f "$dockerfile" ]]; then
        log_error "❌ Unknown profile: ${profile_name}"
        log_error ""
        log_error "Available profiles:"
        log_error ""
        log_error "📦 UBUNTU STANDARD (CLI + optional RStudio via ADD=rstudio):"
        log_error "  ubuntu_standard_minimal     - Minimal Ubuntu (~800MB)"
        log_error "  ubuntu_standard_analysis    - Tidyverse + ML packages (~1.5GB)"
        log_error "  ubuntu_standard_publishing  - LaTeX + Quarto publishing (~3GB)"
        log_error ""
        log_error "🌐 UBUNTU SHINY (Web applications with Shiny Server):"
        log_error "  ubuntu_shiny_minimal        - Basic Shiny Server (~1.8GB)"
        log_error "  ubuntu_shiny_analysis       - Shiny + tidyverse (~3.5GB)"
        log_error ""
        log_error "🖥️  UBUNTU X11 (GUI applications with X11 forwarding):"
        log_error "  ubuntu_x11_minimal          - Basic R with X11 (~1.5GB)"
        log_error "  ubuntu_x11_analysis         - Tidyverse + interactive graphics (~2.5GB)"
        log_error ""
        log_error "⛰️  ALPINE STANDARD (Lightweight, great for CI/CD):"
        log_error "  alpine_standard_minimal     - Ultra-lightweight (~200MB, 4x smaller)"
        log_error "  alpine_standard_analysis    - Core analysis packages (~400MB)"
        log_error ""
        log_error "🗻 ALPINE X11 (Lightweight with graphics):"
        log_error "  alpine_x11_minimal          - Base R plotting with X11 (~300MB)"
        log_error "  alpine_x11_analysis         - Analysis + X11 support (~500MB)"
        log_error ""
        log_error "🔬 LEGACY PROFILES (specialized):"
        log_error "  bioinformatics              - Bioconductor packages"
        log_error "  geospatial                  - Geospatial analysis"
        log_error "  modeling                    - Machine learning"
        log_error "  hpc_alpine                  - HPC on Alpine Linux"
        log_error ""
        log_error "Usage: zzcollab --profile-name <profile>"
        log_error "Example: zzcollab --profile-name ubuntu_standard_analysis"
        exit 1
    fi

    # Profile is valid - Dockerfile exists
    log_info "✓ Using profile: ${profile_name}"
}

# Function: validate_profile_combination
# Purpose: Check if base-image, libs, and pkgs are compatible
validate_profile_combination() {
    local base_image="${1:-$BASE_IMAGE}"
    local libs_bundle="${2:-$LIBS_BUNDLE}"
    local pkgs_bundle="${3:-$PKGS_BUNDLE}"

    local errors=()
    local warnings=()

    # Skip validation if nothing specified
    if [[ -z "$base_image" ]] && [[ -z "$libs_bundle" ]] && [[ -z "$pkgs_bundle" ]]; then
        return 0
    fi

    # Alpine base requires alpine libs
    if [[ "$base_image" == *"alpine"* ]]; then
        if [[ -n "$libs_bundle" ]] && [[ "$libs_bundle" != "alpine" ]]; then
            errors+=("❌ Alpine base image requires --libs alpine")
            errors+=("   Current: --libs ${libs_bundle}")
            errors+=("   Reason: Alpine uses apk package manager, not apt-get")
        fi
        if [[ "$libs_bundle" == "none" ]]; then
            errors+=("❌ Alpine base cannot use --libs none")
            errors+=("   Minimal libraries required for package compilation")
        fi
    fi

    # Bioconductor requires bioinfo libs
    if [[ "$base_image" == *"bioconductor"* ]]; then
        if [[ -n "$libs_bundle" ]] && [[ "$libs_bundle" != "bioinfo" ]]; then
            errors+=("❌ Bioconductor base requires --libs bioinfo")
            errors+=("   Current: --libs ${libs_bundle}")
            errors+=("   Reason: Bioconductor packages need specific dependencies")
        fi
    fi

    # Geospatial requires geospatial libs
    if [[ "$base_image" == *"geospatial"* ]]; then
        if [[ -n "$libs_bundle" ]] && [[ "$libs_bundle" != "geospatial" ]] && [[ "$libs_bundle" != "minimal" ]]; then
            errors+=("❌ Geospatial base requires --libs geospatial or --libs minimal")
            errors+=("   Current: --libs ${libs_bundle}")
            errors+=("   Reason: sf/terra packages require GDAL/PROJ libraries")
        fi
        if [[ "$libs_bundle" == "none" ]]; then
            errors+=("❌ Geospatial packages cannot work with --libs none")
        fi
    fi

    # Package bundle validation
    if [[ "$pkgs_bundle" == "geospatial" ]] && [[ "$libs_bundle" != "geospatial" ]]; then
        errors+=("❌ Package bundle 'geospatial' requires --libs geospatial")
        errors+=("   Reason: sf/terra need GDAL system libraries")
    fi

    if [[ "$pkgs_bundle" == "bioinfo" ]] && [[ "$libs_bundle" != "bioinfo" ]]; then
        errors+=("❌ Package bundle 'bioinfo' requires --libs bioinfo")
        errors+=("   Reason: Bioconductor packages need specific dependencies")
    fi

    # Verse warnings (non-fatal)
    if [[ "$base_image" == *"verse"* ]]; then
        if [[ "$libs_bundle" == "none" ]]; then
            warnings+=("⚠️  Warning: verse base includes LaTeX")
            warnings+=("   Consider: --libs publishing (includes pandoc/LaTeX tools)")
        fi
    fi

    # Print errors and warnings
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo ""
        echo "🚫 INCOMPATIBLE COMBINATION DETECTED:"
        echo ""
        for error in "${errors[@]}"; do
            echo "$error"
        done
        echo ""
        echo "💡 Suggested fix:"
        suggest_compatible_combination "$base_image" "$libs_bundle" "$pkgs_bundle"
        echo ""
        return 1
    fi

    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo ""
        for warning in "${warnings[@]}"; do
            echo "$warning"
        done
        echo ""
    fi

    return 0
}

# Function: suggest_compatible_combination
# Purpose: Provide helpful suggestions for fixing incompatible combinations
suggest_compatible_combination() {
    local base_image="$1"
    local libs_bundle="$2"
    local pkgs_bundle="$3"

    if [[ "$base_image" == *"alpine"* ]]; then
        echo "   zzcollab -b ${base_image} --libs alpine --pkgs minimal"
        echo "   or"
        echo "   zzcollab --profile-name alpine_minimal"
    elif [[ "$base_image" == *"bioconductor"* ]]; then
        echo "   zzcollab -b ${base_image} --libs bioinfo --pkgs bioinfo"
        echo "   or"
        echo "   zzcollab --profile-name bioinformatics"
    elif [[ "$base_image" == *"geospatial"* ]]; then
        echo "   zzcollab -b ${base_image} --libs geospatial --pkgs geospatial"
        echo "   or"
        echo "   zzcollab --profile-name geospatial"
    elif [[ "$base_image" == *"verse"* ]]; then
        echo "   zzcollab -b ${base_image} --libs publishing --pkgs publishing"
        echo "   or"
        echo "   zzcollab --profile-name publishing"
    else
        echo "   zzcollab -b rocker/r-ver --libs minimal --pkgs minimal"
        echo "   or"
        echo "   zzcollab --profile-name minimal"
    fi
}

# Function: apply_smart_defaults
# Purpose: Auto-set libs/pkgs if not specified, based on base image
apply_smart_defaults() {
    local base_image="${1:-$BASE_IMAGE}"

    # Auto-detect libs bundle from base image
    if [[ -z "$LIBS_BUNDLE" ]]; then
        case "$base_image" in
            *alpine*)
                LIBS_BUNDLE="alpine"
                log_info "ℹ️  Auto-detected: --libs alpine (from base image)"
                ;;
            *bioconductor*)
                LIBS_BUNDLE="bioinfo"
                log_info "ℹ️  Auto-detected: --libs bioinfo (from base image)"
                ;;
            *geospatial*)
                LIBS_BUNDLE="geospatial"
                log_info "ℹ️  Auto-detected: --libs geospatial (from base image)"
                ;;
            *tidyverse*)
                LIBS_BUNDLE="minimal"
                log_info "ℹ️  Auto-detected: --libs minimal (from base image)"
                ;;
            *verse*)
                LIBS_BUNDLE="publishing"
                log_info "ℹ️  Auto-detected: --libs publishing (from base image)"
                ;;
            *)
                LIBS_BUNDLE="minimal"
                ;;
        esac
    fi

    # Auto-detect pkgs bundle from base image
    if [[ -z "$PKGS_BUNDLE" ]]; then
        case "$base_image" in
            *alpine*)
                PKGS_BUNDLE="minimal"
                log_info "ℹ️  Auto-detected: --pkgs minimal (for Alpine)"
                ;;
            *bioconductor*)
                PKGS_BUNDLE="bioinfo"
                log_info "ℹ️  Auto-detected: --pkgs bioinfo (for Bioconductor)"
                ;;
            *geospatial*)
                PKGS_BUNDLE="geospatial"
                log_info "ℹ️  Auto-detected: --pkgs geospatial (from base image)"
                ;;
            *tidyverse*)
                PKGS_BUNDLE="tidyverse"
                log_info "ℹ️  Auto-detected: --pkgs tidyverse (from base image)"
                ;;
            *verse*)
                PKGS_BUNDLE="publishing"
                log_info "ℹ️  Auto-detected: --pkgs publishing (from base image)"
                ;;
            *)
                PKGS_BUNDLE="minimal"
                ;;
        esac
    fi
}

# Function: generate_r_package_install_commands
# Purpose: Read bundles.yaml and generate R package installation commands
# Sets: R_PACKAGES_INSTALL_CMD (the actual R install command)
generate_r_package_install_commands() {
    local pkgs_bundle="${1:-$PKGS_BUNDLE}"

    if [[ -z "$pkgs_bundle" ]]; then
        R_PACKAGES_INSTALL_CMD="# No package bundle specified"
        return 0
    fi

    if [[ ! -f "$BUNDLES_FILE" ]]; then
        log_error "❌ Bundles file not found: $BUNDLES_FILE"
        return 1
    fi

    # Extract package list from bundles.yaml
    local packages
    packages=$(yq eval ".package_bundles.${pkgs_bundle}.packages | join(\"', '\")" "$BUNDLES_FILE" 2>/dev/null)

    if [[ "$packages" == "null" ]] || [[ -z "$packages" ]]; then
        log_warn "⚠️  Unknown package bundle: ${pkgs_bundle}, using minimal"
        packages=$(yq eval ".package_bundles.minimal.packages | join(\"', '\")" "$BUNDLES_FILE" 2>/dev/null)
    fi

    # Check if this is a bioconductor bundle
    local is_bioc
    is_bioc=$(yq eval ".package_bundles.${pkgs_bundle}.bioconductor // false" "$BUNDLES_FILE" 2>/dev/null)

    # Determine if we should use install2.r (rocker images) or install.packages (non-rocker)
    # install2.r is only available in rocker/* images
    local use_install2r=false
    if [[ "${BASE_IMAGE:-rocker/r-ver}" =~ ^rocker/ ]]; then
        use_install2r=true
    fi

    if [[ "$is_bioc" == "true" ]]; then
        # Bioconductor packages: install BiocManager first, then use it
        # Extract BiocManager and regular packages
        local bioc_packages
        bioc_packages=$(echo "$packages" | sed 's/BiocManager, //')

        if [[ "$use_install2r" == "true" ]]; then
            # Use install2.r for pre-compiled binaries (rocker images)
            R_PACKAGES_INSTALL_CMD="install2.r --error --skipinstalled renv devtools BiocManager && \\\\\n    R -e \"BiocManager::install(c('${bioc_packages}'))\" && \\\\\n    rm -rf /tmp/downloaded_packages"
        else
            # Use install.packages with PPM repo (non-rocker images)
            R_PACKAGES_INSTALL_CMD="R -e \"install.packages(c('renv', 'devtools', 'BiocManager'), repos = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest')\" && \\\\\n    R -e \"BiocManager::install(c('${bioc_packages}'))\""
        fi
    else
        # Regular CRAN packages
        # shellcheck disable=SC2089,SC2090  # Intentional: command stored for template substitution

        if [[ "$use_install2r" == "true" ]]; then
            # Use install2.r for pre-compiled binaries from Posit PPM (rocker images)
            local packages_space
            packages_space=$(echo "$packages" | sed "s/', '/ /g")
            R_PACKAGES_INSTALL_CMD="install2.r --error --skipinstalled ${packages_space} && rm -rf /tmp/downloaded_packages"
        else
            # Use install.packages with PPM repo for pre-compiled binaries (non-rocker images)
            R_PACKAGES_INSTALL_CMD="R -e \"install.packages(c('${packages}'), repos = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest')\""
        fi
    fi

    # shellcheck disable=SC2090  # Intentional: command stored for template substitution
    export R_PACKAGES_INSTALL_CMD
}

# Function: generate_system_deps_install_commands
# Purpose: Read bundles.yaml and generate system dependency installation commands
# Sets: SYSTEM_DEPS_INSTALL_CMD (the actual apt-get/apk install command)
generate_system_deps_install_commands() {
    local libs_bundle="${1:-$LIBS_BUNDLE}"

    if [[ -z "$libs_bundle" ]]; then
        SYSTEM_DEPS_INSTALL_CMD="# No library bundle specified"
        return 0
    fi

    if [[ ! -f "$BUNDLES_FILE" ]]; then
        log_error "❌ Bundles file not found: $BUNDLES_FILE"
        return 1
    fi

    # Extract system dependency list from bundles.yaml
    local deps package_manager
    deps=$(yq eval ".library_bundles.${libs_bundle}.deps[]" "$BUNDLES_FILE" 2>/dev/null | tr '\n' ' ')
    package_manager=$(yq eval ".library_bundles.${libs_bundle}.package_manager" "$BUNDLES_FILE" 2>/dev/null)

    if [[ "$deps" == "null" ]] || [[ -z "$deps" ]]; then
        SYSTEM_DEPS_INSTALL_CMD="# No additional system dependencies for bundle: ${libs_bundle}"
        return 0
    fi

    # Generate appropriate install command based on package manager
    if [[ "$package_manager" == "apk" ]]; then
        SYSTEM_DEPS_INSTALL_CMD="apk add --no-cache ${deps}"
    else
        # Default to apt-get
        SYSTEM_DEPS_INSTALL_CMD="apt-get update && apt-get install -y ${deps} && rm -rf /var/lib/apt/lists/*"
    fi

    export SYSTEM_DEPS_INSTALL_CMD
}

# Function: validate_team_member_flags
# Purpose: Block flags that team members cannot use
validate_team_member_flags() {
    local is_team_member="$1"

    if [[ "$is_team_member" != "true" ]]; then
        return 0
    fi

    # Team members cannot change base image
    if [[ "${USER_PROVIDED_BASE_IMAGE:-false}" == "true" ]]; then
        log_error "❌ Error: Team members cannot use -b/--base-image flag"
        log_error ""
        log_error "   The team image IS your base:"
        log_error "   FROM ${TEAM_NAME}/${PROJECT_NAME}_core:${IMAGE_TAG:-latest}"
        log_error ""
        log_error "   To use a different base, ask team lead to create a new profile."
        exit 1
    fi

    # Team members cannot change system libraries
    if [[ "${USER_PROVIDED_LIBS:-false}" == "true" ]]; then
        log_error "❌ Error: Team members cannot use --libs flag"
        log_error ""
        log_error "   System libraries are in the team image (immutable)."
        log_error ""
        log_error "   To add system libraries, ask team lead to rebuild:"
        log_error "   zzcollab -t $TEAM_NAME -p $PROJECT_NAME --libs BUNDLE"
        exit 1
    fi

    # Team members cannot use profile shortcuts
    if [[ "${USER_PROVIDED_PROFILE:-false}" == "true" ]]; then
        log_error "❌ Error: Team members cannot use --profile-name flag"
        log_error ""
        log_error "   Profiles set base-image and libs (not allowed for members)."
        log_error "   You can only add R packages with --pkgs"
        log_error ""
        log_error "   Example: zzcollab -t $TEAM_NAME -p $PROJECT_NAME --pkgs modeling"
        exit 1
    fi
}

# Mark module as loaded
readonly ZZCOLLAB_PROFILE_VALIDATION_LOADED=true
