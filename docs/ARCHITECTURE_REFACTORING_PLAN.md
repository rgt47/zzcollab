# ZZCOLLAB Architecture Refactoring Plan

## Executive Summary

This document outlines a comprehensive refactoring of the zzcollab framework to:

1. Eliminate code duplication in projects (~100KB per project)
2. Centralize tools for easier maintenance and updates
3. Modernize the CLI with subcommand patterns
4. Follow conventional directory structures

---

## Current State

### Installed Location (`~/bin/`)

```
~/bin/zzcollab                           # 39KB standalone script
~/bin/zzcollab-support/
    ├── modules/                         # 21 framework modules (~320KB)
    │   ├── cli.sh, docker.sh, config.sh, ...
    │   └── validation.sh (77KB)
    └── templates/                       # Project scaffolding
        ├── modules/                     # DUPLICATE subset (6 files, ~100KB)
        │   ├── core.sh, utils.sh, constants.sh
        │   ├── navigation_scripts.sh, setup_symlinks.sh
        │   └── validation.sh
        ├── zzcollab-uninstall.sh        # Copied to each project
        ├── Makefile                     # References local modules/
        └── ... (Dockerfiles, templates, etc.)
```

### Source Repository (`~/prj/d07/zzcollab/`)

- Same structure as installed
- `install.sh` copies to `~/bin/`

### Current Project Structure (After Setup)

```
project/
    ├── modules/                         # ~100KB of framework code
    │   ├── core.sh, utils.sh, constants.sh
    │   ├── navigation_scripts.sh, setup_symlinks.sh
    │   └── validation.sh
    ├── .zzcollab/
    │   ├── manifest.json
    │   └── uninstall.sh                 # ~26KB duplicate
    ├── Makefile                         # Calls local modules/validation.sh
    └── ... (project files)
```

### Problems

| Problem | Impact |
|---------|--------|
| `templates/modules/` duplicates framework code | ~100KB per project |
| `templates/zzcollab-uninstall.sh` copied to each project | ~26KB per project |
| Updates don't propagate to existing projects | Maintenance burden |
| Awkward `~/bin/zzcollab-support/` naming | Non-standard |
| Mixed CLI patterns (`--config` flag vs subcommands) | Inconsistent UX |

---

## Target State

### Installed Location

```
~/.zzcollab/                             # Hidden framework home
    ├── zzcollab.sh                      # Main CLI with subcommand support
    ├── modules/                         # Internal CLI modules
    │   ├── cli.sh                       # Updated: subcommand routing
    │   ├── docker.sh
    │   ├── config.sh
    │   ├── structure.sh
    │   └── ... (other internal modules)
    ├── lib/                             # NEW: Shared libraries
    │   ├── core.sh                      # Logging, tracking
    │   ├── utils.sh                     # Utility functions
    │   └── constants.sh                 # Global constants
    ├── bin/                             # NEW: Standalone tools
    │   ├── validate.sh                  # Package validation
    │   ├── uninstall.sh                 # Project uninstall
    │   └── nav.sh                       # Navigation setup
    └── templates/                       # Project scaffolding (CLEANED)
        ├── Makefile                     # Updated: calls `zzcollab validate`
        ├── Dockerfile.*
        ├── .Rprofile, DESCRIPTION, etc.
        └── ... (NO modules/, NO uninstall.sh)

~/bin/zzcollab                           # Symlink → ~/.zzcollab/zzcollab.sh
```

### Target Project Structure (After Setup)

```
project/
    ├── .zzcollab/
    │   └── manifest.json                # Metadata only, NO scripts
    ├── Makefile                         # Calls `zzcollab validate`
    ├── Dockerfile
    ├── .Rprofile
    ├── DESCRIPTION
    ├── renv.lock
    ├── analysis/, R/, tests/, ...
    └── (NO modules/ directory)
```

### Comparison

