# Configuration Guide

## Overview

ZZCOLLAB implements a sophisticated multi-layered configuration system that enables teams and individuals to establish consistent defaults while maintaining flexibility for project-specific requirements. This guide provides comprehensive documentation of configuration architecture, file formats, and usage patterns.

## Configuration Philosophy

### Design Principles

The configuration system adheres to four key principles:

1. **Hierarchy**: Project-specific settings override user defaults, which override system defaults
2. **Transparency**: All configuration decisions are explicit and traceable
3. **Flexibility**: Users can customize any aspect while maintaining sensible defaults
4. **Reproducibility**: Configuration files are version-controlled and portable

### Configuration Domains

ZZCOLLAB configuration spans three distinct domains:

- **Docker Profile Management**: Selection of one of three built-in profiles (minimal, analysis, rstudio), or any base image via `zzcollab docker --base-image <image>`
- **Package Management**: Dynamic via standard `install.packages()` inside containers with auto-snapshot/auto-restore
- **Development Settings**: Team collaboration preferences and automation options

## CLI Flag Reference

Flags are either global (valid in any position) or scoped to a specific command. Project and team identity are no longer flags: the project name is the working directory, and the team/GitHub accounts are stored via `zzcollab config set`.

### Global flags (valid in any position)

| Short | Long Flag    | Purpose                           |
|-------|--------------|-----------------------------------|
| `-v`  | `--verbose`  | Verbose output                    |
| `-q`  | `--quiet`    | Quiet mode (errors only)          |
| `-y`  | `--yes`      | Accept defaults (non-interactive) |
| `-Y`  | `--yes-all`  | Same as `--yes`                   |
|       | `--no-build` | Skip the Docker build prompt      |
|       | `--version`  | Print version and exit            |
| `-h`  | `--help`     | Show help (also `help <topic>`)   |

### Per-command flags

| Command            | Short | Long Flag          | Purpose                                  |
|--------------------|-------|--------------------|------------------------------------------|
| `docker`           | `-b`  | `--build`          | Build the image after generating         |
| `docker`           | `-r`  | `--profile <name>` | Select the profile (minimal, analysis, …) |
| `docker`           |       | `--base-image <img>` | Override the base image (default `rocker/r-ver`) |
| `docker`           |       | `--r-version <ver>`  | Pin the R version                      |
| `renv`             |       | `--r-version <ver>`  | Pin the R version for the lockfile     |
| `dockerhub`        | `-t`  | `--tag <tag>`      | DockerHub image tag (default `latest`)   |
| `github`           |       | `--private`        | Create a private repository (default)    |
| `github`           |       | `--public`         | Create a public repository               |
| `rebuild`          |       | `--no-cache`       | Force a full rebuild (skip the cache check) |
| `rebuild`          |       | `--log`            | Save build output to `docker-build.log`  |
| `rm`, `uninstall`  | `-f`  | `--force`          | Skip the confirmation prompt             |
| `uninstall`        | `-n`  | `--dry-run`        | Show what would be removed without removing |

Profile selection is primarily positional (`zzcollab analysis`); `-r`/`--profile` is the same selection scoped to the `docker` command. `config` is a subcommand, not a flag: `config init | set | get | list | validate`.

### Usage Examples

**Create a project with a profile** (run inside the project directory):
```bash
mkdir study && cd study
zzcollab analysis
```

**Select a different profile or base image**:
```bash
zzcollab docker --base-image rocker/verse
zzcollab docker --base-image rocker/shiny
```

### Where settings live

ZZCOLLAB draws one consistent line between flags and configuration:

- **Per-build overrides are flags.** Values that pertain to a single build of a single project are flags on the relevant command: `--base-image`, `--r-version`, `--profile` (and `--tag` for the image push).
- **Durable identity is configuration.** Values reused across projects live in config and have no flag: the DockerHub account (`config set dockerhub-account`) and the GitHub account (`config set github-account`).
- **The project name is the working directory.** It is neither a flag nor a config value.

## Configuration Hierarchy

### Six-Level Precedence

