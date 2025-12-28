#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB DOCKER MODULE (Simplified)
##############################################################################
#
# PURPOSE: Docker environment generation with dynamic dependency resolution
#          - Single universal template with variable substitution
#          - System deps auto-derived from R packages
#          - Simple profile presets (base image shortcuts)
#
# DEPENDENCIES: core.sh (logging), profiles.sh (system deps), validation.sh (package scanning)
##############################################################################

require_module "core" "profiles" "validation"

#=============================================================================
# PROFILE PRESETS (base image shortcuts)
#=============================================================================

get_profile_base_image() {
    local profile="${1:-minimal}"
    case "$profile" in
        minimal|standard|ubuntu_standard_minimal)  echo "rocker/r-ver" ;;
        tidyverse|analysis|ubuntu_standard_analysis|ubuntu_standard_analysis_vim)  echo "rocker/tidyverse" ;;
        verse|publishing|ubuntu_standard_publishing)  echo "rocker/verse" ;;
        rstudio)  echo "rocker/rstudio" ;;
        shiny)    echo "rocker/shiny" ;;
        *)
            log_warn "Unknown profile '$profile', using rocker/r-ver"
            echo "rocker/r-ver"
            ;;
    esac
}

#=============================================================================
# BASE IMAGE TOOL DETECTION
#=============================================================================

# Determine what tools are already in the base image
get_base_image_tools() {
    local base_image="$1"
    local has_pandoc="false"
    local has_tinytex="false"

    case "$base_image" in
        *tidyverse*)
            has_pandoc="true"
            has_tinytex="false"
            ;;
        *verse*)
            has_pandoc="true"
            has_tinytex="true"
            ;;
        *rstudio*|*shiny*)
            has_pandoc="true"
            has_tinytex="false"
            ;;
        *)
            has_pandoc="false"
            has_tinytex="false"
            ;;
    esac

    echo "${has_pandoc}:${has_tinytex}"
}

