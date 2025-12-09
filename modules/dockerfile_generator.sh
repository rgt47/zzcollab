#!/bin/bash
set -euo pipefail
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
##############################################################################
# FUNCTION: validate_bundle_exists
# PURPOSE:  Validate that a bundle name exists in bundles.yaml
# USAGE:    validate_bundle_exists "library_bundles" "geospatial"
# RETURNS:  0 if bundle exists, 1 if not found or validation unavailable
##############################################################################
validate_bundle_exists() {
    local bundle_type="$1"  # "library_bundles" or "package_bundles"
    local bundle_name="$2"

    # Check if bundles.yaml exists
    if [[ ! -f "${TEMPLATES_DIR}/bundles.yaml" ]]; then
        log_warn "bundles.yaml not found - skipping bundle validation"
        return 0  # Non-fatal, validation is best-effort
    fi

    # Check if yq is available for YAML parsing
    if command -v yq >/dev/null 2>&1; then
        # Use yq to check if bundle exists
        local bundle_check
        bundle_check=$(yq eval ".${bundle_type}.${bundle_name}" "${TEMPLATES_DIR}/bundles.yaml" 2>/dev/null)

        if [[ "$bundle_check" == "null" ]] || [[ -z "$bundle_check" ]]; then
            log_debug "Bundle not found: ${bundle_type}.${bundle_name}"
            return 1  # Bundle doesn't exist
        fi

        log_debug "✓ Validated bundle exists: ${bundle_type}.${bundle_name}"
        return 0  # Bundle exists
    else
        # yq not available - use grep as fallback (less reliable)
        if grep -q "^  ${bundle_name}:" "${TEMPLATES_DIR}/bundles.yaml" 2>/dev/null; then
            log_debug "✓ Bundle found (grep fallback): ${bundle_name}"
            return 0
        else
            log_debug "Bundle not found (grep fallback): ${bundle_name}"
            return 1
        fi
    fi
}

