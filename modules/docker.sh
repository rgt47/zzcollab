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
# DEPENDENCIES: core.sh (logging), profiles.sh (system deps)
##############################################################################


#=============================================================================
# BASE IMAGE TOOL DETECTION
#=============================================================================
# get_profile_base_image() is defined in profiles.sh (data-driven from
# bundles.yaml). Do not redefine here.

# Determine what tools are already in the base image
get_base_image_tools() {
    local base_image="$1"
    local has_pandoc="false"

    case "$base_image" in
        *tidyverse*|*verse*|*rstudio*|*shiny*)
            has_pandoc="true"
            ;;
    esac

    echo "$has_pandoc"
}

# Generate install commands for missing tools
# TinyTeX is excluded by default. The project directory is bind-mounted
# from the host, so LaTeX rendering typically runs on the host.
generate_tools_install() {
    local base_image="$1"
    local has_pandoc
    has_pandoc=$(get_base_image_tools "$base_image")

    local cmds=""

    if [[ "$has_pandoc" == "false" ]]; then
        cmds+="# Install pandoc for document rendering
RUN apt-get update && apt-get install -y --no-install-recommends pandoc && rm -rf /var/lib/apt/lists/*

"
    fi

    # R dev-tooling install (none of these belong in renv.lock; see the
    # package-placement white paper). yaml and here are always installed: yaml
    # is needed by renv's R Markdown dependency parser, here is the common
    # compendium path-resolution helper. languageserver (in-container LSP) is
    # installed unless disabled (zzc config set languageserver false). styler
    # and lintr are added when the code-quality feature is active, since with no
    # host R the linters must run in the container. Ncpus parallelises the
    # binary install (white paper F-8).
    load_config 2>/dev/null || true
    local pkgs="'yaml', 'here'"
    [[ "${CONFIG_LANGUAGESERVER:-true}" == "true" ]] && pkgs="'languageserver', ${pkgs}"
    if [[ -f .pre-commit-config.yaml || "${CONFIG_FEAT_CODE_QUALITY:-off}" == "on" ]]; then
        pkgs="${pkgs}, 'styler', 'lintr'"
    fi
    cmds+="# Install R dev tooling (languageserver/styler/lintr are config-gated)
RUN R -e \"install.packages(c(${pkgs}), Ncpus = max(1L, parallel::detectCores()))\"
"

    # For LaTeX-capable bases (rocker/verse, the publishing profile), pre-bake
    # the LaTeX package closure at build time so PDF rendering works for the
    # non-root user without runtime installs. The verse default has auto-install
    # off; two warm-up renders (report format + a kitchen-sink of common
    # statistician packages) install the closure as root with the option
    # explicitly enabled. This block lands before the renv.lock COPY in the
    # generated Dockerfile, so a lockfile change does not invalidate the layer.
    if [[ "${base_image##*/}" == "verse" ]]; then
        cmds+="
"
        cmds+="$(cat <<'WARMUP_BLOCK'
# Pre-bake the LaTeX package closure at build time (as root, where tlmgr can
# write) so PDF rendering works for the non-root user with no runtime install.
# The closure is installed in one bulk tlmgr pass: relying on tinytex to
# discover packages lazily during a render installs them one at a time, and
# each missing .sty triggers a full pdflatex recompile (~14s x ~24 packages,
# ~5 min of build). A single tlmgr call fetches them in ~20-30s; the render
# below then finds everything present and acts as a fast smoke test that also
# self-heals any package this list omits.
RUN <<'WARMUP'
set -eu
R -e "tinytex::tlmgr_install(c('amsfonts','booktabs','setspace','multirow','wrapfig','float','colortbl','pdflscape','tabu','varwidth','threeparttable','threeparttablex','environ','trimspaces','ulem','makecell','mathtools','fancyhdr','caption','enumitem','fp','pgf','pgfplots','siunitx','lineno'))"
d=/tmp/texwarmup
mkdir -p "$d"
cat > "$d/01-report.Rmd" <<'RMD'
---
title: warm-up report
output:
  bookdown::pdf_document2:
    number_sections: true
header-includes:
  - \usepackage{setspace}
---
# Section
Math $\alpha \in \mathbb{R}$ and $\sum_{i=1}^{n} x_i^2$.
```{r}
knitr::kable(head(mtcars, 3), booktabs = TRUE)
```
RMD
cat > "$d/02-kitchensink.Rmd" <<'RMD'
---
title: warm-up kitchen sink
output:
  pdf_document:
    latex_engine: xelatex
    extra_dependencies:
      - booktabs
      - longtable
      - array
      - multirow
      - wrapfig
      - float
      - colortbl
      - pdflscape
      - tabu
      - threeparttable
      - threeparttablex
      - ulem
      - makecell
      - xcolor
      - amsmath
      - amssymb
      - amsfonts
      - mathtools
      - hyperref
      - geometry
      - fancyhdr
      - caption
      - subcaption
      - graphicx
      - multicol
      - setspace
      - enumitem
      - tikz
      - pgfplots
      - siunitx