# Generate install commands for missing tools
generate_tools_install() {
    local base_image="$1"
    local tools
    tools=$(get_base_image_tools "$base_image")

    local has_pandoc="${tools%%:*}"
    local has_tinytex="${tools##*:}"

    local cmds=""

    # Pandoc installation (if missing)
    if [[ "$has_pandoc" == "false" ]]; then
        cmds+="# Install pandoc for document rendering
RUN apt-get update && apt-get install -y --no-install-recommends pandoc && rm -rf /var/lib/apt/lists/*

"
    fi

    # TinyTeX installation (if missing)
    if [[ "$has_tinytex" == "false" ]]; then
        cmds+="# Install tinytex for PDF output
RUN R -e \"install.packages('tinytex')\" && R -e \"tinytex::install_tinytex()\"

"
    fi

    # Always install languageserver for IDE support
    cmds+="# Install languageserver for IDE support
RUN R -e \"install.packages('languageserver')\"
"

    echo "$cmds"
}

#=============================================================================
# R VERSION DETECTION
#=============================================================================

get_cran_r_version() {
    local version major_dir

    # Find highest major version directory (R-4, R-5, etc.)
    major_dir=$(curl -s --max-time 10 https://cran.r-project.org/src/base/ 2>/dev/null | \
        grep -oE 'R-[0-9]+' | sort -V | tail -1)

    if [[ -n "$major_dir" ]]; then
        version=$(curl -s --max-time 10 "https://cran.r-project.org/src/base/${major_dir}/" 2>/dev/null | \
            grep -oE 'R-[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1 | sed 's/R-//')
    fi

    if [[ -z "$version" ]]; then
        version="4.4.2"
        log_warn "Could not query CRAN, using fallback: $version"
    fi
    echo "$version"
}

create_renv_lock_minimal() {
    local r_ver="$1"
    local cran="${2:-https://cloud.r-project.org}"

    if ! command -v jq &>/dev/null; then
        cat > renv.lock << EOF
{
  "R": {
    "Version": "$r_ver",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "$cran"
      }
    ]
  },
  "Packages": {}
}
EOF
    else
        jq -n --arg r "$r_ver" --arg c "$cran" \
            '{R:{Version:$r,Repositories:[{Name:"CRAN",URL:$c}]},Packages:{}}' > renv.lock
    fi
    log_success "Created renv.lock (R $r_ver)"
}

prompt_new_workspace_setup() {
    require_module "config"
    load_config 2>/dev/null || true

    local cran_version
    cran_version=$(get_cran_r_version)
    local project_name
    project_name=$(basename "$(pwd)")
    local selected_profile selected_version base_image
    local github_account dockerhub_account

    # Collect pre-configured values
    selected_profile="${PROFILE_NAME:-${CONFIG_PROFILE_NAME:-}}"
    selected_version="${R_VERSION:-${CONFIG_R_VERSION:-}}"
    github_account="${GITHUB_ACCOUNT:-${CONFIG_GITHUB_ACCOUNT:-}}"
    dockerhub_account="${DOCKERHUB_ACCOUNT:-${CONFIG_DOCKERHUB_ACCOUNT:-}}"

    # All prompts to STDERR so STDOUT only contains the version
    echo "" >&2
    echo "═══════════════════════════════════════════════════════════" >&2
    echo "  New zzcollab workspace: $project_name" >&2
    echo "═══════════════════════════════════════════════════════════" >&2

    # Check if all required values are pre-configured
    if [[ -n "$selected_profile" && -n "$selected_version" ]]; then
        base_image=$(get_profile_base_image "$selected_profile")
        echo "" >&2
        echo "  Profile:    $selected_profile ($base_image)" >&2
        echo "  R version:  $selected_version" >&2
        [[ -n "$github_account" ]] && echo "  GitHub:     $github_account/$project_name" >&2
        [[ -n "$dockerhub_account" ]] && echo "  DockerHub:  $dockerhub_account/$project_name" >&2
        echo "" >&2

        local change_settings
        read -r -p "Change settings? [y/N]: " change_settings
        if [[ ! "$change_settings" =~ ^[Yy]$ ]]; then
            # Use existing settings, proceed to build
            create_renv_lock_minimal "$selected_version" >&2
            R_VERSION="$selected_version"
            BASE_IMAGE="$base_image"
            GITHUB_ACCOUNT="$github_account"
            DOCKERHUB_ACCOUNT="$dockerhub_account"
            ZZCOLLAB_BUILD_AFTER_SETUP="true"
            export R_VERSION BASE_IMAGE GITHUB_ACCOUNT DOCKERHUB_ACCOUNT ZZCOLLAB_BUILD_AFTER_SETUP
            echo "$selected_version"
            return 0
        fi
        echo "" >&2
    fi

    # Interactive setup (either no config or user wants to change)
    local step=1

    # Step 1: Profile selection
    echo "Step $step: Select a Docker profile" >&2
    ((step++))
    echo "" >&2
    echo "  [1] minimal     - Base R only (~300MB)" >&2
    echo "  [2] analysis    - tidyverse packages (~1.5GB)" >&2
    echo "  [3] publishing  - LaTeX + pandoc for documents (~3GB)" >&2
    echo "" >&2

    local default_profile_num=2
    [[ "$selected_profile" == "minimal" ]] && default_profile_num=1
    [[ "$selected_profile" == "publishing" ]] && default_profile_num=3

    local profile_choice
    read -r -p "Profile [$default_profile_num]: " profile_choice
    profile_choice="${profile_choice:-$default_profile_num}"

    case "$profile_choice" in
        1) selected_profile="minimal" ;;
        2) selected_profile="analysis" ;;
        3) selected_profile="publishing" ;;
        *)
            log_error "Invalid choice" >&2
            return 1
            ;;
    esac

    base_image=$(get_profile_base_image "$selected_profile")
    echo "  Selected: $selected_profile ($base_image)" >&2

    # Step 2: R version selection
    echo "" >&2
    echo "Step $step: Select R version" >&2
    ((step++))
    echo "" >&2
    echo "  Current version on CRAN: $cran_version" >&2
    echo "" >&2
    echo "  [1] Use R $cran_version (current)" >&2
    echo "  [2] Specify a different version" >&2
    echo "" >&2

    local version_choice
    read -r -p "R version [1]: " version_choice
    version_choice="${version_choice:-1}"

    case "$version_choice" in
        1)
            selected_version="$cran_version"
            ;;
        2)
            local default_ver="${selected_version:-$cran_version}"
            read -r -p "Enter R version [$default_ver]: " selected_version
            selected_version="${selected_version:-$default_ver}"
            if [[ ! "$selected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                log_error "Invalid version format. Expected: X.Y.Z" >&2
                return 1
            fi
            ;;
        *)
            log_error "Invalid choice" >&2
            return 1
            ;;
    esac

    # Step 3: GitHub setup (optional)
    # Try to detect from gh CLI if not already set
    local gh_user=""
    if command -v gh &>/dev/null; then
        gh_user=$(gh api user --jq '.login' 2>/dev/null) || gh_user=""
    fi
    local default_gh="${github_account:-$gh_user}"

    echo "" >&2
    echo "Step $step: GitHub repository (optional)" >&2
    ((step++))
    echo "" >&2
    if [[ -n "$default_gh" ]]; then
        read -r -p "GitHub username [$default_gh]: " github_account
        github_account="${github_account:-$default_gh}"
    else
        read -r -p "GitHub username (blank to skip): " github_account
    fi

    # Step 4: DockerHub setup (optional)
    local default_docker="${dockerhub_account:-$github_account}"
    echo "" >&2
    echo "Step $step: DockerHub (optional)" >&2
    ((step++))
    echo "" >&2
    if [[ -n "$default_docker" ]]; then
        read -r -p "DockerHub username [$default_docker]: " dockerhub_account
        dockerhub_account="${dockerhub_account:-$default_docker}"
    else
        read -r -p "DockerHub username (blank to skip): " dockerhub_account
    fi

    # Save to config
    echo "" >&2
    read -r -p "Save as defaults? [Y/n]: " save_config
    if [[ ! "$save_config" =~ ^[Nn]$ ]]; then
        config_set "profile-name" "$selected_profile" >&2
        config_set "r-version" "$selected_version" >&2
        [[ -n "$github_account" ]] && config_set "github-account" "$github_account" >&2
        [[ -n "$dockerhub_account" ]] && config_set "dockerhub-account" "$dockerhub_account" >&2
    fi

    create_renv_lock_minimal "$selected_version" >&2

    # Export for Dockerfile generation
    R_VERSION="$selected_version"
    BASE_IMAGE="$base_image"
    GITHUB_ACCOUNT="$github_account"
    DOCKERHUB_ACCOUNT="$dockerhub_account"
    ZZCOLLAB_BUILD_AFTER_SETUP="true"
    export R_VERSION BASE_IMAGE GITHUB_ACCOUNT DOCKERHUB_ACCOUNT ZZCOLLAB_BUILD_AFTER_SETUP

    echo "$selected_version"
}

# Wrapper for backward compatibility
prompt_r_version_selection() {
    prompt_new_workspace_setup
}

extract_r_version() {
    if [[ -n "${R_VERSION:-}" ]]; then
        echo "$R_VERSION"
        return 0
    fi

    if [[ ! -f "renv.lock" ]]; then
        if [[ -t 0 ]]; then
            prompt_r_version_selection
            return $?
        else
            log_error "R version not specified and renv.lock not found"
            log_error "Use: zzcollab docker --r-version 4.4.0"
            log_error "Or:  zzcollab config set r-version 4.4.0"
            return 1
        fi
    fi

    local r_version
    if command -v jq >/dev/null 2>&1; then
        r_version=$(jq -r '.R.Version // empty' renv.lock 2>/dev/null)
    else
        r_version=$(grep -A 5 '"R"' renv.lock 2>/dev/null | grep '"Version"' | head -1 | sed 's/.*"\([0-9.]*\)".*/\1/')
    fi

    if [[ -z "$r_version" ]]; then
        log_error "Could not extract R version from renv.lock"
        return 1
    fi

    log_info "R version from renv.lock: $r_version"
    echo "$r_version"
}