get_profile_defaults() {
    local profile="$1"

    local defaults=""
    case "$profile" in
        # Ubuntu Standard profiles
        ubuntu_standard_minimal)
            defaults="rocker/r-ver:minimal:minimal"
            ;;
        ubuntu_standard_analysis)
            defaults="rocker/tidyverse:modeling:modeling"
            ;;
        ubuntu_standard_publishing)
            defaults="rocker/verse:publishing:publishing"
            ;;
        # Ubuntu Shiny profiles
        ubuntu_shiny_minimal)
            defaults="rocker/shiny:minimal:shiny"
            ;;
        ubuntu_shiny_analysis)
            defaults="rocker/shiny-verse:minimal:shiny"
            ;;
        # Ubuntu X11 profiles
        ubuntu_x11_minimal)
            defaults="rocker/r-ver:gui:minimal"
            ;;
        ubuntu_x11_analysis)
            defaults="rocker/tidyverse:gui:gui"
            ;;
        # Alpine Standard profiles
        alpine_standard_minimal)
            defaults="rhub/r-minimal:alpine:minimal"
            ;;
        alpine_standard_analysis)
            defaults="rhub/r-minimal:alpine:tidyverse"
            ;;
        # Alpine X11 profiles
        alpine_x11_minimal)
            defaults="rhub/r-minimal:alpine_gui:minimal"
            ;;
        alpine_x11_analysis)
            defaults="rhub/r-minimal:alpine_gui:tidyverse"
            ;;
        # Legacy profile names (for backward compatibility)
        minimal)
            defaults="rocker/r-ver:minimal:minimal"
            ;;
        rstudio)
            defaults="rocker/rstudio:minimal:minimal"
            ;;
        analysis)
            defaults="rocker/tidyverse:minimal:tidyverse"
            ;;
        modeling)
            defaults="rocker/r-ver:modeling:modeling"
            ;;
        bioinformatics)
            defaults="bioconductor/bioconductor_docker:bioinfo:bioinfo"
            ;;
        geospatial)
            defaults="rocker/geospatial:geospatial:geospatial"
            ;;
        publishing)
            defaults="rocker/verse:publishing:publishing"
            ;;
        shiny)
            defaults="rocker/shiny:minimal:shiny"
            ;;
        alpine_minimal)
            defaults="rhub/r-minimal:alpine:minimal"
            ;;
        alpine_analysis)
            defaults="rhub/r-minimal:alpine:tidyverse"
            ;;
        alpine_gui)
            defaults="rhub/r-minimal:alpine_gui:tidyverse"
            ;;
        hpc_alpine)
            defaults="rhub/r-minimal:alpine:minimal"
            ;;
        gui)
            defaults="rocker/rstudio:gui:gui"
            ;;
        gui_minimal)
            defaults="rocker/r-ver:gui:minimal"
            ;;
        gui_analysis)
            defaults="rocker/tidyverse:gui:tidyverse"
            ;;
        gui_rstudio)
            defaults="rocker/rstudio:gui:minimal"
            ;;
        *)
            log_error "Unknown profile: $profile"
            return 1
            ;;
    esac

    # Validate that libs and pkgs bundles exist in bundles.yaml
    IFS=':' read -r base libs pkgs <<< "$defaults"

    if ! validate_bundle_exists "library_bundles" "$libs"; then
        log_error "Profile $profile references non-existent library bundle: $libs"
        log_error "Check templates/bundles.yaml for available library bundles"
        return 1
    fi

    if ! validate_bundle_exists "package_bundles" "$pkgs"; then
        log_error "Profile $profile references non-existent package bundle: $pkgs"
        log_error "Check templates/bundles.yaml for available package bundles"
        return 1
    fi

    echo "$defaults"
    return 0
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

    # List of profiles with static Dockerfiles (new naming convention only)
    local profiles=(
        "ubuntu_standard_minimal"
        "ubuntu_standard_analysis"
        "ubuntu_standard_publishing"
        "ubuntu_shiny_minimal"
        "ubuntu_shiny_analysis"
        "ubuntu_x11_minimal"
        "ubuntu_x11_analysis"
        "alpine_standard_minimal"
        "alpine_standard_analysis"
        "alpine_x11_minimal"
        "alpine_x11_analysis"
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
            # Verify static template exists and is readable (Issue #13 fix)
            local template_file="${TEMPLATES_DIR}/Dockerfile.${profile}"
            if [[ -f "$template_file" ]]; then
                if [[ ! -r "$template_file" ]]; then
                    log_warn "Template file exists but is not readable: $template_file"
                    continue
                fi
                log_debug "✓ Matched static template: Dockerfile.${profile}"
                echo "Dockerfile.${profile}"
                return 0
            else
                log_warn "Profile '$profile' configured but template missing: $template_file"
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
#   2. If PROFILE_NAME set → check if Dockerfile.{PROFILE_NAME} exists
#   3. Check if resolved combination matches any static template → use static
#   4. Otherwise → generate custom
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

    # Normalize bundle names if user didn't explicitly provide them
    # This ensures default flags match static templates
    if [[ -z "${USER_PROVIDED_LIBS:-}" ]]; then
        # User didn't specify --libs, apply smart defaults based on base image
        case "$base" in
            *alpine*|*r-minimal*)
                libs="alpine_standard"
                ;;
            *bioconductor*)
                libs="bioinfo"
                ;;
            *geospatial*)
                libs="geospatial"
                ;;
            *tidyverse*|*rstudio*|*shiny*)
                libs="standard"  # these images have standard libs
                ;;
            *verse*)
                libs="standard"  # verse includes publishing tools
                ;;
            *)
                libs="standard"  # default to standard, not minimal
                ;;
        esac
        log_debug "Normalized libs bundle (user did not specify): $libs"
    fi

    if [[ -z "${USER_PROVIDED_PKGS:-}" ]]; then
        # User didn't specify --pkgs, apply smart defaults based on base image
        case "$base" in
            *tidyverse*|*shiny-verse*)
                pkgs="analysis"  # tidyverse implies analysis workflow
                ;;
            *verse*)
                pkgs="publishing"  # verse is for publishing
                ;;
            *alpine*|*r-minimal*)
                pkgs="minimal"  # alpine should stay minimal
                ;;
            *shiny*)
                pkgs="minimal"  # shiny base (not shiny-verse) is minimal
                ;;
            *)
                pkgs="minimal"  # conservative default
                ;;
        esac
        log_debug "Normalized pkgs bundle (user did not specify): $pkgs"
    fi

    # Decision logic:
    # 1. If using team image, use personal template
    if [[ "${USE_TEAM_IMAGE:-false}" == "true" ]]; then
        log_info "Using team Docker image template (Dockerfile.personal.team)"
        echo "static:Dockerfile.personal.team"
        return 0
    fi

    # 2. If PROFILE_NAME is set, check if static Dockerfile.{PROFILE_NAME} exists
    if [[ -n "${PROFILE_NAME:-}" ]]; then
        local profile_template="${TEMPLATES_DIR}/Dockerfile.${PROFILE_NAME}"
        if [[ -f "$profile_template" ]] && [[ -r "$profile_template" ]]; then
            log_info "Using static profile template: Dockerfile.${PROFILE_NAME}"
            echo "static:Dockerfile.${PROFILE_NAME}"
            return 0
        fi
    fi

    # 3. Check if resolved combination matches any static template (Issue #14 fix)
    local matched_template=$(match_static_template "$base" "$libs" "$pkgs")
    if [[ -n "$matched_template" ]]; then
        log_info "Using static template: $matched_template"
        log_debug "  Base: $base, Libs: $libs, Pkgs: $pkgs"
        echo "static:${matched_template}"
        return 0
    fi

    # 3. No match found → generate custom
    log_info "No static template matches - will generate custom Dockerfile"
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

    # Validate template exists and is readable (Issue #15 fix)
    if [[ ! -f "$template" ]]; then
        log_error "Template not found: $template"
        log_error "Check ZZCOLLAB installation and templates/ directory"
        return 1
    fi

    if [[ ! -r "$template" ]]; then
        log_error "Template file exists but is not readable: $template"
        log_error "Check file permissions: chmod 644 $template"
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

        # Also generate custom DESCRIPTION for bundle packages
        if ! generate_custom_description "$pkgs_list"; then
            log_warn "Failed to generate DESCRIPTION (non-fatal)"
        fi

        return 0
    else
        log_error "Failed to generate Dockerfile"
        return 1
    fi
}

