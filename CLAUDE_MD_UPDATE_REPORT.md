# CLAUDE.md Update Report - New Architecture Migration

## Executive Summary

This report identifies ALL sections in CLAUDE.md that reference the old `-i` and `-I` flag architecture and provides specific updates for the new architecture where:

1. **-i flag REMOVED** - Team initialization no longer automatic
2. **-I flag REMOVED** - No interface selection
3. **--use-team-image flag ADDED** - For team members to use pre-built team images
4. **Dockerfile presence determines role** - If exists → team member mode, if not → team lead mode
5. **Team Lead workflow**: `zzcollab -t team -p project` → `make docker-build` → `make docker-push-team`
6. **Team Member workflow**: `git clone` → `zzcollab --use-team-image` → `make docker-zsh`

---

## Section 1: Unified Research Compendium Structure - Usage Examples

**Location**: Lines 162-191
**Status**: CRITICAL - Multiple -i flag references

### Current Content (OUTDATED):
```bash
# With team collaboration
zzcollab -i -t mylab -p study -B rstudio -d ~/dotfiles

# With build mode selection
zzcollab --comprehensive -d ~/dotfiles  # 51 packages - complete toolkit
zzcollab --standard -d ~/dotfiles       # 17 packages - balanced (default)
zzcollab --fast -d ~/dotfiles           # 9 packages - minimal
```

```r
# With team and build mode
init_project(
  team_name = "mylab",
  project_name = "study",
  build_mode = "standard"
)
```

### Proposed Update:
```bash
# Team Lead - Create project structure and team images
zzcollab -t mylab -p study -d ~/dotfiles
make docker-build        # Build team images
make docker-push-team    # Push to Docker Hub

# Team Member - Join existing project
git clone https://github.com/mylab/study.git
cd study
zzcollab --use-team-image -d ~/dotfiles
make docker-zsh         # Start development environment

# Solo Developer - With build mode selection
zzcollab --comprehensive -d ~/dotfiles  # 51 packages - complete toolkit
zzcollab --standard -d ~/dotfiles       # 17 packages - balanced (default)
zzcollab --fast -d ~/dotfiles           # 9 packages - minimal
```

```r
# Team Lead - R Interface
init_project(
  team_name = "mylab",
  project_name = "study",
  build_mode = "standard"
)
# Then: make docker-build && make docker-push-team

# Team Member - R Interface
join_project(
  team_name = "mylab",
  project_name = "study"
)
# Automatically uses team image if available
```

**Changes Required**:
- Remove `-i` flag from team collaboration example
- Add explicit `make docker-build` and `make docker-push-team` steps for team leads
- Add team member workflow with `git clone` → `zzcollab --use-team-image`
- Update R interface examples to reflect new workflow

---

## Section 2: Advanced Configuration System - Configuration Workflows

**Location**: Lines 426-479
**Status**: CRITICAL - Multiple -i and -I flag references

### Current Content (OUTDATED):
```bash
**Solo Developer Setup**:
# 2. Create projects using defaults
zzcollab -i -p data-analysis    # Uses config defaults automatically

**Team Leader Setup**:
# 1. Create team configuration
mkdir team-project && cd team-project
zzcollab -i -p team-project    # Creates base config.yaml

**Team Member Joining**:
# 2. Join with appropriate interface
zzcollab -t team -p team-project -I analysis    # Uses team's analysis profile
make docker-zsh                                 # Start development environment
```

### Proposed Update:
```bash
**Solo Developer Setup**:
# 1. Initialize personal configuration
zzcollab --config init
zzcollab --config set team-name "myteam"
zzcollab --config set build-mode "standard"

# 2. Create projects using defaults
zzcollab -p data-analysis -d ~/dotfiles    # Uses config defaults automatically

# 3. Customize profiles for specific projects
cd data-analysis
./add_profile.sh               # Browse and add specialized environments

**Team Leader Setup**:
# 1. Create team project structure
mkdir team-project && cd team-project
zzcollab -t team -p team-project -d ~/dotfiles    # Creates project + Dockerfile

# 2. Customize team profiles (if needed)
./add_profile.sh               # Add modeling, alpine_minimal for CI/CD
vim Dockerfile                 # Adjust Docker configuration

# 3. Build and share team images
make docker-build              # Build team Docker image
make docker-push-team          # Push to Docker Hub for team

**Team Member Joining**:
# 1. Clone team project
git clone https://github.com/team/team-project.git
cd team-project

# 2. Join using team image
zzcollab --use-team-image -d ~/dotfiles         # Uses pre-built team image
make docker-zsh                                 # Start development environment

**Advanced Custom Variants**:
# 1. Copy and modify existing profile
cp templates/profiles.yaml custom_profiles.yaml
vim custom_profiles.yaml       # Add profiles with specific packages

# 2. Update Dockerfile with custom packages
vim Dockerfile                 # Modify package installation

# 3. Build custom environments
make docker-build
```

