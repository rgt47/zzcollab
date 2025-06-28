# ZZRRTOOLS

[![License: GPL-3](https://img.shields.io/badge/License-GPL%203-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Docker](https://img.shields.io/badge/Docker-Enabled-2496ED?logo=docker)](https://www.docker.com/)
[![R](https://img.shields.io/badge/R-4.0+-276DC3?logo=r)](https://www.r-project.org/)

A tool for creating reproducible research compendia with R package structure, Docker integration, and automated workflows.

## Features

- Docker-based development environment
- R package structure with documentation
- renv dependency management
- Analysis templates and paper generation
- Make-based automation
- GitHub Actions CI/CD workflows
- Personal dotfiles integration
- Symbolic links for navigation
- Safe file operations (no overwrites)

## Installation

### Method 1: Automatic Installation

```bash
git clone https://github.com/yourusername/zzrrtools.git && cd zzrrtools && ./install.sh
```

### Method 2: Manual Installation

```bash
git clone https://github.com/yourusername/zzrrtools.git
cd zzrrtools
ln -s "$(pwd)/zzrrtools.sh" ~/bin/zzrrtools
```

## Usage

```bash
# Create project directory
mkdir my-analysis
cd my-analysis

# Set up research compendium
zzrrtools --dotfiles ~/dotfiles

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
├── R/                     # Package functions (exported to users)
├── analysis/              # Research analysis components
│   ├── paper/            # Research paper (paper.Rmd → paper.pdf)
│   ├── figures/          # Generated plots and visualizations
│   └── tables/           # Generated statistical tables
├── data/                  # Data management
│   ├── raw_data/         # Original, unmodified datasets
│   ├── derived_data/     # Processed, analysis-ready data
│   ├── metadata/         # Data dictionaries and documentation
│   └── validation/       # Data quality reports
├── scripts/               # Working R scripts and exploratory analysis
├── tests/                 # Unit tests for package functions
├── docs/                  # Project documentation
├── .github/workflows/     # Automated CI/CD pipelines
├── DESCRIPTION           # R package metadata
├── Dockerfile            # Reproducible environment definition
├── Makefile              # Automation commands
└── Symbolic links (a→data, n→analysis, p→paper, etc.)
```

## Command Line Options

```bash
zzrrtools [OPTIONS]

OPTIONS:
  --dotfiles DIR       Copy dotfiles from directory (files with leading dots)
  --dotfiles-nodot DIR Copy dotfiles from directory (files without leading dots) 
  --base-image NAME    Use custom Docker base image (default: rocker/r-ver)
  --no-docker          Skip Docker image build during setup
  --next-steps         Show development workflow and next steps
  --help, -h           Show help message

EXAMPLES:
  zzrrtools                                    # Basic setup
  zzrrtools --dotfiles ~/dotfiles              # Include personal dotfiles
  zzrrtools --dotfiles-nodot ~/dotfiles        # Dotfiles without leading dots
  zzrrtools --base-image rgt47/r-pluspackages  # Use custom base image
  zzrrtools --no-docker                        # Setup without Docker build
```

## Docker Integration

### Pre-built Base Images

```bash
# Use base image with common R packages pre-installed
zzrrtools --base-image rgt47/r-pluspackages

# Packages included: tidyverse, DT, conflicted, ggthemes, datapasta, 
# janitor, kableExtra, tidytuesdayR, and more
```

### Custom Base Images

```bash
# Build custom base image with your organization's packages
cd zzrrtools
docker build -f templates/Dockerfile.pluspackages -t myorg/r-base:latest .
docker push myorg/r-base:latest

# Use in projects
zzrrtools --base-image myorg/r-base
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

- [User Guide](templates/ZZRRTOOLS_USER_GUIDE.md) - Comprehensive documentation
- [Command Reference](#command-line-options) - All available options
- [Docker Guide](#docker-integration) - Container workflows
- [Troubleshooting](#troubleshooting) - Common issues and solutions

### Getting Help
```bash
zzrrtools --help          # Command line help
zzrrtools --next-steps     # Show workflow guidance
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
zzrrtools
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
zzrrtools --dotfiles ~/dotfiles
# or for files without leading dots:
zzrrtools --dotfiles-nodot ~/dotfiles
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

1. Check the [User Guide](templates/ZZRRTOOLS_USER_GUIDE.md) for detailed workflows
2. Use built-in help: `zzrrtools --help`
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
git clone https://github.com/yourusername/zzrrtools.git
cd zzrrtools

# Make your changes to zzrrtools.sh or templates/
# Test with a sample project
mkdir test-project && cd test-project
../zzrrtools.sh

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

- [rrtools](https://github.com/benmarwick/rrtools) - Original research compendium framework
- [Rocker Project](https://rocker-project.org/) - Docker images for R
- [renv](https://rstudio.github.io/renv/) - R dependency management
- R Community