Configuration values are resolved through a hierarchical precedence system:

```
Priority 1: Command-line flags (--profile, --base-image, --r-version)
    ↓ (overrides)
Priority 2: Environment variables (ZZCOLLAB_PROFILE_NAME, etc.)
    ↓ (overrides)
Priority 3: Project config (./zzcollab.yaml)
    ↓ (overrides)
Priority 4: User config (~/.zzcollab/config.yaml)
    ↓ (overrides)
Priority 5: System config (/etc/zzcollab/config.yaml)
    ↓ (overrides)
Priority 6: Built-in defaults (hardcoded fallbacks)
```

### Resolution Examples

**Scenario 1: Profile Resolution**

```bash
# User config: profile_name: minimal
# Command-line: --profile analysis
# Result: analysis profile (command-line overrides config)

mkdir study && cd study
zzcollab docker --profile analysis
```

**Scenario 2: Team Name Resolution**

```bash
# No command-line flag
# User config: team_name: "mylab"
# Result: "mylab" (from user config)

mkdir study && cd study
zzcollab analysis
```

**Scenario 3: Custom Composition**

```bash
# Use the analysis profile (run inside the project directory)
mkdir research && cd research
zzcollab analysis
```

## Configuration Files

### User Configuration

**Location**: `~/.zzcollab/config.yaml`

**Purpose**: Personal defaults for all projects

**Typical Contents**:

```yaml
#=========================================================
# USER CONFIGURATION
#=========================================================
# Personal defaults applied to all zzcollab projects

defaults:
  # Team and account settings
  team_name: "mylab"
  github_account: "myusername"
  dockerhub_account: "myusername"  # Defaults to team_name if not set

  # Docker profile selection
  profile_name: "analysis"          # Default profile for new projects
  # Alternative: Specify bundles
  # libs_bundle: "minimal"
  # pkgs_bundle: "tidyverse"

  # R version (for Docker builds)
  r_version: "4.4.0"                # Default R version for all projects

  # Automation preferences
  auto_github: false                # Automatically create GitHub repos
  skip_confirmation: false          # Skip confirmation prompts

#=========================================================
# DOCKER PLATFORM (Optional)
#=========================================================
# Platform architecture for Docker builds

docker:
  platform: "auto"                  # auto, amd64, arm64, native
```

### Project Configuration

**Location**: `./zzcollab.yaml` (project root)

**Purpose**: Team-specific settings for collaborative projects

**Typical Contents**:

```yaml
#=========================================================
# TEAM PROJECT CONFIGURATION
#=========================================================
# Shared configuration for team collaboration

team:
  name: "datasci-lab"
  project: "customer-churn-analysis"
  description: "Machine learning analysis of customer retention patterns"
  maintainer: "Dr. Smith <smith@university.edu>"
  created: "2024-01-15"

#=========================================================
# DOCKER PROFILE
#=========================================================
# Specify Docker environment for team

docker_profile:
  # Option 1: Use predefined profile
  profile_name: "analysis"

  # Option 2: Custom composition with bundles
  # base_image: "rocker/r-ver"
  # libs: "minimal"
  # pkgs: "tidyverse"

#=========================================================
# BUILD CONFIGURATION
#=========================================================

build:
  # Docker build settings
  docker:
    platform: "auto"                # auto, linux/amd64, linux/arm64
    no_cache: false
    parallel_builds: true

  # Package installation settings
  packages:
    repos: "https://cran.rstudio.com/"
    install_suggests: false
    dependencies:
      - Depends
      - Imports
      - LinkingTo

#=========================================================
# TEAM COLLABORATION
#=========================================================

collaboration:
  # GitHub integration
  github:
    auto_create_repo: false
    default_visibility: "private"
    enable_actions: true
    required_reviews: 1

  # Container settings
  container:
    default_user: "analyst"
    working_dir: "/home/analyst/project"
    shared_volumes:
      - "${HOME}/data:/data:ro"     # Read-only data mount

#=========================================================
# QUALITY ASSURANCE
#=========================================================

quality:
  # Testing requirements
  testing:
    min_coverage: 90
    required_tests:
      - unit
      - integration

  # Code standards
  standards:
    max_function_length: 50
    max_file_length: 300
    style_guide: "tidyverse"
```