**Changes Required**:
- Remove ALL `-i` flags from examples
- Remove ALL `-I` flags from examples
- Add explicit `make docker-build` and `make docker-push-team` for team leads
- Add `zzcollab --use-team-image` for team members
- Update workflow to show Dockerfile-based customization instead of config.yaml profiles

---

## Section 3: Docker Profile System - Modern Workflow Commands

**Location**: Lines 701-726
**Status**: CRITICAL - Heavy use of -i and -I flags

### Current Content (OUTDATED):
```bash
**Team Initialization**:
# Quick start - creates optimal default profiles
zzcollab -i -p myproject --github              # Creates: minimal + analysis profiles

# Custom profiles via config file
zzcollab -i -p myproject             # Creates project + config.yaml
./add_profile.sh                     # Browse and select profiles
zzcollab --profiles-config config.yaml --github  # Build selected profiles

# Legacy approach (limited to 3 profiles)
zzcollab -i -p myproject -B rstudio --github     # Traditional RStudio only

**Solo Developer Workflow**:
# Configuration-based (recommended)
zzcollab --config set team-name "myteam"
zzcollab -i -p research-paper        # Uses config defaults

# Traditional explicit
zzcollab -i -t myteam -p analysis-project -B rstudio -d ~/dotfiles
```

### Proposed Update:
```bash
**Team Lead Workflow**:
# 1. Create project structure
zzcollab -t myteam -p myproject -d ~/dotfiles --github

# 2. Customize Docker image (optional)
vim Dockerfile                       # Modify base image, packages, system dependencies

# 3. Build and push team image
make docker-build                    # Build myteam/myprojectcore:latest
make docker-push-team                # Push to Docker Hub

**Team Member Workflow**:
# 1. Clone project repository
git clone https://github.com/myteam/myproject.git
cd myproject

# 2. Use pre-built team image
zzcollab --use-team-image -d ~/dotfiles

# 3. Start development
make docker-zsh                      # Enter container with team environment

**Solo Developer Workflow**:
# Configuration-based (recommended)
zzcollab --config set team-name "myteam"
zzcollab --config set build-mode "standard"
zzcollab -p research-paper -d ~/dotfiles        # Uses config defaults

# Traditional explicit (no team collaboration)
zzcollab -p analysis-project -d ~/dotfiles      # Creates solo project
```

**Changes Required**:
- Replace `-i` flag with explicit `make docker-build` and `make docker-push-team`
- Remove ALL `-B` flag references (no longer relevant)
- Add `zzcollab --use-team-image` for team members
- Separate team workflows from solo workflows clearly
- Remove references to "profiles-config" (now Dockerfile-based)

---

## Section 4: Solo Developer Workflow - Quick Start and Examples

**Location**: Lines 738-872
**Status**: CRITICAL - Multiple -i and -I references

### Current Content (OUTDATED):
```bash
**2. Project Creation**:
# Quick start - optimal profiles automatically
zzcollab -i -p penguin-analysis --github

# Power users - browse 14+ profiles interactively
mkdir penguin-analysis && cd penguin-analysis
zzcollab -i -p penguin-analysis
./add_profile.sh    # Select from bioinformatics, geospatial, alpine, etc.

**From Solo to Team Transition**:
# Others can join your project immediately
git clone https://github.com/yourname/penguin-analysis.git
cd penguin-analysis
zzcollab -t yourname -p penguin-analysis -I analysis
make docker-zsh    # Same environment, instant collaboration
```

### Proposed Update:
```bash
**2. Project Creation**:
# Quick start - optimal setup automatically
zzcollab -p penguin-analysis -d ~/dotfiles --github

# Power users - customize Docker environment
mkdir penguin-analysis && cd penguin-analysis
zzcollab -p penguin-analysis -d ~/dotfiles
vim Dockerfile      # Customize base image, packages, system dependencies

**From Solo to Team Transition**:
# Convert solo project to team collaboration:
# 1. Set team name in project
zzcollab -t yourname -p penguin-analysis -d ~/dotfiles

# 2. Build and push team image
make docker-build
make docker-push-team

# 3. Others can join immediately
git clone https://github.com/yourname/penguin-analysis.git
cd penguin-analysis
zzcollab --use-team-image -d ~/dotfiles
make docker-zsh    # Same environment, instant collaboration
```

**Changes Required**:
- Remove ALL `-i` flags from project creation
- Remove `-I` flag from team joining example
- Add explicit team image build/push steps for solo → team transition
- Replace "profiles" concept with "Docker environment customization"