#=============================================================================
# R PACKAGE EXTRACTION
#=============================================================================
# Uses validation.sh functions for comprehensive package detection:
#   - extract_code_packages(): scans .R/.Rmd/.qmd/.Rnw for library/require/pkg::/@import
#   - clean_packages(): filters base packages, placeholders, false positives
#   - parse_description_imports(): reads DESCRIPTION Imports
#   - parse_renv_lock(): reads renv.lock packages

extract_r_packages() {
    local packages=()
    local base_pkgs=" base utils stats graphics grDevices methods datasets tools grid parallel "
    local skip_pkgs=" package pkg mypackage myproject yourpackage project data result output input test example sample demo template local any all none foo bar baz renv "

    # Helper: filter a package
    _is_valid_pkg() {
        local p="$1"
        [[ -z "$p" || ${#p} -lt 3 ]] && return 1
        [[ "$base_pkgs" == *" $p "* ]] && return 1
        [[ "$skip_pkgs" == *" $p "* ]] && return 1
        [[ "$p" =~ ^[a-zA-Z][a-zA-Z0-9.]*$ ]] && return 0
        return 1
    }

    # 1. Scan code files
    while IFS= read -r pkg; do
        _is_valid_pkg "$pkg" && packages+=("$pkg")
    done < <(extract_code_packages "." "R" "scripts" "analysis" 2>/dev/null)

    # 2. Add packages from DESCRIPTION
    while IFS= read -r pkg; do
        _is_valid_pkg "$pkg" && packages+=("$pkg")
    done < <(parse_description_imports 2>/dev/null)

    # 3. Add packages from renv.lock
    while IFS= read -r pkg; do
        _is_valid_pkg "$pkg" && packages+=("$pkg")
    done < <(parse_renv_lock 2>/dev/null)

    # Deduplicate and sort
    [[ ${#packages[@]} -gt 0 ]] && printf '%s\n' "${packages[@]}" | sort -u
}

#=============================================================================
# SYSTEM DEPS DERIVATION
#=============================================================================

derive_system_deps() {
    [[ $# -eq 0 ]] && { echo ""; return 0; }

    local packages=("$@")
    local all_deps=()

    for pkg in "${packages[@]}"; do
        local deps
        deps=$(get_package_build_deps "$pkg" 2>/dev/null) || continue
        if [[ -n "$deps" ]]; then
            # shellcheck disable=SC2206
            all_deps+=($deps)
        fi
    done

    if [[ ${#all_deps[@]} -eq 0 ]]; then
        echo ""
        return 0
    fi

    printf '%s\n' "${all_deps[@]}" | sort -u | paste -sd' ' -
}

generate_system_deps_install() {
    local deps="$1"

    if [[ -z "$deps" ]]; then
        echo "# No additional system dependencies required"
        return 0
    fi

    cat << EOF
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \\
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \\
    set -ex && \\
    apt-get update && \\
    apt-get install -y --no-install-recommends \\
        build-essential pkg-config \\
        libcurl4-openssl-dev libssl-dev libxml2-dev \\
        $deps && \\
    rm -rf /var/lib/apt/lists/*
EOF
}

#=============================================================================
# DOCKERFILE GENERATION
#=============================================================================

generate_dockerfile() {
    local base_image="${BASE_IMAGE:-}"
    local r_version="${R_VERSION:-}"
    local project_name="${PROJECT_NAME:-$(basename "$(pwd)")}"
    local triggered_wizard=false

    log_info "Generating Dockerfile..."

    if [[ -z "$r_version" ]]; then
        # Check if we'll trigger the wizard (no renv.lock and interactive)
        if [[ ! -f "renv.lock" ]] && [[ -t 0 ]]; then
            triggered_wizard=true
        fi
        r_version=$(extract_r_version) || return 1
        # Wizard exports don't persist from subshell - reload config
        if [[ "$triggered_wizard" == "true" ]]; then
            ZZCOLLAB_BUILD_AFTER_SETUP="true"
            load_config 2>/dev/null || true
            base_image=$(get_profile_base_image "${CONFIG_PROFILE_NAME:-minimal}")
        fi
    fi

    # Default base image if still not set
    [[ -z "$base_image" ]] && base_image="rocker/r-ver"

    log_info "  Base image: ${base_image}:${r_version}"

    local r_packages=()
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && r_packages+=("$pkg")
    done < <(extract_r_packages)
    log_info "  Found ${#r_packages[@]} R packages (from code + DESCRIPTION + renv.lock)"

    local system_deps=""
    if [[ ${#r_packages[@]} -gt 0 ]]; then
        system_deps=$(derive_system_deps "${r_packages[@]}")
    fi
    if [[ -n "$system_deps" ]]; then
        log_info "  System deps: $system_deps"
    else
        log_info "  No additional system deps required"
    fi

    local system_deps_install
    system_deps_install=$(generate_system_deps_install "$system_deps" "$base_image")

    local tools_install
    tools_install=$(generate_tools_install "$base_image")
    log_info "  Tools: pandoc, tinytex, languageserver (as needed)"

    local deps_comment="Packages: (none)"
    if [[ ${#r_packages[@]} -gt 5 ]]; then
        deps_comment="Packages: ${r_packages[*]:0:5}..."
    elif [[ ${#r_packages[@]} -gt 0 ]]; then
        deps_comment="Packages: ${r_packages[*]}"
    fi

    generate_dockerfile_inline "$base_image" "$r_version" "$system_deps_install" "$tools_install" "$deps_comment"
    prompt_docker_build "$project_name" "$r_version"
    return $?
}

prompt_docker_build() {
    local project_name="$1" r_version="$2"

    # Only prompt if coming from new workspace setup and in interactive terminal
    if [[ "${ZZCOLLAB_BUILD_AFTER_SETUP:-}" == "true" ]] && [[ -t 0 ]]; then
        echo ""
        echo "Step: Build Docker image"
        echo ""
        read -r -p "Build now? [Y/n]: " build_now
        if [[ ! "$build_now" =~ ^[Nn]$ ]]; then
            echo ""
            log_info "Building Docker image: $project_name"
            log_info "This may take several minutes on first build..."
            echo ""
            if DOCKER_BUILDKIT=1 docker build --platform linux/amd64 \
                --build-arg R_VERSION="$r_version" \
                -t "$project_name" . ; then
                echo ""
                log_success "Docker image built: $project_name"
                echo ""
                echo "Start container with:"
                echo "  make r          # Interactive R session"
                echo "  make rstudio    # RStudio at localhost:8787"
            else
                log_error "Docker build failed"
                echo "Check the output above for errors."
                echo "Retry with: make docker-build"
            fi
        else
            echo ""
            echo "Build later with: make docker-build"
        fi
        unset ZZCOLLAB_BUILD_AFTER_SETUP
    else
        log_info "  Build with: docker build -t $project_name ."
    fi
    return 0
}

generate_dockerfile_inline() {
    local base_image="$1" r_version="$2" system_deps_install="$3" tools_install="$4" deps_comment="$5"

    cat > Dockerfile << EOF
# syntax=docker/dockerfile:1.4
# Generated by zzcollab - $deps_comment

ARG BASE_IMAGE=${base_image}
ARG R_VERSION=${r_version}
ARG USERNAME=analyst

FROM \${BASE_IMAGE}:\${R_VERSION}

ARG USERNAME=analyst
ARG DEBIAN_FRONTEND=noninteractive

# RENV_CONFIG_REPOS_OVERRIDE forces renv to use Posit PPM binaries
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TZ=UTC \\
    RENV_PATHS_CACHE=/renv/cache \\
    RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/noble/latest" \\
    ZZCOLLAB_CONTAINER=true

${system_deps_install}

# Configure R to use Posit Package Manager for pre-compiled binaries
RUN echo 'options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/noble/latest"))' \\
        >> /usr/local/lib/R/etc/Rprofile.site && \\
    echo 'options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(), paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])))' \\
        >> /usr/local/lib/R/etc/Rprofile.site

# Install renv and restore packages from lockfile (using PPM binaries)
RUN R -e "install.packages('renv')"
RUN mkdir -p /renv/cache && chmod 777 /renv/cache
COPY renv.lock renv.lock
RUN R -e "renv::restore()"

${tools_install}

# Create non-root user
RUN useradd --create-home --shell /bin/bash \${USERNAME} && \\
    chown -R \${USERNAME}:\${USERNAME} /usr/local/lib/R/site-library

USER \${USERNAME}
WORKDIR /home/\${USERNAME}/project

CMD ["R", "--quiet"]
EOF

    log_success "Generated Dockerfile (inline)"
}

#=============================================================================
# DOCKER BUILD
#=============================================================================

# shellcheck disable=SC2120
build_docker_image() {
    local project_name="${1:-$(basename "$(pwd)")}"

    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker not installed"
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon not running"
        return 1
    fi

    [[ ! -f "Dockerfile" ]] && { log_error "Dockerfile not found. Run generate_dockerfile first."; return 1; }

    log_info "Building Docker image: $project_name"

    local platform_args=""
    if [[ "$(uname -m)" == "arm64" ]]; then
        local base_image
        base_image=$(grep "^FROM" Dockerfile | head -1 | awk '{print $2}' | cut -d: -f1)
        case "$base_image" in
            *tidyverse*|*shiny*|*verse*)
                platform_args="--platform linux/amd64"
                log_info "Using AMD64 emulation for $base_image"
                ;;
        esac
    fi

    if DOCKER_BUILDKIT=1 docker build $platform_args -t "$project_name" .; then
        log_success "Docker image '$project_name' built successfully"
        log_info "Run: docker run -it --rm -v \$(pwd):/home/analyst/project $project_name"
    else
        log_error "Docker build failed"
        return 1
    fi
}

#=============================================================================
# CONVENIENCE FUNCTIONS
#=============================================================================

docker_setup() {
    generate_dockerfile && build_docker_image
}

show_docker_help() {
    cat << 'EOF'
Docker Commands:
  docker build -t PROJECT .                    Build image
  docker run -it --rm -v $(pwd):/home/analyst/project PROJECT R
                                               Interactive R
  docker run -it --rm -v $(pwd):/home/analyst/project PROJECT bash
                                               Shell access

First run in container:
  renv::restore()                              Install packages from renv.lock
EOF
}

#=============================================================================
# MODULE LOADED
#=============================================================================

readonly ZZCOLLAB_DOCKER_LOADED=true
readonly ZZCOLLAB_DOCKERFILE_GENERATOR_LOADED=true
