# Development Commands

This guide covers all development commands for working with ZZCOLLAB, including R package development, Docker management, testing, and team collaboration workflows.

*For comprehensive testing documentation, see [Testing Guide](TESTING_GUIDE.md)*

## R Package Development

### Native R Development
```bash
# Native R (requires local R installation)
make test                    # Run R package tests
make check                   # R CMD check validation
make document               # Generate documentation
make build                  # Build R package
```

### Docker-based Development
```bash
# Docker-based (works without local R)
make docker-test           # Run tests in container
make docker-check          # Package validation
make docker-document       # Generate docs
make docker-render         # Render analysis reports
```

### CI/CD Validation
```bash
# CI/CD validation (enhanced with build mode awareness)
Rscript validate_package_environment.R --quiet --fail-on-issues  # Dependency validation
Rscript validate_package_environment.R --build-mode fast --quiet --fail-on-issues  # Fast mode validation
ZZCOLLAB_BUILD_MODE=comprehensive Rscript validate_package_environment.R --fix --fail-on-issues  # Environment variable
Rscript check_rprofile_options.R                          # R options monitoring

# Container-based CI commands (used in GitHub Actions)
docker run --rm -v $(PWD):/project rocker/tidyverse:latest Rscript validate_package_environment.R --quiet --fail-on-issues
docker run --rm -v $(PWD):/project rocker/tidyverse:latest Rscript -e "rcmdcheck::rcmdcheck(args = '--no-manual', error_on = 'warning')"
```

## Docker Development Environments

### Development Shells
```bash
make docker-zsh            # Zsh shell with dotfiles (recommended)
make docker-rstudio        # RStudio Server at localhost:8787
make docker-verse          # Verse environment with LaTeX (publishing)
make docker-r              # R console only
make docker-bash           # Bash shell
```

## Docker Environment Management

### Viewing Available Options
```bash
# View available base images and package bundles
cat bundles.yaml           # View all available profiles and packages
```

### Customizing Docker Environment
```bash
# Customize Docker environment
vim Dockerfile             # Edit base image, R packages, system dependencies

# Build custom Docker image
make docker-build          # Build team/project-specific image
make docker-push-team      # Share with team (for team lead)

# Team members use pre-built image
zzcollab --use-team-image  # Download and use team's Docker image
```

## Dependency Management

### renv Commands
```bash
make check-renv            # Check renv status
make check-renv-fix        # Update renv.lock
make docker-check-renv     # Validate in container
Rscript validate_package_environment.R --quiet --fail-on-issues  # CI validation
Rscript validate_package_environment.R --fix --fail-on-issues    # Auto-fix missing packages
Rscript validate_package_environment.R --build-mode fast --fix   # Build mode aware validation
```

## Installation and Setup

### ZZCOLLAB Installation
```bash
# One-time zzcollab installation
./install.sh                    # Installs zzcollab to ~/bin
export PATH="$HOME/bin:$PATH"   # Add to shell config if needed
```

## Docker Image Building Workflow

### Team Lead - Build and Share Team Image
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

### Team Member - Use Pre-Built Team Image
```bash
# 1. Clone team project
git clone https://github.com/TEAM/PROJECT.git
cd PROJECT

# 2. Use team's Docker image
zzcollab --use-team-image -d ~/dotfiles

# 3. Start development
make docker-zsh            # Enter container with team environment
```

### Solo Developer - Build Personal Image
```bash
# 1. Create project (no team)
zzcollab -p PROJECT -d ~/dotfiles

# 2. Customize if needed
vim Dockerfile             # Adjust packages, base image

# 3. Build image
make docker-build          # Builds personal Docker image
```

## Team Collaboration Setup

### Developer 1 (Team Lead) - Complete Workflow
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

### Developer 2+ (Team Members) - Join Existing Project
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

# That's it! You are using the exact same environment as the team lead.
```

### Environment Customization (Team Lead)
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

### Error Handling
```bash
# If team member cannot pull team image:
# Error: Unable to pull TEAM/PROJECTcore:latest from Docker Hub

# Solutions:
#    1. Ask team lead to verify image was pushed: make docker-push-team
#    2. Check Docker Hub permissions (image must be public or you need access)
#    3. Build image locally if needed: make docker-build
```

## Package Management

### Dynamic Package Installation

ZZCOLLAB uses **dynamic package management** via renv for maximum flexibility:

```bash
# Inside Docker container
make docker-zsh

# Add packages as needed
renv::install("tidyverse")
renv::install("sf")
renv::install("targets")

# Save to renv.lock
renv::snapshot()

# Exit and commit
exit
git add renv.lock
git commit -m "Add analysis packages"
```

### Docker Profiles

**Profile System**: Select pre-configured Docker environments optimized for different use cases:

```bash
# Minimal profile (lightweight, ~200MB)
zzcollab --profile-name minimal

# Analysis profile (tidyverse + common packages)
zzcollab --profile-name analysis

# Bioinformatics profile (Bioconductor packages)
zzcollab --profile-name bioinformatics

# Geospatial profile (GDAL, PROJ, sf, terra)
zzcollab --profile-name geospatial
```

*For complete profile documentation, see [Variants Guide](VARIANTS.md)*

### Dockerfile Customization

Team leads can customize the Docker environment:

```dockerfile
# 1. Choose base image (line ~3):
FROM rocker/rstudio:4.4.0     # RStudio Server
# FROM rocker/r-ver:4.4.0     # Shell-only
# FROM rocker/verse:4.4.0     # Publishing with LaTeX

# 2. Add system dependencies (line ~29):
RUN apt-get update && apt-get install -y \
    libgdal-dev \
    libproj-dev

# 3. Install base R packages (line ~106):
RUN ${R_PACKAGES_INSTALL_CMD}
```

### Team Collaboration Workflow

```bash
# Team Lead:
zzcollab -t team -p project --profile-name analysis
make docker-build && make docker-push-team
git add . && git commit -m "Initial setup" && git push

# Team Members:
git clone https://github.com/team/project.git && cd project
zzcollab --use-team-image
make docker-zsh
# Add packages as needed with renv::install()
```

## Key Benefits

- **Dynamic flexibility**: Add packages on-demand via renv::install()
- **Docker profiles**: Pre-configured environments for common use cases
- **Full Docker control**: Customize base image and system dependencies
- **Easy sharing**: Team members use --use-team-image
- **Collaborative renv.lock**: Accumulates packages from all contributors

## Related Documentation

- **Testing**: [Testing Guide](TESTING_GUIDE.md)
- **Build Modes**: [Build Modes Guide](BUILD_MODES.md)
- **Configuration**: [Configuration Guide](CONFIGURATION.md)
- **Docker Profiles**: [Variants Guide](VARIANTS.md)