---

## Section 5: Development Commands - Profile Management

**Location**: Lines 912-927
**Status**: MODERATE - References to old flag system

### Current Content (OUTDATED):
```bash
### Profile Management (New)
# Interactive profile discovery and addition
./add_profile.sh           # Browse and add profiles from comprehensive library

# Manual profile management
./profiles.yaml    # View all available profile definitions
vim config.yaml            # Edit team profiles (set enabled: true to build)

# Build custom profiles
zzcollab --profiles-config config.yaml              # Build enabled profiles
zzcollab -i -t TEAM -p PROJECT --profiles-config config.yaml  # Team init with custom profiles

# Default behavior (uses config.yaml automatically if use_config_profiles: true)
zzcollab -i -p PROJECT     # Builds default profiles (minimal + analysis)
```

### Proposed Update:
```bash
### Docker Environment Management
# View available base images and package bundles
cat bundles.yaml           # View all available profiles and packages

# Customize Docker environment
vim Dockerfile             # Edit base image, R packages, system dependencies

# Build custom Docker image
make docker-build          # Build team/project-specific image
make docker-push-team      # Share with team (for team lead)

# Team members use pre-built image
zzcollab --use-team-image  # Download and use team's Docker image
```

**Changes Required**:
- Remove ALL references to `--profiles-config`
- Remove `-i` flag from examples
- Replace "profile management" concept with "Docker environment customization"
- Emphasize Dockerfile-based customization instead of config.yaml

---

## Section 6: Core Image Building Workflow

**Location**: Lines 946-1025
**Status**: CRITICAL - Entire section based on old architecture

### Current Content (OUTDATED):
```bash
# NEW: Selective Base Image Building (recommended) - faster, more efficient
# Build only what your team needs:
zzcollab -i -t TEAM -p PROJECT -B r-ver -S -d ~/dotfiles      # Shell only (fastest)
zzcollab -i -t TEAM -p PROJECT -B rstudio -S -d ~/dotfiles    # RStudio only
zzcollab -i -t TEAM -p PROJECT -B verse -S -d ~/dotfiles      # Verse only (publishing)
zzcollab -i -t TEAM -p PROJECT -B all -S -d ~/dotfiles        # All 3 profiles (traditional)

# Skip confirmation prompt for automation/CI:
zzcollab -i -t TEAM -p PROJECT -B rstudio -S -y -d ~/dotfiles # No confirmation prompt

# Combine selective building with build modes:
zzcollab -i -t TEAM -p PROJECT -B rstudio -F -d ~/dotfiles    # RStudio with minimal packages (8)
zzcollab -i -t TEAM -p PROJECT -B all -C -d ~/dotfiles        # All profiles with full packages (27+)

# Incremental approach - start small, add profiles later:
zzcollab -i -t TEAM -p PROJECT -B r-ver -S -d ~/dotfiles      # Start with shell only
# Later, add more profiles as needed:
zzcollab -V rstudio                                            # Add profile
zzcollab -V verse                                              # Add profile for publishing
```

### Proposed Update:
```bash
### Docker Image Building Workflow

**Team Lead - Build and Share Team Image**:
```bash
# 1. Create project with team settings
zzcollab -t TEAM -p PROJECT -d ~/dotfiles

# 2. Customize Docker environment (optional)
vim Dockerfile              # Modify base image (r-ver, rstudio, verse)
                           # Adjust R packages in bundles.yaml reference
                           # Add system dependencies

# 3. Build team Docker image
make docker-build          # Builds TEAM/PROJECTcore:latest

# 4. Share with team
make docker-push-team      # Push to Docker Hub

# Combine with build modes for different package sets:
# Edit Dockerfile to reference different bundle:
# - fast-bundle (9 packages, 2-3 minutes)
# - standard-bundle (17 packages, 4-6 minutes) [default]
# - comprehensive-bundle (47+ packages, 15-20 minutes)
```

**Team Member - Use Pre-Built Team Image**:
```bash
# 1. Clone team project
git clone https://github.com/TEAM/PROJECT.git
cd PROJECT

# 2. Use team's Docker image
zzcollab --use-team-image -d ~/dotfiles

# 3. Start development
make docker-zsh            # Enter container with team environment
```

**Solo Developer - Build Personal Image**:
```bash
# 1. Create project (no team)
zzcollab -p PROJECT -d ~/dotfiles

# 2. Customize if needed
vim Dockerfile             # Adjust packages, base image

