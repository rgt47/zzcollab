# zzcollab: Docker-based Research Collaboration Framework

A systematic framework for reproducible research collaboration using
Docker containers. `zzcollab` provides both command-line tools and R
interfaces to create, manage, and collaborate on research projects with
standardized Docker environments, automated CI/CD workflows, and team
collaboration tools.

## Features

- **Unified Research Paradigm** based on Marwick et al. (2018) research
  compendium framework
  - Single structure supporting entire research lifecycle (data to
    analysis to paper to package)
  - Marwick/rrtools compatible directory layout
  - Comprehensive tutorial library (in framework repository, not
    installed with projects)
- **Docker-based environments** for reproducible research
- **Team collaboration** with shared base images
- **R package interface** for integration with R workflows
- **Advanced configuration system** with user/project-level settings
- **Four Docker profiles**: minimal, tidyverse (formerly `analysis`,
  alias kept), rstudio, publishing
- **Profile-based architecture**: Team lead selects Docker profile,
  members add packages as needed
- **Automated CI/CD** workflows
- **Analysis and reporting** tools
- **Git integration** for version control
- **Command-line tools** for automation
- **Comprehensive documentation** and examples

## Installation

### Command Line Tool

``` bash
# Install zzcollab command-line tool
git clone https://github.com/rgt47/zzcollab.git
cd zzcollab
./install.sh
```

### R Package

``` r

# install.packages('pak')
pak::pak('rgt47/zzcollab')

library(zzcollab)
```

## Research Compendium Structure

zzcollab follows the research compendium framework proposed by Marwick,
Boettiger, and Mullen (2018), providing a standardized structure for
reproducible research projects.

### Directory Structure

    project/
    ├── analysis/
    │   ├── data/
    │   │   ├── raw_data/         # Original, unmodified data
    │   │   └── derived_data/     # Processed, analysis-ready data
    │   ├── report/
    │   │   ├── report.Rmd        # Manuscript
    │   │   └── references.bib
    │   ├── figures/              # Generated visualizations
    │   └── scripts/              # Analysis code
    ├── R/                        # Reusable functions (add as needed)
    ├── tests/                    # Unit tests (add as needed)
    ├── Dockerfile                # Computational environment
    └── renv.lock                 # Package versions

### Use Cases

**All research workflows supported**:

- **Data Analysis**: Use `analysis/scripts/` and `figures/`
- **Manuscript Writing**: Use `analysis/report/report.Rmd`
- **Package Development**: Use `R/`, `man/`, `tests/`
- **Complete Compendium**: Use all directories for full reproducibility

**Progressive disclosure**: Start with data analysis, add manuscript
when writing, extract functions to R/ when reusing code. No migration
required as research evolves.

### Learning Resources

Tutorial examples and complete projects available at:
<https://github.com/rgt47/zzcollab/tree/main/examples>

- Step-by-step tutorials for EDA, modeling, validation
- Complete example research compendia
- Reusable code patterns

## Team Collaboration Model

zzcollab implements a **two-layer reproducibility architecture**:

### Layer 1: Docker Profile (Team Lead Decision)

The **team lead** selects a Docker profile that defines the foundational
environment:

- **Base R version** (e.g., R 4.4.0)
- **System dependencies** (GDAL, PROJ, LaTeX, etc.)
- **Pre-installed packages** (tidyverse, sf, etc.)
- **Four profiles** available: minimal, tidyverse (formerly `analysis`,
  alias kept), rstudio, publishing

**Key principle**: Once selected, the Docker profile is **fixed** for
the team. Team members cannot change the base image to ensure consistent
environments.

### Layer 2: R Packages (Individual Flexibility)

**All team members** can independently add R packages as needed:

``` r

# Inside the Docker container
install.packages("tidymodels")
install.packages("plotly")
```

When you exit the container, packages are automatically captured in
`renv.lock`. The lock file accumulates packages from **all team
members** (union model), ensuring everyone has access to all required
packages while maintaining flexibility.

**For GitHub packages:**

``` r

install.packages("remotes")
remotes::install_github("user/package")
```

