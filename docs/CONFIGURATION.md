# Configuration Guide

## Overview

ZZCOLLAB implements a sophisticated multi-layered configuration
system that enables teams and individuals to establish consistent
defaults while maintaining flexibility for project-specific
requirements. This guide provides comprehensive documentation of
configuration architecture, file formats, and usage patterns.

## Configuration Philosophy

### Design Principles

The configuration system adheres to four key principles:

1. **Hierarchy**: Project-specific settings override user defaults,
   which override system defaults
2. **Transparency**: All configuration decisions are explicit and
   traceable
3. **Flexibility**: Users can customize any aspect while maintaining
   sensible defaults
4. **Reproducibility**: Configuration files are version-controlled
   and portable

### Configuration Domains

ZZCOLLAB configuration spans three distinct domains:

- **Docker Variant Management**: Selection and customization of 14+
  specialized environments
- **Package Management**: Build mode selection and custom package
  lists
- **Development Settings**: Team collaboration preferences and
  automation options

## Configuration Hierarchy

### Four-Level Precedence

Configuration values are resolved through a hierarchical precedence
system:

```
Priority 1: Command-line flags (-F, -t, -p, etc.)
    ↓ (overrides)
Priority 2: Environment variables (ZZCOLLAB_BUILD_MODE, etc.)
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

**Scenario 1: Build Mode Resolution**

```bash
# User config: build_mode: standard
# Command-line: -F (fast)
# Result: Fast mode (command-line overrides config)

zzcollab -i -t lab -p study -F
```

**Scenario 2: Team Name Resolution**

```bash
# No command-line flag
# User config: team_name: "mylab"
# Result: "mylab" (from user config)

zzcollab -i -p study
```

**Scenario 3: Complete Override Chain**

```bash
# System config: build_mode: standard
# User config: build_mode: fast
# Project config: build_mode: comprehensive
# Command-line: --fast
# Result: fast (command-line overrides all)

zzcollab -i -p research --fast
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

  # Project defaults
  build_mode: "standard"        # fast, standard, comprehensive

  # Development environment
  dotfiles_dir: "~/dotfiles"
  dotfiles_nodot: false

  # Automation preferences
  auto_github: false            # Automatically create GitHub repos
  skip_confirmation: false      # Skip confirmation prompts

#=========================================================
# CUSTOM BUILD MODES (Optional)
#=========================================================
# Define specialized build modes for specific workflows

build_modes:
  fast:
    description: "Minimal development environment"
    docker_packages:
      - renv
      - remotes
      - here
      - usethis
      - devtools
      - testthat
      - knitr
      - rmarkdown
      - targets
    renv_packages:
      - renv
      - remotes
      - here
      - usethis
      - devtools
      - testthat
      - knitr
      - rmarkdown
      - targets

  custom_ml:
    description: "Machine learning workflow"
    docker_packages:
      - renv
      - tidyverse
      - tidymodels
      - xgboost
      - keras
      - tensorflow
    renv_packages:
      - renv
      - tidyverse
      - tidymodels
      - xgboost
      - keras
      - tensorflow
      - caret
      - mlr3

  custom_spatial:
    description: "Geospatial analysis workflow"
    docker_packages:
      - renv
      - tidyverse
      - sf
      - terra
      - leaflet
    renv_packages:
      - renv
      - tidyverse
      - sf
      - terra
      - leaflet
      - tmap
      - raster

#=========================================================
# PARADIGM CUSTOMIZATION (Optional)
#=========================================================
# Override default packages for research paradigms

paradigms:
  analysis:
    docker_packages:
      - renv
      - tidyverse
      - targets
      - plotly
    renv_packages:
      - renv
      - tidyverse
      - targets
      - plotly
      - DT
      - flexdashboard

  manuscript:
    docker_packages:
      - renv
      - tidyverse
      - rmarkdown
      - bookdown
    renv_packages:
      - renv
      - tidyverse
      - rmarkdown
      - bookdown
      - papaja
      - kableExtra
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
  description: "Machine learning analysis of customer
                retention patterns"
  maintainer: "Dr. Smith <smith@university.edu>"
  created: "2024-01-15"