# 3. Build image
make docker-build          # Builds personal Docker image
```

**Changes Required**:
- Remove ALL `-i` flags
- Remove ALL `-B` flags (base image selection)
- Remove ALL `-V` flags (variant addition)
- Replace with Dockerfile-based customization
- Add explicit `make docker-build` and `make docker-push-team` commands
- Add `zzcollab --use-team-image` for team members

---

## Section 7: Team Collaboration Setup

**Location**: Lines 1027-1068
**Status**: CRITICAL - Core team workflow documentation

### Current Content (OUTDATED):
```bash
# Developer 1 (Team Lead) - Team Image Creation Only
# Step 1: Create and push team Docker images (this is all -i does now)
zzcollab -i -t TEAM -p PROJECT -B r-ver -F -d ~/dotfiles      # Creates TEAM/PROJECTcore-shell:latest only
zzcollab -i -t TEAM -p PROJECT -B rstudio -S -d ~/dotfiles    # Creates TEAM/PROJECTcore-rstudio:latest only
zzcollab -i -t TEAM -p PROJECT -B all -C -d ~/dotfiles        # Creates all profiles (shell, rstudio, verse)

# Step 2: Create full project structure (run separately)
mkdir PROJECT && cd PROJECT  # or git clone if repo exists
zzcollab -t TEAM -p PROJECT -I shell -d ~/dotfiles            # Full project setup with shell interface

# Add profiles later (incremental workflow)
zzcollab -V rstudio                                            # Add profile
zzcollab -V verse                                              # Add profile

# Developer 2+ (Team Members) - Join Existing Project
git clone https://github.com/TEAM/PROJECT.git                 # Clone existing project
cd PROJECT
# Choose available interface:
zzcollab -t TEAM -p PROJECT -I shell -d ~/dotfiles             # Command-line development
zzcollab -t TEAM -p PROJECT -I rstudio -d ~/dotfiles           # RStudio Server (if profile available)
zzcollab -t TEAM -p PROJECT -I verse -d ~/dotfiles             # Publishing workflow (if profile available)

# Error handling: If team image profile not available, you'll get helpful guidance:
# Error: Team image 'TEAM/PROJECTcore-rstudio:latest' not found
# Available profiles for this project:
#     - TEAM/PROJECTcore-shell:latest
# Solutions:
#    1. Use available profile: zzcollab -t TEAM -p PROJECT -I shell -d ~/dotfiles
#    2. Ask team lead to build rstudio profile: zzcollab -V rstudio
```

### Proposed Update:
```bash
### Team Collaboration Setup

**Developer 1 (Team Lead) - Complete Workflow**:
```bash
# Step 1: Create project structure with team settings
zzcollab -t TEAM -p PROJECT -d ~/dotfiles

# Step 2: Customize Docker environment (optional)
cd PROJECT
vim Dockerfile              # Modify base image: rocker/r-ver, rocker/rstudio, rocker/verse
vim bundles.yaml            # Adjust R package selection if needed

# Step 3: Build team Docker image
make docker-build          # Builds TEAM/PROJECTcore:latest

# Step 4: Share with team
make docker-push-team      # Push to Docker Hub

# Step 5: Commit and push project
git add .
git commit -m "Initial project setup"
git push
```

**Developer 2+ (Team Members) - Join Existing Project**:
```bash
# Step 1: Clone team project
git clone https://github.com/TEAM/PROJECT.git
cd PROJECT

# Step 2: Use team's pre-built Docker image
zzcollab --use-team-image -d ~/dotfiles

# Step 3: Start development environment
make docker-zsh            # Enter container (command-line)
# OR
make docker-rstudio        # Start RStudio Server at localhost:8787

# That's it! You're using the exact same environment as the team lead.
```

**Environment Customization (Team Lead)**:
```bash
# If team needs different packages or base images:
vim Dockerfile             # Change FROM rocker/rstudio to rocker/verse for LaTeX
                          # Modify COPY --from lines to reference different bundles
                          # Add system dependencies with apt-get

# Rebuild and share
make docker-build
make docker-push-team

# Team members update their images:
docker pull TEAM/PROJECTcore:latest
make docker-zsh            # Automatically uses updated image
```

**Error Handling**:
```bash
# If team member cannot pull team image:
# Error: Unable to pull TEAM/PROJECTcore:latest from Docker Hub

# Solutions:
#    1. Ask team lead to verify image was pushed: make docker-push-team
#    2. Check Docker Hub permissions (image must be public or you need access)
#    3. Build image locally if needed: make docker-build
```

**Changes Required**:
- Remove ALL `-i` flags (team initialization)
- Remove ALL `-I` flags (interface selection)
- Remove ALL `-B` flags (base image selection)
- Remove ALL `-V` flags (variant addition)
- Add explicit `make docker-build` and `make docker-push-team` commands
- Add `zzcollab --use-team-image` for team members
- Update error handling to reflect new architecture
- Emphasize Dockerfile customization instead of profile selection

