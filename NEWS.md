# zzcollab 0.1.0

## Initial Release

### Core Framework

* Docker-based reproducible research environments
* Five Pillars of Reproducibility (Dockerfile, renv.lock, .Rprofile, source code, data)
* Two-layer architecture: Docker profile (team lead) + R packages (members)
* Research compendium structure following Marwick et al. (2018)

### Docker Integration

* 14+ specialized Docker profiles (minimal, analysis, publishing, bioinformatics, etc.)
* Auto-snapshot/restore architecture for package management
* Host-based validation without requiring R installation
* Profile system with configurable R versions and system dependencies

### Configuration System

* Multi-level hierarchy (project, user, system, defaults)
* YAML-based configuration files
* CLI configuration management

### R Package Interface

* `init_project()` for solo and team project initialization
* `join_project()` for team member onboarding
* Configuration management functions (get_config, set_config, list_config)
* Docker management utilities

### Documentation

* Comprehensive user guide
* Technical documentation for testing, configuration, variants
* Developer workflow guides
* Vignette system with examples

### System Requirements

* Docker required for containerized development
* Git recommended for version control
* Optional: GitHub CLI for automated repository creation
