# zzcollab: Docker-based Research Collaboration Framework

[![R-CMD-check](https://github.com/rgt47/zzcollab/workflows/R-CMD-check/badge.svg)](https://github.com/rgt47/zzcollab/actions)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Docker](https://img.shields.io/badge/Docker-Enabled-2496ED?logo=docker)](https://www.docker.com/)
[![R](https://img.shields.io/badge/R-4.0+-276DC3?logo=r)](https://www.r-project.org/)

A systematic framework for reproducible research collaboration using Docker
containers. `zzcollab` provides both command-line tools and R interfaces to
create, manage, and collaborate on research projects with standardized Docker
environments, automated CI/CD workflows, and team collaboration tools.

## Features

- **Unified Research Paradigm** based on Marwick et al. (2018) research compendium framework
  - Single structure supporting entire research lifecycle (data → analysis → paper → package)
  - Marwick/rrtools compatible directory layout
  - Comprehensive tutorial library (in framework repo, not installed with projects)
- **Docker-based environments** for reproducible research
- **Team collaboration** with shared base images
- **R package interface** for integration with R workflows
- **Advanced configuration system** with user/project-level settings
- **14+ specialized Docker variants** (from 200MB Alpine to 3.5GB full-featured)
- **Three build modes** (fast, standard, comprehensive) for different use cases
- **Automated CI/CD** workflows
- **Analysis and reporting** tools
- **Git integration** for version control
- **Command-line tools** for automation
- **Comprehensive documentation** and examples

## Installation

### Command Line Tool

```bash
# Install zzcollab command-line tool
git clone https://github.com/rgt47/zzcollab.git
cd zzcollab
./install.sh
```

### R Package

```r
# Install from GitHub
devtools::install_github("rgt47/zzcollab")

# Load the package
library(zzcollab)
```

## Research Compendium Structure

zzcollab follows the research compendium framework proposed by Marwick, Boettiger, and Mullen (2018), providing a standardized structure for reproducible research projects.

### Directory Structure

```
project/
├── analysis/
│   ├── data/
│   │   ├── raw_data/         # Original, unmodified data
│   │   └── derived_data/     # Processed, analysis-ready data
│   ├── paper/
│   │   ├── paper.Rmd         # Manuscript
│   │   └── references.bib
│   ├── figures/              # Generated visualizations
│   └── scripts/              # Analysis code
├── R/                        # Reusable functions (add as needed)
├── tests/                    # Unit tests (add as needed)
├── Dockerfile                # Computational environment
└── renv.lock                 # Package versions
```

### Use Cases

**All research workflows supported**:
- **Data Analysis**: Use `analysis/scripts/` and `figures/`
- **Manuscript Writing**: Use `analysis/paper/paper.Rmd`
- **Package Development**: Use `R/`, `man/`, `tests/`
- **Complete Compendium**: Use all directories for full reproducibility

**Progressive disclosure**: Start with data analysis, add manuscript when writing, extract functions to R/ when reusing code. No migration required as research evolves.

### Learning Resources

Tutorial examples and complete projects available at:
https://github.com/rgt47/zzcollab/tree/main/examples

- 📚 Step-by-step tutorials for EDA, modeling, validation
- 🔬 Complete example research compendia
- 🧩 Reusable code patterns

## R Interface Implementation

### Configuration Setup (One-time)

```r
library(zzcollab)

# Set up your defaults once
set_config("team_name", "myteam")
set_config("build_mode", "standard")
set_config("dotfiles_dir", "~/dotfiles")
set_config("github_account", "myusername")

# View your configuration
list_config()
```

### Initialize a New Research Compendium

```r
# Using config defaults (recommended)
init_project(project_name = "myproject")

# Or with explicit parameters
init_project(
  team_name = "myteam",
  project_name = "myproject",
  build_mode = "standard",
  dotfiles_path = "~/dotfiles"
)
```

### Join an Existing Project

```r
# Using config defaults
join_project(project_name = "myproject")

# Or with explicit parameters
join_project(
  team_name = "myteam",
  project_name = "myproject",
  build_mode = "standard"
)
```

## Build Modes

zzcollab supports three build modes to optimize for different use cases:

| Mode | Description | Docker Size | Package Count | Key Packages | Build Time |
|------|-------------|-------------|---------------|--------------|------------|
| **Fast** (`-F`) | Minimal setup | Small | 9 packages | renv, here, devtools, testthat, knitr, rmarkdown, targets | Fast |
| **Standard** (`-S`) | Balanced (default) | Medium | 17 packages | + dplyr, ggplot2, tidyr, palmerpenguins, broom, janitor, DT | Medium |
| **Comprehensive** (`-C`) | Full-featured | Large | 51 packages | + tidymodels, shiny, plotly, quarto, bookdown, papaja, pkgdown | Slow |

All packages work seamlessly whether you're doing data analysis, writing manuscripts, or developing packages.

## Configuration System

zzcollab includes a hierarchical configuration system to establish project defaults and reduce parameter specification.

### Configuration Files
- **User config**: `~/.zzcollab/config.yaml` (your personal defaults)
- **Project config**: `./zzcollab.yaml` (project-specific overrides)
- **Priority**: project > user > built-in defaults

### Configuration Commands
```bash
zzcollab --config init                    # Create default config file
zzcollab --config set team-name "myteam"  # Set a configuration value
zzcollab --config get team-name           # Get a configuration value
zzcollab --config list                    # List all configuration
zzcollab --config validate               # Validate YAML syntax
```

### Customizable Settings
- **Team settings**: `team_name`, `github_account`
- **Build settings**: `build_mode`, `dotfiles_dir`, `dotfiles_nodot`
- **Automation**: `auto_github`, `skip_confirmation`
- **Custom package lists**: Override default packages for each build mode

### Custom Package Lists
Edit your config file to customize packages for different build modes:

```yaml
build_modes:
  fast:
    description: "Quick development setup"
    docker_packages: [renv, remotes, here, usethis]
    renv_packages: [renv, here, usethis, devtools, testthat]
  
  standard:
    description: "Balanced research workflow"  
    docker_packages: [renv, remotes, tidyverse, here, usethis, devtools]
    renv_packages: [renv, here, usethis, devtools, dplyr, ggplot2, tidyr, testthat, palmerpenguins]
```

## Core R Functions

### Configuration Management
- `get_config()` - Get configuration values
- `set_config()` - Set configuration values
- `list_config()` - List all configuration
- `validate_config()` - Validate configuration files
- `init_config()` - Initialize default config

### Project Management
- `init_project()` - Initialize team project (config-aware)
- `join_project()` - Join existing project (config-aware)
- `setup_project()` - Setup individual project (config-aware)

### Docker Management
- `status()` - Check container status
- `rebuild()` - Rebuild Docker images
- `team_images()` - List team images

### Package Management
- `add_package()` - Add R packages
- `sync_env()` - Sync environment with renv

### Analysis & Reporting
- `run_script()` - Execute R scripts in container
- `render_report()` - Render analysis reports
- `validate_repro()` - Check reproducibility

### Git Integration
- `git_status()` - Check git status
- `git_commit()` - Create commits
- `git_push()` - Push to GitHub
- `create_pr()` - Create pull requests
- `create_branch()` - Create feature branches

## Example R Workflow

```r
# 0. One-time setup (configure your defaults)
set_config("team_name", "datascience")
set_config("build_mode", "standard")
set_config("dotfiles_dir", "~/dotfiles")

# 1. Initialize project (uses config defaults)
init_project(project_name = "covid-analysis")

# 2. Add required packages
add_package(c("tidyverse", "lubridate", "plotly"))

# 3. Create feature branch
create_branch("feature/exploratory-analysis")

# 4. Run analysis
run_script("analysis/scripts/exploratory_analysis.R")

# 5. Render report
render_report("analysis/paper/paper.Rmd")

# 6. Validate reproducibility
validate_repro()

# 7. Commit and push
git_commit("Add COVID-19 exploratory analysis")
git_push()
```

## Installation

### Method 1: Automatic Installation

```bash
git clone https://github.com/yourusername/zzcollab.git && cd zzcollab && ./install.sh
```

### Method 2: Manual Installation

```bash
git clone https://github.com/yourusername/zzcollab.git
cd zzcollab
ln -s "$(pwd)/zzcollab.sh" ~/bin/zzcollab
```

## Usage

```bash
# Create project directory
mkdir my-analysis
cd my-analysis

# Set up research compendium
zzcollab --dotfiles ~/dotfiles

# Start development environment
make docker-rstudio  # → http://localhost:8787 (user: analyst, pass: analyst)
```

## Development Workflow

```bash
# Available development environments
make docker-rstudio    # RStudio Server GUI
make docker-r          # R console  
make docker-zsh        # Zsh shell with your dotfiles
make docker-bash       # Bash shell

# Common tasks
make docker-render     # Generate research paper PDF
make docker-test       # Run package tests
make docker-check      # Validate package structure
make help             # See all available commands
```

## Project Structure

```
your-project/
├── analysis/              # Research workspace
│   ├── data/
│   │   ├── raw_data/     # Original, unmodified data
│   │   └── derived_data/ # Processed data
│   ├── paper/
│   │   ├── paper.Rmd     # Manuscript
│   │   └── references.bib
│   ├── figures/          # Generated visualizations
│   └── scripts/          # Analysis code
├── R/                    # Reusable functions
├── tests/                # Unit tests
├── .github/workflows/    # CI/CD automation
├── DESCRIPTION           # Project metadata
├── Dockerfile            # Computational environment
├── Makefile              # Automation commands
└── README.md
```

## Command Line Options

```bash
zzcollab [OPTIONS]
zzcollab config [SUBCOMMAND]

OPTIONS:
  --dotfiles DIR, -d   Copy dotfiles from directory (files with leading dots)
  --dotfiles-nodot DIR Copy dotfiles from directory (files without leading dots) 
  --base-image NAME    Use custom Docker base image (default: rocker/r-ver)
  --no-docker, -n      Skip Docker image build during setup
  --fast, -F           Fast build mode (minimal packages)
  --standard, -S       Standard build mode (balanced packages, default)
  --comprehensive, -C  Comprehensive build mode (full packages)
  --team NAME, -t      Team name for collaboration
  --project NAME, -p   Project name
  --interface TYPE, -I Interface type (shell, rstudio, verse)
  --init, -i           Initialize team base images
  --next-steps         Show development workflow and next steps
  --help, -h           Show help message

CONFIG COMMANDS:
  zzcollab config init                    # Create default config file
  zzcollab config set KEY VALUE           # Set configuration value
  zzcollab config get KEY                 # Get configuration value  
  zzcollab config list                    # List all configuration
  zzcollab config validate               # Validate YAML syntax

EXAMPLES:
  # Configuration setup
  zzcollab config init                        # One-time setup
  zzcollab config set team_name "myteam"      # Set team default
  zzcollab config set build_mode "fast"       # Set build mode default

  # Basic usage (uses config defaults)
  zzcollab --fast                             # Fast mode setup
  zzcollab --dotfiles ~/dotfiles              # Include personal dotfiles

  # Team collaboration
  zzcollab -i -t myteam -p study -B rstudio   # Team lead: create images
  zzcollab -t myteam -p study -I rstudio      # Team member: join project

  # Traditional usage
  zzcollab --base-image rgt47/r-pluspackages  # Use custom base image
  zzcollab --no-docker                        # Setup without Docker build
```

## Docker Integration

### Pre-built Base Images

```bash
# Use base image with common R packages pre-installed
zzcollab --base-image rgt47/r-pluspackages

# Packages included: tidyverse, DT, conflicted, ggthemes, datapasta, 
# janitor, kableExtra, tidytuesdayR, and more
```

### Custom Base Images

```bash
# Build custom base image with your organization's packages
cd zzcollab
docker build -f templates/Dockerfile.pluspackages -t myorg/r-base:latest .
docker push myorg/r-base:latest

# Use in projects
zzcollab --base-image myorg/r-base
```

## Use Cases

### Academic Research
- Manuscript preparation with automated figure/table generation
- Reproducible analysis with renv dependency management
- Collaboration with standardized project structure
- Publication with GitHub Actions workflows

### Data Science Projects
- Exploratory data analysis with organized script structure
- Model development with testing and validation
- Reporting with R Markdown integration
- Deployment with containerized environments

### Team Collaboration
- Standardized structure across team projects
- Consistent environments with Docker
- Version control integration with Git/GitHub
- Documentation with package-style help system


## Documentation

- [Unified Paradigm Guide](docs/UNIFIED_PARADIGM_GUIDE.md) - Complete framework documentation
- [Marwick Comparison](docs/MARWICK_COMPARISON_ANALYSIS.md) - Research compendium alignment
- [Tutorial Examples](examples/) - Step-by-step learning resources
- [Command Reference](#command-line-options) - All available options
- [Docker Guide](#docker-integration) - Container workflows
- [Troubleshooting](#troubleshooting) - Common issues and solutions

## Tutorial Examples

Comprehensive tutorial examples and code patterns available at:
https://github.com/rgt47/zzcollab/tree/main/examples

**Available Resources**:
- 📚 **Tutorials**: Step-by-step workflows for EDA, modeling, validation, dashboards, reporting
- 🔬 **Complete Projects**: Full example research compendia demonstrating end-to-end workflows
- 🧩 **Code Patterns**: Reusable patterns for data validation, model evaluation, reproducible plots

These examples live in the zzcollab repository (not installed with projects) as learning resources you can reference when needed.

### Getting Help
```bash
zzcollab --help          # Command line help
zzcollab --next-steps     # Show workflow guidance
make help                 # Show all make targets
```

## Requirements

### Required
- **Docker** - For containerized development environments
- **Git** - For version control (recommended)

### Optional
- **R & RStudio** - For native development (can work entirely in Docker)
- **GitHub CLI** (`gh`) - For automated repository creation
- **Make** - Usually pre-installed on Unix systems

### System Support
- macOS (Intel and Apple Silicon)
- Linux (Ubuntu, CentOS, etc.)
- Windows (with WSL2 recommended)

## Troubleshooting

### Common Issues

**Docker build fails:**
```bash
# Try disabling BuildKit
export DOCKER_BUILDKIT=0
zzcollab
```

**Platform warnings on ARM64 (Apple Silicon):**
```bash
# Already handled automatically with --platform linux/amd64
# Or set environment variable:
export DOCKER_DEFAULT_PLATFORM=linux/amd64
```

**Missing dotfiles in container:**
```bash
# Make sure to specify dotfiles directory
zzcollab --dotfiles ~/dotfiles
# or for files without leading dots:
zzcollab --dotfiles-nodot ~/dotfiles
```

**Package name errors:**
```bash
# Ensure directory name contains only letters, numbers, and periods
# Avoid underscores and special characters
# Must start with a letter
```

**Permission errors:**
```bash
# Check directory permissions
ls -la
# Make sure Docker is running
docker info
```

### Getting Help

1. Check the [User Guide](templates/ZZCOLLAB_USER_GUIDE.md) for detailed workflows
2. Use built-in help: `zzcollab --help`
3. Validate your environment: `make docker-check-renv`
4. Clean and rebuild: `make docker-clean && make docker-build`
5. Open an issue on GitHub with system details and error messages

## Contributing

### Reporting Issues
- Bug reports with system info and reproduction steps
- Feature requests with use case descriptions
- Documentation improvements and clarifications

### Development Setup
```bash
# Fork and clone the repository
git clone https://github.com/yourusername/zzcollab.git
cd zzcollab

# Make your changes to zzcollab.sh or templates/
# Test with a sample project
mkdir test-project && cd test-project
../zzcollab.sh

# Submit a pull request
```

### Guidelines
- Test thoroughly with different project types
- Update documentation for any new features
- Follow shell scripting best practices
- Use clear commit messages

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

- Free to use for any purpose
- Modify and distribute with same license
- Commercial use allowed
- Source code must remain open
- No warranty provided

## Acknowledgments

- [Ben Marwick et al.](https://doi.org/10.1080/00031305.2017.1375986) - Research compendium framework
- [rrtools](https://github.com/benmarwick/rrtools) - Original research compendium implementation
- [Rocker Project](https://rocker-project.org/) - Docker images for R
- [renv](https://rstudio.github.io/renv/) - R dependency management
- R Community