---
# Kitchen sink
Math $\mathcal{N}(\mu, \sigma^2)$.
RMD
R -e 'options(tinytex.install_packages = TRUE); for (f in list.files("/tmp/texwarmup", pattern = "[.]Rmd$", full.names = TRUE)) rmarkdown::render(f, quiet = TRUE)'
rm -rf "$d"
WARMUP
WARMUP_BLOCK
)
"
    fi

    printf '%s\n' "$cmds"
}

create_renv_lock_minimal() {
    local r_ver="$1"
    local codename snapshot default_url
    codename="$(get_ubuntu_codename "$r_ver")"
    snapshot="${PPM_SNAPSHOT:-$(date +%Y-%m-%d)}"
    default_url="https://packagemanager.posit.co/cran/__linux__/${codename}/${snapshot}"
    local repo_url="${2:-$default_url}"

    cat > renv.lock << EOF
{
  "R": {
    "Version": "$r_ver",
    "Repositories": [
      {
        "Name": "CRAN",
        "URL": "$repo_url"
      }
    ]
  },
  "Packages": {
    "renv": {
      "Package": "renv",
      "Version": "${ZZCOLLAB_DEFAULT_RENV_VERSION}",
      "Source": "Repository",
      "Repository": "RSPM"
    },
    "tinytest": {
      "Package": "tinytest",
      "Version": "${ZZCOLLAB_DEFAULT_TINYTEST_VERSION}",
      "Source": "Repository",
      "Repository": "RSPM"
    }
  }
}
EOF
    log_success "Created renv.lock (R $r_ver)"
}

# Fast path for prompt_new_workspace_setup: when a profile and R version are
# already configured, show them and offer to keep them. Echoes the chosen R
# version and returns 0 when the configured settings are used; returns 1 to
# fall through to the interactive wizard.
# Args: profile version github_account dockerhub_account project_name
_workspace_use_configured() {
    local selected_profile="$1" selected_version="$2"
    local github_account="$3" dockerhub_account="$4" project_name="$5"

    [[ -n "$selected_profile" && -n "$selected_version" ]] || return 1

    local base_image
    base_image=$(get_profile_base_image "$selected_profile")
    echo "" >&2
    echo "  Profile:    $selected_profile ($base_image)" >&2
    echo "  R version:  $selected_version" >&2
    [[ -n "$github_account" ]] && echo "  GitHub:     $github_account/$project_name" >&2
    [[ -n "$dockerhub_account" ]] && echo "  DockerHub:  $dockerhub_account/$project_name" >&2
    echo "" >&2

    local change_settings
    zzc_read -r -p "Change settings? [y/N]: " change_settings
    if [[ "$change_settings" =~ ^[Yy]$ ]]; then
        echo "" >&2
        return 1
    fi

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
}

