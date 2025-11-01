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

#-----------------------------------------------------------------------------
# FUNCTION: expand_profile_name
# PURPOSE:  Validate profile name corresponds to existing Dockerfile template
# DESCRIPTION:
#   Validates that the provided profile name has a corresponding Dockerfile
#   template in the templates directory. If the profile is invalid, displays
#   comprehensive help message showing all available profiles organized by
#   category (Ubuntu, Alpine, Shiny, X11, Legacy). Empty profile names are
#   allowed (returns success) to support optional profile specification.
#   On validation failure, exits with error code 1.
# ARGS:
#   $1 - profile_name: Profile identifier (e.g., "ubuntu_standard_minimal")
# RETURNS:
#   0 - Profile is valid (Dockerfile exists) or empty (optional)
#   1 - Profile is invalid (no corresponding Dockerfile), exits after error
# OUTPUTS:
#   Success: "✓ Using profile: <profile_name>" via log_info
#   Error: Comprehensive multi-category profile list via log_error
# FILES CHECKED:
#   ${TEMPLATES_DIR}/Dockerfile.${profile_name} - Profile template existence
# PROFILE CATEGORIES DISPLAYED ON ERROR:
#   📦 UBUNTU STANDARD: CLI + optional RStudio (3 profiles)
#     - ubuntu_standard_minimal (~800MB)
#     - ubuntu_standard_analysis (~1.5GB)
#     - ubuntu_standard_publishing (~3GB)
#   🌐 UBUNTU SHINY: Web applications with Shiny Server (2 profiles)
#     - ubuntu_shiny_minimal (~1.8GB)
#     - ubuntu_shiny_analysis (~3.5GB)
#   🖥️  UBUNTU X11: GUI with X11 forwarding (2 profiles)
#     - ubuntu_x11_minimal (~1.5GB)
#     - ubuntu_x11_analysis (~2.5GB)
#   ⛰️  ALPINE STANDARD: Lightweight for CI/CD (2 profiles)
#     - alpine_standard_minimal (~200MB)
#     - alpine_standard_analysis (~400MB)
#   🗻 ALPINE X11: Lightweight with graphics (2 profiles)
#     - alpine_x11_minimal (~300MB)
#     - alpine_x11_analysis (~500MB)
#   🔬 LEGACY: Specialized domains (4 profiles)
#     - bioinformatics, geospatial, modeling, hpc_alpine
# GLOBALS READ:
#   TEMPLATES_DIR - Path to Dockerfile templates
# EXIT BEHAVIOR:
#   Exits immediately with code 1 on validation failure (not just return)
#   This prevents continuing with invalid configuration
# VALIDATION LOGIC:
#   1. Empty profile → return 0 (optional parameter)
#   2. Construct path: ${TEMPLATES_DIR}/Dockerfile.${profile_name}
#   3. Check file existence with [[ -f ]]
#   4. If missing → display help and exit 1
#   5. If exists → log confirmation and return 0
# USE CASES:
#   - CLI flag validation: zzcollab --profile-name <name>
#   - Interactive profile selection
#   - Configuration file profile validation
#   - Error recovery with helpful suggestions
# EXAMPLE CALLS:
#   expand_profile_name "ubuntu_standard_minimal"  # Valid → confirms
#   expand_profile_name ""                         # Empty → returns 0
#   expand_profile_name "invalid_profile"          # Invalid → exits 1
#-----------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------
# FUNCTION: validate_profile_combination
# PURPOSE:  Validate compatibility between base image, libs, and package bundles
# DESCRIPTION:
#   Performs comprehensive validation of the three-layer Docker configuration:
#   base image (OS + R version), system library bundle (apt/apk packages), and
#   R package bundle. Checks for architectural mismatches (e.g., Alpine base
#   with Ubuntu libs), missing dependencies (e.g., geospatial packages without
#   GDAL libs), and suboptimal configurations (e.g., verse without publishing
#   tools). Returns validation errors with actionable fix suggestions.
# ARGS:
#   $1 - base_image: Docker base image (default: $BASE_IMAGE)
#   $2 - libs_bundle: System library bundle (default: $LIBS_BUNDLE)
#   $3 - pkgs_bundle: R package bundle (default: $PKGS_BUNDLE)
# RETURNS:
#   0 - Configuration is valid or empty (no conflicts detected)
#   1 - Configuration has errors (incompatible combination)
# OUTPUTS:
#   Errors: Multi-line error message with "🚫 INCOMPATIBLE COMBINATION DETECTED"
#   Warnings: Non-fatal compatibility warnings (⚠️)
#   Suggestions: Calls suggest_compatible_combination() for fixes
# VALIDATION RULES:
#   ALPINE CONSTRAINTS:
#     - Alpine base REQUIRES --libs alpine (uses apk not apt-get)
#     - Alpine base CANNOT use --libs none (needs build dependencies)
#   BIOCONDUCTOR CONSTRAINTS:
#     - Bioconductor base REQUIRES --libs bioinfo
#     - bioinfo packages REQUIRE --libs bioinfo
#   GEOSPATIAL CONSTRAINTS:
#     - Geospatial base REQUIRES --libs geospatial or --libs minimal
#     - Geospatial base CANNOT use --libs none
#     - geospatial packages REQUIRE --libs geospatial (need GDAL/PROJ)
#   VERSE WARNINGS (non-fatal):
#     - verse base with --libs none → suggest --libs publishing
# ERROR MESSAGE FORMAT:
#   🚫 INCOMPATIBLE COMBINATION DETECTED:
#
#   ❌ <Error description>
#      Current: <user's configuration>
#      Reason: <technical explanation>
#
#   💡 Suggested fix:
#   <output from suggest_compatible_combination()>
# GLOBALS READ:
#   BASE_IMAGE, LIBS_BUNDLE, PKGS_BUNDLE - Fallback values if args empty
# SKIP LOGIC:
#   Returns 0 immediately if all three parameters are empty (nothing to validate)
# ERROR ACCUMULATION:
#   Collects all errors before displaying (shows complete picture)
#   Uses arrays: errors=(), warnings=()
# USE CASES:
#   - Pre-flight validation before Docker build
#   - Configuration file validation
#   - Interactive setup with immediate feedback
#   - CI/CD pipeline validation
# EXAMPLE VALIDATION FAILURES:
#   alpine base + --libs minimal → Error (requires --libs alpine)
#   --pkgs geospatial + --libs minimal → Error (need GDAL system libs)
#   bioconductor base + --libs minimal → Error (requires --libs bioinfo)
# EXAMPLE VALID COMBINATIONS:
#   alpine base + --libs alpine + --pkgs minimal → Valid
#   rocker/r-ver + --libs minimal + --pkgs tidyverse → Valid
#   rocker/geospatial + --libs geospatial + --pkgs geospatial → Valid
# INTEGRATION:
#   Called by main workflow after flag parsing, before Dockerfile generation
#   Prevents invalid Docker builds (fail-fast principle)
#-----------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------
# FUNCTION: suggest_compatible_combination
# PURPOSE:  Generate actionable fix suggestions for incompatible configurations
# DESCRIPTION:
#   Analyzes the base image and provides concrete command-line examples to fix
#   incompatible base/libs/pkgs combinations. Returns two suggestions per case:
#   (1) explicit flags for fine-grained control, and (2) profile shortcut for
#   convenience. Suggestions match the constraints enforced by
#   validate_profile_combination() and reflect architectural requirements.
# ARGS:
#   $1 - base_image: Docker base image causing incompatibility
#   $2 - libs_bundle: Current (invalid) library bundle
#   $3 - pkgs_bundle: Current (invalid) package bundle
# RETURNS:
#   0 - Always succeeds (pure output function)
# OUTPUTS:
#   Two command-line suggestions to stdout:
#     Line 1: Manual flags (e.g., "zzcollab -b IMAGE --libs BUNDLE --pkgs BUNDLE")
#     Line 2: "or"
#     Line 3: Profile shortcut (e.g., "zzcollab --profile-name PROFILE")
# SUGGESTION LOGIC BY BASE IMAGE:
#   ALPINE (*alpine*):
#     Manual: zzcollab -b ${base_image} --libs alpine --pkgs minimal
#     Profile: zzcollab --profile-name alpine_minimal
#     Rationale: Alpine requires apk package manager (--libs alpine)
#   BIOCONDUCTOR (*bioconductor*):
#     Manual: zzcollab -b ${base_image} --libs bioinfo --pkgs bioinfo
#     Profile: zzcollab --profile-name bioinformatics
#     Rationale: Bioconductor packages need specialized dependencies
#   GEOSPATIAL (*geospatial*):
#     Manual: zzcollab -b ${base_image} --libs geospatial --pkgs geospatial
#     Profile: zzcollab --profile-name geospatial
#     Rationale: Spatial packages require GDAL/PROJ/GEOS system libraries
#   VERSE (*verse*):
#     Manual: zzcollab -b ${base_image} --libs publishing --pkgs publishing
#     Profile: zzcollab --profile-name publishing
#     Rationale: verse includes LaTeX, best used with publishing tools
#   DEFAULT (rocker/r-ver, etc.):
#     Manual: zzcollab -b rocker/r-ver --libs minimal --pkgs minimal
#     Profile: zzcollab --profile-name minimal
#     Rationale: Generic R environment with minimal dependencies
# INTEGRATION:
#   Called by validate_profile_combination() after error accumulation
#   Output appears under "💡 Suggested fix:" section
# USE CASES:
#   - Error recovery guidance for users
#   - Learning tool showing valid configurations
#   - Quick reference for profile capabilities
#   - Documentation for CI/CD setup
# EXAMPLE OUTPUT (alpine):
#   zzcollab -b rocker/r-ver:alpine3.19 --libs alpine --pkgs minimal
#   or
#   zzcollab --profile-name alpine_minimal
# NOTE:
#   Suggestions are always valid (match validation rules)
#   No argument validation needed (called from validated context)
#-----------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------
# FUNCTION: apply_smart_defaults
# PURPOSE:  Intelligently set libs/pkgs bundles based on base image heuristics
# DESCRIPTION:
#   Reduces configuration burden by auto-detecting appropriate library and
#   package bundles from the base image name. Only applies defaults if user
#   has not explicitly specified bundles via CLI flags. Uses pattern matching
#   on base image names to infer requirements (e.g., alpine → alpine libs,
#   bioconductor → bioinfo libs). Ensures valid combinations that will pass
#   validate_profile_combination() checks. Logs informational messages when
#   defaults are applied for transparency.
# ARGS:
#   $1 - base_image: Docker base image (default: $BASE_IMAGE)
# RETURNS:
#   0 - Always succeeds
# SIDE EFFECTS:
#   Sets/exports LIBS_BUNDLE if empty (based on base image detection)
#   Sets/exports PKGS_BUNDLE if empty (based on base image detection)
#   Logs informational messages via log_info() when defaults applied
# LIBS_BUNDLE AUTO-DETECTION (only if LIBS_BUNDLE is empty):
#   *alpine*       → alpine      (apk package manager)
#   *bioconductor* → bioinfo     (Bioconductor system dependencies)
#   *geospatial*   → geospatial  (GDAL, PROJ, GEOS libraries)
#   *tidyverse*    → minimal     (tidyverse already includes packages)
#   *verse*        → publishing  (LaTeX, pandoc, publishing tools)
#   (other)        → minimal     (safe default)
# PKGS_BUNDLE AUTO-DETECTION (only if PKGS_BUNDLE is empty):
#   *alpine*       → minimal     (lightweight package set)
#   *bioconductor* → bioinfo     (Bioconductor packages)
#   *geospatial*   → geospatial  (sf, terra, raster)
#   *tidyverse*    → tidyverse   (dplyr, ggplot2, tidyr, etc.)
#   *verse*        → publishing  (knitr, rmarkdown, bookdown)
#   (other)        → minimal     (safe default)
# SMART DEFAULT RATIONALE:
#   1. ARCHITECTURAL CONSTRAINTS: Alpine requires alpine libs (apk vs apt-get)
#   2. DEPENDENCY REQUIREMENTS: Geospatial packages need GDAL system libraries
#   3. OPTIMIZATION: tidyverse base already has packages, no need to reinstall
#   4. BEST PRACTICES: verse base pairs naturally with publishing workflow
#   5. SAFETY: Unknown bases default to minimal (conservative choice)
# GLOBALS READ:
#   LIBS_BUNDLE, PKGS_BUNDLE - Check if already set by user
#   BASE_IMAGE - Fallback if $1 not provided
# GLOBALS MODIFIED:
#   LIBS_BUNDLE - Set if empty after detection
#   PKGS_BUNDLE - Set if empty after detection
# USER OVERRIDE BEHAVIOR:
#   If user specified --libs or --pkgs flags, those values are preserved
#   Function only fills in missing values (respects explicit choices)
# LOGGING:
#   "ℹ️  Auto-detected: --libs <bundle> (from base image)" when LIBS set
#   "ℹ️  Auto-detected: --pkgs <bundle> (from base image)" when PKGS set
#   "ℹ️  Auto-detected: --pkgs <bundle> (for Alpine)" for Alpine special case
# USE CASES:
#   - Solo developers using minimal flags: zzcollab -b rocker/verse
#   - CI/CD with simplified configuration
#   - Profile implementation (profiles set base, auto-detect libs/pkgs)
#   - Reducing cognitive load for new users
# EXAMPLE BEHAVIOR:
#   zzcollab -b rocker/verse          → auto-sets --libs publishing, --pkgs publishing
#   zzcollab -b rocker/geospatial     → auto-sets --libs geospatial, --pkgs geospatial
#   zzcollab -b rocker/verse --libs minimal → respects user's --libs minimal
# INTEGRATION:
#   Called after flag parsing, before validation
#   Works in conjunction with validate_profile_combination()
#   Ensures auto-detected values produce valid configurations
#-----------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------
# FUNCTION: generate_r_package_install_commands
# PURPOSE:  Generate R package installation commands from bundle configuration
# DESCRIPTION:
#   Translates high-level package bundle names (e.g., "tidyverse", "bioinfo")
#   into concrete R installation commands for Dockerfile RUN instructions.
#   Reads bundle definitions from bundles.yaml, extracts package lists,
#   determines appropriate installation method (CRAN vs Bioconductor,
#   install2.r vs install.packages), and constructs optimized commands using
#   Posit Package Manager for pre-compiled binaries. Handles special cases
#   for Bioconductor packages requiring BiocManager.
# ARGS:
#   $1 - pkgs_bundle: Package bundle name (default: $PKGS_BUNDLE)
# RETURNS:
#   0 - Success (command generated or bundle empty)
#   1 - Error (bundles.yaml not found)
# SIDE EFFECTS:
#   Sets and exports R_PACKAGES_INSTALL_CMD environment variable
#   Contains the complete installation command for Dockerfile substitution
# OUTPUTS:
#   Warning: "⚠️  Unknown package bundle: <bundle>, using minimal" via log_warn
#   Error: "❌ Bundles file not found: <path>" via log_error
# FILES READ:
#   ${BUNDLES_FILE} - YAML configuration (templates/bundles.yaml)
#     Structure: .package_bundles.<bundle>.packages = ["pkg1", "pkg2", ...]
#                .package_bundles.<bundle>.bioconductor = true/false
# INSTALLATION METHOD SELECTION:
#   ROCKER IMAGES (BASE_IMAGE =~ ^rocker/):
#     - Use install2.r (pre-installed in rocker images)
#     - Advantages: Pre-compiled binaries from Posit PPM (10-20x faster)
#     - Format: install2.r --error --skipinstalled pkg1 pkg2 pkg3
#   NON-ROCKER IMAGES:
#     - Use R -e "install.packages(...)"
#     - Explicitly specify Posit PPM repo for binaries
#     - Format: R -e "install.packages(c('pkg1', 'pkg2'), repos = 'https://...')"
# BIOCONDUCTOR HANDLING:
#   Detection: Checks .package_bundles.<bundle>.bioconductor field in YAML
#   Special processing:
#     1. Install BiocManager first (gateway to Bioconductor)
#     2. Remove BiocManager from package list (avoid duplicate install)
#     3. Use BiocManager::install() for Bioconductor packages
#   Example command (rocker):
#     install2.r --error --skipinstalled renv devtools BiocManager && \
#     R -e "BiocManager::install(c('GenomicRanges', 'DESeq2'))" && \
#     rm -rf /tmp/downloaded_packages
# CRAN PACKAGE HANDLING:
#   ROCKER: install2.r --error --skipinstalled pkg1 pkg2 pkg3 && rm -rf /tmp/downloaded_packages
#   NON-ROCKER: R -e "install.packages(c('pkg1', 'pkg2'), repos = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest')"
# PACKAGE LIST EXTRACTION:
#   Uses yq to parse YAML: yq eval ".package_bundles.<bundle>.packages | join(\"', '\")"
#   Result: Single quoted, comma-separated string for R c() vector
#   Example: "'dplyr', 'ggplot2', 'tidyr'"
# FALLBACK BEHAVIOR:
#   Empty bundle → Returns comment: "# No package bundle specified"
#   Unknown bundle → Falls back to "minimal" bundle with warning
#   Missing bundles.yaml → Returns error
# ENVIRONMENT VARIABLE:
#   R_PACKAGES_INSTALL_CMD - Complete command string for Dockerfile substitution
#   Exported for use in template rendering (e.g., via envsubst)
#   May contain multi-line commands with && chains
# POSIT PACKAGE MANAGER:
#   URL: https://packagemanager.posit.co/cran/__linux__/jammy/latest
#   Benefits: Pre-compiled binaries (avoid compilation), faster builds
#   Platform: __linux__/jammy (Ubuntu 22.04 binaries)
# SHELLCHECK DISABLES:
#   SC2089, SC2090: Intentional - command stored as string for template substitution
# GLOBALS READ:
#   PKGS_BUNDLE - Fallback if $1 not provided
#   BASE_IMAGE - Determines install2.r availability
#   BUNDLES_FILE - Path to bundles.yaml
# USE CASES:
#   - Dockerfile generation (primary use case)
#   - Preview package installation commands
#   - Validation of bundle configurations
#   - CI/CD pipeline optimization
# EXAMPLE OUTPUT (tidyverse, rocker):
#   R_PACKAGES_INSTALL_CMD="install2.r --error --skipinstalled dplyr ggplot2 tidyr && rm -rf /tmp/downloaded_packages"
# EXAMPLE OUTPUT (bioinfo, non-rocker):
#   R_PACKAGES_INSTALL_CMD="R -e \"install.packages(c('renv', 'devtools', 'BiocManager'), repos = 'https://...')\" && R -e \"BiocManager::install(c('GenomicRanges', 'DESeq2'))\""
#-----------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------
# FUNCTION: generate_system_deps_install_commands
# PURPOSE:  Generate system dependency installation commands from bundle config
# DESCRIPTION:
#   Translates high-level system library bundle names (e.g., "minimal",
#   "geospatial", "alpine") into concrete package manager commands for
#   Dockerfile RUN instructions. Reads bundle definitions from bundles.yaml,
#   extracts dependency lists, determines appropriate package manager
#   (apt-get for Debian/Ubuntu, apk for Alpine), and constructs optimized
#   commands with cache cleanup. Critical for R package compilation that
#   requires system libraries (e.g., sf needs GDAL, curl needs libcurl).
# ARGS:
#   $1 - libs_bundle: Library bundle name (default: $LIBS_BUNDLE)
# RETURNS:
#   0 - Success (command generated or bundle empty)
#   1 - Error (bundles.yaml not found)
# SIDE EFFECTS:
#   Sets and exports SYSTEM_DEPS_INSTALL_CMD environment variable
#   Contains complete installation command for Dockerfile substitution
# OUTPUTS:
#   Error: "❌ Bundles file not found: <path>" via log_error
# FILES READ:
#   ${BUNDLES_FILE} - YAML configuration (templates/bundles.yaml)
#     Structure: .library_bundles.<bundle>.deps = ["pkg1", "pkg2", ...]
#                .library_bundles.<bundle>.package_manager = "apt-get" | "apk"
# PACKAGE MANAGER DETECTION:
#   APK (Alpine Linux):
#     - Indicator: package_manager field = "apk" in YAML
#     - Command: apk add --no-cache <packages>
#     - No update needed (--no-cache fetches latest)
#     - Example: apk add --no-cache build-base curl-dev libxml2-dev
#   APT-GET (Debian/Ubuntu):
#     - Indicator: package_manager field = "apt-get" or unspecified (default)
#     - Command: apt-get update && apt-get install -y <packages> && rm -rf /var/lib/apt/lists/*
#     - Update + install + cleanup pattern (best practice for Docker layer size)
#     - Example: apt-get update && apt-get install -y libgdal-dev libproj-dev && rm -rf /var/lib/apt/lists/*
# DEPENDENCY LIST EXTRACTION:
#   Uses yq to parse YAML: yq eval ".library_bundles.<bundle>.deps[]"
#   Pipes through tr to convert newlines to spaces
#   Result: Space-separated package list for command line
#   Example: "libgdal-dev libproj-dev libgeos-dev"
# BUNDLE EXAMPLES:
#   minimal:
#     - Ubuntu: libcurl4-openssl-dev, libssl-dev, libxml2-dev, zlib1g-dev
#     - Required for basic R package compilation (httr, xml2, etc.)
#   alpine:
#     - Alpine: build-base, curl-dev, openssl-dev, libxml2-dev
#     - Equivalent to minimal but for Alpine Linux (apk packages)
#   geospatial:
#     - Ubuntu: libgdal-dev, libproj-dev, libgeos-dev, libudunits2-dev
#     - Required for sf, terra, raster packages
#   bioinfo:
#     - Bioconductor system dependencies
#   publishing:
#     - LaTeX, pandoc, Quarto publishing tools
# FALLBACK BEHAVIOR:
#   Empty bundle → Returns comment: "# No library bundle specified"
#   No deps in bundle → Returns comment: "# No additional system dependencies for bundle: <bundle>"
#   Missing bundles.yaml → Returns error
# ENVIRONMENT VARIABLE:
#   SYSTEM_DEPS_INSTALL_CMD - Complete command string for Dockerfile substitution
#   Exported for use in template rendering
#   Single-line command (multi-command chained with &&)
# DOCKER BEST PRACTICES:
#   APT-GET PATTERN:
#     1. apt-get update (refresh package lists)
#     2. apt-get install -y (install without prompts)
#     3. rm -rf /var/lib/apt/lists/* (clean cache, reduce layer size)
#     All in one RUN command to minimize layers
#   APK PATTERN:
#     - apk add --no-cache (no persistent cache, smaller images)
# GLOBALS READ:
#   LIBS_BUNDLE - Fallback if $1 not provided
#   BUNDLES_FILE - Path to bundles.yaml
# USE CASES:
#   - Dockerfile generation (primary use case)
#   - Preview system dependency requirements
#   - Validation of bundle configurations
#   - Understanding what system libraries a bundle provides
# EXAMPLE OUTPUT (geospatial, apt-get):
#   SYSTEM_DEPS_INSTALL_CMD="apt-get update && apt-get install -y libgdal-dev libproj-dev libgeos-dev libudunits2-dev && rm -rf /var/lib/apt/lists/*"
# EXAMPLE OUTPUT (alpine, apk):
#   SYSTEM_DEPS_INSTALL_CMD="apk add --no-cache build-base curl-dev openssl-dev libxml2-dev"
# EXAMPLE OUTPUT (empty bundle):
#   SYSTEM_DEPS_INSTALL_CMD="# No library bundle specified"
# WHY SYSTEM DEPENDENCIES MATTER:
#   R packages with compiled code often require system libraries:
#   - sf → GDAL, PROJ, GEOS (geospatial operations)
#   - curl → libcurl (HTTP requests)
#   - xml2 → libxml2 (XML parsing)
#   - openssl → libssl (encryption)
#   Without system libs, R package installation fails during compilation
#-----------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------
# FUNCTION: validate_team_member_flags
# PURPOSE:  Enforce team collaboration constraints on CLI flag usage
# DESCRIPTION:
#   Implements the two-layer Docker architecture security model by preventing
#   team members from modifying immutable team image components. Team members
#   join existing projects and inherit the team's base image and system
#   libraries (set by team lead). This function blocks flags that would
#   circumvent this model, ensuring team environment consistency while still
#   allowing personal R package additions. Provides clear error messages
#   explaining the architectural rationale and suggesting proper workflows.
# ARGS:
#   $1 - is_team_member: "true" if user is joining existing project (string)
# RETURNS:
#   0 - Validation passed (not a team member OR no restricted flags used)
#   Exits 1 - Team member attempted to use restricted flag (immediate exit)
# RESTRICTED FLAGS FOR TEAM MEMBERS:
#   -b/--base-image:
#     - Reason: Team image IS the base (FROM team/project_core:tag)
#     - Error: "Team members cannot use -b/--base-image flag"
#     - Fix: Ask team lead to create new profile
#   --libs:
#     - Reason: System libraries are immutable in team image
#     - Error: "Team members cannot use --libs flag"
#     - Fix: Ask team lead to rebuild with: zzcollab -t TEAM -p PROJECT --libs BUNDLE
#   --profile-name/-r:
#     - Reason: Profiles set base-image and libs (both restricted)
#     - Error: "Team members cannot use --profile-name flag"
#     - Fix: Use --pkgs for R package additions
# ALLOWED FLAGS FOR TEAM MEMBERS:
#   --pkgs: Team members CAN add R packages (personal layer)
#   -d/--dotfiles: Personal development environment customization
#   -u/--use-team-image: Required for team members (how they join)
#   Git flags: Standard version control operations
# TWO-LAYER ARCHITECTURE:
#   TEAM LAYER (immutable for members):
#     - Docker base image (rocker/r-ver, rocker/verse, etc.)
#     - System libraries (GDAL, PROJ, LaTeX, etc.)
#     - Set once by team lead, inherited by all members
#   PERSONAL LAYER (customizable):
#     - R packages via renv::install()
#     - Personal dotfiles and environment
#     - Individual R package additions via --pkgs
# FLAG DETECTION:
#   Uses sentinel variables set during flag parsing:
#     - USER_PROVIDED_BASE_IMAGE="true" when -b/--base-image used
#     - USER_PROVIDED_LIBS="true" when --libs used
#     - USER_PROVIDED_PROFILE="true" when --profile-name/-r used
# ERROR MESSAGE FORMAT:
#   ❌ Error: Team members cannot use <FLAG> flag
#
#      The team image IS your base:
#      FROM team/project_core:tag
#
#      To use different base, ask team lead to create new profile.
# EXIT BEHAVIOR:
#   Exits immediately with code 1 on validation failure (not just return)
#   Prevents Docker builds with invalid configurations
#   User must either remove flag or contact team lead
# SKIP LOGIC:
#   Returns 0 immediately if is_team_member != "true"
#   No validation needed for team leads or solo developers
# INTEGRATION:
#   Called after flag parsing, before Docker operations
#   Part of pre-flight validation checklist
#   Works with validate_profile_combination()
# GLOBALS READ:
#   USER_PROVIDED_BASE_IMAGE, USER_PROVIDED_LIBS, USER_PROVIDED_PROFILE - Flag sentinels
#   TEAM_NAME, PROJECT_NAME, IMAGE_TAG - For error message context
# USE CASES:
#   - Team member attempts: zzcollab -u -b rocker/verse → Error
#   - Team member attempts: zzcollab -u --libs geospatial → Error
#   - Team member attempts: zzcollab -u -r analysis → Error
#   - Team member valid: zzcollab -u --pkgs tidyverse → Success
# ARCHITECTURAL RATIONALE:
#   1. REPRODUCIBILITY: All team members have identical environments
#   2. SECURITY: Prevents accidental/malicious base image changes
#   3. SIMPLICITY: Team members don't need Docker/system library expertise
#   4. FLEXIBILITY: Team leads can update shared environment when needed
# EXAMPLE VALID TEAM MEMBER WORKFLOW:
#   1. Clone project: git clone https://github.com/team/project.git
#   2. Join project: zzcollab -u -d ~/dotfiles
#   3. Add packages: renv::install("tidymodels")
#   4. Work in container: make docker-zsh
#-----------------------------------------------------------------------------
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