---

## Section 8: Selective Base Image Building System (Recent Enhancements)

**Location**: Lines 1177-1206
**Status**: CRITICAL - Entire section describes removed functionality

### Current Content (OUTDATED):
```bash
### Selective Base Image Building System
Major improvement to team initialization workflow with selective base image building:

**New Features:**
- **Selective building**: Teams can build only needed profiles (r-ver, rstudio, verse) instead of all
- **Incremental workflow**: Start with one profile, add others later with `-V` flag
- **Enhanced error handling**: Helpful guidance when team members request unavailable profiles
- **Short flags**: All major options now have one-letter shortcuts (-i, -t, -p, -I, -B, -V)
- **Verse support**: Publishing workflow with LaTeX support via rocker/verse
- **Team communication**: Clear coordination between team leads and members about available tooling

**CLI Improvements:**
```bash
# New selective base image flags
-B, --init-base-image TYPE   # r-ver, rstudio, verse, all (for team initialization)
-V, -V TYPE     # r-ver, rstudio, verse (for adding profiles later)
-I, --interface TYPE         # shell, rstudio, verse (for team members joining)

# Examples
zzcollab -i -t mylab -p study -B rstudio -S -d ~/dotfiles    # RStudio only
zzcollab -V verse                                             # Add profile later
zzcollab -t mylab -p study -I shell -d ~/dotfiles           # Join with shell interface
```

### Proposed Update:
```bash
### Docker Image Customization System
Complete Dockerfile-based customization for team and solo projects:

**Key Features:**
- **Dockerfile-based**: Full control over base image, packages, and system dependencies
- **Bundle system**: Pre-defined package collections in bundles.yaml
- **Multi-stage builds**: Efficient layer caching for faster rebuilds
- **Team image sharing**: Simple push/pull workflow via Docker Hub
- **Build mode support**: Fast (9 packages), Standard (17 packages), Comprehensive (47+ packages)

**Dockerfile Customization:**
```bash
# Team leads customize Dockerfile directly:
vim Dockerfile

# Change base image (line ~10):
FROM rocker/r-ver:latest       # Shell-only, lightweight
FROM rocker/rstudio:latest     # RStudio Server included
FROM rocker/verse:latest       # Publishing workflow with LaTeX

# Change package bundle (line ~50):
COPY --from=bundles fast-bundle /       # 9 packages (2-3 min)
COPY --from=bundles standard-bundle /   # 17 packages (4-6 min)
COPY --from=bundles comprehensive-bundle /  # 47+ packages (15-20 min)

# Add system dependencies (line ~30):
RUN apt-get update && apt-get install -y \
    libgdal-dev \      # Geospatial packages
    libproj-dev \
    libgeos-dev

# Build and share:
make docker-build
make docker-push-team
```

**Team Workflow:**
```bash
# Team Lead:
zzcollab -t mylab -p study -d ~/dotfiles
vim Dockerfile             # Customize as needed
make docker-build
make docker-push-team

# Team Members:
git clone https://github.com/mylab/study.git
cd study
zzcollab --use-team-image -d ~/dotfiles
make docker-zsh
```

**Changes Required**:
- Replace entire section with Dockerfile-based approach
- Remove ALL mentions of `-i`, `-I`, `-B`, `-V` flags
- Emphasize Dockerfile customization over flag-based configuration
- Update examples to use `make docker-build` and `zzcollab --use-team-image`

---

## Section 9: Revolutionary Docker Profile Management System

**Location**: Lines 1207-1269
**Status**: CRITICAL - Describes old config.yaml profile system

### Current Content (OUTDATED):
This entire section describes the config.yaml-based profile system with `enabled: true` flags and `--profiles-config` usage.

### Proposed Update:
```bash
### Simplified Docker Environment System
ZZCOLLAB uses Dockerfile-based customization with pre-defined package bundles:

**Bundle System (bundles.yaml)**:
```yaml
# Fast bundle - 9 essential packages (2-3 minutes)
fast-bundle:
  packages:
    - renv
    - remotes
    - here
    - usethis
    - devtools
    - testthat
    - knitr
    - rmarkdown
    - targets

# Standard bundle - 17 balanced packages (4-6 minutes, default)
standard-bundle:
  packages:
    - [all fast-bundle packages]
    - dplyr
    - ggplot2
    - tidyr
    - palmerpenguins
    - broom
    - janitor
    - DT
    - conflicted

# Comprehensive bundle - 47+ full ecosystem (15-20 minutes)
comprehensive-bundle:
  packages:
    - [all standard-bundle packages]
    - tidymodels
    - shiny
    - plotly
    - quarto
    - flexdashboard
    - survival
    - lme4
    - [database connectors, parallel processing]
