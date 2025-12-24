#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB PROFILES MODULE (Simplified)
##############################################################################
#
# PURPOSE: R package to system dependency mapping
#          Used by docker.sh to derive system deps from R packages
#
# DEPENDENCIES: core.sh (logging)
##############################################################################

require_module "core"

#=============================================================================
# R PACKAGE → SYSTEM DEPENDENCY MAPPING
#=============================================================================
# Maps R packages to their required system libraries for compilation
# Format: package_name → "build_dep1 build_dep2 ..."

get_package_build_deps() {
    local package="$1"
    case "$package" in
        # Geospatial
        sf|terra|rgdal|raster|stars)
            echo "libgdal-dev libproj-dev libgeos-dev" ;;
        sp|proj4|proj)
            echo "libproj-dev" ;;
        units|udunits2)
            echo "libudunits2-dev" ;;

        # Graphics
        ragg|gdtools|svglite)
            echo "libcairo2-dev libfreetype6-dev libjpeg-dev libpng-dev" ;;
        systemfonts)
            echo "libfontconfig1-dev" ;;
        magick)
            echo "libmagick++-dev" ;;

        # Data formats
        xml2)
            echo "libxml2-dev" ;;
        jsonlite|V8)
            echo "" ;;  # header-only or bundled

        # Databases
        RPostgres|RPostgreSQL)
            echo "libpq-dev" ;;
        RMySQL|RMariaDB)
            echo "libmariadb-dev" ;;
        RSQLite)
            echo "libsqlite3-dev" ;;
        odbc)
            echo "unixodbc-dev" ;;

        # Network/web
        curl|httr|httr2)
            echo "libcurl4-openssl-dev" ;;
        openssl)
            echo "libssl-dev" ;;
        sodium)
            echo "libsodium-dev" ;;
        ssh)
            echo "libssh2-1-dev" ;;
        git2r)
            echo "libgit2-dev" ;;

        # Scientific computing
        gsl)
            echo "libgsl-dev" ;;
        nloptr)
            echo "libnlopt-dev" ;;
        igraph)
            echo "libglpk-dev" ;;

        # Linear algebra (usually in base, but for completeness)
        Matrix|RcppArmadillo)
            echo "liblapack-dev libblas-dev" ;;

        # Bioconductor common
        Rhtslib|Rsamtools)
            echo "libbz2-dev liblzma-dev" ;;
        zlibbioc)
            echo "zlib1g-dev" ;;

        # Text processing
        stringi)
            echo "libicu-dev" ;;
        hunspell)
            echo "libhunspell-dev" ;;

        # Audio/video (rare but included)
        av)
            echo "libavfilter-dev" ;;
        audio)
            echo "portaudio19-dev" ;;

        # Compression
        archive)
            echo "libarchive-dev" ;;

        # HDF5
        hdf5r|rhdf5)
            echo "libhdf5-dev" ;;

        # NetCDF
        ncdf4|RNetCDF)
            echo "libnetcdf-dev" ;;

        # FFTW
        fftw|fftwtools)
            echo "libfftw3-dev" ;;

        # Protocol buffers
        RProtoBuf)
            echo "libprotobuf-dev protobuf-compiler" ;;

        # Java (for rJava)
        rJava)
            echo "default-jdk" ;;

        # Default: no special deps
        *)
            echo "" ;;
    esac
}

get_package_runtime_deps() {
    local package="$1"
    case "$package" in
        sf|terra|rgdal|raster|stars)
            echo "libgdal30 libproj25 libgeos-c1v5" ;;
        units|udunits2)
            echo "libudunits2-0" ;;
        ragg|gdtools|svglite)
            echo "libcairo2 libfreetype6 libjpeg8 libpng16-16" ;;
        magick)
            echo "libmagick++-6.q16-8" ;;
        RPostgres|RPostgreSQL)
            echo "libpq5" ;;
        RMySQL|RMariaDB)
            echo "libmariadb3" ;;
        gsl)
            echo "libgsl27" ;;
        stringi)
            echo "libicu72" ;;
        *)
            echo "" ;;
    esac
}

# Check if a package has system dependencies
package_has_system_deps() {
    local deps
    deps=$(get_package_build_deps "$1")
    [[ -n "$deps" ]]
}

# Get all deps for a list of packages
get_all_package_deps() {
    local type="$1"
    shift
    local packages=("$@")
    local all_deps=()

    for pkg in "${packages[@]}"; do
        local deps
        if [[ "$type" == "build" ]]; then
            deps=$(get_package_build_deps "$pkg")
        else
            deps=$(get_package_runtime_deps "$pkg")
        fi
        if [[ -n "$deps" ]]; then
            # shellcheck disable=SC2206
            all_deps+=($deps)
        fi
    done

    [[ ${#all_deps[@]} -gt 0 ]] && printf '%s\n' "${all_deps[@]}" | sort -u | paste -sd' ' -
}

# Export functions for use by docker.sh
export -f get_package_build_deps get_package_runtime_deps package_has_system_deps get_all_package_deps

#=============================================================================
# MODULE LOADED
#=============================================================================

readonly ZZCOLLAB_PROFILES_LOADED=true
readonly ZZCOLLAB_PROFILE_VALIDATION_LOADED=true
readonly ZZCOLLAB_SYSTEM_DEPS_MAP_LOADED=true
