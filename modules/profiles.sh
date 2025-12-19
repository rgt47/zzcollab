#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB PROFILES MODULE
##############################################################################
#
# PURPOSE: Profile validation, bundle configuration, and system dependency mapping
#          - Docker profile validation (base images, libs, pkgs)
#          - R package to system dependency mapping
#          - Bundle configuration from bundles.yaml
#
# DEPENDENCIES: core.sh (logging)
##############################################################################

require_module "core"

BUNDLES_FILE="${TEMPLATES_DIR:-}/bundles.yaml"

#=============================================================================
# YAML BUNDLE QUERIES
#=============================================================================

query_bundle_value() {
    local bundle_type="$1" bundle_name="$2" query_path="$3"
    [[ -f "$BUNDLES_FILE" ]] || { log_error "Bundles file not found: $BUNDLES_FILE"; return 1; }
    yq eval ".${bundle_type}.${bundle_name}${query_path}" "$BUNDLES_FILE" 2>/dev/null || return 1
}

#=============================================================================
# PROFILE LISTING AND VALIDATION
#=============================================================================

list_available_profiles() {
    find "${TEMPLATES_DIR}" -name "Dockerfile.*" -type f \
        ! -name "*.bak" ! -name "*.template" ! -name "Dockerfile.base.template" \
        ! -name "Dockerfile.unified" ! -name "Dockerfile.personal.team" \
        -exec basename {} \; | sed 's/^Dockerfile\.//' | sort
}

expand_profile_name() {
    local profile_name="$1"
    [[ -z "$profile_name" ]] && return 0

    local dockerfile="${TEMPLATES_DIR}/Dockerfile.${profile_name}"
    if [[ ! -f "$dockerfile" ]]; then
        log_error "Unknown profile: ${profile_name}"
        log_error ""
        log_error "Available profiles:"
        log_error "  Ubuntu: ubuntu_standard_minimal, ubuntu_standard_analysis, ubuntu_standard_publishing"
        log_error "  Shiny:  ubuntu_shiny_minimal, ubuntu_shiny_analysis"
        log_error "  X11:    ubuntu_x11_minimal, ubuntu_x11_analysis"
        log_error "  Alpine: alpine_standard_minimal, alpine_standard_analysis"
        log_error "  Legacy: bioinformatics, geospatial, modeling, hpc_alpine"
        log_error ""
        log_error "Usage: zzcollab --profile-name <profile>"
        exit 1
    fi
    log_info "Using profile: ${profile_name}"
}

#=============================================================================
# VALIDATION FUNCTIONS
#=============================================================================