### System Configuration

**Location**: `/etc/zzcollab/config.yaml`

**Purpose**: Organization-wide defaults

**Typical Contents**:

```yaml
#=========================================================
# ORGANIZATION CONFIGURATION
#=========================================================
# System-wide defaults for entire organization

defaults:
  # Organization settings
  github_org: "university-research"
  docker_registry: "registry.university.edu"

  # Standard Docker profile
  profile_name: "analysis"

  # Networking
  proxy: "http://proxy.university.edu:8080"

  # Resource limits
  max_memory: "8GB"
  max_cpus: 4

# Mandatory package requirements
required_packages:
  - renv
  - here
  - testthat

# Security policies
security:
  require_signed_commits: true
  allowed_repositories:
    - "https://cran.rstudio.com/"
    - "https://cran.r-project.org/"
```

## Configuration Commands

### Initialization

```bash
# Create user configuration file with defaults
zzcollab config init

# Create user configuration in custom location
ZZCOLLAB_CONFIG_USER=~/custom/config.yaml zzcollab config init
```

### Setting Values

```bash
# Set single values
zzcollab config set team-name "mylab"
zzcollab config set github-account "myusername"
zzcollab config set profile-name "analysis"

# Set boolean values
zzcollab config set auto-github true
zzcollab config set skip-confirmation false

# Force the Docker build platform (Docker's own env var, not a config key)
export DOCKER_DEFAULT_PLATFORM=linux/amd64
```

### Getting Values

```bash
# Get single values
zzcollab config get team-name
zzcollab config get profile-name

# Get all configuration
zzcollab config list
```

### Validation

```bash
# Validate YAML syntax and required fields
zzcollab config validate

# Validate specific config file
zzcollab config validate ./zzcollab.yaml
```

### Configuration Inspection

```bash
# List the merged configuration (resolved hierarchy)
zzcollab config list

# Read a single resolved value
zzcollab config get profile-name
```

## Configuration Parameters

### Required Parameters

**team_name**

- **Type**: String
- **Description**: Team identifier for Docker images and collaboration
- **Example**: `"datasci-lab"`
- **Used in**: Docker image naming (`datasci-lab/project:latest`)

**project_name**

- **Type**: String
- **Description**: Project identifier
- **Example**: `"customer-churn"`
- **Used in**: Docker image naming, directory naming

### Optional Parameters

**github_account**

- **Type**: String
- **Description**: GitHub username or organization
- **Default**: Current user
- **Example**: `"myusername"`

**dockerhub_account**

- **Type**: String
- **Description**: Docker Hub username
- **Default**: Same as team_name
- **Example**: `"myorganization"`

**profile_name**

- **Type**: String
- **Values**: `minimal`, `analysis`, `rstudio`
- **Default**: `minimal`
- **Description**: Predefined Docker environment profile

**base_image** (for custom composition)

- **Type**: String
- **Description**: Docker base image
- **Default**: `rocker/r-ver`
- **Example**: `"bioconductor/bioconductor_docker"`

**libs_bundle** (for custom composition)

- **Type**: String
- **Values**: `none`, `minimal`, `terminals`
- **Description**: System library bundle (defined in `templates/bundles.yaml`)
- **Example**: `"minimal"`

**pkgs_bundle** (for custom composition)

- **Type**: String
- **Values**: `minimal`, `tidyverse`
- **Description**: R package bundle (defined in `templates/bundles.yaml`)
- **Example**: `"tidyverse"`

**auto_github**

- **Type**: Boolean
- **Description**: Automatically create GitHub repositories
- **Default**: `false`
- **Example**: `true`

**skip_confirmation**

- **Type**: Boolean
- **Description**: Skip confirmation prompts
- **Default**: `false`
- **Example**: `true`

## Environment Variables

### Configuration Override Variables

