#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB PROFILES MODULE
##############################################################################
#
# PURPOSE: R package to system dependency mapping
#          Used by docker.sh to derive system deps
#
# SOURCE: Mappings derived from rstudio/r-system-requirements
#         https://github.com/rstudio/r-system-requirements
#         (The authoritative database used by pak and rhub2)
#
# PLATFORM: Debian/Ubuntu packages (for rocker-based Docker images)
#
# LAST UPDATED: 2025-12-28
#
# DEPENDENCIES: core.sh (logging)
##############################################################################


#=============================================================================
# R PACKAGE → SYSTEM DEPENDENCY MAPPING
#=============================================================================
# Maps R packages to required system libraries for compilation (Debian/Ubuntu)
#
# Source: https://github.com/rstudio/r-system-requirements/tree/main/rules
# Format: package_name → "build_dep1 build_dep2 ..."

get_package_build_deps() {
    local package="$1"
    case "$package" in
        #---------------------------------------------------------------------
        # GEOSPATIAL (gdal, geos, proj rules)
        #---------------------------------------------------------------------
        sf|terra|rgdal|vapour|gdalcubes)
            echo "libgdal-dev gdal-bin libgeos-dev libproj-dev" ;;
        raster|stars|exactextractr)
            echo "libgdal-dev libgeos-dev libproj-dev" ;;
        sp|proj4|s2|wk)
            echo "libproj-dev" ;;
        rgeos|geos)
            echo "libgeos-dev" ;;
        units|udunits2)
            echo "libudunits2-dev" ;;
        lwgeom)
            echo "libgdal-dev libgeos-dev libproj-dev liblwgeom-dev" ;;

        #---------------------------------------------------------------------
        # GRAPHICS (cairo, freetype, imagemagick rules)
        #---------------------------------------------------------------------
        ragg)
            echo "libfreetype6-dev libpng-dev libtiff-dev libjpeg-dev" ;;
        gdtools|svglite)
            echo "libcairo2-dev libfreetype6-dev" ;;
        Cairo)
            echo "libcairo2-dev libxt-dev" ;;
        systemfonts|textshaping)
            echo "libfontconfig1-dev libfreetype6-dev" ;;
        magick)
            echo "libmagick++-dev" ;;
        pdftools|qpdf)
            echo "libpoppler-cpp-dev" ;;
        rsvg)
            echo "librsvg2-dev" ;;
        opencv)
            echo "libopencv-dev" ;;

        #---------------------------------------------------------------------
        # DATA FORMATS (xml2, json, hdf5, netcdf rules)
        #---------------------------------------------------------------------
        xml2)
            echo "libxml2-dev" ;;
        xslt|XML)
            echo "libxml2-dev libxslt1-dev" ;;
        jqr)
            echo "libjq-dev" ;;
        jsonlite|rapidjsonr)
            echo "" ;;  # header-only
        hdf5r|rhdf5|Rhdf5lib)
            echo "libhdf5-dev" ;;
        ncdf4|RNetCDF|tidync)
            echo "libnetcdf-dev" ;;
        fst)
            echo "libzstd-dev liblz4-dev" ;;
        arrow)
            echo "libcurl4-openssl-dev libssl-dev" ;;

        #---------------------------------------------------------------------
        # DATABASES (postgresql, mysql, sqlite, odbc rules)
        #---------------------------------------------------------------------
        RPostgres|RPostgreSQL|rpostgis)
            echo "libpq-dev" ;;
        RMySQL|RMariaDB)
            echo "libmariadb-dev" ;;
        RSQLite|duckdb)
            echo "libsqlite3-dev" ;;
        odbc|RODBC)
            echo "unixodbc-dev" ;;
        mongolite)
            echo "libssl-dev libsasl2-dev" ;;
        redux|RcppRedis)
            echo "libhiredis-dev" ;;

        #---------------------------------------------------------------------
        # NETWORK/WEB (curl, ssl, ssh, git rules)
        #---------------------------------------------------------------------
        curl|httr|httr2|crul)
            echo "libcurl4-openssl-dev" ;;
        openssl)
            echo "libssl-dev" ;;
        sodium|cyphr)
            echo "libsodium-dev" ;;
        ssh)
            echo "libssh-dev" ;;
        git2r|gert)
            echo "libgit2-dev" ;;
        websocket)
            echo "libssl-dev" ;;
        V8)
            echo "libv8-dev" ;;
        protolite|RProtoBuf)
            echo "libprotobuf-dev protobuf-compiler" ;;

        #---------------------------------------------------------------------
        # SCIENTIFIC COMPUTING (gsl, fftw, nlopt rules)
        #---------------------------------------------------------------------
        gsl|RcppGSL)
            echo "libgsl-dev" ;;
        nloptr)
            echo "libnlopt-dev" ;;
        fftw|fftwtools|rgl)
            echo "libfftw3-dev" ;;
        igraph)
            echo "libglpk-dev libxml2-dev" ;;
        Rmpfr|gmp)
            echo "libmpfr-dev" ;;
        Rglpk|ROI.plugin.glpk)
            echo "libglpk-dev" ;;
        Rsymphony|ROI.plugin.symphony)
            echo "coinor-libsymphony-dev" ;;
        Rclp|ROI.plugin.clp)
            echo "coinor-libclp-dev" ;;
        lpSolve|lpSolveAPI)
            echo "" ;;  # bundled
        quadprog|osqp)
            echo "" ;;  # bundled

        #---------------------------------------------------------------------
        # LINEAR ALGEBRA (lapack, blas, eigen rules)
        #---------------------------------------------------------------------
        Matrix|RcppArmadillo)
            echo "liblapack-dev libblas-dev" ;;
        RcppEigen)
            echo "" ;;  # header-only
        RSpectra|irlba)
            echo "liblapack-dev" ;;

        #---------------------------------------------------------------------
        # BIOCONDUCTOR COMMON (htslib, samtools rules)
        #---------------------------------------------------------------------
        Rhtslib|Rsamtools|VariantAnnotation)
            echo "libbz2-dev liblzma-dev libcurl4-openssl-dev" ;;
        zlibbioc|Rcompression)
            echo "zlib1g-dev" ;;
        mzR|Spectra)
            echo "libnetcdf-dev" ;;
        Biostrings|XVector)
            echo "zlib1g-dev" ;;

        #---------------------------------------------------------------------
        # TEXT PROCESSING (icu, hunspell rules)
        #---------------------------------------------------------------------
        stringi)
            echo "libicu-dev" ;;
        hunspell)
            echo "libhunspell-dev" ;;
        tesseract)
            echo "libtesseract-dev libleptonica-dev" ;;
        antiword)
            echo "antiword" ;;

        #---------------------------------------------------------------------
        # COMPRESSION/ARCHIVE (archive, lzma rules)
        #---------------------------------------------------------------------
        archive)
            echo "libarchive-dev" ;;
        bz2)
            echo "libbz2-dev" ;;
        R.utils)
            echo "" ;;  # no special deps

        #---------------------------------------------------------------------
        # AUDIO/VIDEO (av, audio rules)
        #---------------------------------------------------------------------
        av)
            echo "libavfilter-dev" ;;
        audio|tuneR)
            echo "portaudio19-dev" ;;

        #---------------------------------------------------------------------
        # JAVA (rJava rule)
        #---------------------------------------------------------------------
        rJava|RJDBC|xlsx|XLConnect)
            echo "default-jdk" ;;

        #---------------------------------------------------------------------
        # AUTHENTICATION/SECURITY (sasl, gpg rules)
        #---------------------------------------------------------------------
        gpg|gpgr)
            echo "libgpgme-dev" ;;
        secret)
            echo "libsecret-1-dev" ;;
        keyring)
            echo "libsecret-1-dev" ;;

        #---------------------------------------------------------------------
        # IMAGE PROCESSING (png, jpeg, tiff rules)
        #---------------------------------------------------------------------
        png)
            echo "libpng-dev" ;;
        jpeg)
            echo "libjpeg-dev" ;;
        tiff)
            echo "libtiff-dev" ;;
        webp)
            echo "libwebp-dev" ;;

        #---------------------------------------------------------------------
        # MISC SCIENTIFIC (jags, gmp, mpfr rules)
        #---------------------------------------------------------------------
        rjags|R2jags)
            echo "jags" ;;
        BH|StanHeaders)
            echo "" ;;  # header-only
        rstan|rstanarm)
            echo "" ;;  # uses bundled stan

        #---------------------------------------------------------------------
        # SYSTEM UTILITIES
        #---------------------------------------------------------------------
        ps|processx|callr)
            echo "" ;;  # no special deps
        sys|unix)
            echo "" ;;  # no special deps
        fs)
            echo "" ;;  # no special deps

        #---------------------------------------------------------------------
        # DEFAULT: no special deps required
        #---------------------------------------------------------------------
        *)
            echo "" ;;
    esac
}

