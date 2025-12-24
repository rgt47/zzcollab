# ZZCOLLAB Documentation

This directory contains comprehensive documentation for the ZZCOLLAB framework.
Documentation is organized into subdirectories by purpose.

## Directory Structure

```
docs/
├── adr/           # Architecture Decision Records
├── archive/       # Historical documents (completed plans, analyses)
├── guides/        # User guides and how-tos
├── motivation/    # Research motivation documents
├── standards/     # Coding and development standards
└── *.md           # Core reference documentation
```

## Quick Start

- **New Users**: Start with [guides/workflow.md](guides/workflow.md) and the
  [motivation/REPRODUCIBILITY_WORKFLOW_TUTORIAL.md](motivation/REPRODUCIBILITY_WORKFLOW_TUTORIAL.md)
- **Configuration**: See [CONFIGURATION.md](CONFIGURATION.md)
- **Docker Profiles**: See [VARIANTS.md](VARIANTS.md)
- **Testing**: See [TESTING_GUIDE.md](TESTING_GUIDE.md)

## Core Documentation

| Document | Purpose |
|----------|---------|
| [CHANGELOG.md](CHANGELOG.md) | Version history and release notes |
| [CONFIGURATION.md](CONFIGURATION.md) | Multi-layer configuration system |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Developer commands and workflows |
| [DOCKER_ARCHITECTURE.md](DOCKER_ARCHITECTURE.md) | Docker technical details |
| [TESTING_GUIDE.md](TESTING_GUIDE.md) | Testing framework and best practices |
| [VARIANTS.md](VARIANTS.md) | Docker profile system (14+ profiles) |
| [TEAM_WORKFLOW.md](TEAM_WORKFLOW.md) | Team collaboration patterns |
| [COLLABORATIVE_REPRODUCIBILITY.md](COLLABORATIVE_REPRODUCIBILITY.md) | Five Pillars model |
| [VALIDATION_QUICK_REFERENCE.md](VALIDATION_QUICK_REFERENCE.md) | Package validation reference |

## Subdirectories

### [adr/](adr/) - Architecture Decision Records

Formal records of significant architectural decisions:

- [0000-TEMPLATE.md](adr/0000-TEMPLATE.md) - ADR template
- [0001-r-version-detection-and-mismatch-handling.md](adr/0001-r-version-detection-and-mismatch-handling.md)

### [guides/](guides/) - User Guides

Practical how-to guides for common tasks:

- [workflow.md](guides/workflow.md) - Daily development workflow
- [config.md](guides/config.md) - Configuration management
- [docker.md](guides/docker.md) - Docker operations
- [renv.md](guides/renv.md) - Package management with renv
- [cicd.md](guides/cicd.md) - CI/CD pipeline setup
- [troubleshooting.md](guides/troubleshooting.md) - Common issues and solutions

### [motivation/](motivation/) - Research Motivation

Documents explaining why certain practices matter:

- [REPRODUCIBILITY_WORKFLOW_TUTORIAL.md](motivation/REPRODUCIBILITY_WORKFLOW_TUTORIAL.md) - Hands-on tutorial
- [REPRODUCIBILITY_BEST_PRACTICES.md](motivation/REPRODUCIBILITY_BEST_PRACTICES.md) - Best practices guide
- [UNIT_TESTING_MOTIVATION_DATA_ANALYSIS.md](motivation/UNIT_TESTING_MOTIVATION_DATA_ANALYSIS.md) - Testing rationale
- [CICD_MOTIVATION_DATA_ANALYSIS.md](motivation/CICD_MOTIVATION_DATA_ANALYSIS.md) - CI/CD rationale
- [DOCKER_MOTIVATION_DATA_ANALYSIS.md](motivation/DOCKER_MOTIVATION_DATA_ANALYSIS.md) - Docker rationale
- [RENV_MOTIVATION_DATA_ANALYSIS.md](motivation/RENV_MOTIVATION_DATA_ANALYSIS.md) - renv rationale
- [WHY_DOCKER_AND_RENV.md](motivation/WHY_DOCKER_AND_RENV.md) - Combined approach
- [VALIDATION_WHITEPAPER.md](motivation/VALIDATION_WHITEPAPER.md) - Validation system design

### [standards/](standards/) - Development Standards

Coding standards and development guidelines:

- [BASH_STANDARDS.md](standards/BASH_STANDARDS.md) - Bash coding standards
- [BASH_IMPROVEMENTS_SUMMARY.md](standards/BASH_IMPROVEMENTS_SUMMARY.md) - Quality achievements
- [CODING_STANDARDS.md](standards/CODING_STANDARDS.md) - General coding guidelines
- [ERROR_MESSAGE_DEVELOPER_GUIDE.md](standards/ERROR_MESSAGE_DEVELOPER_GUIDE.md) - Error message patterns
- [MODULE_DEPENDENCIES.md](standards/MODULE_DEPENDENCIES.md) - Module architecture

### [archive/](archive/) - Historical Documents

Completed plans, one-time analyses, and deprecated documents. These are kept
for historical reference but are not actively maintained.

## Additional Reference

| Document | Purpose |
|----------|---------|
| [DOCUMENTATION_STRATEGY.md](DOCUMENTATION_STRATEGY.md) | Three-tier documentation system |
| [ERROR_HANDLING_GUIDE.md](ERROR_HANDLING_GUIDE.md) | Error handling patterns |
| [GUI_PROFILE_GUIDE.md](GUI_PROFILE_GUIDE.md) | X11/GUI profile setup |
| [SHELL_TESTING_SETUP.md](SHELL_TESTING_SETUP.md) | Shell test infrastructure |
| [TESTING_LESSONS_LEARNED.md](TESTING_LESSONS_LEARNED.md) | Testing discoveries |
| [UNIFIED_PARADIGM_GUIDE.md](UNIFIED_PARADIGM_GUIDE.md) | Research compendium design |
| [VERBOSITY_LEVELS.md](VERBOSITY_LEVELS.md) | Logging verbosity system |
| [X11_PLOTTING_WORKFLOW.md](X11_PLOTTING_WORKFLOW.md) | Graphics workflows |
| [zzcollab_python.md](zzcollab_python.md) | Multi-language considerations |

## Related Documentation

- **Root README.md**: Project overview and quick start
- **CLAUDE.md**: Comprehensive architecture reference (AI/developer context)
- **vignettes/**: R package vignettes with detailed tutorials
- **templates/ZZCOLLAB_USER_GUIDE.md**: End-user documentation

---

**Last Updated**: December 2025