**ZZCOLLAB_PROFILE_NAME**

- **Description**: Override Docker profile
- **Values**: Profile names (minimal, analysis, rstudio)
- **Example**: `export ZZCOLLAB_PROFILE_NAME=analysis`

**ZZCOLLAB_TEAM_NAME**

- **Description**: Override team name
- **Example**: `export ZZCOLLAB_TEAM_NAME=mylab`

**ZZCOLLAB_PROJECT_NAME**

- **Description**: Override project name
- **Example**: `export ZZCOLLAB_PROJECT_NAME=study`

### Configuration Path Variables

**ZZCOLLAB_CONFIG_USER**

- **Description**: Override user config file location
- **Default**: `~/.zzcollab/config.yaml`
- **Example**: `export ZZCOLLAB_CONFIG_USER=~/custom/config.yaml`

**ZZCOLLAB_CONFIG_PROJECT**

- **Description**: Override project config file location
- **Default**: `./zzcollab.yaml`
- **Example**: `export ZZCOLLAB_CONFIG_PROJECT=./custom.yaml`

**ZZCOLLAB_CONFIG_SYSTEM**

- **Description**: Override system config file location
- **Default**: `/etc/zzcollab/config.yaml`
- **Example**: `export ZZCOLLAB_CONFIG_SYSTEM=/opt/zzcollab/config.yaml`

## Configuration Workflows

### Solo Developer Workflow

**Initial Setup**:

```bash
# 1. Create user configuration
zzcollab config init

# 2. Set personal defaults
zzcollab config set team-name "myusername"
zzcollab config set profile-name "analysis"

# 3. Verify configuration
zzcollab config list
```

**Project Creation**:

```bash
# Configuration is automatically applied
mkdir research-project && cd research-project
zzcollab
make docker-build

# Override profile for a specific project
mkdir genomics && cd genomics
zzcollab analysis

# Custom base image
mkdir spatial && cd spatial
zzcollab docker --base-image rocker/r-ver
```

### Team Leader Workflow

**Team Configuration Setup**:

```bash
# 1. Record the team DockerHub account (one-time)
zzcollab config set dockerhub-account lab

# 2. Create the project with a Docker profile
mkdir study && cd study
zzcollab analysis

# 3. Push the team image to Docker Hub
zzcollab dockerhub

# 4. Commit configuration to the repository
git add zzcollab.yaml Dockerfile
git commit -m "Initial setup with analysis profile"
git push
```

**Team Member Workflow**:

```bash
# 1. Clone project
git clone https://github.com/lab/study.git
cd study

# 2. Build Docker image from project's Dockerfile
make docker-build

# Start development environment
make r
```

### Organization Administrator Workflow

**System Configuration Setup**:

```bash
# 1. Create system configuration directory
sudo mkdir -p /etc/zzcollab

# 2. Create system configuration
sudo vim /etc/zzcollab/config.yaml

# 3. Set organization-wide defaults (profile, platform, etc.)

# 4. Validate configuration
zzcollab config validate /etc/zzcollab/config.yaml
```

## R Interface

### Configuration from R

```r
library(zzcollab)

# Initialize configuration
init_config()

# Set configuration values
set_config("team_name", "mylab")
set_config("profile_name", "analysis")

# Get configuration values
team <- get_config("team_name")
profile <- get_config("profile_name")

# List all configuration
config <- list_config()
print(config)

# Validate configuration
validate_config()
```

### Configuration-Aware Functions

```r
# Functions automatically use configuration defaults

# Project initialization (uses config for team_name, profile_name)
init_project(project_name = "study")

# Explicit parameter override
init_project(
  project_name = "study",
  team_name = "otherlab",   # Overrides config
  profile = "analysis"      # Selects the Docker profile
)

# Team member joining
join_project(project_name = "study")
```

## Configuration Validation

### YAML Syntax Validation

```bash
# Validate configuration file syntax
zzcollab config validate

# Validate specific file
zzcollab config validate ./zzcollab.yaml

# Output:
# ✓ Configuration syntax valid
# ✓ All required fields present
# ✓ Profile names properly formatted
```