#=========================================================
# DOCKER ENVIRONMENTS
#=========================================================
# Specify which Docker environments to build

environments:
  minimal:
    enabled: true             # Essential development (~800MB)

  analysis:
    enabled: true             # Primary analysis environment (~1.2GB)

  modeling:
    enabled: true             # Machine learning (~1.5GB)

  alpine_minimal:
    enabled: true             # CI/CD testing (~200MB)

  publishing:
    enabled: false            # LaTeX documents (~3GB)

  geospatial:
    enabled: false            # Spatial analysis (~2.5GB)

  bioinformatics:
    enabled: false            # Genomics (~2GB)

#=========================================================
# BUILD CONFIGURATION
#=========================================================

build:
  # Variant management
  use_config_environments: true
  environment_library: "environments.yaml"

  # Docker build settings
  docker:
    platform: "auto"          # auto, linux/amd64, linux/arm64
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

  # Development environment
  development:
    default_interface: "analysis"    # Which environment for new members
    default_build_mode: "standard"

  # Container settings
  container:
    default_user: "analyst"
    working_dir: "/home/analyst/project"
    shared_volumes:
      - "${HOME}/data:/data:ro"     # Read-only data mount

#=========================================================
# PROJECT-SPECIFIC SETTINGS
#=========================================================

project:
  # Package requirements (beyond build mode defaults)
  additional_packages:
    - survival
    - lme4
    - brms

  # Data management
  data:
    raw_data_dir: "data/raw_data"
    derived_data_dir: "data/derived_data"
    external_data_sources:
      - name: "Public dataset"
        url: "https://example.com/data.csv"

  # Output management
  outputs:
    figures_dir: "outputs/figures"
    tables_dir: "outputs/tables"
    reports_dir: "outputs/reports"

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

  # Standard build mode
  build_mode: "standard"

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
zzcollab --config init

# Create user configuration in custom location
ZZCOLLAB_CONFIG_USER=~/custom/config.yaml zzcollab --config init
```

### Setting Values

```bash
# Set single values
zzcollab --config set team-name "mylab"
zzcollab --config set github-account "myusername"
zzcollab --config set build-mode "fast"
zzcollab --config set dotfiles-dir "~/dotfiles"

# Set boolean values
zzcollab --config set auto-github true
zzcollab --config set skip-confirmation false
```

### Getting Values

```bash
# Get single values
zzcollab --config get team-name
zzcollab --config get build-mode

# Get all configuration
zzcollab --config list
```

### Validation

```bash
# Validate YAML syntax and required fields
zzcollab --config validate

# Validate specific config file
zzcollab --config validate ./zzcollab.yaml
```

### Configuration Inspection

```bash
# Show effective configuration (resolved hierarchy)
zzcollab --config show

# Show configuration sources
zzcollab --config sources

# Show configuration precedence
zzcollab --config precedence
```

## Configuration Parameters

### Required Parameters

**team_name**

- **Type**: String
- **Description**: Team identifier for Docker images and
  collaboration
- **Example**: `"datasci-lab"`
- **Used in**: Docker image naming, GitHub repository creation

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

**build_mode**

- **Type**: Enum
- **Values**: `fast`, `standard`, `comprehensive`
- **Default**: `standard`
- **Description**: Package installation mode

**dotfiles_dir**

- **Type**: Path
- **Description**: Path to dotfiles directory
- **Default**: None
- **Example**: `"~/dotfiles"`

**dotfiles_nodot**

- **Type**: Boolean
- **Description**: Whether dotfiles lack leading dots
- **Default**: `false`
- **Example**: `true`

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

## Advanced Configuration

### Custom Build Modes

Define specialized build modes for specific workflows:

```yaml
build_modes:
  bioinformatics:
    description: "Bioinformatics pipeline"
    docker_packages:
      - renv
      - tidyverse
      - BiocManager
      - Biostrings
      - GenomicRanges
    renv_packages:
      - renv
      - tidyverse
      - BiocManager
      - Biostrings
      - GenomicRanges
      - DESeq2
      - edgeR
      - limma

  timeseries:
    description: "Time series forecasting"
    docker_packages:
      - renv
      - tidyverse
      - forecast
      - tsibble
    renv_packages:
      - renv
      - tidyverse
      - forecast
      - tsibble
      - fable
      - prophet