##############################################################################
# FUNCTION: generate_custom_description
# PURPOSE:  Generate custom DESCRIPTION file with bundle packages
# USAGE:    generate_custom_description "publishing,tidyverse"
# ARGS:
#   $1 - pkgs_list: Comma-separated list of package bundles
# RETURNS:
#   0 - Success, DESCRIPTION created/updated
#   1 - Error (template not found, not writable, etc)
# GLOBALS READ:
#   TEAM_NAME, PROJECT_NAME (for project metadata)
# DESCRIPTION:
#   Creates or updates DESCRIPTION file with:
#   - Generic template structure (from DESCRIPTION template)
#   - Imports field populated from package bundles
#   - Preserves package name and author if DESCRIPTION already exists
#
#   This ensures DESCRIPTION Imports matches Dockerfile packages automatically.
##############################################################################
generate_custom_description() {
    local pkgs_list="$1"
    local desc_file="DESCRIPTION"
    local generic_template="${TEMPLATES_DIR}/DESCRIPTION"

    # If DESCRIPTION already exists, only update Imports field
    if [[ -f "$desc_file" ]]; then
        log_debug "Updating existing DESCRIPTION with bundle packages"

        # Extract Imports field from bundles
        local imports=$(extract_description_imports "$pkgs_list")

        # Use awk to replace Imports field while preserving other fields
        awk -v imports="$imports" '
        BEGIN { in_imports = 0 }

        # Skip old Imports field
        /^Imports:/ {
            in_imports = 1
            next
        }

        # End of Imports field (line starts with capital letter)
        in_imports && /^[A-Z]/ {
            in_imports = 0
            # Output new Imports before this field
            print imports ""
            print $0
            next
        }

        # Skip lines within old Imports
        in_imports { next }

        # Print everything else
        { print }

        # Handle EOF while still in imports
        END {
            if (in_imports) {
                print imports
            }
        }
        ' "$desc_file" > "${desc_file}.tmp"

        if [[ $? -eq 0 ]]; then
            mv "${desc_file}.tmp" "$desc_file"
            log_success "✓ Updated DESCRIPTION Imports from bundles"
            return 0
        else
            rm -f "${desc_file}.tmp"
            log_error "Failed to update DESCRIPTION Imports"
            return 1
        fi
    fi

    # DESCRIPTION doesn't exist - create from template
    if [[ ! -f "$generic_template" ]]; then
        log_warn "DESCRIPTION template not found - skipping DESCRIPTION generation"
        return 1
    fi

    log_debug "Creating new DESCRIPTION from template"

    # Extract Imports from bundles
    local imports=$(extract_description_imports "$pkgs_list")

    # Get metadata
    local project_name="${PROJECT_NAME:-project}"
    local author_name="${AUTHOR_NAME:-Researcher}"
    local author_email="${AUTHOR_EMAIL:-researcher@example.com}"

    # Substitute template variables and add Imports
    sed -e "s|\${PKG_NAME}|${project_name}|g" \
        -e "s|\${AUTHOR_NAME}|${author_name}|g" \
        -e "s|\${AUTHOR_EMAIL}|${author_email}|g" \
        "$generic_template" | \
    awk -v imports="$imports" '
    /^Imports:/ {
        print imports
        in_imports = 1
        next
    }
    in_imports && /^[A-Z]/ {
        in_imports = 0
        print $0
        next
    }
    in_imports { next }
    { print }
    ' > "$desc_file"

    if [[ $? -eq 0 ]]; then
        log_success "✓ Generated custom DESCRIPTION with bundle packages"
        return 0
    else
        rm -f "$desc_file"
        log_error "Failed to generate DESCRIPTION"
        return 1
    fi
}