```

**Dockerfile Customization**:
```dockerfile
# Team leads modify Dockerfile to select bundle and base image:

# 1. Choose base image (line ~10):
FROM rocker/rstudio:latest    # RStudio Server
# FROM rocker/r-ver:latest    # Shell-only
# FROM rocker/verse:latest    # Publishing with LaTeX

# 2. Choose package bundle (line ~50):
COPY --from=bundles standard-bundle /   # Default
# COPY --from=bundles fast-bundle /      # Minimal
# COPY --from=bundles comprehensive-bundle /  # Full

# 3. Add custom packages (optional, line ~60):
RUN Rscript -e "install.packages(c('sf', 'terra', 'leaflet'))"

# 4. Add system dependencies (optional, line ~30):
RUN apt-get update && apt-get install -y \
    libgdal-dev \
    libproj-dev
```

**Workflow**:
```bash
# Team Lead:
zzcollab -t team -p project -d ~/dotfiles
vim Dockerfile             # Select bundle, base image, add custom packages
make docker-build
make docker-push-team

# Team Members:
git clone https://github.com/team/project.git
cd project
zzcollab --use-team-image -d ~/dotfiles
make docker-zsh
```

**Key Benefits**:
- **Single source of truth**: Dockerfile defines entire environment
- **Full Docker control**: Use any base image, add any package
- **Efficient caching**: Multi-stage builds for fast rebuilds
- **Easy sharing**: One command to push, one flag to use team image
- **Transparent**: Team sees exact Dockerfile configuration

**Changes Required**:
- Replace entire profile system section with bundle system documentation
- Remove all config.yaml references
- Remove `--profiles-config` flag
- Add Dockerfile customization examples
- Emphasize bundles.yaml as package catalog, Dockerfile as configuration

---

## Section 10: R Package Integration

**Location**: Lines 1316-1380
**Status**: HIGH - R interface functions need architecture update

### Current Content (OUTDATED):
```r
# Team Lead with build modes
init_project(team_name = "mylab", project_name = "study", build_mode = "fast")
init_project(team_name = "mylab", project_name = "paper", build_mode = "standard")

# Team Member with build modes
join_project(team_name = "mylab", project_name = "study", build_mode = "comprehensive")

# R-Centric Workflow (Enhanced with Configuration)
# Method 1: Using Configuration (Recommended)
library(zzcollab)

# One-time setup for team lead
init_config()                                      # Initialize config file
set_config("team_name", "TEAM")                    # Set team name
set_config("build_mode", "standard")               # Set preferred mode
set_config("dotfiles_dir", "~/dotfiles")           # Set dotfiles path

# Developer 1 (Team Lead) - Simplified with config
init_project(project_name = "PROJECT")             # Uses config defaults (team, mode)

# Developer 2+ (Team Members) - Simplified with config
set_config("team_name", "TEAM")                    # Match team settings
join_project(project_name = "PROJECT", interface = "shell")  # Uses config defaults

# Method 2: Traditional Explicit Parameters
library(zzcollab)
# Developer 1 (Team Lead) - R Interface with build modes
init_project(
  team_name = "TEAM",
  project_name = "PROJECT",
  build_mode = "standard",  # "fast", "standard", "comprehensive"
  dotfiles_path = "~/dotfiles"
)

# Developer 2+ (Team Members) - R Interface with build modes
join_project(
  team_name = "TEAM",
  project_name = "PROJECT",
  interface = "shell",  # or "rstudio" or "verse"
  build_mode = "fast",  # matches team's preferred mode
  dotfiles_path = "~/dotfiles"
)
```

### Proposed Update:
```r
# Team Lead - R Interface
library(zzcollab)

# Method 1: Using Configuration (Recommended)
init_config()                                      # Initialize config file
set_config("team_name", "TEAM")                    # Set team name
set_config("build_mode", "standard")               # Set preferred mode
set_config("dotfiles_dir", "~/dotfiles")           # Set dotfiles path

init_project(project_name = "PROJECT")             # Uses config defaults
# Then build and push team image:
system("make docker-build")
system("make docker-push-team")

# Method 2: Traditional Explicit Parameters
init_project(
  team_name = "TEAM",
  project_name = "PROJECT",
  build_mode = "standard",
  dotfiles_path = "~/dotfiles"
)
# Then build and push team image:
system("make docker-build")
system("make docker-push-team")

# Team Member - R Interface
library(zzcollab)

# Join existing project
join_project(
  team_name = "TEAM",
  project_name = "PROJECT",
  use_team_image = TRUE,      # Use pre-built team image
  dotfiles_path = "~/dotfiles"
)

# Or with config:
set_config("team_name", "TEAM")
join_project(project_name = "PROJECT", use_team_image = TRUE)