### Semantic Validation

Configuration validation checks:

1. **Required fields**: team_name, project_name present when needed
2. **Value types**: Correct types for all parameters
3. **Profile names**: Valid profile from bundles.yaml
4. **YAML structure**: Proper nesting and formatting

### Common Validation Errors

**Missing Required Field**:

```
Error: Required field 'team_name' not found in configuration
Solution: zzcollab config set team-name "myteam"
```

**Invalid Profile Name**:

```
Error: profile_name 'ultra-fast' not recognized
Valid profiles: minimal, analysis, rstudio
Solution: zzc list profiles  # See all available profiles
```

**Missing System Dependencies**:

```
Error: Package 'sf' requires system libraries not in Dockerfile
Solution: Add the package to renv.lock, then regenerate the
Dockerfile; required system libraries are derived automatically at
Dockerfile-generation time. Rebuild with 'make docker-build'.
```

## Troubleshooting

### Configuration Not Applied

**Issue**: Settings in config file not taking effect

**Diagnosis**:

```bash
# List the merged configuration to see the effective values
zzcollab config list

# Check for environment variable overrides
echo $ZZCOLLAB_PROFILE_NAME
```

**Solution**: Remove higher-precedence overrides or use explicit command-line flags

### YAML Parsing Errors

**Issue**: Configuration file not parsed correctly

**Diagnosis**:

```bash
# Validate YAML syntax
zzcollab config validate

# Check yq installation
command -v yq
```

**Solution**: Install yq for full YAML support:

```bash
# macOS
brew install yq

# Ubuntu
snap install yq
```

### Missing Configuration File

**Issue**: User configuration file not found

**Diagnosis**:

```bash
# Check file existence
ls -la ~/.zzcollab/config.yaml

# Check configuration directory
ls -la ~/.zzcollab/
```

**Solution**: Initialize configuration:

```bash
zzcollab config init
```

### Permission Issues

**Issue**: Cannot write to system configuration

**Diagnosis**:

```bash
# Check system config permissions
ls -la /etc/zzcollab/config.yaml
```

**Solution**: Use sudo for system configuration:

```bash
sudo vim /etc/zzcollab/config.yaml
```

## Best Practices

### Configuration Organization

1. **User Config**: Personal defaults for all projects
2. **Project Config**: Team-specific settings in version control
3. **System Config**: Organization-wide requirements
4. **Command-line**: Temporary overrides for specific invocations

### Version Control

**Include in Git**:

- `zzcollab.yaml` (project configuration)
- `bundles.yaml` (if customized)
- `Dockerfile` (generated from profile/bundles)

**Exclude from Git**:

- `~/.zzcollab/config.yaml` (user-specific)
- `/etc/zzcollab/config.yaml` (system-specific)

### Security Considerations

1. **Sensitive Data**: Never commit credentials or tokens to configuration files
2. **Access Control**: Restrict system config to administrators
3. **Audit Trail**: Track configuration changes through version control
4. **Environment Variables**: Use for sensitive values:
   ```bash
   export GITHUB_TOKEN="ghp_..."
   export DOCKERHUB_TOKEN="dckr_..."
   ```

### Documentation Standards

Document configuration decisions:

```yaml
# zzcollab.yaml

# RATIONALE: Using analysis profile for machine-learning workflows
# (ML packages such as tidymodels are added via renv)
docker_profile:
  profile_name: "analysis"  # tidyverse base; add ML packages via renv

# RATIONALE: AMD64 platform for rocker/verse compatibility on ARM64 Macs
build:
  docker:
    platform: "amd64"  # Required for the rocker/verse base image on Apple Silicon
```

## Docker Profile Configuration

### Predefined Profiles

View all available profiles:

```bash
zzcollab list
```

**Output** (profiles):
```
Available profiles:

  minimal            rocker/r-ver       Minimal development environment (~650MB)
  analysis           rocker/tidyverse   Data analysis with tidyverse (~1.2GB)
  rstudio            rocker/rstudio     RStudio Server environment (~980MB)
```