#=============================================================================
# BUNDLE DEPENDENCY EXTRACTION
#=============================================================================

##############################################################################
# FUNCTION: extract_system_deps_build
# PURPOSE:  Extract build-time system dependencies from bundles.yaml dynamically
# USAGE:    extract_system_deps_build "geospatial,modeling"
# ARGS:
#   $1 - libs_list: Comma-separated list of library bundles
# RETURNS:
#   0 - Success, outputs apt-get install command fragment
# DESCRIPTION:
#   Dynamically queries bundles.yaml for system dependencies.
#   Uses yq to parse YAML (single source of truth).
#   Falls back to case statement if yq unavailable.
##############################################################################
extract_system_deps_build() {
    local libs_list="$1"
    local bundles_file="${TEMPLATES_DIR}/bundles.yaml"

    # Split comma-separated list
    IFS=',' read -ra LIBS <<< "$libs_list"

    local deps=()

    # Check if yq is available for dynamic parsing
    if command -v yq &>/dev/null && [[ -f "$bundles_file" ]]; then
        for lib in "${LIBS[@]}"; do
            lib=$(echo "$lib" | xargs)  # Trim whitespace
            # Query bundles.yaml for deps array
            local lib_deps=$(yq eval ".library_bundles.${lib}.deps[]?" "$bundles_file" 2>/dev/null)
            if [[ -n "$lib_deps" ]]; then
                while IFS= read -r dep; do
                    [[ -n "$dep" ]] && deps+=("$dep")
                done <<< "$lib_deps"
            fi
        done
    else
        # Fallback: use hardcoded case statement if yq unavailable
        log_warn "yq not available - using hardcoded dependencies (not dynamic)"
        for lib in "${LIBS[@]}"; do
            lib=$(echo "$lib" | xargs)
            case "$lib" in
                geospatial)
                    deps+=("gdal-bin" "proj-bin" "libgeos-dev" "libproj-dev" "libgdal-dev" "libudunits2-dev" "netcdf-bin")
                    ;;
                modeling)
                    deps+=("libgsl-dev" "libblas-dev" "liblapack-dev" "libopenblas-dev" "gfortran")
                    ;;
                bioinfo)
                    deps+=("zlib1g-dev" "libbz2-dev" "liblzma-dev")
                    ;;
                gui)
                    deps+=("xorg" "x11-apps" "xauth" "libx11-dev" "libxt-dev" "libcairo2-dev" "libgl1-mesa-dev" "libglu1-mesa-dev")
                    ;;
                terminals)
                    deps+=("xfce4-terminal" "terminator" "xterm" "fonts-jetbrains-mono" "fonts-firacode" "fonts-hack")
                    ;;
            esac
        done
    fi

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
# PURPOSE:  Extract runtime system libraries (NOT -dev versions)
# ARGS:     $1 - libs_list: Comma-separated list of library bundles
# RETURNS:  Runtime libraries for final stage
# NOTE:     Runtime deps are hardcoded (bundles.yaml only has build deps)
#           This derives runtime packages from build deps pattern:
#           libgdal-dev → libgdal30, libxml2-dev → libxml2, etc.
##############################################################################
extract_system_deps_runtime() {
    local libs_list="$1"

    IFS=',' read -ra LIBS <<< "$libs_list"

    local deps=()
    for lib in "${LIBS[@]}"; do
        lib=$(echo "$lib" | xargs)
        # Runtime deps are hardcoded based on common patterns
        # Future: Could extend bundles.yaml to specify runtime_deps
        case "$lib" in
            geospatial)
                deps+=("libgdal30" "libproj25" "libgeos-c1v5" "libudunits2-0")
                ;;
            modeling)
                deps+=("libgsl27" "libopenblas0")
                ;;
            # Most libs have -dev versions handled by rocker base images
            # No explicit runtime deps needed for: bioinfo, gui, terminals, publishing
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
# PURPOSE:  Extract R packages from bundles.yaml dynamically
# ARGS:     $1 - pkgs_list: Comma-separated list of package bundles
# RETURNS:  Quoted, comma-separated R package list for install.packages()
# DESCRIPTION:
#   Dynamically queries bundles.yaml for packages in each bundle.
#   Uses yq to parse YAML (single source of truth).
#   Falls back to hardcoded case statements if yq unavailable.
##############################################################################
extract_r_packages() {
    local pkgs_list="$1"
    local bundles_file="${TEMPLATES_DIR}/bundles.yaml"

    IFS=',' read -ra PKGS <<< "$pkgs_list"

    local packages=()

    # Check if yq is available for dynamic parsing
    if command -v yq &>/dev/null && [[ -f "$bundles_file" ]]; then
        for pkg in "${PKGS[@]}"; do
            pkg=$(echo "$pkg" | xargs)  # Trim whitespace
            # Query bundles.yaml for packages array
            local pkg_list=$(yq eval ".package_bundles.${pkg}.packages[]?" "$bundles_file" 2>/dev/null)
            if [[ -n "$pkg_list" ]]; then
                while IFS= read -r package; do
                    [[ -n "$package" ]] && packages+=("'$package'")
                done <<< "$pkg_list"
            fi
        done
    else
        # Fallback: use hardcoded case statement if yq unavailable
        log_warn "yq not available - using hardcoded packages (not dynamic)"
        for pkg in "${PKGS[@]}"; do
            pkg=$(echo "$pkg" | xargs)
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
    fi

    # Join with commas, deduplicating packages
    # Use printf with dedup: sort | uniq
    local result=$(printf '%s\n' "${packages[@]}" | sort -u | paste -sd, -)
    echo "$result"
}

