# Team Collaboration Workflow Guide

**Official documentation for team-based research projects using ZZCOLLAB**

---

## Table of Contents
1. [Quick Start](#quick-start)
2. [Team Lead Workflow](#team-lead-workflow)
3. [Team Member Workflow](#team-member-workflow)
4. [Daily Workflows](#daily-workflows)
5. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Team Lead (First Time Setup)
```bash
# 1. Create project directory
mkdir study-project && cd study-project

# 2. Initialize with team configuration
zzcollab -t myteam -p study

# 3. Build and push Docker image
make docker-build
make docker-push-team

# 4. Commit and push to GitHub
git add . && git commit -m "Initial team project setup" && git push -u origin main
```

### Team Member (Joining Project)
```bash
# 1. Clone the repository
git clone https://github.com/myteam/study.git && cd study

# 2. Pull team's Docker image
zzcollab -t myteam -p study --use-team-image

# 3. Start development
make docker-sh
```

---

## Team Lead Workflow

### Initial Setup

The team lead establishes the computational foundation that all team members will use.

#### Step 1: Configure Team Settings (Optional)

```bash
# Set default team configuration (one-time setup)
zzcollab --config init
zzcollab --config set team-name "myteam"
zzcollab --config set github-account "myteam"
zzcollab --config set dotfiles-dir "~/dotfiles"
```

#### Step 2: Create Project

```bash
# Navigate to workspace
cd ~/projects

# Create and initialize project
mkdir study-project && cd study-project
zzcollab -t myteam -p study

# Or with explicit options
zzcollab -t myteam -p study --profile-name analysis
```

**What this creates:**
- R package structure
- Docker configuration (Dockerfile)
- Team base image configuration
- GitHub Actions workflows
- Analysis directory structure
- renv.lock for package management

#### Step 3: Build Team Docker Image

```bash
# Build the Docker image
make docker-build

# This creates: myteam/study:latest
```

**Important**: Team Docker image contains:
- R version (locked)
- System dependencies (locked)
- Base R packages (from profile)
- Development tools
- Environment configuration

#### Step 4: Push to Docker Hub

```bash
# Login to Docker Hub (if needed)
docker login

# Push team image
make docker-push-team

# Image now available at: myteam/study:latest
```

#### Step 5: Initialize Git Repository

```bash
# Initialize git (if not already done)
git init
git add .
git commit -m "Initial team project setup"

# Create GitHub repository and push
gh repo create myteam/study --public --source=. --push
```

#### Step 6: Notify Team Members

Share with team:
1. Repository URL: `https://github.com/myteam/study`
2. Docker Hub image: `myteam/study:latest`
3. Team name: `myteam`
4. Project name: `study`

---

## Team Member Workflow

### Initial Setup

Team members pull the pre-built Docker image instead of building locally.

#### Step 1: Clone Repository

```bash
# Clone the team repository
git clone https://github.com/myteam/study.git
cd study
```

#### Step 2: Pull Team Docker Image

```bash
# Option 1: Pull team image automatically
zzcollab -t myteam -p study --use-team-image

# Option 2: Pull manually
docker pull myteam/study:latest
make docker-sh
```

**What `--use-team-image` does:**
- Configures Makefile to pull from Docker Hub
- Skips local Docker build
- Uses team's pre-built image
- Much faster than building locally

#### Step 3: Start Development

```bash
# Enter Docker environment
make docker-sh

# Inside container:
# - All team packages available
# - Consistent environment
# - Add personal packages as needed
```

### Adding Personal Packages

Team members can add packages independently:

```bash
# Inside Docker container
renv::install("ggplot2")
renv::install("dplyr")

# Save to renv.lock
renv::snapshot()

# Exit and commit
exit
git add renv.lock
git commit -m "Add ggplot2 and dplyr packages"
git push
```

**Important**:
- Docker image = team foundation (shared, locked)
- renv.lock = union of all packages (collaborative, grows)
- Team members add packages independently
- Lead does NOT need to rebuild Docker image

---

## Daily Workflows

### Team Lead

#### Updating Docker Foundation

Only needed when:
- Changing R version
- Adding system dependencies
- Changing base image

```bash
# Update Dockerfile or profile
vim Dockerfile  # or update --profile-name

# Rebuild and push
make docker-build
make docker-push-team

# Notify team to pull new image
git add Dockerfile
git commit -m "Update Docker foundation: add GDAL support"
git push
```

#### Reviewing Team Contributions

```bash
# Pull latest changes
git pull

# Review renv.lock changes
git log -p renv.lock

# Restore environment
make r
renv::restore()
```

### Team Members

#### Standard Development Workflow

```bash
# 1. Pull latest changes
git pull

# 2. Restore packages
make r
renv::restore()

# 3. Work on analysis
# ... make changes ...

# 4. Add any new packages needed
renv::install("newpackage")
renv::snapshot()

# 5. Commit and push
exit
git add .
git commit -m "Add analysis for aim 2"
git push
```

#### Syncing with Team Updates

```bash
# Pull team changes
git pull

# Check if Docker image updated
git log --oneline Dockerfile

# If Dockerfile changed, pull new image
docker pull myteam/study:latest

# Restore packages
make r
renv::restore()
```

---

## Foundation vs. Packages

Understanding the two-layer system:

### Layer 1: Docker Image (Team Foundation)
**Controlled by**: Team lead
**Contains**: R version, system libraries, base packages
**Frequency**: Rarely changes (weeks/months)
**Sharing**: Docker Hub

```bash
# Lead updates:
make docker-build && make docker-push-team

# Members sync:
docker pull myteam/study:latest
```

### Layer 2: R Packages (Personal Choice)
**Controlled by**: Each team member
**Contains**: Analysis-specific packages
**Frequency**: Changes often (daily)
**Sharing**: renv.lock in git

```bash
# Anyone can add:
renv::install("tidyverse")
renv::snapshot()
git push

# Everyone syncs:
git pull
renv::restore()
```

**Key Principle**: Docker provides speed and consistency. renv provides flexibility and reproducibility.

---

## Configuration Flags

### Team Lead Flags

```bash
# Minimal
zzcollab -t TEAM -p PROJECT

# With dotfiles
zzcollab -t TEAM -p PROJECT

# With custom profile
zzcollab -t TEAM -p PROJECT --profile-name bioinformatics

# With custom base image
zzcollab -t TEAM -p PROJECT -b rocker/geospatial
```

### Team Member Flags

```bash
# Standard (pulls team image)
zzcollab -t TEAM -p PROJECT --use-team-image

# With dotfiles
zzcollab -t TEAM -p PROJECT --use-team-image

# Build locally (not recommended)
zzcollab -t TEAM -p PROJECT  # omit --use-team-image
```

### Automation Flags

```bash
# For CI/CD pipelines (skip file conflict prompts)
zzcollab -t TEAM -p PROJECT --force

# Combine with other flags
zzcollab -t TEAM -p PROJECT --use-team-image --force
```

**When to use `--force`**:
- CI/CD workflows (GitHub Actions, GitLab CI, etc.)
- Automated testing environments
- Container build pipelines
- Any non-interactive context where prompts would fail

**Security note**: Only use `--force` in trusted automation contexts. It will overwrite existing files without confirmation.

---

## Troubleshooting

### "Cannot use --profile-name: Dockerfile already exists"

**Problem**: Trying to change foundation after it's set

**Solution**:
```bash
# Only team lead can change foundation:
rm Dockerfile
zzcollab -t TEAM -p PROJECT --profile-name NEW_PROFILE
make docker-build && make docker-push-team
```

### "Docker image pull failed"

**Problem**: Team image not pushed or authentication issue

**Solution**:
```bash
# Verify image exists
docker search myteam/study

# Login to Docker Hub
docker login

# Pull manually
docker pull myteam/study:latest
```

### "Package installation failed in renv::restore()"

**Problem**: Package dependencies missing from Docker image

**Solution**:
```bash
# Temporary: Install in container
make r
install.packages("problematic-package")

# Permanent: Ask lead to update Docker image
# Lead adds system dependency to Dockerfile
```

### "Merge conflicts in renv.lock"

**Problem**: Two team members added different packages

**Solution**:
```bash
# Accept both changes (union model)
git pull
# Manually merge renv.lock keeping all packages
renv::restore()  # Install all packages
```

---

## Best Practices

### For Team Leads

1. **Minimize Docker Changes**: Only rebuild for system dependencies
2. **Document Foundation**: Clearly communicate Docker image contents
3. **Test Before Pushing**: Ensure Docker image works before sharing
4. **Version Images**: Use tags for major changes: `myteam/study:v2.0`
5. **Communication**: Notify team when foundation changes

### For Team Members

1. **Pull Before Push**: Always `git pull` before starting work
2. **Snapshot Regularly**: Run `renv::snapshot()` after adding packages
3. **Don't Build Locally**: Use `--use-team-image` for consistency
4. **Test Packages**: Ensure packages work before committing renv.lock
5. **Communicate**: Mention major package additions in commits

### For Everyone

1. **Commit Messages**: Be descriptive about changes
2. **Pull Requests**: Use PRs for major analysis changes
3. **Documentation**: Update docs when adding features
4. **Testing**: Run tests before pushing (`make test`)
5. **Reproducibility**: Verify analyses run in clean environment

---

## Migration from Solo to Team

Converting an existing solo project to team collaboration:

```bash
# 1. Navigate to existing project
cd my-solo-project

# 2. Re-initialize with team settings
zzcollab -t myteam -p study

# 3. Build and push team image
make docker-build
make docker-push-team

# 4. Commit and push
git add .
git commit -m "Convert to team collaboration project"
git push -u origin main
```

---

## Related Documentation

- [Configuration Guide](CONFIGURATION.md) - Multi-level config system
- [Docker Architecture](DOCKER_ARCHITECTURE.md) - Docker technical details
- [Profile System](VARIANTS.md) - Available Docker profiles
- [Development Guide](DEVELOPMENT.md) - Daily development commands

---

**Last Updated**: October 2025
**ZZCOLLAB Version**: 2.0+
