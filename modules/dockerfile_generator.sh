#!/bin/bash
##############################################################################
# ZZCOLLAB DOCKERFILE GENERATOR MODULE
##############################################################################
#
# PURPOSE: Generate custom Dockerfiles from template for non-standard profiles
#          - Lookup system dependencies from bundles.yaml
#          - Lookup R packages from bundles.yaml
#          - Generate Dockerfile from Dockerfile.base.template
#          - Handle custom base images, libraries, and packages
#
# DEPENDENCIES: core.sh (logging), profile_validation.sh (bundle lookups)
#
##############################################################################

require_module "core" "profile_validation"

#=============================================================================
# DOCKERFILE SELECTION LOGIC
#=============================================================================

##############################################################################
# FUNCTION: select_dockerfile_strategy
# PURPOSE:  Determine whether to use static profile Dockerfile or generate custom
# USAGE:    select_dockerfile_strategy
# ARGS:     None (uses global variables)
# RETURNS:
#   0 - Success, outputs "static:Dockerfile.{profile}" or "generate:custom"
#   1 - Error
# GLOBALS:
#   READ:  PROFILE_NAME, BASE_IMAGE_FLAG, LIBS_BUNDLE, PKGS_BUNDLE
#   WRITE: None (outputs to stdout)
# DESCRIPTION:
#   Decision tree:
#   1. If standard profile (minimal/analysis/etc) AND no custom flags → static
#   2. If custom base image OR custom libs/pkgs → generate
#   3. If team image → static (Dockerfile.personal.team)
# EXAMPLE:
#   strategy=$(select_dockerfile_strategy)
#   case "$strategy" in
#       static:*)  ... ;;
#       generate:*) ... ;;
#   esac
##############################################################################
select_dockerfile_strategy() {
    local profile="${PROFILE_NAME:-}"
    local custom_base="${BASE_IMAGE_FLAG:-}"  # Only set if user specified -b
    local custom_libs="${LIBS_BUNDLE:-}"
    local custom_pkgs="${PKGS_BUNDLE:-}"

    # Check if static profile Dockerfile exists
    local static_dockerfile="Dockerfile.${profile}"

    # Decision logic:
    # 1. If using team image, use personal template
    if [[ "${USE_TEAM_IMAGE:-false}" == "true" ]]; then
        echo "static:Dockerfile.personal.team"
        return 0
    fi

    # 2. If user specified custom base image → must generate
    if [[ -n "$custom_base" ]]; then
        log_debug "Custom base image specified: $custom_base - using generator"
        echo "generate:custom"
        return 0
    fi

    # 3. If user specified custom libs/pkgs → must generate
    if [[ -n "$custom_libs" ]] || [[ -n "$custom_pkgs" ]]; then
        log_debug "Custom libraries or packages specified - using generator"
        echo "generate:custom"
        return 0
    fi

    # 4. If standard profile exists → use static
    if [[ -f "${TEMPLATES_DIR}/${static_dockerfile}" ]]; then
        log_debug "Using optimized static Dockerfile: $static_dockerfile"
        echo "static:${static_dockerfile}"
        return 0
    fi

    # 5. Fallback to generation for unknown profiles
    log_debug "Profile '$profile' has no static Dockerfile - using generator"
    echo "generate:custom"
    return 0
}

#=============================================================================
# CUSTOM DOCKERFILE GENERATION
#=============================================================================

##############################################################################
# FUNCTION: generate_custom_dockerfile
# PURPOSE:  Generate Dockerfile from template for custom configurations
# USAGE:    generate_custom_dockerfile
# ARGS:     None (uses global variables)
# RETURNS:
#   0 - Success, Dockerfile created
#   1 - Error during generation
# GLOBALS:
#   READ:  BASE_IMAGE, R_VERSION, LIBS_BUNDLE, PKGS_BUNDLE, TEAM_NAME, PROJECT_NAME
#   WRITE: ./Dockerfile (generated file)
# DESCRIPTION:
#   Reads Dockerfile.base.template and performs substitutions:
#   - ${BASE_IMAGE}, ${R_VERSION}
#   - ${CUSTOM_SYSTEM_DEPS_INSTALL} - from bundles.yaml
#   - ${CUSTOM_R_PACKAGES_INSTALL} - from bundles.yaml
#   - ${CUSTOM_RUNTIME_LIBS_INSTALL} - from bundles.yaml
# EXAMPLE:
#   generate_custom_dockerfile
##############################################################################
generate_custom_dockerfile() {
    log_info "Generating custom Dockerfile from template..."

    local template="${TEMPLATES_DIR}/Dockerfile.base.template"
    local output="Dockerfile"

    # Validate template exists
    if [[ ! -f "$template" ]]; then
        log_error "Template not found: $template"
        return 1
    fi

    # Get values from globals (set by CLI or config)
    local base_image="${BASE_IMAGE:-rocker/r-ver}"
    local r_version="${R_VERSION:-latest}"
    local team_name="${TEAM_NAME:-zzcollab}"
    local project_name="${PROJECT_NAME:-project}"
    local libs_list="${LIBS_BUNDLE:-minimal}"
    local pkgs_list="${PKGS_BUNDLE:-minimal}"
    local generation_date=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

    log_info "  Base image: ${base_image}:${r_version}"
    log_info "  Libraries: $libs_list"
    log_info "  Packages: $pkgs_list"

    # Look up system dependencies from bundles.yaml
    local system_deps_build=""
    local system_deps_runtime=""

    if [[ -f "${TEMPLATES_DIR}/bundles.yaml" ]]; then
        # Parse bundles.yaml for system dependencies
        # This would use yq or similar to extract deps
        # For now, use basic grep (replace with yq in production)
        system_deps_build=$(extract_system_deps_build "$libs_list")
        system_deps_runtime=$(extract_system_deps_runtime "$libs_list")
    fi

    # Look up R packages from bundles.yaml
    local r_packages=""
    if [[ -f "${TEMPLATES_DIR}/bundles.yaml" ]]; then
        r_packages=$(extract_r_packages "$pkgs_list")
    fi

    # Perform template substitution
    sed -e "s|\${BASE_IMAGE}|${base_image}|g" \
        -e "s|\${R_VERSION}|${r_version}|g" \
        -e "s|\${TEAM_NAME}|${team_name}|g" \
        -e "s|\${PROJECT_NAME}|${project_name}|g" \
        -e "s|\${GENERATION_DATE}|${generation_date}|g" \
        -e "s|\${LIBS_BUNDLE_LIST}|${libs_list}|g" \
        -e "s|\${PKGS_BUNDLE_LIST}|${pkgs_list}|g" \
        -e "s|\${CUSTOM_SYSTEM_DEPS_INSTALL}|${system_deps_build}|g" \
        -e "s|\${CUSTOM_RUNTIME_LIBS_INSTALL}|${system_deps_runtime}|g" \
        -e "s|\${CUSTOM_R_PACKAGES_INSTALL}|${r_packages}|g" \
        "$template" > "$output"

    if [[ $? -eq 0 ]]; then
        log_success "✓ Generated custom Dockerfile"
        log_info "  Specification: ${libs_list} + ${pkgs_list}"
        return 0
    else
        log_error "Failed to generate Dockerfile"
        return 1
    fi
}