# Start development
system("make docker-zsh")     # Command-line
# OR
system("make docker-rstudio") # RStudio Server

# Full R workflow support (no changes needed)
add_package("tidyverse")
git_commit("Add analysis")
create_pr("New feature")
```

**Changes Required**:
- Remove `interface` parameter from `join_project()`
- Add `use_team_image` parameter to `join_project()`
- Add explicit `system("make docker-build")` and `system("make docker-push-team")` calls after `init_project()`
- Update `join_project()` to use `--use-team-image` flag internally
- Remove all references to "interface" selection in R functions

---

## Section 11: Default Base Image Change

**Location**: Lines 1382-1404
**Status**: MODERATE - Historical documentation, may be removable

### Current Content (OUTDATED):
```bash
### Default Base Image Change (August 2025)
**Change**: Modified default base image from "all" to "r-ver" for faster, more efficient builds.

**Impact**:
# Old behavior (built all 3 profiles by default):
zzcollab -i -t mylab -p study    # Built shell + rstudio + verse

# New behavior (builds shell-only by default):
zzcollab -i -t mylab -p study    # Builds shell only (faster)
zzcollab -i -t mylab -p study -B all  # Explicit flag for all profiles
```

### Proposed Update:
```bash
### Dockerfile-Based Architecture (October 2025)
**Major Change**: Replaced flag-based profile selection with Dockerfile-based customization.

**Old Architecture** (deprecated):
```bash
zzcollab -i -t mylab -p study -B rstudio    # Flag-based profile selection
```

**New Architecture** (current):
```bash
# Team Lead:
zzcollab -t mylab -p study -d ~/dotfiles
vim Dockerfile              # Edit base image: rocker/r-ver, rocker/rstudio, rocker/verse
make docker-build
make docker-push-team

# Team Member:
git clone https://github.com/mylab/study.git
cd study
zzcollab --use-team-image -d ~/dotfiles
make docker-zsh
```

**Benefits**:
- **Full Docker control**: Any base image, any packages
- **Transparent configuration**: Dockerfile shows exact environment
- **Simpler CLI**: No complex flag combinations
- **Better team coordination**: One Dockerfile, one team image

**Changes Required**:
- Replace historical flag change documentation with architecture migration explanation
- Remove references to `-i`, `-B` flags
- Add new architecture workflow examples

---

## Section 12: Critical Bug Fix: -i Flag Behavior

**Location**: Lines 1406-1436
**Status**: CRITICAL - Entire section about deprecated flag

### Current Content (OUTDATED):
This entire section documents the behavior of the `-i` flag which has been removed.

### Proposed Update:
```bash
### Architecture Simplification: Removed -i and -I Flags (October 2025)
**Change**: Removed `-i` (team initialization) and `-I` (interface selection) flags in favor of Dockerfile-based architecture.

**Rationale**:
- **Complexity reduction**: Flag-based profile selection was confusing
- **Docker best practices**: Dockerfile as single source of truth
- **Simpler team workflow**: Build image → push → pull pattern is standard Docker
- **Better transparency**: Team members see exact Dockerfile configuration

**Migration**:
```bash
# OLD (deprecated):
zzcollab -i -t mylab -p study -B rstudio -S
mkdir study && cd study
zzcollab -t mylab -p study -I rstudio -S

# NEW (current):
zzcollab -t mylab -p study -d ~/dotfiles
vim Dockerfile              # Customize if needed
make docker-build
make docker-push-team
```

**Team Member Migration**:
```bash
# OLD (deprecated):
git clone https://github.com/mylab/study.git
cd study
zzcollab -t mylab -p study -I rstudio -d ~/dotfiles

# NEW (current):
git clone https://github.com/mylab/study.git
cd study
zzcollab --use-team-image -d ~/dotfiles
make docker-zsh    # or make docker-rstudio
```

**Changes Required**:
- Replace entire bug fix section with architecture migration explanation
- Document OLD → NEW migration path
- Remove all references to `-i` and `-I` flags

---

## Section 13: ARM64 Compatibility Issues

**Location**: Lines 1438-1461
**Status**: LOW - Minor flag reference

### Current Content (OUTDATED):
```bash
1. **Use compatible base images only**:
   zzcollab -i -t TEAM -p PROJECT -B r-ver,rstudio -S    # Skip verse
```

### Proposed Update:
```bash
1. **Use compatible base images**:
   # Edit Dockerfile and change base image:
   FROM rocker/rstudio:latest    # ARM64 compatible
   # Avoid: FROM rocker/verse:latest (AMD64 only)

   make docker-build