| Aspect | Current | Target |
|--------|---------|--------|
| Framework location | `~/bin/zzcollab-support/` | `~/.zzcollab/` |
| Project overhead | ~126KB scripts | ~1KB manifest only |
| Update propagation | Manual per-project | Automatic |
| CLI pattern | Mixed flags/subcommands | Consistent subcommands |
| Tool invocation | Local `modules/validation.sh` | `zzcollab validate` |

---

## CLI Interface Changes

### Current CLI

```bash
# Project setup
zzcollab [setup flags]

# Config management (flag-based, unusual pattern)
zzcollab --config init
zzcollab --config set key value
zzcollab --config get key
zzcollab --config list
```

### Target CLI

```bash
# Default action (no subcommand) = project setup (unchanged)
zzcollab [setup flags]

# Subcommands (new)
zzcollab validate [--fix] [--strict] [--verbose]
zzcollab uninstall [--dry-run] [--force] [--keep-docker]
zzcollab nav install
zzcollab nav uninstall

# Config as subcommand (cleaner)
zzcollab config init
zzcollab config set <key> <value>
zzcollab config get <key>
zzcollab config list

# Help system
zzcollab help                            # General help
zzcollab help <subcommand>               # Subcommand-specific help
zzcollab --help                          # Alias for help
zzcollab <subcommand> --help             # Subcommand help
```

### Subcommand Reference

| Subcommand | Purpose | Key Flags |
|------------|---------|-----------|
| `validate` | Package dependency validation | `--fix`, `--strict`, `--verbose`, `--system-deps` |
| `uninstall` | Remove zzcollab from project | `--dry-run`, `--force`, `--keep-docker` |
| `nav install` | Install shell navigation shortcuts | None |
| `nav uninstall` | Remove shell navigation shortcuts | None |
| `config init` | Create default config file | `--global`, `--project` |
| `config set` | Set configuration value | None |
| `config get` | Get configuration value | None |
| `config list` | List all configuration | `--global`, `--project` |
| `help` | Show help | None |

---

## Implementation Phases

### Phase 1: Create New Directory Structure

**Objective**: Establish `lib/` and `bin/` directories in the repository.

#### Step 1.1: Create `lib/` directory

```bash
mkdir -p lib/
```

#### Step 1.2: Move shared libraries to `lib/`

| Source | Destination | Notes |
|--------|-------------|-------|
| `modules/core.sh` | `lib/core.sh` | Update path references |
| `modules/utils.sh` | `lib/utils.sh` | Update path references |
| `modules/constants.sh` | `lib/constants.sh` | Add `ZZCOLLAB_HOME` |

#### Step 1.3: Create `bin/` directory

```bash
mkdir -p bin/
```

#### Step 1.4: Create standalone tools

| Tool | Source | Purpose |
|------|--------|---------|
| `bin/validate.sh` | `modules/validation.sh` | Package validation |
| `bin/uninstall.sh` | `templates/zzcollab-uninstall.sh` | Project cleanup |
| `bin/nav.sh` | `templates/modules/navigation_scripts.sh` | Shell navigation |

Each tool will:

- Source `$ZZCOLLAB_HOME/lib/core.sh`
- Source `$ZZCOLLAB_HOME/lib/utils.sh`
- Source `$ZZCOLLAB_HOME/lib/constants.sh`
- Be executable standalone
- Handle `ZZCOLLAB_HOME` detection

---

### Phase 2: Update Module Dependencies

**Objective**: Update all modules to use the new `lib/` location.

#### Step 2.1: Update `lib/constants.sh`

Add `ZZCOLLAB_HOME` detection:

```bash
# Detect ZZCOLLAB_HOME if not set
if [[ -z "${ZZCOLLAB_HOME:-}" ]]; then
    # Determine from script location
    ZZCOLLAB_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export ZZCOLLAB_HOME

# Update path constants
readonly ZZCOLLAB_TEMPLATES_DIR="$ZZCOLLAB_HOME/templates"
readonly ZZCOLLAB_MODULES_DIR="$ZZCOLLAB_HOME/modules"
readonly ZZCOLLAB_LIB_DIR="$ZZCOLLAB_HOME/lib"
readonly ZZCOLLAB_BIN_DIR="$ZZCOLLAB_HOME/bin"
```

