# ZZCOLLAB Module Dependencies

This document maps the dependencies between zzcollab modules to help with maintenance and development.

## Module Loading Order

Modules must be loaded in dependency order to ensure all required functions are available:

```
1. constants.sh    (foundation - no dependencies)
2. core.sh         (depends on constants.sh)
3. templates.sh    (depends on core.sh)
4. structure.sh    (depends on core.sh, templates.sh)
5. utils.sh        (depends on core.sh)
6. config.sh       (depends on core.sh, constants.sh)
7. cli.sh          (depends on core.sh, constants.sh)
8. rpackage.sh     (depends on core.sh, templates.sh)
9. docker.sh       (depends on core.sh, templates.sh)
10. analysis.sh    (depends on core.sh, templates.sh, utils.sh)
11. cicd.sh        (depends on core.sh, templates.sh)
12. devtools.sh    (depends on core.sh, templates.sh)
13. team_init.sh   (depends on core.sh, templates.sh, docker.sh)
14. help.sh        (depends on core.sh)
15. github.sh      (depends on core.sh)
```

## Dependency Graph

```
constants.sh (foundation)
├── core.sh
│   ├── templates.sh
│   │   ├── structure.sh
│   │   ├── rpackage.sh
│   │   ├── docker.sh
│   │   │   └── team_init.sh
│   │   ├── analysis.sh (also depends on utils.sh)
│   │   ├── cicd.sh
│   │   └── devtools.sh
│   ├── utils.sh
│   ├── help.sh
│   └── github.sh
├── config.sh (also depends on core.sh)
└── cli.sh (also depends on core.sh)
```

## Module Functions

### Foundation Modules
- **constants.sh**: Global constants, paths, defaults
- **core.sh**: Logging, validation, tracking, utilities
- **templates.sh**: Template processing and file creation

### Configuration Modules  
- **config.sh**: Configuration file management
- **cli.sh**: Command-line argument processing

### Feature Modules
- **structure.sh**: Directory structure creation
- **rpackage.sh**: R package development files
- **docker.sh**: Docker containerization
- **analysis.sh**: Research analysis framework
- **cicd.sh**: GitHub Actions workflows
- **devtools.sh**: Development tools and configs
- **team_init.sh**: Team collaboration setup
- **help.sh**: Help system and documentation
- **github.sh**: GitHub repository management
- **utils.sh**: Utility functions

## Module Loading Validation

Each module uses `require_module()` to validate dependencies:

```bash
# Example from analysis.sh
require_module "core" "templates" "utils"
```

This ensures that if a module is loaded out of order or a dependency is missing, the script will fail fast with a clear error message.

## Adding New Modules

When adding new modules:

1. Add dependency validation at the top
2. Set the loaded flag at the bottom
3. Update this documentation
4. Update the main loading sequence in zzcollab.sh

Example template:
```bash
#!/bin/bash
# Validate required modules are loaded
require_module "core" "templates"

# Your module code here

# Set module loaded flag
readonly ZZCOLLAB_YOURMODULE_LOADED=true
```