### Bundle Configuration

View available bundles:

```bash
# Lists profiles, system library bundles, and R package bundles
zzcollab list
```

### Custom Profile Configuration

Create custom profiles in project `zzcollab.yaml`:

```yaml
docker_profile:
  # Option 1: Predefined profile
  profile_name: "analysis"

  # Option 2: Custom composition
  base_image: "rocker/r-ver:4.4.0"
  libs: "minimal"
  pkgs: "tidyverse"

  # Option 3: Fully custom
  base_image: "my-org/custom-r:latest"
  system_deps:
    - libgsl-dev
    - libnetcdf-dev
  r_packages:
    - renv
    - tidyverse
    - specialized-package
```

## Configuration Migration

The user and project configuration files are plain YAML, so
migration is handled with ordinary file operations rather than
dedicated subcommands.

### Backing Up Configuration

```bash
# Backup existing configuration
cp ~/.zzcollab/config.yaml ~/.zzcollab/config.yaml.backup

# After any manual edit, confirm the file still parses
zzcollab config validate
```

### Migrating Between Systems

```bash
# Copy the configuration file to the new system
scp ~/.zzcollab/config.yaml newhost:~/.zzcollab/config.yaml

# On the new system, confirm it parses
zzcollab config validate
```

## Verbosity System

ZZCOLLAB supports 4 verbosity levels to control output detail:

| Level | Flag | Output Lines | Use Case |
|-------|------|--------------|----------|
| 0 | `--quiet` / `-q` | ~0 (errors only) | CI/CD, scripts |
| 1 | (default) | ~8-10 | Daily usage |
| 2 | `-v` / `--verbose` | ~25-30 | Troubleshooting |
| 3 | `-vv` / `--debug` | ~400+ | Development, debugging |

### Verbosity Examples

**Level 0: Quiet Mode** (`--quiet` / `-q`)
```bash
zzcollab analysis --quiet
# (no output on success, errors only)
```

**Level 1: Default** (no flag)
```bash
zzcollab analysis
Creating project 'project'...
✅ Structure (16 dirs, 40 files)
✅ R package
✅ Docker environment
Done! Next: make docker-build
```

**Level 2: Verbose** (`-v` / `--verbose`)
```bash
zzcollab analysis -v
# Shows progress messages and created structure
```

**Level 3: Debug** (`-vv` / `--debug`)
```bash
zzcollab analysis -vv
# Full detail (~400 lines), creates .zzcollab.log
```

### Log File Support

Debug mode automatically writes to `.zzcollab.log`:

```
[2025-10-20 08:45:12] DEBUG: Loading core module...
[2025-10-20 08:45:13] SUCCESS: Structure (16 dirs, 40 files)
```

Enable log file without debug output:
```bash
export ENABLE_LOG_FILE=true
zzcollab analysis
```

### Verbosity Environment Variables

```bash
# Set verbosity level (0-3)
export VERBOSITY_LEVEL=2

# Enable log file
export ENABLE_LOG_FILE=true

# Custom log file location
export LOG_FILE="setup.log"
```

### Log Function Hierarchy

```bash
log_error()   # Always shown (even in --quiet)
log_warn()    # Shown at level >= 1 (default)
log_success() # Shown at level >= 1 (default)
log_info()    # Shown at level >= 2 (-v)
log_debug()   # Shown at level >= 3 (-vv)
```

---

## References

### Documentation

- ZZCOLLAB User Guide: Comprehensive usage documentation
- Docker Profile Guide: Profile system and customization (docs/VARIANTS.md)
- Package Management: Dynamic renv workflow

### Technical Specifications

- YAML Specification: https://yaml.org/spec/1.2/spec.html
- yq Documentation: https://mikefarah.gitbook.io/yq/
- Docker Configuration: https://docs.docker.com/engine/reference/commandline/config/

### Related Guides

- Configuration Best Practices: https://12factor.net/config
- Environment Variables: https://wiki.archlinux.org/title/Environment_variables
