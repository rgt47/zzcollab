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
# FUNCTION: get_profile_defaults
# PURPOSE:  Get default base image, libs, and packages for a profile
# USAGE:    get_profile_defaults "minimal"
# ARGS:     $1 - profile_name
# RETURNS:  Outputs "base_image:libs:pkgs" or empty if profile unknown
# DESCRIPTION:
#   Maps profile names to their default specifications
##############################################################################
get_profile_defaults() {
    local profile="$1"

    case "$profile" in
        minimal)
            echo "rocker/r-ver:minimal:minimal"
            ;;
        analysis)
            echo "rocker/tidyverse:minimal:analysis"
            ;;
        modeling)
            echo "rocker/r-ver:modeling:modeling"
            ;;
        geospatial)
            echo "rocker/r-ver:geospatial:geospatial"
            ;;
        bioinformatics)
            echo "bioconductor/bioconductor_docker:bioinformatics:bioinformatics"
            ;;
        publishing)
            echo "rocker/verse:publishing:publishing"
            ;;
        shiny)
            echo "rocker/shiny:minimal:shiny"
            ;;
        alpine_minimal)
            echo "alpine-r:alpine:minimal"
            ;;
        alpine_analysis)
            echo "alpine-r:alpine:analysis"
            ;;
        hpc_alpine)
            echo "alpine-r:hpc:minimal"
            ;;
        *)
            echo ""
            ;;
    esac
}

##############################################################################
# FUNCTION: match_static_template
# PURPOSE:  Check if resolved combination matches any static template
# USAGE:    match_static_template "rocker/r-ver" "minimal" "minimal"
# ARGS:     $1 - base_image, $2 - libs_bundle, $3 - pkgs_bundle
# RETURNS:  Outputs "Dockerfile.{profile}" if match found, empty otherwise
# DESCRIPTION:
#   Iterates through known profiles and checks if the combination matches
##############################################################################
match_static_template() {
    local base="$1"
    local libs="$2"
    local pkgs="$3"

    # List of profiles with static Dockerfiles (excluding .bak files)
    local profiles=(
        "minimal"
        "analysis"
        "modeling"
        "geospatial"
        "bioinformatics"
        "publishing"
        "shiny"
        "alpine_minimal"
        "alpine_analysis"
        "hpc_alpine"
    )

    for profile in "${profiles[@]}"; do
        local defaults=$(get_profile_defaults "$profile")
        if [[ -z "$defaults" ]]; then
            continue
        fi

        IFS=':' read -r def_base def_libs def_pkgs <<< "$defaults"

        # Check if current combination matches this profile's defaults
        if [[ "$base" == "$def_base" ]] && \
           [[ "$libs" == "$def_libs" ]] && \
           [[ "$pkgs" == "$def_pkgs" ]]; then
            # Verify static template exists
            if [[ -f "${TEMPLATES_DIR}/Dockerfile.${profile}" ]]; then
                echo "Dockerfile.${profile}"
                return 0
            fi
        fi
    done

    echo ""
    return 1
}

##############################################################################
# FUNCTION: select_dockerfile_strategy
# PURPOSE:  Determine whether to use static profile Dockerfile or generate custom
# USAGE:    select_dockerfile_strategy
# ARGS:     None (uses global variables)
# RETURNS:
#   0 - Success, outputs "static:Dockerfile.{profile}" or "generate:custom"
#   1 - Error
# GLOBALS:
#   READ:  BASE_IMAGE, LIBS_BUNDLE, PKGS_BUNDLE, USE_TEAM_IMAGE
#   WRITE: None (outputs to stdout)
# DESCRIPTION:
#   New logic: Check resolved values against static templates
#   1. If using team image → static (Dockerfile.personal.team)
#   2. Check if resolved combination matches any static template → use static
#   3. Otherwise → generate custom
# EXAMPLE:
#   strategy=$(select_dockerfile_strategy)
#   case "$strategy" in
#       static:*)  ... ;;
#       generate:*) ... ;;
#   esac
##############################################################################
select_dockerfile_strategy() {
    # Use resolved values, not just flags
    local base="${BASE_IMAGE:-rocker/r-ver}"
    local libs="${LIBS_BUNDLE:-minimal}"
    local pkgs="${PKGS_BUNDLE:-minimal}"

    # Decision logic:
    # 1. If using team image, use personal template
    if [[ "${USE_TEAM_IMAGE:-false}" == "true" ]]; then
        echo "static:Dockerfile.personal.team"
        return 0
    fi

    # 2. Check if resolved combination matches any static template
    local matched_template=$(match_static_template "$base" "$libs" "$pkgs")
    if [[ -n "$matched_template" ]]; then
        log_debug "Resolved combination matches static template: $matched_template"
        log_debug "  Base: $base, Libs: $libs, Pkgs: $pkgs"
        echo "static:${matched_template}"
        return 0
    fi

    # 3. No match found → generate custom
    log_debug "No static template matches resolved combination - using generator"
    log_debug "  Base: $base, Libs: $libs, Pkgs: $pkgs"
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

    # Generate complete RUN command or comment if no deps
    if [[ ${#deps[@]} -gt 0 ]]; then
        echo "RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \\"
        echo "    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \\"
        echo "    set -ex && \\"
        echo "    apt-get update && \\"
        echo "    apt-get install -y --no-install-recommends \\"
        printf "        %s \\\\\n" "${deps[@]}" | sed '$ s/ \\$//'
    else
        echo "# No additional build dependencies for ${libs_list} profile"
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

    # Generate complete RUN command or comment if no deps
    if [[ ${#deps[@]} -gt 0 ]]; then
        echo "RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \\"
        echo "    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \\"
        echo "    set -ex && \\"
        echo "    apt-get update && \\"
        echo "    apt-get install -y --no-install-recommends \\"
        printf "        %s \\\\\n" "${deps[@]}" | sed '$ s/ \\$//'
    else
        echo "# No additional runtime dependencies for ${libs_list} profile"
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