#=============================================================================
# BUNDLE DEPENDENCY EXTRACTION
#=============================================================================

##############################################################################
# FUNCTION: extract_system_deps_build
# PURPOSE:  Extract build-time system dependencies from bundles.yaml
# USAGE:    extract_system_deps_build "geospatial,modeling"
# ARGS:
#   $1 - libs_list: Comma-separated list of library bundles
# RETURNS:
#   0 - Success, outputs apt-get install command fragment
# DESCRIPTION:
#   Looks up system_dependencies for each bundle in bundles.yaml
#   and formats as apt-get install fragment with proper indentation
##############################################################################
extract_system_deps_build() {
    local libs_list="$1"

    # Split comma-separated list
    IFS=',' read -ra LIBS <<< "$libs_list"

    local deps=()
    for lib in "${LIBS[@]}"; do
        # Look up in bundles.yaml (simplified - use yq in production)
        case "$lib" in
            geospatial)
                deps+=("gdal-bin" "proj-bin" "libgeos-dev" "libproj-dev" "libgdal-dev" "libudunits2-dev")
                ;;
            modeling)
                deps+=("libgsl-dev" "libblas-dev" "liblapack-dev" "libopenblas-dev" "gfortran")
                ;;
            bioinformatics)
                deps+=("zlib1g-dev" "libbz2-dev" "liblzma-dev" "libncurses5-dev")
                ;;
        esac
    done

    # Format as indented list (8 spaces for Dockerfile RUN)
    if [[ ${#deps[@]} -gt 0 ]]; then
        printf "        %s \\\\\n" "${deps[@]}" | sed '$ s/ \\$//'
    else
        echo "        # No additional build dependencies"
    fi
}

##############################################################################
# FUNCTION: extract_system_deps_runtime
# PURPOSE:  Extract runtime system libraries from bundles.yaml
# ARGS:     $1 - libs_list: Comma-separated list of library bundles
# RETURNS:  Runtime libraries (NOT -dev versions)
##############################################################################
extract_system_deps_runtime() {
    local libs_list="$1"

    IFS=',' read -ra LIBS <<< "$libs_list"

    local deps=()
    for lib in "${LIBS[@]}"; do
        case "$lib" in
            geospatial)
                deps+=("libgdal30" "libproj25" "libgeos-c1v5" "libudunits2-0")
                ;;
            modeling)
                deps+=("libgsl27" "libopenblas0")
                ;;
            # No runtime deps for bioinformatics (static linking)
        esac
    done

    if [[ ${#deps[@]} -gt 0 ]]; then
        printf "        %s \\\\\n" "${deps[@]}" | sed '$ s/ \\$//'
    else
        echo "        # No additional runtime dependencies"
    fi
}

##############################################################################
# FUNCTION: extract_r_packages
# PURPOSE:  Extract R packages from bundles.yaml
# ARGS:     $1 - pkgs_list: Comma-separated list of package bundles
# RETURNS:  Quoted, comma-separated R package list
##############################################################################
extract_r_packages() {
    local pkgs_list="$1"

    IFS=',' read -ra PKGS <<< "$pkgs_list"

    local packages=()
    for pkg in "${PKGS[@]}"; do
        case "$pkg" in
            minimal)
                packages+=("'renv'" "'devtools'" "'usethis'" "'testthat'" "'roxygen2'")
                ;;
            analysis)
                packages+=("'renv'" "'devtools'" "'tidyverse'" "'here'" "'janitor'" "'scales'" "'patchwork'" "'gt'" "'DT'")
                ;;
            modeling)
                packages+=("'renv'" "'tidyverse'" "'tidymodels'" "'xgboost'" "'randomForest'" "'glmnet'" "'caret'")
                ;;
            geospatial)
                packages+=("'renv'" "'sf'" "'terra'" "'leaflet'" "'mapview'" "'tmap'" "'tidyverse'")
                ;;
            publishing)
                packages+=("'renv'" "'devtools'" "'tidyverse'" "'quarto'" "'bookdown'" "'blogdown'" "'rmarkdown'" "'knitr'")
                ;;
        esac
    done

    # Join with commas
    local result=$(IFS=,; echo "${packages[*]}")
    echo "$result"
}
