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

- **New Users**: Start with [guides/workflow.md](guides/workflow.md)
- **Configuration**: See [configuration.md](configuration.md)
- **Docker Profiles**: See [variants.md](variants.md)
- **Testing**: See [testing-guide.md](testing-guide.md)

## Core Documentation

| Document | Purpose |
|----------|---------|
| [CHANGELOG.md](CHANGELOG.md) | Version history and release notes |
| [configuration.md](configuration.md) | Multi-layer configuration system (includes verbosity) |
| [development.md](development.md) | Developer commands and workflows |
| [docker-architecture.md](docker-architecture.md) | Docker technical details |
| [testing-guide.md](testing-guide.md) | Testing framework and best practices |
| [variants.md](variants.md) | Docker profile system (14+ profiles) |
| [team-workflow.md](team-workflow.md) | Team collaboration patterns |
| [collaborative-reproducibility.md](collaborative-reproducibility.md) | Five Pillars model |
| [validation-quick-reference.md](validation-quick-reference.md) | Package validation reference |
| [x11-graphics-guide.md](x11-graphics-guide.md) | X11/GUI graphics in Docker |
| [error-handling-guide.md](error-handling-guide.md) | Error handling patterns |

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

- [reproducibility-workflow-tutorial.md](motivation/reproducibility-workflow-tutorial.md) - Hands-on tutorial
- [reproducibility-best-practices.md](motivation/reproducibility-best-practices.md) - Best practices guide
- [unit-testing-motivation-data-analysis.md](motivation/unit-testing-motivation-data-analysis.md) - Testing rationale
- [cicd-motivation-data-analysis.md](motivation/cicd-motivation-data-analysis.md) - CI/CD rationale
- [docker-motivation-data-analysis.md](motivation/docker-motivation-data-analysis.md) - Docker rationale
- [renv-motivation-data-analysis.md](motivation/renv-motivation-data-analysis.md) - renv rationale
- [why-docker-and-renv.md](motivation/why-docker-and-renv.md) - Combined approach
- [validation-whitepaper.md](motivation/validation-whitepaper.md) - Validation system design

### [standards/](standards/) - Development Standards

Coding standards and development guidelines:

- [bash-standards.md](standards/bash-standards.md) - Bash coding standards
- [coding-standards.md](standards/coding-standards.md) - General coding guidelines
- [module-dependencies.md](standards/module-dependencies.md) - Module architecture

### [archive/](archive/) - Historical Documents

Completed plans, one-time analyses, and deprecated documents. These are kept
for historical reference but are not actively maintained.

## Additional Reference

| Document | Purpose |
|----------|---------|
| [documentation-strategy.md](documentation-strategy.md) | Three-tier documentation system |
| [shell-testing-setup.md](shell-testing-setup.md) | Shell test infrastructure |
| [testing-lessons-learned.md](testing-lessons-learned.md) | Testing discoveries |
| [unified-paradigm-guide.md](unified-paradigm-guide.md) | Research compendium design |
| [workflow-type-system.md](workflow-type-system.md) | CI/CD workflow types |
| [zzcollab_python.md](zzcollab_python.md) | Multi-language considerations |

## Related Documentation

- **Root README.md**: Project overview and quick start
- **CLAUDE.md**: Comprehensive architecture reference (AI/developer context)
- **vignettes/**: R package vignettes with detailed tutorials
- **templates/ZZCOLLAB_USER_GUIDE.md**: End-user documentation

---

**Last Updated**: December 2025