#### Step 2.2: Update `lib/core.sh`

```bash
# Source constants
source "${ZZCOLLAB_HOME}/lib/constants.sh"

# Rest of core.sh unchanged
```

#### Step 2.3: Update all `modules/*.sh`

Change in each module:

```bash
# Old
source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# New
source "${ZZCOLLAB_HOME}/lib/constants.sh"
source "${ZZCOLLAB_HOME}/lib/core.sh"
```

#### Step 2.4: Update `require_module` function

Update to look in correct locations:

```bash
require_module() {
    for module in "$@"; do
        local module_upper=$(echo "$module" | tr '[:lower:]' '[:upper:]')
        local module_var="ZZCOLLAB_${module_upper}_LOADED"

        if [[ "${!module_var:-}" != "true" ]]; then
            # Try to source it
            if [[ -f "${ZZCOLLAB_HOME}/modules/${module}.sh" ]]; then
                source "${ZZCOLLAB_HOME}/modules/${module}.sh"
            elif [[ -f "${ZZCOLLAB_HOME}/lib/${module}.sh" ]]; then
                source "${ZZCOLLAB_HOME}/lib/${module}.sh"
            else
                echo "❌ Module not found: ${module}" >&2
                exit 1
            fi
        fi
    done
}
```

---

### Phase 3: Add Subcommand Support to CLI

**Objective**: Implement subcommand routing in the main CLI.

#### Step 3.1: Update `zzcollab.sh` entry point

```bash
#!/bin/bash
set -euo pipefail

# Detect ZZCOLLAB_HOME
export ZZCOLLAB_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source core libraries
source "$ZZCOLLAB_HOME/lib/constants.sh"
source "$ZZCOLLAB_HOME/lib/core.sh"
source "$ZZCOLLAB_HOME/lib/utils.sh"

# Source CLI module
source "$ZZCOLLAB_HOME/modules/cli.sh"

# Main entry point
main "$@"
```

#### Step 3.2: Update `modules/cli.sh` for subcommand routing

```bash
main() {
    # Check for subcommand as first argument
    local subcommand="${1:-}"

    case "$subcommand" in
        validate)
            shift
            exec "$ZZCOLLAB_HOME/bin/validate.sh" "$@"
            ;;
        uninstall)
            shift
            exec "$ZZCOLLAB_HOME/bin/uninstall.sh" "$@"
            ;;
        nav|navigation)
            shift
            exec "$ZZCOLLAB_HOME/bin/nav.sh" "$@"
            ;;
        config)
            shift
            handle_config_subcommand "$@"
            ;;
        help|--help|-h)
            shift
            show_help "${1:-}"
            ;;
        -*)
            # Flag-based invocation (existing setup flow)
            parse_arguments "$@"
            run_setup
            ;;
        "")
            # No arguments - show help or run default
            show_help
            ;;
        *)
            # Unknown subcommand - might be a directory or error
            if [[ -d "$subcommand" ]]; then
                # Directory provided - use as project path
                parse_arguments "$@"
                run_setup
            else
                log_error "Unknown subcommand: $subcommand"
                log_error "Run 'zzcollab help' for usage"
                exit 1
            fi
            ;;
    esac
}
```

#### Step 3.3: Update help system

Add subcommand documentation to `modules/help.sh`:

