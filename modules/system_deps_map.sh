#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB SYSTEM DEPENDENCIES MAPPING MODULE
##############################################################################
#
# PURPOSE: Map R packages to system dependencies (build and runtime)
#          Enables validation.sh to detect missing system libraries
#
# USAGE:   source modules/system_deps_map.sh
#          get_package_build_deps "sf"     → returns "libgdal-dev libproj-dev"
#          get_package_runtime_deps "sf"   → returns "libgdal30 libproj25"
#
# DEPENDENCIES: None (standalone module)
#
##############################################################################

##############################################################################
# FUNCTION: get_package_build_deps
# PURPOSE:  Get build-time system dependencies for an R package
# USAGE:    get_package_build_deps "sf"
# ARGS:     $1 - R package name
# RETURNS:  Space-separated list of system dependencies (build -dev versions)
#           Empty string if package has no special dependencies
##############################################################################
get_package_build_deps() {
    local package="$1"

    case "$package" in
        # Geospatial packages
        sf|terra|rgdal|raster|stars)
            echo "libgdal-dev libproj-dev libgeos-dev"
            ;;
        sp)
            echo "libproj-dev"
            ;;
        gdal)
            echo "libgdal-dev"
            ;;
        proj4|proj)
            echo "libproj-dev"
            ;;
        libudunits2|units)
            echo "libudunits2-dev"
            ;;

        # Graphics/visualization packages
        gdtools|ragg|graphicsutils)
            echo "libcairo2-dev libfreetype6-dev libjpeg-dev libpng-dev"
            ;;
        systemfonts)
            echo "libfontconfig1-dev"
            ;;
        magick)
            echo "libmagick++-dev"
            ;;
        xml2|xml)
            echo "libxml2-dev"
            ;;

        # Database packages
        RPostgres|DBI)
            echo "postgresql-client libpq-dev"
            ;;
        RMySQL|MySQL)
            echo "libmysqlclient-dev"
            ;;
        RSQLite)
            echo "sqlite3 libsqlite3-dev"
            ;;

        # Scientific computing
        gsl)
            echo "libgsl-dev"
            ;;
        nlme|Matrix)
            echo "liblapack-dev libblas-dev"
            ;;

        # Bioinformatics packages
        Biostrings|GenomicRanges|rtracklayer)
            echo "zlib1g-dev libbz2-dev liblzma-dev"
            ;;

        # Text/string packages
        stringi)
            echo "libicu-dev"
            ;;

        # Other common packages
        igraph)
            echo "libigraph-dev"
            ;;
        udunits2)
            echo "libudunits2-dev"
            ;;
        GEOS)
            echo "libgeos-dev"
            ;;
        *)
            # Unknown package - no special dependencies
            echo ""
            ;;
    esac
}

##############################################################################
# FUNCTION: get_package_runtime_deps
# PURPOSE:  Get runtime system dependencies for an R package
# USAGE:    get_package_runtime_deps "sf"
# ARGS:     $1 - R package name
# RETURNS:  Space-separated list of system libraries (runtime, no -dev)
#           Empty string if package has no special runtime dependencies
# NOTE:     Runtime deps are derived from build deps by removing -dev suffix
#           and mapping to correct version numbers (e.g., libgdal-dev → libgdal30)
##############################################################################
get_package_runtime_deps() {
    local package="$1"

    case "$package" in
        # Geospatial packages (map -dev to runtime versions)
        sf|terra|rgdal|raster|stars)
            echo "libgdal30 libproj25 libgeos-c1v5"
            ;;
        sp)
            echo "libproj25"
            ;;
        gdal)
            echo "libgdal30"
            ;;
        proj4|proj)
            echo "libproj25"
            ;;
        libudunits2|units)
            echo "libudunits2-0"
            ;;

        # Graphics/visualization packages
        gdtools|ragg|graphicsutils)
            echo "libcairo2 libfreetype6 libjpeg8 libpng16-16"
            ;;
        systemfonts)
            echo "libfontconfig1"
            ;;
        magick)
            echo "libmagick++"
            ;;
        xml2|xml)
            echo "libxml2"
            ;;

        # Database packages
        RPostgres|DBI)
            echo "postgresql-client libpq5"
            ;;
        RMySQL|MySQL)
            echo "libmysqlclient21"
            ;;
        RSQLite)
            echo "sqlite3 libsqlite3-0"
            ;;

        # Scientific computing
        gsl)
            echo "libgsl27"
            ;;
        nlme|Matrix)
            echo "liblapack3 libblas3"
            ;;

        # Bioinformatics packages
        Biostrings|GenomicRanges|rtracklayer)
            echo "zlib1g libbz2-1.0 liblzma5"
            ;;

        # Text/string packages
        stringi)
            echo "libicu72"
            ;;

        # Other common packages
        igraph)
            echo "libigraph0"
            ;;
        udunits2)
            echo "libudunits2-0"
            ;;
        GEOS)
            echo "libgeos-c1v5"
            ;;
        *)
            # Unknown package - no special runtime dependencies
            echo ""
            ;;
    esac
}

##############################################################################
# FUNCTION: get_all_package_deps
# PURPOSE:  Get all system dependencies for a list of R packages
# USAGE:    get_all_package_deps "build" "sf" "terra" "rgdal"
# ARGS:     $1 - type: "build" or "runtime"
#           $2+ - R package names
# RETURNS:  Space-separated list of unique system dependencies
##############################################################################
get_all_package_deps() {
    local type="$1"
    shift
    local packages=("$@")

    local all_deps=()

    for package in "${packages[@]}"; do
        local deps
        if [[ "$type" == "build" ]]; then
            deps=$(get_package_build_deps "$package")
        else
            deps=$(get_package_runtime_deps "$package")
        fi

        if [[ -n "$deps" ]]; then
            all_deps+=($deps)
        fi
    done

    # Return unique, sorted dependencies
    if [[ ${#all_deps[@]} -gt 0 ]]; then
        printf '%s\n' "${all_deps[@]}" | sort -u | paste -sd' ' -
    fi
}

##############################################################################
# FUNCTION: package_has_system_deps
# PURPOSE:  Check if an R package has special system dependencies
# USAGE:    if package_has_system_deps "sf"; then ...
# ARGS:     $1 - R package name
# RETURNS:  0 if has deps, 1 if no special deps
##############################################################################
package_has_system_deps() {
    local package="$1"
    local deps=$(get_package_build_deps "$package")
    [[ -n "$deps" ]]
}

export -f get_package_build_deps
export -f get_package_runtime_deps
export -f get_all_package_deps
export -f package_has_system_deps