##############################################################################
# FUNCTION: extract_description_imports
# PURPOSE:  Extract R packages for DESCRIPTION Imports field
# ARGS:     $1 - pkgs_list: Comma-separated list of package bundles
# RETURNS:  DESCRIPTION Imports field format (indented, newline-separated)
# DESCRIPTION:
#   Extracts packages from bundles.yaml and formats for DESCRIPTION file.
#   Output includes renv (required), then packages from bundles, 4-space indented.
#   Format:
#     Imports:
#         renv,
#         package1,
#         package2
##############################################################################
extract_description_imports() {
    local pkgs_list="$1"
    local bundles_file="${TEMPLATES_DIR}/bundles.yaml"

    IFS=',' read -ra PKGS <<< "$pkgs_list"

    local packages=("renv")  # Always include renv

    # Check if yq is available for dynamic parsing
    if command -v yq &>/dev/null && [[ -f "$bundles_file" ]]; then
        for pkg in "${PKGS[@]}"; do
            pkg=$(echo "$pkg" | xargs)
            local pkg_list=$(yq eval ".package_bundles.${pkg}.packages[]?" "$bundles_file" 2>/dev/null)
            if [[ -n "$pkg_list" ]]; then
                while IFS= read -r package; do
                    [[ -n "$package" && "$package" != "renv" ]] && packages+=("$package")
                done <<< "$pkg_list"
            fi
        done
    else
        # Fallback: hardcoded packages
        for pkg in "${PKGS[@]}"; do
            pkg=$(echo "$pkg" | xargs)
            case "$pkg" in
                minimal)
                    packages+=("devtools" "usethis" "testthat" "roxygen2")
                    ;;
                analysis)
                    packages+=("devtools" "tidyverse" "here" "janitor" "scales" "patchwork" "gt" "DT")
                    ;;
                modeling)
                    packages+=("tidyverse" "tidymodels" "xgboost" "randomForest" "glmnet" "caret")
                    ;;
                geospatial)
                    packages+=("sf" "terra" "leaflet" "mapview" "tmap" "tidyverse")
                    ;;
                publishing)
                    packages+=("devtools" "tidyverse" "quarto" "bookdown" "blogdown" "rmarkdown" "knitr")
                    ;;
            esac
        done
    fi

    # Deduplicate and sort
    local sorted_packages=($(printf '%s\n' "${packages[@]}" | sort -u))

    # Format as DESCRIPTION Imports with 4-space indentation
    local result="Imports:"
    for i in "${!sorted_packages[@]}"; do
        result+=$'\n    '"${sorted_packages[$i]}"
        # Add comma if not last item
        if [[ $i -lt $((${#sorted_packages[@]} - 1)) ]]; then
            result+=","
        fi
    done

    echo "$result"
}