```bash
show_main_help() {
    cat << 'EOF'
zzcollab - Docker-based Research Collaboration Framework

USAGE:
    zzcollab [command] [options]
    zzcollab [setup-options]

COMMANDS:
    validate     Validate package dependencies (DESCRIPTION ↔ renv.lock)
    uninstall    Remove zzcollab files from current project
    nav          Manage shell navigation shortcuts
    config       Manage configuration settings
    help         Show help information

SETUP OPTIONS:
    -t, --team NAME         Team name for Docker Hub
    -p, --project NAME      Project name
    -r, --profile NAME      Docker profile (default: ubuntu_standard_analysis_vim)
    -d, --dotfiles DIR      Copy dotfiles from directory
    -u, --use-team-image    Pull existing team Docker image
    -h, --help              Show this help

EXAMPLES:
    # Create new project
    zzcollab -t myteam -p myproject -r analysis

    # Validate packages
    zzcollab validate --fix --strict

    # Remove zzcollab from project
    zzcollab uninstall --dry-run

    # Install navigation shortcuts
    zzcollab nav install

Run 'zzcollab help <command>' for command-specific help.
EOF
}

show_validate_help() {
    cat << 'EOF'
zzcollab validate - Package dependency validation

USAGE:
    zzcollab validate [options]

OPTIONS:
    --fix           Auto-fix missing packages (add to DESCRIPTION/renv.lock)
    --no-fix        Validation only, no modifications
    --strict        Include tests/ and vignettes/ in scan
    --no-strict     Exclude tests/ and vignettes/
    --verbose       Show detailed output
    --system-deps   Check system dependencies in Dockerfile

EXAMPLES:
    zzcollab validate --fix --strict
    zzcollab validate --no-fix --verbose
    zzcollab validate --system-deps
EOF
}
```

---

### Phase 4: Clean Up Templates

**Objective**: Remove duplicated code from templates.

#### Step 4.1: Remove `templates/modules/`

```bash
rm -rf templates/modules/
```

Files removed:

- `templates/modules/core.sh`
- `templates/modules/utils.sh`
- `templates/modules/constants.sh`
- `templates/modules/navigation_scripts.sh`
- `templates/modules/setup_symlinks.sh`
- `templates/modules/validation.sh`

#### Step 4.2: Remove `templates/zzcollab-uninstall.sh`

```bash
rm templates/zzcollab-uninstall.sh
```

#### Step 4.3: Update `templates/Makefile`

Change validation targets:

```makefile
# Old
check-renv:
	@bash modules/validation.sh --fix --strict --verbose

check-renv-no-fix:
	@bash modules/validation.sh --no-fix --strict --verbose

check-renv-no-strict:
	@bash modules/validation.sh --fix --verbose

# New
check-renv:
	@zzcollab validate --fix --strict --verbose

check-renv-no-fix:
	@zzcollab validate --no-fix --strict --verbose

check-renv-no-strict:
	@zzcollab validate --fix --verbose

check-system-deps:
	@zzcollab validate --system-deps
```

#### Step 4.4: Update project creation code

In `modules/structure.sh` (or wherever project files are copied):

```bash
# Remove these lines:
copy_template_directory "modules" "$project_dir/modules"
copy_template_file "zzcollab-uninstall.sh" "$project_dir/.zzcollab/uninstall.sh"

# Keep:
create_manifest "$project_dir/.zzcollab/manifest.json"
```

---

### Phase 5: Update Installer

**Objective**: Install to new location with proper structure.

#### Step 5.1: Update `install.sh`