**Alternative:**
[`renv::install()`](https://rstudio.github.io/renv/reference/install.html)
works for both CRAN and GitHub packages:

``` r

renv::install("tidymodels")              # CRAN
renv::install("user/package")            # GitHub
```

### Dependency Manifest: renv.lock + DESCRIPTION

Reproducibility rests on two complementary files, not one. `renv.lock`
pins the exact package closure (versions), while `DESCRIPTION` declares
dependency roles: packages used by code in `R/` belong in `Imports`, and
packages used only by `analysis/` (reports, scripts, notebooks) belong
in `Suggests`. Run `make snapshot` to grow both from the built image
([`renv::hydrate()`](https://rstudio.github.io/renv/reference/hydrate.html),
[`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html),
then `zzrenvcheck::check_packages()`). The R-package CI workflow
enforces this with a ‘Validate dependency manifest (renv.lock +
DESCRIPTION)’ step that fails the build when code references a package
that is not declared in `DESCRIPTION` or not locked in `renv.lock`. For
guidance on which packages belong in the Dockerfile versus `renv.lock`
versus `DESCRIPTION`, see
[docs/package-placement-whitepaper.md](https://rgt47.github.io/zzcollab/docs/package-placement-whitepaper.md).

### Workflow Example

**Team Lead** (one-time setup):

``` bash
zzcollab config set dockerhub-account mylab   # one-time
mkdir study && cd study
zzcollab tidyverse                             # init + renv + docker (tidyverse)
zzcollab dockerhub                            # push team image to Docker Hub
git add . && git commit -m "Initial setup" && git push
```

**Team Member** (joining project):

``` bash
git clone https://github.com/mylab/study.git && cd study
make docker-build             # Build Docker image from Dockerfile
make r
# Inside container: install.packages("package") as needed
```

## R Interface Implementation

### Configuration Setup (One-time)

``` r

library(zzcollab)

# Set up your defaults once
set_config("team_name", "myteam")
set_config("github_account", "myusername")

# View your configuration
list_config()
```

### Initialize a New Research Compendium

``` r

# Using config defaults (recommended)
init_project(project_name = "myproject")

# Or with explicit parameters
init_project(
  team_name = "myteam",
  project_name = "myproject"
)
```

### Join an Existing Project

``` r

# Using config defaults
join_project(project_name = "myproject")

# Or with explicit parameters
join_project(
  team_name = "myteam",
  project_name = "myproject"
)
```

## Docker Profiles

zzcollab provides several Docker profiles optimized for different
research needs. The profile is selected when creating the project (or
switched later in an existing project).

| Profile | Base Image | Size | Use Case |
|----|----|----|----|
| `minimal` | rocker/r-ver | ~650 MB | Lightweight, CI/CD |
| `tidyverse` | rocker/tidyverse | ~1.2 GB | Data analysis with tidyverse |
| `rstudio` | rocker/rstudio | ~980 MB | RStudio Server development |
| `publishing` | rocker/verse | ~4.2 GB | Manuscript rendering (PDF-adaptive, pre-baked LaTeX) |

The `tidyverse` profile was formerly named `analysis`; `analysis` is
retained as a deprecated alias. The `publishing` profile renders PDF by
default when a LaTeX toolchain is present and falls back to HTML
otherwise; its LaTeX package closure is pre-baked into the image, so PDF
rendering needs no runtime install.

For other specialised needs (Shiny, machine learning), start from one of
these profiles and add packages inside the container with
[`install.packages()`](https://rdrr.io/r/utils/install.packages.html),
then commit the updated `renv.lock`.

Run `zzcollab list` for the full set of available profiles and bundles.

### Selecting a Profile

``` bash
# Select the profile when creating the project (run inside the project directory)
zzcollab tidyverse
```

### Adding Packages (All Team Members)

After the Docker profile is set, team members add packages as needed:

``` bash
# Enter container (starts R directly)
make r

# Inside R - add packages using standard R
> install.packages("tidymodels")
> install.packages("here")
> q()  # Exit R → returns to host (auto-snapshot runs on exit)

# renv.lock automatically updated and validated!

# Commit the updated renv.lock
git add renv.lock
git commit -m "Add tidymodels and here packages"
git push
```

Packages are automatically captured in `renv.lock` when you exit the
container - no manual snapshot needed!

## Configuration System

zzcollab includes a hierarchical configuration system to establish
project defaults and reduce parameter specification.

### Configuration Files

- **User config**: `~/.zzcollab/config.yaml` (personal defaults)
- **Project config**: `./zzcollab.yaml` (project-specific overrides)
- **Priority**: project \> user \> built-in defaults

### Configuration Commands

``` bash
zzcollab config init                    # Create default config file
zzcollab config set team-name "myteam"  # Set configuration value
zzcollab config get team-name           # Get configuration value
zzcollab config list                    # List all configuration
zzcollab config validate               # Validate YAML syntax
```

### Customizable Settings

- **Team settings**: `team_name`, `github_account`
- **Forge**: `forge` (`github` \| `gitlab` \| `none`), `gitlab_account`,
  `gitlab_host` (self-hosted)
- **Automation**: `auto_github`, `skip_confirmation`
- **Tooling**: `languageserver` (default `true`) installs the R language
  server in the Docker image for in-container LSP completion and
  diagnostics; set `false` for REPL-only workflows

## Core R Functions

### Configuration Management

- [`get_config()`](https://rgt47.github.io/zzcollab/reference/get_config.md) -
  Get configuration values
- [`set_config()`](https://rgt47.github.io/zzcollab/reference/set_config.md) -
  Set configuration values
- [`list_config()`](https://rgt47.github.io/zzcollab/reference/list_config.md) -
  List all configuration
- [`validate_config()`](https://rgt47.github.io/zzcollab/reference/validate_config.md) -
  Validate configuration files
- [`init_config()`](https://rgt47.github.io/zzcollab/reference/init_config.md) -
  Initialize default config

### Project Management

- [`init_project()`](https://rgt47.github.io/zzcollab/reference/init_project.md) -
  Initialize team project (config-aware)
- [`join_project()`](https://rgt47.github.io/zzcollab/reference/join_project.md) -
  Join existing project (config-aware)
- [`setup_project()`](https://rgt47.github.io/zzcollab/reference/setup_project.md) -
  Setup individual project (config-aware)

### Docker Management

- [`status()`](https://rgt47.github.io/zzcollab/reference/status.md) -
  Check container status
- [`rebuild()`](https://rgt47.github.io/zzcollab/reference/rebuild.md) -
  Rebuild Docker images
- [`team_images()`](https://rgt47.github.io/zzcollab/reference/team_images.md) -
  List team images

### Package Management

- [`add_package()`](https://rgt47.github.io/zzcollab/reference/add_package.md) -
  Add R packages
- [`sync_env()`](https://rgt47.github.io/zzcollab/reference/sync_env.md) -
  Sync environment with renv

### Analysis and Reporting

- [`run_script()`](https://rgt47.github.io/zzcollab/reference/run_script.md) -
  Execute R scripts in container
- [`render_report()`](https://rgt47.github.io/zzcollab/reference/render_report.md) -
  Render analysis reports
- [`validate_repro()`](https://rgt47.github.io/zzcollab/reference/validate_repro.md) -
  Check reproducibility

### Git Integration

- [`git_status()`](https://rgt47.github.io/zzcollab/reference/git_status.md) -
  Check git status
- [`git_commit()`](https://rgt47.github.io/zzcollab/reference/git_commit.md) -
  Create commits
- [`git_push()`](https://rgt47.github.io/zzcollab/reference/git_push.md) -
  Push to GitHub
- [`create_pr()`](https://rgt47.github.io/zzcollab/reference/create_pr.md) -
  Create pull requests
- [`create_branch()`](https://rgt47.github.io/zzcollab/reference/create_branch.md) -
  Create feature branches

## Example R Workflow

``` r

# 0. One-time setup (configure your defaults)
set_config("team_name", "datascience")

# 1. Initialize project (uses config defaults)
init_project(project_name = "covid-analysis")

# 2. Add required packages (inside container via make r)
# In container:
#   install.packages(c("tidyverse", "lubridate", "plotly"))
# Packages automatically captured on exit

# 3. Create feature branch
create_branch("feature/exploratory-analysis")

# 4. Run analysis
run_script("analysis/scripts/exploratory_analysis.R")

# 5. Render report
render_report("analysis/report/report.Rmd")

# 6. Validate reproducibility
validate_repro()

# 7. Commit and push
git_commit("Add COVID-19 exploratory analysis")
git_push()
```

## Installation

### Method 1: Automatic Installation

``` bash
git clone https://github.com/yourusername/zzcollab.git && \
  cd zzcollab && ./install.sh
```

### Method 2: Manual Installation

``` bash
git clone https://github.com/yourusername/zzcollab.git
cd zzcollab
ln -s "$(pwd)/zzcollab.sh" ~/bin/zzcollab
```

## Usage

``` bash
# Create project directory
mkdir my-analysis
cd my-analysis

# Set up research compendium
zzcollab

# Start development environment
make r                  # Interactive shell (edit on host with vim)
```

## Development Workflow

``` bash
# Available development environments
make r                 # Interactive shell (recommended)
make rstudio           # RStudio Server GUI at localhost:8787

# Common tasks
make docker-render     # Generate research paper PDF
make docker-test       # Run package tests
make docker-check      # Validate package structure
make style             # Format R code with styler (in container)
make lint              # Lint R code with lintr (in container)
make snapshot          # Grow renv.lock + DESCRIPTION from the image
make help             # See all available commands
```

## Project Structure

    your-project/
    ├── analysis/              # Research workspace
    │   ├── data/
    │   │   ├── raw_data/     # Original, unmodified data
    │   │   └── derived_data/ # Processed data
    │   ├── report/
    │   │   ├── report.Rmd    # Manuscript
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

## Command Line Options

``` bash
zzcollab <command> [options]
zzcollab <profile>            # quickstart: init + renv + docker
zzcollab config <subcommand>

COMMANDS (can be combined):
  init, renv, docker, git, github, gitlab, push (alias: dockerhub)
  build, doctor, validate, config, list, help

PROFILES (quickstart, or switch profile in an existing project):
  minimal, tidyverse (alias: analysis), rstudio, publishing

GLOBAL OPTIONS:
  -v, --verbose            More output
  -q, --quiet              Errors only
  -y, --yes  /  -Y         Accept defaults (non-interactive)
  --no-build               Skip Docker build prompt
  --version                Print version
  -h, --help               Show help message

PER-COMMAND OPTIONS:
  init:      --force                  Scaffold even if the directory is not empty
  docker:    -b, --build              Build image after generating
             -r, --profile NAME       Select profile (tidyverse, minimal, ...)
             --base-image IMG         Override base image (default: rocker/r-ver)
             --r-version VER          Pin R version
  push:      -t, --tag TAG            Image tag (default: latest); alias: dockerhub
  github:    --private | --public     Repo visibility (default: private)
  gitlab:    --private | --public | --internal   Repo visibility (default: private)
  rm:        -f, --force              Skip the removal confirmation prompt

CONFIG COMMANDS:
  zzcollab config init                    # Create default config
  zzcollab config set KEY VALUE           # Set configuration value
  zzcollab config get KEY                 # Get configuration value
  zzcollab config list                    # List all configuration
  zzcollab config validate                # Validate YAML syntax

EXAMPLES:
  # Configuration (one-time)
  zzcollab config set dockerhub-account myteam   # Docker Hub namespace
  zzcollab config set github-account myorg       # GitHub namespace
  # GitLab instead of GitHub (single forge):
  zzcollab config set forge gitlab               # use GitLab
  zzcollab config set gitlab-account mylab       # GitLab namespace

  # Solo researcher
  mkdir study && cd study
  zzcollab tidyverse                           # Full setup (tidyverse)

  # Team collaboration - Lead
  cd study && zzcollab tidyverse
  zzcollab push                               # Push team image to the registry
  zzcollab github                             # Create repo + push
  # (with forge=gitlab: zzcollab gitlab)

  # Team collaboration - Member
  git clone https://github.com/myteam/study.git && cd study
  make docker-build                           # Build from project Dockerfile
  make r                                      # Start development
  # Inside container: install.packages("pkg") as needed

  # Custom base image
  zzcollab docker --base-image rgt47/r-pluspackages
```

## Docker Integration

### Pre-built Base Images

``` bash
# Use base image with common R packages pre-installed
zzcollab docker --base-image rgt47/r-pluspackages

# Packages included: tidyverse, DT, conflicted, ggthemes,
# datapasta, janitor, kableExtra, tidytuesdayR, and more
```

### Custom Base Images

``` bash
# Build custom base image with organization packages
cd zzcollab
docker build -f templates/Dockerfile.pluspackages \
  -t myorg/r-base:latest .
docker push myorg/r-base:latest

# Use in projects
zzcollab docker --base-image myorg/r-base
```

## Security Considerations

**IMPORTANT**: ZZCOLLAB containers are designed for local development
and research environments, not production deployment.

### Container Security

- **No default passwords**: Containers do not set default passwords for
  security
- **No sudo access**: Users do not have root/sudo privileges in
  containers
- **Local use only**: Containers are intended for local development, not
  internet-facing services

### RStudio Server Authentication

RStudio Server requires authentication. Choose one option:

**Option 1: Set password when starting container** (recommended)

``` bash
docker run -e PASSWORD=your_secure_password -p 8787:8787 your-image
```

**Option 2: Set password in running container**

``` bash
docker exec -it CONTAINER_NAME bash
echo "analyst:your_password" | chpasswd
exit
```

**Option 3: Disable authentication** (local use only)

``` bash
docker run -e RSTUDIO_AUTH=none -p 8787:8787 your-image
```

### Best Practices

- **Do not use default/weak passwords** in any deployment
- **Do not expose RStudio Server to the internet** without proper
  authentication and HTTPS
- **Use strong passwords** if running containers on shared systems
- **Keep containers updated** by rebuilding with latest base images
- **Limit port exposure** - only expose ports you need (e.g., 8787 for
  RStudio)

## Use Cases

### Academic Research

- Manuscript preparation with automated figure/table generation
- Reproducible analysis with automated dependency management
- Collaboration with standardized project structure
- Publication with GitHub Actions workflows

### Data Science Projects

- Exploratory data analysis with organized script structure
- Model development with testing and validation
- Reporting with R Markdown integration
- Deployment with containerized environments

### Team Collaboration

- Team lead defines Docker profile (R version, system dependencies)
- Team members add R packages independently using standard R commands
- Packages automatically captured and shared via renv.lock
- Consistent base environment across all team members
- Version control integration with Git/GitHub

## Documentation

- [Tutorial Examples](https://rgt47.github.io/zzcollab/examples/) -
  Step-by-step learning resources
- [Command Reference](#command-line-options) - All available options
- [Docker Guide](#docker-integration) - Container workflows
- [Troubleshooting](#troubleshooting) - Common issues and solutions

## Tutorial Examples

Comprehensive tutorial examples and code patterns available at:
<https://github.com/rgt47/zzcollab/tree/main/examples>

**Available Resources**:

- **Tutorials**: Step-by-step workflows for EDA, modeling, validation,
  dashboards, reporting
- **Complete Projects**: Full example research compendia demonstrating
  end-to-end workflows
- **Code Patterns**: Reusable patterns for data validation, model
  evaluation, reproducible plots

These examples are located in the zzcollab repository (not installed
with projects) as learning resources available for reference.

### Getting Help

``` bash
zzcollab --help            # Command line help
zzcollab help next-steps   # Show workflow guidance
make help                  # Show all make targets
```

## Requirements

### Required

- **Docker** - For containerized development environments
- **Git** - For version control (recommended)

### Optional

- **R and RStudio** - For native development (can work entirely in
  Docker)
- **GitHub CLI** (`gh`) - For automated repository creation
- **Make** - Usually pre-installed on Unix systems

### System Support

- macOS (Intel and Apple Silicon)
- Linux (Ubuntu, CentOS, etc.)
- Windows (with WSL2 recommended)

## Troubleshooting

### Common Issues

**Docker build fails:**

``` bash
# Try disabling BuildKit
export DOCKER_BUILDKIT=0
zzcollab
```

**Platform warnings on ARM64 (Apple Silicon):**

``` bash
# Already handled automatically with --platform linux/amd64
# Or set environment variable:
export DOCKER_DEFAULT_PLATFORM=linux/amd64
```

**Package name errors:**

``` bash
# Ensure directory name contains only letters, numbers, and periods
# Avoid underscores and special characters
# Must start with a letter
```

**Permission errors:**

``` bash
# Check directory permissions
ls -la
# Make sure Docker is running
docker info
```

### Getting Help

1.  Check the [User
    Guide](https://rgt47.github.io/zzcollab/templates/ZZCOLLAB_USER_GUIDE.md)
    for detailed workflows
2.  Use built-in help: `zzcollab --help`
3.  Validate your environment: `make check-renv`
4.  Clean and rebuild: `make docker-clean && make docker-build`
5.  Open an issue on GitHub with system details and error messages

## Contributing

### Reporting Issues

- Bug reports with system info and reproduction steps
- Feature requests with use case descriptions
- Documentation improvements and clarifications

### Development Setup

``` bash
# Fork and clone the repository
git clone https://github.com/yourusername/zzcollab.git
cd zzcollab

# Make changes to zzcollab.sh or templates/
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

This project is licensed under the GNU General Public License v3.0 - see
the [LICENSE](https://rgt47.github.io/zzcollab/LICENSE) file for
details.

- Free to use for any purpose
- Modify and distribute with same license
- Commercial use allowed
- Source code must remain open
- No warranty provided

## Acknowledgments

- [Ben Marwick et al.](https://doi.org/10.1080/00031305.2017.1375986) -
  Research compendium framework
- [rrtools](https://github.com/benmarwick/rrtools) - Original research
  compendium implementation
- [Rocker Project](https://rocker-project.org/) - Docker images for R
- [renv](https://rstudio.github.io/renv/) - R dependency management
- R Community