prompt_new_workspace_setup() {
    load_config 2>/dev/null || true

    local cran_version
    cran_version="${CONFIG_R_VERSION:-$ZZCOLLAB_DEFAULT_R_VERSION}"
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

    # Fast path: reuse the configured profile + R version if the user agrees.
    if _workspace_use_configured "$selected_profile" "$selected_version" \
           "$github_account" "$dockerhub_account" "$project_name"; then
        return 0
    fi

    # Interactive setup (either no config or user wants to change)
    local step=1

    # Step 1: Profile selection
    echo "Step $step: Select a Docker profile" >&2
    ((step++))
    echo "" >&2
    echo "  [1] minimal     - Base R, command-line only (~650MB)" >&2
    echo "  [2] tidyverse   - tidyverse data analysis (~1.2GB)" >&2
    echo "  [3] rstudio     - RStudio Server (~980MB)" >&2
    echo "" >&2

    local default_profile_num=2
    [[ "$selected_profile" == "minimal" ]] && default_profile_num=1
    [[ "$selected_profile" == "rstudio" ]] && default_profile_num=3

    local profile_choice
    zzc_read -r -p "Profile [$default_profile_num]: " profile_choice
    profile_choice="${profile_choice:-$default_profile_num}"

    case "$profile_choice" in
        1) selected_profile="minimal" ;;
        2) selected_profile="tidyverse" ;;
        3) selected_profile="rstudio" ;;
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
    zzc_read -r -p "R version [1]: " version_choice
    version_choice="${version_choice:-1}"

    case "$version_choice" in
        1)
            selected_version="$cran_version"
            ;;
        2)
            local default_ver="${selected_version:-$cran_version}"
            zzc_read -r -p "Enter R version [$default_ver]: " selected_version
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
    # Try to detect the logged-in GitHub user if not already set.
    local gh_user
    gh_user=$(forge_user github 2>/dev/null) || gh_user=""
    local default_gh="${github_account:-$gh_user}"

    echo "" >&2
    echo "Step $step: GitHub repository (optional)" >&2
    ((step++))
    echo "" >&2
    if [[ -n "$default_gh" ]]; then
        zzc_read -r -p "GitHub username [$default_gh]: " github_account
        github_account="${github_account:-$default_gh}"
    else
        zzc_read -r -p "GitHub username (blank to skip): " github_account
    fi

    # Step 4: DockerHub setup (optional)
    local default_docker="${dockerhub_account:-$github_account}"
    echo "" >&2
    echo "Step $step: DockerHub (optional)" >&2
    ((step++))
    echo "" >&2
    if [[ -n "$default_docker" ]]; then
        zzc_read -r -p "DockerHub username [$default_docker]: " dockerhub_account
        dockerhub_account="${dockerhub_account:-$default_docker}"
    else
        zzc_read -r -p "DockerHub username (blank to skip): " dockerhub_account
    fi

    # Save to config
    echo "" >&2
    zzc_read -r -p "Save as defaults? [Y/n]: " save_config
    # shellcheck disable=SC2154  # save_config set by zzc_read
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