```

### Custom Paradigm Packages

Override default packages for research paradigms:

```yaml
paradigms:
  analysis:
    docker_packages:
      - renv
      - tidyverse
      - targets
      - arrow
    renv_packages:
      - renv
      - tidyverse
      - targets
      - arrow
      - pins
      - vetiver

  manuscript:
    docker_packages:
      - renv
      - rmarkdown
      - bookdown
      - quarto
    renv_packages:
      - renv
      - rmarkdown
      - bookdown
      - quarto
      - distill
      - posterdown
```

### Docker Variant Customization

Define completely custom Docker environments:

```yaml
environments:
  custom_ml:
    base_image: "nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04"
    description: "GPU-accelerated machine learning"
    packages:
      - renv
      - tidyverse
      - keras
      - tensorflow
      - xgboost
    system_deps:
      - libcudnn8
      - python3-pip
    enabled: true
```

## Environment Variables

### Configuration Override Variables

**ZZCOLLAB_BUILD_MODE**

- **Description**: Override build mode
- **Values**: `fast`, `standard`, `comprehensive`
- **Example**: `export ZZCOLLAB_BUILD_MODE=fast`

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
zzcollab --config init

# 2. Set personal defaults
zzcollab --config set team-name "myteam"
zzcollab --config set build-mode "standard"
zzcollab --config set dotfiles-dir "~/dotfiles"

# 3. Verify configuration
zzcollab --config list
```

**Project Creation**:

```bash
# Configuration is automatically applied
zzcollab -i -p research-project --github

# Override specific settings with build mode
zzcollab -i -p comprehensive-project --comprehensive --github
```

### Team Leader Workflow

**Team Configuration Setup**:

```bash
# 1. Create project with initial config
zzcollab -i -t lab -p study --github

# 2. Customize team configuration
cd study
vim zzcollab.yaml

# 3. Edit variants, collaboration settings, build options

# 4. Commit configuration to repository
git add zzcollab.yaml
git commit -m "Add team configuration"
git push
```

**Team Member Workflow**:

```bash
# 1. Clone project
git clone https://github.com/lab/study.git
cd study

# 2. Join with team configuration
zzcollab -t lab -p study -I analysis

# Team configuration automatically applied
```

### Organization Administrator Workflow

**System Configuration Setup**:

```bash
# 1. Create system configuration directory
sudo mkdir -p /etc/zzcollab

# 2. Create system configuration
sudo vim /etc/zzcollab/config.yaml

# 3. Set organization-wide defaults

# 4. Validate configuration
zzcollab --config validate /etc/zzcollab/config.yaml
```

## R Interface

### Configuration from R

```r
library(zzcollab)

# Initialize configuration
init_config()

# Set configuration values
set_config("team_name", "mylab")
set_config("build_mode", "fast")
set_config("dotfiles_dir", "~/dotfiles")

# Get configuration values
team <- get_config("team_name")
mode <- get_config("build_mode")

# List all configuration
config <- list_config()
print(config)

# Validate configuration
validate_config()
```

### Configuration-Aware Functions

```r
# Functions automatically use configuration defaults

# Team initialization (uses config for team_name, build_mode)
init_project(project_name = "study")

# Explicit parameter override
init_project(
  project_name = "study",
  team_name = "otherlab",  # Overrides config
  build_mode = "comprehensive"
)

# Team member joining (uses config for team_name, build_mode)
join_project(project_name = "study", interface = "shell")
```