#=============================================================================
# PROFILE CONFIGURATION
#=============================================================================
# Profile lookup from bundles.yaml

get_profile_base_image() {
    local profile="$1"
    local bundles_file="${ZZCOLLAB_TEMPLATES_DIR:-$HOME/.zzcollab/templates}/bundles.yaml"

    [[ ! -f "$bundles_file" ]] && { echo "rocker/r-ver"; return 0; }

    local result
    result=$(yq eval ".profiles.\"$profile\".base_image // \"\"" "$bundles_file" 2>/dev/null)

    if [[ -n "$result" && "$result" != "null" ]]; then
        echo "$result"
    else
        log_warn "Unknown profile '$profile', using rocker/r-ver"
        echo "rocker/r-ver"
    fi
}

#=============================================================================
# LIST FUNCTIONS (for cmd_list)
#=============================================================================

list_profiles() {
    local bundles_file="${ZZCOLLAB_TEMPLATES_DIR:-$HOME/.zzcollab/templates}/bundles.yaml"

    if [[ ! -f "$bundles_file" ]]; then
        log_error "bundles.yaml not found at $bundles_file"
        return 1
    fi

    echo "Available profiles:"
    echo ""

    yq eval '.profiles | to_entries | .[] |
        .key + "\t" + .value.base_image + "\t" + .value.description + "\t" + .value.size' \
        "$bundles_file" | while IFS=$'\t' read -r profile base desc size; do
        printf "  %-12s %-20s %s (%s)\n" "$profile" "$base" "$desc" "$size"
    done

    echo ""
    echo "Usage: zzcollab init -r <profile>"
}