validate_base_image_constraints() {
    local base_image="$1" libs_bundle="$2"
    local errors=()

    if [[ "$base_image" == *"alpine"* ]]; then
        [[ -n "$libs_bundle" && "$libs_bundle" != "alpine" ]] && \
            errors+=("Alpine base requires --libs alpine (uses apk, not apt-get)")
        [[ "$libs_bundle" == "none" ]] && \
            errors+=("Alpine base cannot use --libs none")
    fi

    if [[ "$base_image" == *"bioconductor"* ]]; then
        [[ -n "$libs_bundle" && "$libs_bundle" != "bioinfo" ]] && \
            errors+=("Bioconductor base requires --libs bioinfo")
    fi

    if [[ "$base_image" == *"geospatial"* ]]; then
        [[ -n "$libs_bundle" && "$libs_bundle" != "geospatial" && "$libs_bundle" != "minimal" ]] && \
            errors+=("Geospatial base requires --libs geospatial or minimal")
        [[ "$libs_bundle" == "none" ]] && \
            errors+=("Geospatial packages cannot work with --libs none")
    fi

    [[ ${#errors[@]} -gt 0 ]] && printf '%s\n' "${errors[@]}"
}

validate_package_bundle_constraints() {
    local pkgs_bundle="$1" libs_bundle="$2"
    local errors=()

    [[ "$pkgs_bundle" == "geospatial" && "$libs_bundle" != "geospatial" ]] && \
        errors+=("Package bundle 'geospatial' requires --libs geospatial")
    [[ "$pkgs_bundle" == "bioinfo" && "$libs_bundle" != "bioinfo" ]] && \
        errors+=("Package bundle 'bioinfo' requires --libs bioinfo")

    [[ ${#errors[@]} -gt 0 ]] && printf '%s\n' "${errors[@]}"
}

validate_verse_warnings() {
    local base_image="$1" libs_bundle="$2"
    [[ "$base_image" == *"verse"* && "$libs_bundle" == "none" ]] && \
        echo "Warning: verse base includes LaTeX. Consider --libs publishing"
}

suggest_compatible_combination() {
    local base_image="$1"
    case "$base_image" in
        *alpine*)      echo "  zzcollab -b ${base_image} --libs alpine --pkgs minimal" ;;
        *bioconductor*) echo "  zzcollab -b ${base_image} --libs bioinfo --pkgs bioinfo" ;;
        *geospatial*)  echo "  zzcollab -b ${base_image} --libs geospatial --pkgs geospatial" ;;
        *verse*)       echo "  zzcollab -b ${base_image} --libs publishing --pkgs publishing" ;;
        *)             echo "  zzcollab -b rocker/r-ver --libs minimal --pkgs minimal" ;;
    esac
}

validate_profile_combination() {
    local base_image="${1:-$BASE_IMAGE}" libs_bundle="${2:-$LIBS_BUNDLE}" pkgs_bundle="${3:-$PKGS_BUNDLE}"
    [[ -z "$base_image" && -z "$libs_bundle" && -z "$pkgs_bundle" ]] && return 0

    local all_items=()
    while IFS= read -r line; do [[ -n "$line" ]] && all_items+=("$line"); done < <(validate_base_image_constraints "$base_image" "$libs_bundle")
    while IFS= read -r line; do [[ -n "$line" ]] && all_items+=("$line"); done < <(validate_package_bundle_constraints "$pkgs_bundle" "$libs_bundle")
    while IFS= read -r line; do [[ -n "$line" ]] && all_items+=("$line"); done < <(validate_verse_warnings "$base_image" "$libs_bundle")

    if [[ ${#all_items[@]} -gt 0 ]]; then
        echo ""
        echo "INCOMPATIBLE COMBINATION DETECTED:"
        printf '  %s\n' "${all_items[@]}"
        echo ""
        echo "Suggested fix:"
        suggest_compatible_combination "$base_image"
        return 1
    fi
    return 0
}

#=============================================================================
# SMART DEFAULTS
#=============================================================================

apply_smart_defaults() {
    local base_image="${1:-$BASE_IMAGE}"

    if [[ -z "$LIBS_BUNDLE" ]]; then
        case "$base_image" in
            *alpine*)      LIBS_BUNDLE="alpine"; log_info "Auto-detected: --libs alpine" ;;
            *bioconductor*) LIBS_BUNDLE="bioinfo"; log_info "Auto-detected: --libs bioinfo" ;;
            *geospatial*)  LIBS_BUNDLE="geospatial"; log_info "Auto-detected: --libs geospatial" ;;
            *tidyverse*)   LIBS_BUNDLE="minimal" ;;
            *verse*)       LIBS_BUNDLE="publishing"; log_info "Auto-detected: --libs publishing" ;;
            *)             LIBS_BUNDLE="minimal" ;;
        esac
    fi

    if [[ -z "$PKGS_BUNDLE" ]]; then
        case "$base_image" in
            *alpine*)      PKGS_BUNDLE="minimal"; log_info "Auto-detected: --pkgs minimal" ;;
            *bioconductor*) PKGS_BUNDLE="bioinfo"; log_info "Auto-detected: --pkgs bioinfo" ;;
            *geospatial*)  PKGS_BUNDLE="geospatial"; log_info "Auto-detected: --pkgs geospatial" ;;
            *tidyverse*)   PKGS_BUNDLE="tidyverse"; log_info "Auto-detected: --pkgs tidyverse" ;;
            *verse*)       PKGS_BUNDLE="publishing"; log_info "Auto-detected: --pkgs publishing" ;;
            *)             PKGS_BUNDLE="minimal" ;;
        esac
    fi
}

#=============================================================================
# INSTALL COMMAND GENERATION
#=============================================================================