extract_r_version() {
    if [[ -n "${R_VERSION:-}" ]]; then
        echo "$R_VERSION"
        return 0
    fi

    if [[ ! -f "renv.lock" ]]; then
        if [[ -t 0 ]] || [[ "${ZZCOLLAB_ACCEPT_DEFAULTS:-false}" == "true" ]]; then
            prompt_new_workspace_setup
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
# Self-contained package detection for Dockerfile system-dep derivation.
# (Dependency validation proper is handled by the zzrenvcheck R package.)

# File types scanned and paths skipped when detecting package usage.
_DOCKER_FILE_EXTENSIONS=("R" "Rmd" "qmd" "Rnw")
_DOCKER_SKIP_FILES=("*/README.Rmd" "*/README.md" "*/CLAUDE.md" "*/examples/*" "*/renv/*" "*/.git/*")

# Scan code files for library()/require()/pkg::/@importFrom/@import usages.
extract_code_packages() {
    local dirs=("$@")
    # Build the find expression as arrays so patterns/paths are passed as
    # literal arguments -- no eval, no word-splitting on whitespace/globs.
    local name_args=() exclude_args=() ext skip
    for ext in "${_DOCKER_FILE_EXTENSIONS[@]}"; do
        [[ ${#name_args[@]} -gt 0 ]] && name_args+=(-o)
        name_args+=(-name "*.$ext")
    done
    for skip in "${_DOCKER_SKIP_FILES[@]}"; do
        exclude_args+=(! -path "$skip")
    done

    # Single awk pass per file replaces the previous four grep|sed pipelines
    # (each spawning 2-3 processes). One pass emits library()/require() args,
    # pkg:: references, and roxygen @import/@importFrom targets. Using \047
    # (octal single quote) is portable across GNU and BSD awk, unlike the old
    # sed which silently dropped single-quoted args on BSD/macOS.
    while IFS= read -r file; do
        [[ -f "$file" ]] || continue
        awk '
            /@importFrom[[:space:]]+[a-zA-Z]/ {
                if (match($0, /@importFrom[[:space:]]+[a-zA-Z0-9.]+/)) {
                    s = substr($0, RSTART, RLENGTH); sub(/@importFrom[[:space:]]+/, "", s); print s
                }
            }
            /@import[[:space:]]+[a-zA-Z]/ {
                if ($0 !~ /@importFrom/ && match($0, /@import[[:space:]]+[a-zA-Z0-9.]+/)) {
                    s = substr($0, RSTART, RLENGTH); sub(/@import[[:space:]]+/, "", s); print s
                }
            }
            /^[[:space:]]*#/ { next }
            {
                tmp = $0
                while (match(tmp, /(library|require)[[:space:]]*\([[:space:]]*["\047]?[a-zA-Z][a-zA-Z0-9.]*/)) {
                    s = substr(tmp, RSTART, RLENGTH); sub(/.*\([[:space:]]*["\047]?/, "", s); print s
                    tmp = substr(tmp, RSTART + RLENGTH)
                }
                tmp = $0
                while (match(tmp, /[a-zA-Z][a-zA-Z0-9.]*::/)) {
                    s = substr(tmp, RSTART, RLENGTH); sub(/::$/, "", s); print s
                    tmp = substr(tmp, RSTART + RLENGTH)
                }
            }
        ' "$file" 2>/dev/null || true
    done < <(find "${dirs[@]}" -type f \( "${name_args[@]}" \) "${exclude_args[@]}" 2>/dev/null)
}

# Extract a comma-separated DESCRIPTION field (e.g. Imports), one pkg per line.
parse_description_field() {
    local field="$1"
    [[ -f "DESCRIPTION" ]] || return 0
    awk -v f="$field" '
    BEGIN { in_field=0; content="" }
    $0 ~ "^"f":" { in_field=1; content=$0; next }
    in_field && /^[[:space:]]/ { content=content " " $0; next }
    in_field && /^[A-Z]/ { in_field=0 }
    END {
        if (content) {
            gsub("^"f":[[:space:]]*", "", content)
            gsub(/\([^)]*\)/, "", content)
            gsub(/[[:space:]]+/, " ", content)
            gsub(/,/, "\n", content)
            print content
        }
    }
    ' DESCRIPTION | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort -u
}

parse_description_imports() { parse_description_field "Imports"; }

# List package names from renv.lock (requires jq).
parse_renv_lock() {
    command -v jq &>/dev/null || { log_warn "jq not found"; return 0; }
    [[ -f "renv.lock" ]] || return 0
    jq -r '.Packages | keys[]' renv.lock 2>/dev/null | grep -v '^$' | sort -u || true
}

# Package-name filters for _is_valid_pkg (R base packages and heuristic noise).
_DOCKER_BASE_PKGS=" base utils stats graphics grDevices methods datasets tools grid parallel "
_DOCKER_SKIP_PKGS=" package pkg mypackage myproject yourpackage project data result output input test example sample demo template local any all none foo bar baz renv "

# Filter a package name. The length filter ($2 = "strict") suppresses noise
# from the heuristic code scan only; names sourced from renv.lock or
# DESCRIPTION are authoritative and must not be dropped for being short
# (e.g. sf, sp, V8, XML, gsl, gmp, png, bz2, fs, BH). Defined at file scope so
# it is not re-created on every extract_r_packages call.
_is_valid_pkg() {
    local p="$1" mode="${2:-}"
    [[ -z "$p" ]] && return 1
    [[ "$mode" == "strict" && ${#p} -lt 3 ]] && return 1
    [[ "$_DOCKER_BASE_PKGS" == *" $p "* ]] && return 1
    [[ "$_DOCKER_SKIP_PKGS" == *" $p "* ]] && return 1
    [[ "$p" =~ ^[a-zA-Z][a-zA-Z0-9.]*$ ]] && return 0
    return 1
}

extract_r_packages() {
    local packages=()

    # 1. Scan code files (heuristic — apply the length filter). '.' already
    # covers R/, scripts/, analysis/; listing them again just re-traverses.
    while IFS= read -r pkg; do
        _is_valid_pkg "$pkg" strict && packages+=("$pkg")
    done < <(extract_code_packages "." 2>/dev/null)

    # 2. Add packages from DESCRIPTION (authoritative — no length filter)
    while IFS= read -r pkg; do
        _is_valid_pkg "$pkg" && packages+=("$pkg")
    done < <(parse_description_imports 2>/dev/null)

    # 3. Add packages from renv.lock (authoritative — no length filter)
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

# Write tooling.lock: a JSON file recording the pinned versions of tools
# installed into the image outside of renv (zzrenvcheck, renv itself).
# This file serves as the content-addressed record called for by R-5.
write_tooling_lock() {
    local r_version="$1" image_digest="${2:-}"
    local tag="${ZZRENVCHECK_TAG:-v0.3.1}"
    local snapshot="${PPM_SNAPSHOT:-$(date +%Y-%m-%d)}"
    local digest_field
    if [[ -n "$image_digest" ]]; then
        digest_field="\"${image_digest}\""
    else
        digest_field="null"
    fi

    cat > tooling.lock << EOF
{
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "r_version": "${r_version}",
  "base_image_digest": ${digest_field},
  "ppm_snapshot": "${snapshot}",
  "tools": {
    "zzrenvcheck": {
      "source": "github",
      "ref": "rgt47/zzrenvcheck@${tag}",
      "tag": "${tag}"
    }
  }
}
EOF
    log_info "  Wrote tooling.lock (zzrenvcheck ${tag})"
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

    # Load config to get profile settings
    load_config 2>/dev/null || true

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
        fi
    fi

    # Use profile from config if base_image not explicitly set
    if [[ -z "$base_image" ]]; then
        base_image=$(get_profile_base_image "${CONFIG_PROFILE_NAME:-minimal}")
    fi


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
    system_deps_install=$(generate_system_deps_install "$system_deps")

    local deps_comment="Packages: (none)"
    if [[ ${#r_packages[@]} -gt 5 ]]; then
        deps_comment="Packages: ${r_packages[*]:0:5}..."
    elif [[ ${#r_packages[@]} -gt 0 ]]; then
        deps_comment="Packages: ${r_packages[*]}"
    fi

    local tools_install
    tools_install=$(generate_tools_install "$base_image")
    log_info "  Tools: pandoc, languageserver, yaml (as needed)"

    # Resolve the base-image digest for content-addressed pinning (R-2).
    local image_digest
    image_digest=$(resolve_image_digest "${base_image}:${r_version}")

    generate_dockerfile_inline "$base_image" "$r_version" \
        "$system_deps_install" "$tools_install" \
        "$deps_comment" "$image_digest"

    # Write a tooling lockfile recording the pinned tool versions (R-5).
    write_tooling_lock "$r_version" "$image_digest"

    # Write project marker so _zzcollab_root() can detect this directory.
    touch .zzcollab

    prompt_docker_build "$project_name" "$r_version"
    return $?
}

prompt_docker_build() {
    local project_name="$1" r_version="$2"

    # Only prompt if coming from new workspace setup and in interactive terminal
    if [[ "${ZZCOLLAB_BUILD_AFTER_SETUP:-}" == "true" ]] && [[ -t 0 ]]; then
        echo ""
        zzc_read -r -p "Build Docker image now? [Y/n]: " build_now
        # shellcheck disable=SC2154  # build_now set by zzc_read
        if [[ ! "$build_now" =~ ^[Nn]$ ]]; then
            if make docker-build; then
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
        log_info "  Build with: make docker-build"
    fi
    return 0
}

# Resolve the repo digest for a pulled image tag so the Dockerfile FROM line
# can be pinned by content address rather than by mutable tag.
# Returns the full sha256:... string, or an empty string if Docker is not
# available or the pull fails (caller must handle the degraded case).
resolve_image_digest() {
    local image_ref="$1"
    local digest

    if ! command -v docker > /dev/null 2>&1; then
        log_warn "Docker not found; base-image digest not pinned (R-2)"
        echo ""
        return 0
    fi

    log_info "  Pulling ${image_ref} to resolve digest..."
    if ! docker pull "$image_ref" > /dev/null 2>&1; then
        log_warn "Could not pull ${image_ref}; base-image digest not pinned (R-2)"
        echo ""
        return 0
    fi

    digest=$(docker inspect --format '{{index .RepoDigests 0}}' "$image_ref" 2>/dev/null)
    # RepoDigests entry is "name@sha256:..." -- extract just the sha256 part
    digest="${digest##*@}"
    echo "$digest"
}

# Map an R version string (e.g. "4.4.2") to the Ubuntu codename used by the
# rocker images and Posit Package Manager for that release.
get_ubuntu_codename() {
    local r_version="$1"
    local minor
    minor="$(echo "$r_version" | cut -d. -f1-2)"
    case "$minor" in
        4.2|4.3) echo "jammy" ;;
        4.4|4.5) echo "noble" ;;
        *)        echo "noble" ;;
    esac
}

generate_dockerfile_inline() {
    local base_image="$1" r_version="$2" system_deps_install="$3"
    local tools_install="$4" deps_comment="$5" image_digest="${6:-}"
    local ubuntu_codename ppm_snapshot ppm_url from_spec zzrenvcheck_tag zzrenvcheck_version
    ubuntu_codename="$(get_ubuntu_codename "$r_version")"
    ppm_snapshot="${PPM_SNAPSHOT:-$(date +%Y-%m-%d)}"
    ppm_url="https://packagemanager.posit.co/cran/__linux__/${ubuntu_codename}/${ppm_snapshot}"
    zzrenvcheck_tag="${ZZRENVCHECK_TAG:-v0.3.1}"
    zzrenvcheck_version="${zzrenvcheck_tag#v}"

    # Pin the FROM line to a content-addressed digest when available (R-2).
    # Fallback to tag-only reference if digest resolution was skipped.
    if [[ -n "$image_digest" ]]; then
        from_spec="${base_image}:${r_version}@${image_digest}"
    else
        from_spec="${base_image}:${r_version}"
    fi

    # Self-adapting dependency install: branch on renv.lock presence at
    # generation time (a true build-time branch is blocked by Docker's
    # inability to COPY an optionally-present file; see the toggle plan).
    # renv mode restores the lockfile; DESCRIPTION mode installs declared
    # dependencies from DESCRIPTION against the dated snapshot pinned above.
    # The choice is recorded as INSTALL_MODE (ARG + LABEL) so the image is
    # self-describing rather than silently context-dependent.
    local install_mode install_block
    if [[ -f renv.lock ]]; then
        install_mode="renv"
        install_block=$(cat <<'IRENV'
RUN R -e "install.packages('renv')"
# 0777 so the non-root run user can hydrate/snapshot into the library (F-2);
# single-user research container, so world-writable here is acceptable.
RUN mkdir -p /opt/renv/library /opt/renv/cache && chmod 777 /opt/renv/library /opt/renv/cache
COPY renv.lock renv.lock
# RENV_LOCK_HASH is passed by the builder as a digest of renv.lock. Declaring
# it here and referencing it in the RUN below makes the restore layer's cache
# key depend on the lockfile content, so renv::restore() re-runs whenever
# renv.lock changes. This guards against BuildKit serving a stale restore
# layer, which would otherwise bake a library that silently diverges from the
# lockfile (and from the image's content-addressable hash label).
ARG RENV_LOCK_HASH=unknown
# renv::init creates the platform-specific library directory structure that
# renv::restore() requires to link packages from the cache.
RUN echo "renv.lock hash: ${RENV_LOCK_HASH}" && \
    R -e "renv::init(bare=TRUE, force=TRUE, restart=FALSE); renv::restore(exclude = 'renv')"
IRENV
)
    else
        install_mode="description"
        install_block=$(cat <<'IDESC'
COPY DESCRIPTION DESCRIPTION
# No renv.lock: install declared dependencies from DESCRIPTION against the
# dated PPM snapshot pinned above (no renv; pak resolves Imports/Suggests).
RUN R -e "install.packages('pak'); pak::local_install_deps(root = '.', dependencies = TRUE)"
IDESC
)
    fi

    rm -f Dockerfile
    cat > Dockerfile << EOF
# syntax=docker/dockerfile:1.4
# zzcollab Dockerfile v${ZZCOLLAB_TEMPLATE_VERSION}

# BASE_IMAGE is parsed out of this file by the project Makefile ('make r'
# derives the profile label from it); keep it even though the FROM below uses
# a fully-substituted literal and does not reference the ARG.
ARG BASE_IMAGE=${base_image}

FROM ${from_spec}

# OCI image labels for reproducibility provenance and tooling integration.
# base_digest records the resolved sha256 of the rocker base at build time;
# ppm_snapshot records the dated PPM URL used to pin package binaries.
LABEL org.opencontainers.image.created="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \\
      org.opencontainers.image.licenses="GPL-3.0-or-later" \\
      zzcollab.template.version="${ZZCOLLAB_TEMPLATE_VERSION}" \\
      zzcollab.r.version="${r_version}" \\
      zzcollab.base.image="${base_image}:${r_version}" \\
      zzcollab.base.digest="${image_digest:-unknown}" \\
      zzcollab.ppm.snapshot="${ppm_snapshot}" \\
      zzcollab.install.mode="${install_mode}"

ARG USERNAME=analyst
ARG DEBIAN_FRONTEND=noninteractive

# RENV_PATHS_LIBRARY is outside the project bind-mount so the baked library
# is not shadowed at runtime. ZZCOLLAB_AUTO_RESTORE=false disables the
# startup restore so the image library is authoritative.
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TZ=UTC \\
    RENV_PATHS_LIBRARY=/opt/renv/library \\
    RENV_PATHS_CACHE=/opt/renv/cache \\
    RENV_CONFIG_REPOS_OVERRIDE="${ppm_url}" \\
    ZZCOLLAB_CONTAINER=true \\
    ZZCOLLAB_INSTALL_MODE=${install_mode} \\
    ZZCOLLAB_AUTO_RESTORE=false

${system_deps_install}

# Configure R to use Posit Package Manager for pre-compiled binaries
RUN echo 'options(repos = c(CRAN = "${ppm_url}"))' \\
        >> /usr/local/lib/R/etc/Rprofile.site && \\
    echo 'options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(), paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])))' \\
        >> /usr/local/lib/R/etc/Rprofile.site

${tools_install}

# Dependency install (self-adapting, INSTALL_MODE=${install_mode}). The block
# below is emitted by generation-time branch on renv.lock presence. In renv
# mode, tools_install above runs BEFORE renv::init so IDE tools are in the
# system library; renv::init then activates renv and routes later installs to
# RENV_PATHS_LIBRARY.
${install_block}

# Install zzrenvcheck as a validation tool (system library, outside project renv).
# Installed post-build via make install-zzrenvcheck to avoid GitHub/network
# issues during docker build on cloud-mounted filesystems.


# Create non-root user, in the 'staff' group. rocker/verse owns its TeX tree
# (/opt/texlive, /usr/local/texlive) as root:staff and makes it group-writable,
# so a render that installs LaTeX packages at run time (tinytex) needs the run
# user to be in 'staff'; otherwise tlmgr/fmtutil fail with permission errors.
# Own the renv library AND cache (populated as root by the restore above) so the
# run user can hydrate/snapshot into them; the earlier chmod is non-recursive
# and predates the restore, so it does not cover the package subdirectories (F-2).
RUN useradd --create-home --shell /bin/bash --groups staff \${USERNAME} && \\
    chown -R \${USERNAME}:\${USERNAME} /usr/local/lib/R/site-library /opt/renv

USER \${USERNAME}
WORKDIR /home/\${USERNAME}/project

CMD ["R", "--quiet"]
EOF

    # Generator-written state record (machine-readable; never hand-edited).
    # zzc status reads this for robust read-back instead of re-parsing the
    # Dockerfile FROM/ARG lines, which is brittle under digest pins and
    # multi-stage builds (toggle plan, Section 4). Shared writer with cmd_init.
    _zzc_write_state "${r_version}" "${base_image}:${r_version}" \
        "${image_digest:-unknown}" "${ppm_snapshot}" "${install_mode}"

    log_success "Generated Dockerfile"
}

#=============================================================================
# DOCKER BUILD WITH CONTENT-ADDRESSABLE CACHING
#=============================================================================
# Images are labeled with a hash of Dockerfile + renv.lock content.
# Before building, we check if an identical image already exists locally.
# If found, we simply tag the existing image with the new project name.
# This avoids redundant builds when multiple projects use identical configs.

# Compute SHA256 hash of Dockerfile and renv.lock combined
compute_dockerfile_hash() {
    local hash=""
    if [[ -f "Dockerfile" ]] && [[ -f "renv.lock" ]]; then
        # Combine Dockerfile and renv.lock content for hash
        hash=$(cat Dockerfile renv.lock | shasum -a 256 | cut -d' ' -f1)
    elif [[ -f "Dockerfile" ]]; then
        hash=$(shasum -a 256 Dockerfile | cut -d' ' -f1)
    fi
    echo "$hash"
}

# Find existing image with matching Dockerfile hash
find_cached_image() {
    local target_hash="$1"
    [[ -z "$target_hash" ]] && return 1

    local image_id
    image_id=$(docker images --filter "label=zzcollab.dockerfile.hash=$target_hash" \
        --format '{{.ID}}' | head -1)

    [[ -n "$image_id" ]] && echo "$image_id"
    # A "no cached image" result is not an error. Without this explicit success,
    # the function returns the exit status of the failed [[ -n ]] test (1), and
    # the caller's `cached_image=$(find_cached_image ...)` trips set -e, aborting
    # the build silently before it ever starts.
    return 0
}

build_docker_image() {
    local project_name="${1:-$(basename "$(pwd)")}"
    local no_cache="${2:-false}"

    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker not installed"
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon not running"
        return 1
    fi

    [[ ! -f "Dockerfile" ]] && { log_error "Dockerfile not found. Run generate_dockerfile first."; return 1; }

    # Compute hash of current Dockerfile + renv.lock
    local dockerfile_hash
    dockerfile_hash=$(compute_dockerfile_hash)

    # Skip cache check when --no-cache
    if [[ "$no_cache" == "false" ]] && [[ -n "$dockerfile_hash" ]]; then
        local cached_image
        cached_image=$(find_cached_image "$dockerfile_hash")

        if [[ -n "$cached_image" ]]; then
            log_success "Found cached image with identical configuration"
            docker tag "$cached_image" "$project_name:latest"
            log_success "Tagged as: $project_name:latest"
            log_info "Run: docker run -it --rm -v \$(pwd):/home/analyst/project $project_name"
            return 0
        fi
    fi

    log_info "Building Docker image: $project_name"

    # Assemble docker build flags as an array so multi-token values are passed
    # as distinct, unsplit arguments.
    local build_args=()
    # The Makefile runs every container with --platform linux/amd64 (for parity
    # with CI, which is amd64). Build the image the same way on arm64 hosts, for
    # ALL base images: an arm64-native build (e.g. rocker/r-ver for the minimal
    # and rstudio profiles) is invisible to the amd64-pinned `make r` /
    # `docker-test`, which then report "image not found". A previous version
    # pinned amd64 only for tidyverse/shiny/verse, so minimal/rstudio builds on
    # Apple Silicon broke at run time (found by the real-infra validation pass).
    if [[ "$(uname -m)" == "arm64" ]]; then
        build_args+=(--platform linux/amd64)
        log_info "arm64 host: building for linux/amd64 (matches the amd64-pinned container runs)"
    fi

    # Build with hash label for future cache lookups
    [[ -n "$dockerfile_hash" ]] && build_args+=(--label "zzcollab.dockerfile.hash=$dockerfile_hash")
    [[ "$no_cache" == "true" ]] && build_args+=(--no-cache)

    # Pass a digest of renv.lock as a build-arg so the Dockerfile's restore
    # layer (which declares ARG RENV_LOCK_HASH) is cache-busted whenever the
    # lockfile changes. Without this, BuildKit can reuse a stale restore layer
    # and bake a library that no longer matches renv.lock, producing an image
    # whose contents contradict its content-addressable hash label.
    if [[ -f "renv.lock" ]]; then
        local renv_lock_hash
        renv_lock_hash=$(shasum -a 256 renv.lock | cut -d' ' -f1)
        build_args+=(--build-arg "RENV_LOCK_HASH=$renv_lock_hash")
    fi

    # Container runtime for the local build: docker (BuildKit) or podman, which
    # accepts the same build flags. (Multi-arch team publishing uses docker
    # buildx and stays docker-specific; see the Makefile.)
    [[ -z "${CONFIG_DOCKER_RUNTIME:-}" ]] && load_config 2>/dev/null || true
    local runtime="${CONFIG_DOCKER_RUNTIME:-docker}"
    # Apptainer execs a SIF built from an OCI image, so the local image is still
    # built with docker (the SIF source); 'make sif' then converts it.
    if [[ "$runtime" == "apptainer" ]]; then
        runtime="docker"
        log_info "Apptainer runtime: building the OCI image with docker; run 'make sif' to convert."
    fi
    log_info "Building image with $runtime..."

    local _built=false
    local _log=""
    # Interactive + gum available: show a spinner instead of a flood of build
    # output, capture the full log to a file, and offer to view it (errors are
    # surfaced automatically on failure). Otherwise stream the build directly,
    # so CI and no-TTY runs - where the streamed log is the only feedback - are
    # unchanged.
    if has_gum && [[ -t 1 ]]; then
        if mkdir -p .zzcollab 2>/dev/null; then _log=".zzcollab/docker-build.log"; else _log="docker-build.log"; fi
        local _script
        _script=$(mktemp "${TMPDIR:-/tmp}/zzc-build.XXXXXX")
        {
            printf 'cd %q\n' "$PWD"
            [[ "$runtime" == "docker" ]] && printf 'export DOCKER_BUILDKIT=1\n'
            printf '%q build' "$runtime"
            [[ ${#build_args[@]} -gt 0 ]] && printf ' %q' "${build_args[@]}"
            printf ' -t %q . > %q 2>&1\n' "$project_name" "$_log"
        } > "$_script"
        if gum spin --spinner dot \
            --title "Building image with $runtime (this can take a few minutes)…" -- \
            bash "$_script"; then
            _built=true
        fi
        rm -f "$_script"
    elif [[ "$runtime" == "docker" ]]; then
        DOCKER_BUILDKIT=1 docker build ${build_args[@]+"${build_args[@]}"} -t "$project_name" . && _built=true
    else
        "$runtime" build ${build_args[@]+"${build_args[@]}"} -t "$project_name" . && _built=true
    fi

    if [[ "$_built" == true ]]; then
        log_success "Image '$project_name' built successfully ($runtime)"
        if [[ -n "$_log" ]]; then
            log_info "Build log saved: $_log"
            gum_confirm "View the build log?" no && { less "$_log" 2>/dev/null || cat "$_log"; }
        fi
        log_info "Run: $runtime run -it --rm -v \$(pwd):/home/analyst/project $project_name"
    else
        log_error "Image build failed ($runtime)"
        if [[ -n "$_log" && -f "$_log" ]]; then
            log_error "Last 30 lines of the build log:"
            tail -n 30 "$_log" >&2
            log_info "Full log: $_log"
        fi
        return 1
    fi
}

#=============================================================================
# MODULE LOADED
#=============================================================================