list_library_bundles() {
    local bundles_file="${ZZCOLLAB_TEMPLATES_DIR:-$HOME/.zzcollab/templates}/bundles.yaml"

    if [[ ! -f "$bundles_file" ]]; then
        log_error "bundles.yaml not found at $bundles_file"
        return 1
    fi

    echo "System library bundles (components of profiles in bundles.yaml):"
    echo ""

    yq eval '.library_bundles | to_entries | .[] | .key + "\t" + .value.description' \
        "$bundles_file" | while IFS=$'\t' read -r bundle desc; do
        printf "  %-12s %s\n" "$bundle" "$desc"
    done

    echo ""
    echo "Note: System deps are auto-derived from R packages in renv.lock."
    echo "Libraries are selected by profile (zzc <profile> or --profile)."
}

list_package_bundles() {
    local bundles_file="${ZZCOLLAB_TEMPLATES_DIR:-$HOME/.zzcollab/templates}/bundles.yaml"

    if [[ ! -f "$bundles_file" ]]; then
        log_error "bundles.yaml not found at $bundles_file"
        return 1
    fi

    echo "R package bundles (components of profiles in bundles.yaml):"
    echo ""

    yq eval '.package_bundles | to_entries | .[] | .key + "\t" + .value.description' \
        "$bundles_file" | while IFS=$'\t' read -r bundle desc; do
        printf "  %-12s %s\n" "$bundle" "$desc"
    done

    echo ""
    echo "Note: Packages are managed via renv.lock. Add packages with"
    echo "install.packages() inside the container."
}