## Configuration Validation

### YAML Syntax Validation

```bash
# Validate configuration file syntax
zzcollab --config validate

# Validate specific file
zzcollab --config validate ./zzcollab.yaml

# Output:
# ✓ Configuration syntax valid
# ✓ All required fields present
# ✓ Package lists properly formatted
```

### Semantic Validation

Configuration validation checks:

1. **Required fields**: team_name, project_name present when needed
2. **Value types**: Correct types for all parameters
3. **Enum values**: build_mode in allowed set (fast, standard, comprehensive)
4. **File paths**: Dotfiles directories exist
5. **Package names**: Valid R package identifiers
6. **YAML structure**: Proper nesting and formatting

### Common Validation Errors

**Missing Required Field**:

```
Error: Required field 'team_name' not found in configuration
Solution: zzcollab --config set team-name "myteam"
```

**Invalid Build Mode**:

```
Error: build_mode 'ultra-fast' not recognized
Valid values: fast, standard, comprehensive
Solution: zzcollab --config set build-mode "fast"
```

**Invalid Package Name**:

```
Error: Package 'tidyvurse' contains invalid characters
Solution: Check spelling, correct to 'tidyverse'
```

## Troubleshooting

### Configuration Not Applied

**Issue**: Settings in config file not taking effect

**Diagnosis**:

```bash
# Check configuration precedence
zzcollab --config precedence

# Verify configuration loading
zzcollab --config sources

# Check for command-line overrides
echo $ZZCOLLAB_BUILD_MODE
```

**Solution**: Remove higher-precedence overrides or use
explicit command-line flags

### YAML Parsing Errors

**Issue**: Configuration file not parsed correctly

**Diagnosis**:

```bash
# Validate YAML syntax
zzcollab --config validate

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
zzcollab --config init
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
sudo zzcollab --config set-system parameter value
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
- `environments.yaml` (if customized)

**Exclude from Git**:

- `~/.zzcollab/config.yaml` (user-specific)
- `/etc/zzcollab/config.yaml` (system-specific)

### Security Considerations

1. **Sensitive Data**: Never commit credentials or tokens to
   configuration files
2. **Access Control**: Restrict system config to administrators
3. **Audit Trail**: Track configuration changes through version
   control
4. **Environment Variables**: Use for sensitive values:
   ```bash
   export GITHUB_TOKEN="ghp_..."
   ```

### Documentation Standards

Document configuration decisions:

```yaml
# zzcollab.yaml

# RATIONALE: Using comprehensive mode for advanced statistical methods
build:
  docker:
    platform: "linux/amd64"  # Required for rocker/verse compatibility

# RATIONALE: Enabling modeling environment for machine learning workflows
environments:
  modeling:
    enabled: true           # Team requires tidymodels and xgboost
```

## Configuration Migration

### Upgrading Configuration Format

When zzcollab introduces new configuration features:

```bash
# Backup existing configuration
cp ~/.zzcollab/config.yaml ~/.zzcollab/config.yaml.backup

# Upgrade configuration format
zzcollab --config upgrade

# Validate upgraded configuration
zzcollab --config validate
```

### Migrating Between Systems

```bash
# Export configuration
zzcollab --config export > config-export.yaml

# On new system, import configuration
zzcollab --config import < config-export.yaml
```

## References

### Documentation

- ZZCOLLAB User Guide: Comprehensive usage documentation
- Build Modes Guide: Detailed build mode specifications
- Environment System Guide: Docker environment customization

### Technical Specifications

- YAML Specification: https://yaml.org/spec/1.2/spec.html
- yq Documentation: https://mikefarah.gitbook.io/yq/
- Docker Configuration: https://docs.docker.com/engine/reference/commandline/config/

### Related Guides

- Configuration Best Practices: https://12factor.net/config
- Environment Variables: https://wiki.archlinux.org/title/Environment_variables