generate_r_package_install_commands() {
    local pkgs_bundle="${1:-$PKGS_BUNDLE}"
    [[ -z "$pkgs_bundle" ]] && { R_PACKAGES_INSTALL_CMD="# No package bundle specified"; return 0; }

    local packages
    if ! packages=$(query_bundle_value "package_bundles" "$pkgs_bundle" ".packages | join(\"', '\")"); then
        log_warn "Unknown package bundle: ${pkgs_bundle}, using minimal"
        packages=$(query_bundle_value "package_bundles" "minimal" ".packages | join(\"', '\")" 2>/dev/null) || return 1
    fi

    local is_bioc
    is_bioc=$(query_bundle_value "package_bundles" "$pkgs_bundle" ".bioconductor // false" 2>/dev/null) || is_bioc="false"

    local use_install2r=false
    [[ "${BASE_IMAGE:-rocker/r-ver}" =~ ^rocker/ ]] && use_install2r=true

    if [[ "$is_bioc" == "true" ]]; then
        local bioc_packages; bioc_packages=$(echo "$packages" | sed 's/BiocManager, //')
        if [[ "$use_install2r" == "true" ]]; then
            R_PACKAGES_INSTALL_CMD="install2.r --error --skipinstalled renv devtools BiocManager && \\\\\n    R -e \"BiocManager::install(c('${bioc_packages}'))\" && \\\\\n    rm -rf /tmp/downloaded_packages"
        else
            R_PACKAGES_INSTALL_CMD="R -e \"install.packages(c('renv', 'devtools', 'BiocManager'), repos = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest')\" && \\\\\n    R -e \"BiocManager::install(c('${bioc_packages}'))\""
        fi
    else
        if [[ "$use_install2r" == "true" ]]; then
            local packages_space; packages_space=$(echo "$packages" | sed "s/', '/ /g")
            R_PACKAGES_INSTALL_CMD="install2.r --error --skipinstalled ${packages_space} && rm -rf /tmp/downloaded_packages"
        else
            R_PACKAGES_INSTALL_CMD="R -e \"install.packages(c('${packages}'), repos = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest')\""
        fi
    fi
    export R_PACKAGES_INSTALL_CMD
}

generate_system_deps_install_commands() {
    local libs_bundle="${1:-$LIBS_BUNDLE}"
    [[ -z "$libs_bundle" ]] && { SYSTEM_DEPS_INSTALL_CMD="# No library bundle specified"; return 0; }

    local deps package_manager
    deps=$(query_bundle_value "library_bundles" "$libs_bundle" ".deps[]" 2>/dev/null | tr '\n' ' ') || deps=""
    package_manager=$(query_bundle_value "library_bundles" "$libs_bundle" ".package_manager" 2>/dev/null) || package_manager="apt-get"

    if [[ "$deps" == "null" || -z "$deps" ]]; then
        SYSTEM_DEPS_INSTALL_CMD="# No system dependencies for bundle: ${libs_bundle}"
        return 0
    fi

    if [[ "$package_manager" == "apk" ]]; then
        SYSTEM_DEPS_INSTALL_CMD="apk add --no-cache ${deps}"
    else
        SYSTEM_DEPS_INSTALL_CMD="apt-get update && apt-get install -y ${deps} && rm -rf /var/lib/apt/lists/*"
    fi
    export SYSTEM_DEPS_INSTALL_CMD
}

#=============================================================================
# TEAM MEMBER VALIDATION
#=============================================================================

validate_team_member_flags() {
    local is_team_member="$1"
    [[ "$is_team_member" != "true" ]] && return 0

    if [[ "${USER_PROVIDED_BASE_IMAGE:-false}" == "true" ]]; then
        log_error "Team members cannot use -b/--base-image flag"
        log_error "The team image is your base. Ask team lead to create new profile."
        exit 1
    fi

    if [[ "${USER_PROVIDED_LIBS:-false}" == "true" ]]; then
        log_error "Team members cannot use --libs flag"
        log_error "System libraries are in the team image (immutable)."
        exit 1
    fi

    if [[ "${USER_PROVIDED_PROFILE:-false}" == "true" ]]; then
        log_error "Team members cannot use --profile-name flag"
        log_error "Profiles set base-image and libs. Use --pkgs for R packages."
        exit 1
    fi
}