```bash
#!/bin/bash
set -euo pipefail

ZZCOLLAB_HOME="$HOME/.zzcollab"
BIN_DIR="$HOME/bin"
OLD_LOCATION="$BIN_DIR/zzcollab-support"

install_zzcollab() {
    echo "Installing zzcollab to $ZZCOLLAB_HOME..."

    # Create directory structure
    mkdir -p "$ZZCOLLAB_HOME"/{modules,lib,bin,templates}
    mkdir -p "$BIN_DIR"

    # Copy files
    cp zzcollab.sh "$ZZCOLLAB_HOME/"
    cp -r modules/* "$ZZCOLLAB_HOME/modules/"
    cp -r lib/* "$ZZCOLLAB_HOME/lib/"
    cp -r bin/* "$ZZCOLLAB_HOME/bin/"
    cp -r templates/* "$ZZCOLLAB_HOME/templates/"

    # Make executable
    chmod +x "$ZZCOLLAB_HOME/zzcollab.sh"
    chmod +x "$ZZCOLLAB_HOME/bin/"*.sh

    # Create symlink
    ln -sf "$ZZCOLLAB_HOME/zzcollab.sh" "$BIN_DIR/zzcollab"

    echo "✅ Installed zzcollab to $ZZCOLLAB_HOME"
    echo "✅ Symlink created at $BIN_DIR/zzcollab"
}

migrate_from_old() {
    if [[ -d "$OLD_LOCATION" ]]; then
        echo "⚠️  Found old installation at $OLD_LOCATION"
        read -p "Remove old installation? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$OLD_LOCATION"
            # Remove old standalone script if it exists
            [[ -f "$BIN_DIR/zzcollab" && ! -L "$BIN_DIR/zzcollab" ]] && rm "$BIN_DIR/zzcollab"
            echo "✅ Removed old installation"
        fi
    fi
}

uninstall_zzcollab() {
    echo "Uninstalling zzcollab..."
    rm -rf "$ZZCOLLAB_HOME"
    rm -f "$BIN_DIR/zzcollab"
    echo "✅ Uninstalled zzcollab"
}

# Main
case "${1:-install}" in
    install)
        migrate_from_old
        install_zzcollab
        ;;
    uninstall|--uninstall)
        uninstall_zzcollab
        ;;
    *)
        echo "Usage: ./install.sh [install|uninstall]"
        exit 1
        ;;
esac
```

---

### Phase 6: Migration Support

**Objective**: Support existing projects and installations.

#### Step 6.1: Detect and handle old project structure

Add to `bin/validate.sh`:

```bash
# Check for old project structure
if [[ -d "modules" && -f "modules/validation.sh" ]]; then
    log_warn "Detected old project structure with local modules/"
    log_warn "Consider running 'zzcollab migrate' to clean up"
fi
```

#### Step 6.2: Add `migrate` subcommand (optional)

```bash
# zzcollab migrate - Clean up old project structure
migrate_project() {
    if [[ -d "modules" ]]; then
        if confirm "Remove local modules/ directory?"; then
            rm -rf modules/
            log_success "Removed modules/"
        fi
    fi

    if [[ -f ".zzcollab/uninstall.sh" ]]; then
        if confirm "Remove .zzcollab/uninstall.sh?"; then
            rm .zzcollab/uninstall.sh
            log_success "Removed .zzcollab/uninstall.sh"
        fi
    fi

    log_success "Project migrated to new structure"
}
```

---

## File Change Summary

### Files to CREATE

| File | Description |
|------|-------------|
| `lib/core.sh` | Moved from modules/, updated paths |
| `lib/utils.sh` | Moved from modules/, updated paths |
| `lib/constants.sh` | Moved from modules/, added ZZCOLLAB_HOME |
| `bin/validate.sh` | Standalone validation tool |
| `bin/uninstall.sh` | Standalone uninstall tool |
| `bin/nav.sh` | Standalone navigation setup |

### Files to MODIFY

| File | Changes |
|------|---------|
| `zzcollab.sh` | Add ZZCOLLAB_HOME, subcommand routing |
| `modules/cli.sh` | Add subcommand parsing |
| `modules/help.sh` | Add subcommand help |
| `modules/*.sh` (all) | Update source paths to lib/ |
| `templates/Makefile` | Change to `zzcollab validate` |
| `install.sh` | New location, structure, migration |

### Files to DELETE

| File | Reason |
|------|--------|
| `templates/modules/` (directory) | No longer copied to projects |
| `templates/zzcollab-uninstall.sh` | Replaced by `bin/uninstall.sh` |

### Files UNCHANGED

