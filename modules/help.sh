#!/bin/bash
set -euo pipefail
##############################################################################
# ZZCOLLAB HELP MODULE
##############################################################################
#
# PURPOSE: Command reference for the zzcollab CLI.
#          Concise per-command and per-topic synopses. Deep explanations
#          live in the vignettes and docs/, not here.
#
# DEPENDENCIES: core.sh (logging)
##############################################################################

#=============================================================================
# MAIN HELP
#=============================================================================

show_help_brief() {
    cat << 'EOF'
usage: zzc <command> [options]
   or: zzc help <topic>

zzcollab - reproducible research compendium framework.
Creates R package projects with Docker, renv, and CI/CD.

Commands:
  init [--force]        Create compendium structure in current directory
  analysis | minimal | rstudio
                        Quickstart: init + renv + docker (new project),
                        or switch profile (existing project)
  docker [--build]      Generate/build the Docker image
  renv                  Create or update renv.lock
  github [--public]     Create GitHub repo and push
  dockerhub [--tag T]   Push image to Docker Hub
  status                Show reproducibility features and level (read-only)
  validate              Check package dependencies (via zzrenvcheck)
  verify [--full]       Confirm reproducibility: coherence, or rebuild for L3
  data                  Write a sha256 manifest of raw data (integrity toggle)
  code-quality          Install pre-commit hooks (styler + lintr)
  doctor [--fix]        Check workspace files are current with templates
  config <subcommand>   Manage configuration (get/set/list/init)
  list <profiles|libs|pkgs>
                        List available profiles and bundles
  rm <feature>          Remove a feature (docker, renv, git, github, cicd, data, all)
  uninstall [--force]   Remove the zzcollab scaffold from this directory
  help <topic>          Show detailed help for a topic

Topics: docker, profiles, config

Daily workflow:
  mkdir myproject && cd myproject
  zzc analysis                 # full setup
  make r                       # enter container, work in R, q() to exit
  make docker-test             # run tests
  git add . && git commit && git push

Both 'zzc' and 'zzcollab' invoke the same tool.
EOF
}

# Main help dispatcher. Called by cmd_help in zzcollab.sh.
show_help() {
    local topic="${1:-}"
    case "$topic" in
        ""|--all|-a)        show_help_brief ;;
        docker)             show_help_docker ;;
        profiles)           show_help_profiles ;;
        config)             show_help_config_topic ;;
        next-steps|next_steps) show_help_next_steps ;;
        *)
            echo "Unknown help topic: $topic"
            echo "Available topics: docker, profiles, config, next-steps"
            echo "Run 'zzc help' for the command list."
            return 1
            ;;
    esac
}

# Post-creation guidance. Also surfaced by the R wrapper zzcollab_next_steps().
show_help_next_steps() {
    cat << 'EOF'
NEXT STEPS

After zzc init / zzc <profile>:

  1. Build the image:        make docker-build
  2. Enter the container:    make r        (or: make docker-rstudio)
  3. Work in R; on exit, renv snapshots your package additions
  4. Run tests:             make docker-test
  5. Validate deps:         make check-renv
  6. Commit and push:       git add . && git commit && git push
  7. (optional) Publish:    zzc github      zzc dockerhub

See vignette("quickstart1") for the full walkthrough.
EOF
}

#=============================================================================
# TOPIC HELP
#=============================================================================

show_help_docker() {
    cat << 'EOF'
DOCKER

  zzc docker                  Generate Dockerfile (interactive)
  zzc docker --build          Generate and build the image
  zzc docker --profile NAME   Use a specific profile
  zzc docker --base-image IMG Use a custom base image
  zzc docker --no-renv        Install from DESCRIPTION (no renv.lock)

Make targets:
  make docker-build           Build image (runs check-binaries first)
  make r                      Interactive R session in the container
  make docker-rstudio         RStudio Server at http://localhost:8787
  make docker-test            Run tests in the container
  make check-binaries         Audit renv.lock for missing system deps

The image provides the shared environment; renv.lock pins exact package
versions. See vignette("quickstart1") for the full workflow.
EOF
}

show_help_profiles() {
    cat << 'EOF'
PROFILES

  minimal     Base R, command-line only          (~650MB)
  analysis    Tidyverse data analysis            (~1.2GB)  [recommended]
  rstudio     RStudio Server                     (~980MB)

  zzc <profile>          New project: init + renv + docker
                         Existing project: switch profile, regenerate Dockerfile
  zzc list profiles      Show profiles with base images and sizes
  zzc list libs          Show system library bundles
  zzc list pkgs          Show R package bundles

Profiles are defined in templates/bundles.yaml.
EOF
}

show_help_config_topic() {
    cat << 'EOF'
CONFIGURATION

  zzc config list                          Show all settings
  zzc config get KEY                       Get one setting
  zzc config set KEY VALUE                 Set a user-level default
  zzc config set-local KEY VALUE           Set a project-level override
  zzc config init [--interactive]          Create the user config

Files (project overrides user):
  ~/.zzcollab/config.yaml   user defaults
  ./zzcollab.yaml           project overrides (commit to version control)

Keys: author-name, author-email, author-orcid, author-affiliation,
      github-account, dockerhub-account, profile-name, r-version,
      license-type
EOF
}