#=============================================================================
# SYSTEM DEPENDENCY MAPPING (merged from system_deps_map.sh)
#=============================================================================

get_package_build_deps() {
    local package="$1"
    case "$package" in
        sf|terra|rgdal|raster|stars) echo "libgdal-dev libproj-dev libgeos-dev" ;;
        sp|proj4|proj)               echo "libproj-dev" ;;
        gdal)                        echo "libgdal-dev" ;;
        libudunits2|units|udunits2)  echo "libudunits2-dev" ;;
        gdtools|ragg|graphicsutils)  echo "libcairo2-dev libfreetype6-dev libjpeg-dev libpng-dev" ;;
        systemfonts)                 echo "libfontconfig1-dev" ;;
        magick)                      echo "libmagick++-dev" ;;
        xml2|xml)                    echo "libxml2-dev" ;;
        RPostgres|DBI)               echo "postgresql-client libpq-dev" ;;
        RMySQL|MySQL)                echo "libmysqlclient-dev" ;;
        RSQLite)                     echo "sqlite3 libsqlite3-dev" ;;
        gsl)                         echo "libgsl-dev" ;;
        nlme|Matrix)                 echo "liblapack-dev libblas-dev" ;;
        Biostrings|GenomicRanges|rtracklayer) echo "zlib1g-dev libbz2-dev liblzma-dev" ;;
        stringi)                     echo "libicu-dev" ;;
        igraph)                      echo "libigraph-dev" ;;
        GEOS)                        echo "libgeos-dev" ;;
        *)                           echo "" ;;
    esac
}

get_package_runtime_deps() {
    local package="$1"
    case "$package" in
        sf|terra|rgdal|raster|stars) echo "libgdal30 libproj25 libgeos-c1v5" ;;
        sp|proj4|proj)               echo "libproj25" ;;
        gdal)                        echo "libgdal30" ;;
        libudunits2|units|udunits2)  echo "libudunits2-0" ;;
        gdtools|ragg|graphicsutils)  echo "libcairo2 libfreetype6 libjpeg8 libpng16-16" ;;
        systemfonts)                 echo "libfontconfig1" ;;
        magick)                      echo "libmagick++" ;;
        xml2|xml)                    echo "libxml2" ;;
        RPostgres|DBI)               echo "postgresql-client libpq5" ;;
        RMySQL|MySQL)                echo "libmysqlclient21" ;;
        RSQLite)                     echo "sqlite3 libsqlite3-0" ;;
        gsl)                         echo "libgsl27" ;;
        nlme|Matrix)                 echo "liblapack3 libblas3" ;;
        Biostrings|GenomicRanges|rtracklayer) echo "zlib1g libbz2-1.0 liblzma5" ;;
        stringi)                     echo "libicu72" ;;
        igraph)                      echo "libigraph0" ;;
        GEOS)                        echo "libgeos-c1v5" ;;
        *)                           echo "" ;;
    esac
}

get_all_package_deps() {
    local type="$1"; shift
    local packages=("$@") all_deps=()

    for package in "${packages[@]}"; do
        local deps
        [[ "$type" == "build" ]] && deps=$(get_package_build_deps "$package") || deps=$(get_package_runtime_deps "$package")
        [[ -n "$deps" ]] && all_deps+=($deps)
    done
    [[ ${#all_deps[@]} -gt 0 ]] && printf '%s\n' "${all_deps[@]}" | sort -u | paste -sd' ' -
}

package_has_system_deps() {
    [[ -n "$(get_package_build_deps "$1")" ]]
}

export -f get_package_build_deps get_package_runtime_deps get_all_package_deps package_has_system_deps

#=============================================================================
# MODULE LOADED FLAGS
#=============================================================================

readonly ZZCOLLAB_PROFILES_LOADED=true
readonly ZZCOLLAB_PROFILE_VALIDATION_LOADED=true
readonly ZZCOLLAB_SYSTEM_DEPS_MAP_LOADED=true