| File | Reason |
|------|--------|
| `templates/Dockerfile.*` | Project templates |
| `templates/.Rprofile` | Project template |
| `templates/DESCRIPTION.*` | Project templates |
| `templates/bundles.yaml` | Profile definitions |
| `templates/workflows/*` | GitHub Actions templates |

---

## Testing Plan

### Unit Tests

| Test | Description |
|------|-------------|
| `lib/*.sh` sourcing | Each lib file sources without errors |
| `bin/*.sh` execution | Each tool runs with `--help` |
| Subcommand routing | Each subcommand routes correctly |
| Path detection | `ZZCOLLAB_HOME` detected correctly |

### Integration Tests

| Test | Description |
|------|-------------|
| Fresh install | `./install.sh` creates correct structure |
| Project creation | `zzcollab -t test -p test` creates project without `modules/` |
| Validation | `zzcollab validate` works in project |
| Uninstall | `zzcollab uninstall` removes files |
| Config operations | `zzcollab config` works correctly |
| Migration | Old installation detected and migrated |

### Backward Compatibility Tests

| Test | Description |
|------|-------------|
| Old project with `modules/` | Makefile with local paths still works |
| Old installation | Detected and migration offered |

---

## Rollback Plan

### Before Starting

1. Tag current commit: `git tag pre-refactor-v1`
2. Backup `install.sh`: `cp install.sh install.sh.backup`

### If Issues Arise

1. Checkout pre-refactor tag: `git checkout pre-refactor-v1`
2. Run old installer: `./install.sh.backup`
3. Document issues for investigation

---

## Open Questions

### 1. Migration Strategy

**Question**: Should `zzcollab migrate` be a subcommand to clean old projects?

**Options**:

- A) Add `migrate` subcommand (explicit cleanup)
- B) Auto-detect and warn only (manual cleanup)
- C) Auto-cleanup with confirmation

**Recommendation**: Option A - explicit is safer

### 2. Backward Compatibility Duration

**Question**: How long to support old `modules/` in projects?

**Options**:

- A) Immediate break (document migration)
- B) Warn for 1-2 releases, then break
- C) Permanent backward compatibility

**Recommendation**: Option B - warn, then remove

### 3. Navigation Scripts

**Question**: How should navigation scripts be handled?

**Current**: User sources `modules/navigation_scripts.sh` into shell

**Options**:

- A) `zzcollab nav install` adds source line to `.zshrc`/`.bashrc`
- B) `zzcollab nav install` copies functions to shell config
- C) Keep current pattern (source from `~/.zzcollab/bin/nav.sh`)

**Recommendation**: Option A - cleanest integration

### 4. Config Backward Compatibility

**Question**: Keep `--config` flag or only subcommand?

**Options**:

- A) Only `zzcollab config` (breaking change)
- B) Support both `--config` and `config` (indefinitely)
- C) Support both, deprecate `--config` with warning

**Recommendation**: Option C - graceful deprecation

---

## Timeline Estimate

| Phase | Estimated Effort |
|-------|------------------|
| Phase 1: Directory structure | 1-2 hours |
| Phase 2: Module dependencies | 2-3 hours |
| Phase 3: CLI subcommands | 3-4 hours |
| Phase 4: Template cleanup | 1 hour |
| Phase 5: Installer update | 1-2 hours |
| Phase 6: Migration support | 1-2 hours |
| Testing | 2-3 hours |
| **Total** | **11-17 hours** |

---

## Success Criteria

1. ✅ `~/.zzcollab/` contains framework (no `~/bin/zzcollab-support/`)
2. ✅ `~/bin/zzcollab` is symlink to `~/.zzcollab/zzcollab.sh`
3. ✅ New projects have NO `modules/` directory
4. ✅ New projects have NO `.zzcollab/uninstall.sh`
5. ✅ `zzcollab validate` works in projects
6. ✅ `zzcollab uninstall` works in projects
7. ✅ `zzcollab config` works (subcommand style)
8. ✅ Old installations detected and migration offered
9. ✅ All existing tests pass
10. ✅ Documentation updated