```

**Changes Required**:
- Remove `-i` and `-B` flags from example
- Add Dockerfile editing approach

---

## Section 14: Vignette System Documentation - R Interface Examples

**Location**: Lines 1739-1753
**Status**: HIGH - R interface examples

### Current Content (OUTDATED):
```r
# Solo workflow - feels like regular R development
library(zzcollab)
init_project("my-analysis")        # Creates reproducible project
start_rstudio()                    # Opens RStudio at localhost:8787
# ... familiar R development in RStudio ...
git_commit("Add analysis")         # Version control through R
git_push()                         # Sharing through R

# Team workflow - effective collaboration
init_project("team-project", team_name = "lab")  # Team lead setup
join_project("lab", "team-project")              # Team members join
start_rstudio()                                   # Identical environments
```

### Proposed Update:
```r
# Solo workflow - feels like regular R development
library(zzcollab)
init_project("my-analysis")        # Creates reproducible project
system("make docker-build")        # Build Docker image
start_rstudio()                    # Opens RStudio at localhost:8787
# ... familiar R development in RStudio ...
git_commit("Add analysis")         # Version control through R
git_push()                         # Sharing through R

# Team workflow - effective collaboration
init_project("team-project", team_name = "lab")  # Team lead setup
system("make docker-build")                      # Build team image
system("make docker-push-team")                  # Share with team

# Team members join:
join_project("lab", "team-project", use_team_image = TRUE)  # Uses pre-built image
start_rstudio()                                             # Identical environment
```

**Changes Required**:
- Add `system("make docker-build")` after `init_project()`
- Add `system("make docker-push-team")` for team leads
- Add `use_team_image = TRUE` parameter to `join_project()`
- Update comments to reflect new workflow

---

## Summary of Required Changes

### Flag Removals (Complete Elimination):
1. **-i flag**: Remove from ALL examples (50+ occurrences)
2. **-I flag**: Remove from ALL examples (15+ occurrences)
3. **-B flag**: Remove from ALL examples (30+ occurrences)
4. **-V flag**: Remove from ALL examples (5+ occurrences)
5. **--profiles-config**: Remove from ALL examples (5+ occurrences)

### New Flag Additions:
1. **--use-team-image**: Add to ALL team member workflows (20+ locations)

### Workflow Updates:
1. **Team Lead**: Add `make docker-build` + `make docker-push-team` (15+ locations)
2. **Team Member**: Add `git clone` → `zzcollab --use-team-image` → `make docker-zsh` (10+ locations)
3. **Dockerfile customization**: Replace config.yaml profile examples (8+ locations)
4. **Bundle system**: Add bundles.yaml documentation (3+ locations)

### R Interface Updates:
1. **init_project()**: Add `system("make docker-build")` calls after
2. **join_project()**: Add `use_team_image` parameter, remove `interface` parameter
3. **R workflow examples**: Update 5+ code blocks

### Documentation Structure:
1. **Remove sections**: "Selective Base Image Building System" (deprecated)
2. **Replace sections**: "Revolutionary Docker Profile Management" → "Simplified Docker Environment System"
3. **Update sections**: "Critical Bug Fix: -i Flag" → "Architecture Simplification"
4. **Add sections**: "Bundle System Documentation", "Dockerfile Customization Guide"

### Estimated Total Changes:
- **Lines to modify**: 150+
- **Sections to rewrite**: 8 major sections
- **Code blocks to update**: 40+
- **Flag removals**: 100+ occurrences
- **New workflow additions**: 30+ examples

---

## Recommended Implementation Order

1. **Phase 1: Critical Workflow Sections** (Highest priority)
   - Section 1: Usage Examples (lines 162-191)
   - Section 6: Core Image Building (lines 946-1025)
   - Section 7: Team Collaboration Setup (lines 1027-1068)

2. **Phase 2: Configuration and Profile System** (High priority)
   - Section 2: Configuration Workflows (lines 426-479)
   - Section 3: Modern Workflow Commands (lines 701-726)
   - Section 9: Docker Profile Management (lines 1207-1269)

3. **Phase 3: Solo Developer and Examples** (Medium priority)
   - Section 4: Solo Developer Workflow (lines 738-872)
   - Section 14: Vignette Examples (lines 1739-1753)

4. **Phase 4: R Interface and Integration** (Medium priority)
   - Section 10: R Package Integration (lines 1316-1380)

5. **Phase 5: Historical and Minor Updates** (Low priority)
   - Section 5: Profile Management (lines 912-927)
   - Section 8: Selective Base Image System (lines 1177-1206)
   - Section 11: Default Base Image Change (lines 1382-1404)
   - Section 12: Critical Bug Fix (lines 1406-1436)
   - Section 13: ARM64 Compatibility (lines 1438-1461)

---

## End of Report
