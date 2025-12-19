# ZZCOLLAB Architecture Refactoring Plan

## Executive Summary

This document provides a comprehensive refactoring plan based on a complete
audit of the zzcollab codebase. The refactoring addresses:

1. **Directory structure**: Relocate from `~/bin/zzcollab-support/` to `~/.zzcollab/`
2. **CLI architecture**: Modernize with subcommands, remove vestigial flags
3. **Code consolidation**: Eliminate ~100KB duplication per project
4. **Help system**: Unify orphaned modular architecture
5. **Documentation**: Synchronize docs with actual implementation

---

## Part 1: Current State Analysis

### 1.1 Codebase Size by Module

| Module | Lines | Purpose | Status |
|--------|-------|---------|--------|
| help.sh | 1,651 | Help system | Keep |
| docker.sh | 321 | Docker + Dockerfile gen | ✅ SIMPLIFIED (was 1,955 combined) |
| validation.sh | 486 | Package validation | ✅ TRIMMED (was 2,093) |
| config.sh | 284 | Configuration | ✅ TRIMMED (was 1,015) |
| github.sh | 221 | GitHub + CI/CD | ✅ MERGED (was 471 combined) |
| profiles.sh | 189 | System deps mapping | ✅ SIMPLIFIED (was 1,447 combined) |
| cli.sh | 680 | CLI parsing | Keep |
| analysis.sh | 997 | Analysis structure | → project.sh (pending) |
| rpackage.sh | 387 | R package structure | → project.sh (pending) |
| devtools.sh | 322 | Dev tools | → project.sh (pending) |
| structure.sh | 179 | Directory structure | → project.sh (pending) |
| lib/core.sh | 471 | Logging/tracking | ✅ CREATED |
| lib/templates.sh | 181 | Template handling | ✅ CREATED |
| lib/constants.sh | 119 | Global constants | ✅ CREATED |
| ~~dockerfile_generator.sh~~ | ~~840~~ | ~~Dockerfile creation~~ | **DELETED** ✅ |
| ~~profile_validation.sh~~ | ~~1,198~~ | ~~Profile validation~~ | **DELETED** ✅ |
| ~~system_deps_map.sh~~ | ~~248~~ | ~~System deps~~ | **DELETED** ✅ |
| ~~cicd.sh~~ | ~~300~~ | ~~CI/CD~~ | **DELETED** ✅ |
| ~~help_core.sh~~ | ~~231~~ | ~~Help dispatcher~~ | **DELETED** ✅ |
| ~~help_guides.sh~~ | ~~156~~ | ~~Markdown guides~~ | **DELETED** ✅ |
| **Refactored Total** | **~6,488** | Reduced from ~12,200 | **47% reduction** |

### 1.2 Current Installation Structure

```
~/bin/zzcollab                           # 39KB standalone script
~/bin/zzcollab-support/
    ├── modules/                         # 21 modules (~320KB)
    └── templates/
        ├── modules/                     # DUPLICATE (6 files, ~100KB)
        │   ├── core.sh, utils.sh, constants.sh
        │   ├── navigation_scripts.sh, setup_symlinks.sh
        │   └── validation.sh
        ├── zzcollab-uninstall.sh        # Copied to each project
        └── ...
```

### 1.3 Current Project Structure (After Setup)

```
project/
    ├── modules/                         # ~100KB framework duplication
    ├── .zzcollab/
    │   ├── manifest.json
    │   └── uninstall.sh                 # ~26KB duplicate
    └── ...
```

---

## Part 2: CLI Architecture Analysis

### 2.1 Current Flags Inventory

#### Active Setup Flags

| Short | Long | Variable | Purpose | Recommendation |
|-------|------|----------|---------|----------------|
| `-t` | `--team` | `TEAM_NAME` | Docker Hub namespace | Keep as flag |
| `-p` | `--project-name` | `PROJECT_NAME` | Project/package name | Keep as flag |
| `-g` | `--github-account` | `GITHUB_ACCOUNT` | GitHub account | Keep as flag |
| `-r` | `--profile-name` | `PROFILE_NAME` | Docker profile | Keep as flag |
| `-b` | `--base-image` | `BASE_IMAGE` | Custom base image | Keep as flag |
| `-l` | `--libs` | `LIBS_BUNDLE` | System library bundle | Keep as flag |
| `-k` | `--pkgs` | `PKGS_BUNDLE` | R package bundle | Keep as flag |
| `-a` | `--tag` | `IMAGE_TAG` | Docker image tag | Keep as flag |
| `-u` | `--use-team-image` | `USE_TEAM_IMAGE` | Pull team image | Keep as flag |
| `-x` | `--with-examples` | `WITH_EXAMPLES` | Include examples | Keep as flag |
| | `--r-version` | `R_VERSION` | R version | Keep as flag |
| | `--build-docker` | `BUILD_DOCKER` | Build during setup | Keep as flag |
| `-n` | `--no-docker` | `BUILD_DOCKER=false` | Skip Docker build | Keep as flag |
| `-P` | `--prepare-dockerfile` | `PREPARE_DOCKERFILE` | Prepare only | Keep as flag |
| `-f` | `--dockerfile` | `DOCKERFILE_PATH` | Custom Dockerfile | Keep as flag |
| `-G` | `--github` | `CREATE_GITHUB_REPO` | Create GitHub repo | Keep as flag |
| | `--force` | `FORCE_DIRECTORY` | Skip validation | Keep as flag |
| | `--add-examples` | `ADD_EXAMPLES` | Add to existing | Keep as flag |

#### Behavioral Flags

| Short | Long | Variable | Purpose | Recommendation |
|-------|------|----------|---------|----------------|
| `-y` | `--yes` | `SKIP_CONFIRMATION` | Skip prompts | Keep as flag |
| `-q` | `--quiet` | `VERBOSITY_LEVEL=0` | Quiet mode | Keep as flag |
| `-v` | `--verbose` | `VERBOSITY_LEVEL=2` | Verbose mode | Keep as flag |
| `-vv` | `--debug` | `VERBOSITY_LEVEL=3` | Debug mode | Keep as flag |
| `-w` | `--log-file` | `ENABLE_LOG_FILE` | Enable logging | Keep as flag |

#### Help/Info Flags (to be removed, replaced by subcommands)

| Short | Long | Variable | Purpose | Recommendation |
|-------|------|----------|---------|----------------|
| `-h` | `--help` | `SHOW_HELP` | Show help | **REMOVE** → `zzcollab help` |
| | `--help TOPIC` | `SHOW_HELP_TOPIC` | Topic help | **REMOVE** → `zzcollab help <topic>` |
| | `--next-steps` | `SHOW_NEXT_STEPS` | Workflow guide | **REMOVE** → `zzcollab help workflow` |
| | `--list-profiles` | `LIST_PROFILES` | List profiles | **REMOVE** → `zzcollab list profiles` |
| | `--list-libs` | `LIST_LIBS` | List lib bundles | **REMOVE** → `zzcollab list libs` |
| | `--list-pkgs` | `LIST_PKGS` | List pkg bundles | **REMOVE** → `zzcollab list pkgs` |

#### Config Flags (to be removed, replaced by subcommand)

| Short | Long | Variable | Purpose | Recommendation |
|-------|------|----------|---------|----------------|
| `-c` | `--config` | `CONFIG_COMMAND` | Config subcommand | **REMOVE** → `zzcollab config` |

#### Vestigial Variables ✅ REMOVED

| Variable | Location | Issue | Status |
|----------|----------|-------|--------|
| ~~`DOCKERHUB_ACCOUNT`~~ | cli.sh:237 | Initialized empty, exported but never set | **REMOVED** |
| ~~`MULTIARCH_VERSE_IMAGE`~~ | cli.sh:229 | Exported but unused | **REMOVED** |
| ~~`FORCE_PLATFORM`~~ | cli.sh:230 | Exported but unused | **REMOVED** |
| ~~`INIT_BASE_IMAGE`~~ | cli.sh:244 | Commented options, never used | **REMOVED** |

#### Placeholder Functions ✅ REMOVED

| Function | Location | Issue | Status |
|----------|----------|-------|--------|
| ~~`validate_cli_arguments()`~~ | cli.sh:480-483 | No-op (just `:`) | **REMOVED** |

### 2.2 Subcommand vs Flag Design Rationale

#### Design Principles

**Subcommands** are appropriate when:

- The action is a distinct operation (not project setup)
- It has its own set of flags/options
- It can stand alone without other arguments
- It represents a different "mode" of operation

**Flags** are appropriate when:

- The option modifies the behavior of the primary action
- It's a boolean toggle or takes a simple value
- It works in combination with other flags
- It's part of the setup workflow

#### Recommended CLI Structure

```bash
# Project Setup (default action, no subcommand)
zzcollab [flags]                         # Create new project
zzcollab -t team -p project -r profile   # Full setup

# Subcommands (distinct operations)
zzcollab validate [flags]                # Package validation
zzcollab uninstall [flags]               # Remove zzcollab from project
zzcollab nav <action>                    # Navigation shortcuts
zzcollab config <action>                 # Configuration management
zzcollab list <type>                     # List profiles/libs/pkgs
zzcollab help [topic]                    # Help system
zzcollab migrate [flags]                 # Migrate old project structure
```

### 2.3 Proposed Subcommand Specifications

#### `zzcollab validate`

**Purpose**: Package dependency validation (DESCRIPTION ↔ renv.lock)

**Rationale for subcommand**: Distinct operation, not part of setup, has own flags

```bash
zzcollab validate [options]

Options:
  --fix              Auto-fix missing packages
  --no-fix           Validation only (default)
  --strict           Include tests/ and vignettes/
  --no-strict        Exclude tests/ and vignettes/ (default)
  --verbose          Show detailed output
  --system-deps      Check system dependencies in Dockerfile
  --help             Show validate help
```

#### `zzcollab uninstall`

**Purpose**: Remove zzcollab files from current project

**Rationale for subcommand**: Destructive operation, needs own flags, distinct from setup

```bash
zzcollab uninstall [options]

Options:
  --dry-run          Preview what would be removed
  --force            Skip confirmation prompts
  --keep-docker      Don't remove Docker images
  --help             Show uninstall help
```

#### `zzcollab nav`

**Purpose**: Manage shell navigation shortcuts

**Rationale for subcommand**: Distinct operation affecting shell config

```bash
zzcollab nav <action>

Actions:
  install            Add navigation shortcuts to shell config
  uninstall          Remove navigation shortcuts
  show               Display current shortcuts

Options:
  --shell <type>     Target shell (zsh, bash, auto)
  --help             Show nav help
```

#### `zzcollab config`

**Purpose**: Configuration management

**Rationale for subcommand**: Already hybrid (`--config`), should be pure subcommand

```bash
zzcollab config <action> [args]

Actions:
  init               Create default configuration file
  set <key> <value>  Set configuration value
  get <key>          Get configuration value
  list               List all configuration
  validate           Validate configuration files
  path               Show configuration file paths

Options:
  --global           User config (~/.zzcollab/config.yaml)
  --project          Project config (./zzcollab.yaml)
  --help             Show config help
```

#### `zzcollab list`

**Purpose**: List available profiles, libraries, packages

**Rationale for subcommand**: Info retrieval, not setup modification

```bash
zzcollab list <type>

Types:
  profiles           List Docker profiles
  libs               List system library bundles
  pkgs               List R package bundles
  all                List everything

Options:
  --json             Output as JSON
  --help             Show list help
```

#### `zzcollab help`

**Purpose**: Unified help system

**Rationale for subcommand**: Standard CLI pattern, integrates with topic system

```bash
zzcollab help [topic]

Topics:
  # Commands
  validate           Package validation help
  uninstall          Uninstall help
  nav                Navigation help
  config             Configuration help
  list               List command help
  migrate            Migration help

  # Guides
  quickstart         Quick start for solo developers
  workflow           Daily development workflow
  team               Team collaboration setup
  profiles           Docker profile selection
  docker             Docker architecture
  renv               Package management
  cicd               CI/CD automation
  troubleshoot       Common issues

Options:
  --all              List all topics
```

#### `zzcollab migrate`

**Purpose**: Migrate old project structure to new format

**Rationale for subcommand**: One-time operation, distinct from setup

```bash
zzcollab migrate [options]

Options:
  --dry-run          Preview changes
  --force            Skip confirmation
  --help             Show migrate help
```

---

## Part 3: Directory Structure Refactoring

### 3.1 Target Installation Structure (After Consolidation)

```
~/.zzcollab/                             # Hidden framework home
    ├── bin/                             # Executables (4 files)
    │   ├── zzcollab.sh                  # Main CLI entry point
    │   ├── validate.sh                  # Package validation (from modules/)
    │   ├── uninstall.sh                 # Project uninstall (new)
    │   └── nav.sh                       # Navigation setup (extracted)
    ├── lib/                             # Shared libraries (3 files)
    │   ├── constants.sh                 # Global constants
    │   ├── core.sh                      # Logging, tracking, utilities (absorbs utils.sh)
    │   └── templates.sh                 # Template handling
    ├── modules/                         # CLI modules (7 files)
    │   ├── cli.sh                       # CLI parsing, subcommand routing
    │   ├── config.sh                    # Configuration management
    │   ├── docker.sh                    # Docker ops (absorbs dockerfile_generator.sh)
    │   ├── github.sh                    # GitHub/CI (absorbs cicd.sh)
    │   ├── help.sh                      # Help system
    │   ├── profiles.sh                  # Profiles (absorbs profile_validation + system_deps_map)
    │   └── project.sh                   # Project structure (absorbs structure + analysis + rpackage + devtools)
    └── templates/                       # Project scaffolding
        ├── Makefile                     # Updated for subcommands
        ├── Dockerfile.*                 # Docker templates
        ├── DESCRIPTION.*                # R package templates
        ├── bundles.yaml                 # Profile definitions
        ├── workflows/                   # GitHub Actions
        └── ...                          # Other templates
        # NO modules/ directory
        # NO zzcollab-uninstall.sh

~/bin/zzcollab                           # Symlink → ~/.zzcollab/bin/zzcollab.sh

# Total: 4 + 3 + 7 = 14 shell files (down from 18)
```

### 3.2 Target Project Structure

```
project/
    ├── .zzcollab/
    │   └── manifest.json                # Metadata only
    ├── Makefile                         # Calls `zzcollab validate`
    ├── Dockerfile
    ├── .Rprofile
    ├── DESCRIPTION
    ├── renv.lock
    ├── R/
    ├── analysis/
    ├── tests/
    └── ...
    # NO modules/ directory (~100KB saved)
    # NO .zzcollab/uninstall.sh (~26KB saved)
```

### 3.3 Comparison

| Aspect | Current | Target | Savings |
|--------|---------|--------|---------|
| Framework location | `~/bin/zzcollab-support/` | `~/.zzcollab/` | Cleaner |
| Project modules/ | 100KB per project | 0KB | 100KB/project |
| Project uninstall.sh | 26KB per project | 0KB | 26KB/project |
| Update propagation | Manual | Automatic | Maintenance |
| CLI pattern | Mixed | Pure subcommands | Consistency |

---

## Part 4: Vestigial Code Removal ✅ COMPLETED

### 4.1 Variables Removed ✅

```bash
# cli.sh - These have been removed:

# ~~Line 229-231: Unused multi-arch constants~~
# MULTIARCH_VERSE_IMAGE - REMOVED
# FORCE_PLATFORM - REMOVED

# ~~Line 237: Never populated via CLI~~
# DOCKERHUB_ACCOUNT - REMOVED

# ~~Line 244: Commented, never used~~
# INIT_BASE_IMAGE - REMOVED

# ~~Line 462: Removed from export statement~~
# DOCKERHUB_ACCOUNT removed from export
```

### 4.2 Functions Removed ✅

```bash
# cli.sh - validate_cli_arguments() no-op function REMOVED
# Call to validate_cli_arguments in process_cli() REMOVED
```

### 4.3 Modules Removed/Pending

| Module | Lines | Issue | Status |
|--------|-------|-------|--------|
| ~~help_core.sh~~ | 231 | Orphaned dispatcher | **REMOVED** ✅ |
| ~~help_guides.sh~~ | 156 | Broken references | **REMOVED** ✅ |
| templates/modules/ | ~100KB | Duplicated in projects | **PENDING** |
| templates/zzcollab-uninstall.sh | 740 | Duplicated in projects | **PENDING** |

### 4.4 Dead Code Paths Removed ✅

```bash
# help_core.sh entirely removed - no longer have broken require_module calls
```

---

## Part 5: Help System Consolidation

### 5.1 Current State (After Cleanup)

```
modules/help.sh        (1,651 lines) - All topics, consolidated ✅
~~modules/help_core.sh~~   REMOVED ✅
~~modules/help_guides.sh~~ REMOVED ✅
```

**Problem solved**: Orphaned modular architecture removed.

### 5.2 Target State ✅ PARTIALLY COMPLETE

```
modules/help.sh        (consolidated) - All help in one place ✅
```

**Decision**: Consolidate rather than complete modularization.

**Rationale**:

1. Help content is static text, not complex logic
2. Single file is easier to maintain
3. Module loading overhead not justified for help
4. Current monolithic help.sh works correctly

### 5.3 Help System Integration with Subcommands

```bash
# All of these should work identically:
zzcollab help validate          # Topic-style
zzcollab validate --help        # Subcommand flag (delegates to help)
zzcollab help --all             # Lists commands AND guides

# help.sh show_help() routing:
show_help() {
    local topic="${1:-}"
    case "$topic" in
        # Subcommand help (NEW)
        validate)    show_validate_help ;;
        uninstall)   show_uninstall_help ;;
        nav)         show_nav_help ;;
        config)      show_config_help ;;
        list)        show_list_help ;;
        migrate)     show_migrate_help ;;

        # Guide topics (existing)
        quickstart)  show_quickstart_help ;;
        workflow)    show_workflow_help ;;
        team)        show_team_help ;;
        profiles)    show_profiles_help ;;
        docker)      show_docker_help ;;
        renv)        show_renv_help ;;
        cicd)        show_cicd_help ;;
        troubleshoot) show_troubleshoot_help ;;

        # Meta
        ""|--brief)  show_help_brief ;;
        --all|-a)    show_help_topics_list ;;
        *)           show_unknown_topic "$topic" ;;
    esac
}
```

### 5.4 Help Categories Display

```
zzcollab help

USAGE:
    zzcollab [command] [options]
    zzcollab [setup-flags]

COMMANDS:
    validate      Validate package dependencies
    uninstall     Remove zzcollab from project
    nav           Shell navigation shortcuts
    config        Configuration management
    list          List profiles/libs/pkgs
    help          Show help information
    migrate       Migrate old project structure

GUIDES:
    quickstart    Quick start for solo developers
    workflow      Daily development workflow
    team          Team collaboration setup
    profiles      Docker profile selection
    docker        Docker architecture
    renv          Package management
    cicd          CI/CD automation
    troubleshoot  Common issues

Run 'zzcollab help <topic>' for details.
Run 'zzcollab help --all' for complete list.
```

---

## Part 6: Documentation Updates

### 6.1 Documentation Audit Findings

| Document | Status | Issues |
|----------|--------|--------|
| docs/README.md | **OUTDATED** | References non-existent docs/guides/*.md |
| ZZCOLLAB_USER_GUIDE.md | **CURRENT** | Accurate but needs subcommand updates |
| help_guides.sh | **BROKEN** | References docs/guides/ that doesn't exist |
| docs/TESTING_GUIDE.md | CURRENT | Accurate |
| docs/DATA_WORKFLOW_GUIDE.md | CURRENT | Accurate |

### 6.2 Required Documentation Updates

#### docs/README.md

**Remove**: References to markdown guide files in docs/guides/

**Update**: Document actual help system architecture

```markdown
## Help System

Help is provided through the `zzcollab help` command:

    zzcollab help              # Overview
    zzcollab help <topic>      # Specific topic
    zzcollab help --all        # All topics

All help content is in modules/help.sh (consolidated).
```

#### ZZCOLLAB_USER_GUIDE.md

**Add**: Subcommand documentation

```markdown
## Commands

### zzcollab validate
Validates package dependencies...

### zzcollab uninstall
Removes zzcollab files...

### zzcollab config
Manages configuration...
```

#### templates/Makefile

**Update**: Use subcommands instead of local modules

```makefile
# OLD
check-renv:
    @bash modules/validation.sh --fix --strict --verbose

# NEW
check-renv:
    @zzcollab validate --fix --strict --verbose
```

### 6.3 Files to Remove

```bash
rm modules/help_core.sh      # Orphaned dispatcher
rm modules/help_guides.sh    # References non-existent files
rm -rf templates/modules/    # No longer copied to projects
rm templates/zzcollab-uninstall.sh  # Replaced by subcommand
```

---

## Part 7: Implementation Phases

### Phase 1: Vestigial Code Cleanup ✅ COMPLETED

**Removed from cli.sh:**
- ~~`MULTIARCH_VERSE_IMAGE`~~ (line 229)
- ~~`FORCE_PLATFORM`~~ (line 230)
- ~~`DOCKERHUB_ACCOUNT`~~ (line 237)
- ~~`INIT_BASE_IMAGE`~~ (lines 243-244)
- ~~`validate_cli_arguments()` no-op function~~ (lines 478-483)
- ~~Call to `validate_cli_arguments` in `process_cli()`~~

**Deleted orphaned modules:**
- ~~`modules/help_core.sh`~~ (231 lines)
- ~~`modules/help_guides.sh`~~ (156 lines)

**Remaining:** Update docs/README.md to remove guide references

### Phase 2: Directory Restructure ✅ IN PROGRESS

**Module Trimming (Bash 3.2 compatible):**
- ~~config.sh: 1,015 → 284 lines~~ ✅ (72% reduction)
- ~~validation.sh: 2,093 → 486 lines~~ ✅ (77% reduction)
- Total savings: ~2,338 lines

**Library consolidation:**
1. ~~Create lib/ directory~~ ✅
2. ~~Create bin/ directory~~ ✅
3. ~~Consolidate core.sh + utils.sh → lib/core.sh~~ ✅ (471 lines)
4. ~~Move constants.sh → lib/constants.sh~~ ✅ (119 lines, with dynamic ZZCOLLAB_HOME)
5. ~~Move templates.sh → lib/templates.sh~~ ✅ (181 lines)
6. Create bin/zzcollab.sh (main entry point) - PENDING
7. Create bin/validate.sh (from modules/validation.sh) - PENDING
8. Create bin/uninstall.sh (new standalone) - PENDING
9. Create bin/nav.sh (extracted from navigation_scripts.sh) - PENDING
10. Update ZZCOLLAB_HOME detection to work from bin/ location - PENDING

**Library consolidation summary:**
```
lib/constants.sh  (119 lines) - dynamic path resolution
lib/core.sh       (471 lines) - merged core.sh + utils.sh
lib/templates.sh  (181 lines) - template processing
Total: 771 lines in 3 files
```

### Phase 3: Module Consolidation ✅ COMPLETE

**Major architectural simplification: Dynamic Dockerfile generation**

The static Dockerfile template system was replaced with dynamic generation:
- **Before:** 14 static Dockerfile templates + complex selection logic
- **After:** 1 universal template + dynamic system deps derivation from R packages

**Docker system refactoring (87% reduction):**
```
BEFORE:                              AFTER:
dockerfile_generator.sh (840)   →    docker.sh (321 lines)
docker.sh (1115)                     Dockerfile.template (52 lines)
14 static Dockerfile templates
profile_validation.sh (1198)    →    profiles.sh (189 lines)
system_deps_map.sh (249)
─────────────────────────────────    ─────────────────────
~3400 lines + templates              ~562 lines
```

**How dynamic generation now works:**
1. Extract R packages from DESCRIPTION/renv.lock
2. Look up system deps for each package via mapping (profiles.sh)
3. Substitute into universal Dockerfile.template
4. Done - no bundle configuration, no profile validation complexity

**Other consolidations:**
- cicd.sh (300) + github.sh (171) → github.sh (221 lines) - 53% reduction

**Files deleted:**
- modules/dockerfile_generator.sh (absorbed into docker.sh)
- modules/cicd.sh (absorbed into github.sh)
- modules/profile_validation.sh (absorbed into profiles.sh)
- modules/system_deps_map.sh (absorbed into profiles.sh)
- 14 static Dockerfile.* templates (replaced by dynamic generation)

### Phase 4: Subcommand Implementation

1. Refactor cli.sh for subcommand routing
2. Implement each subcommand handler
3. Update help.sh with subcommand help
4. Integrate `--help` delegation

### Phase 5: Template Cleanup

1. Remove templates/modules/
2. Remove templates/zzcollab-uninstall.sh
3. Update templates/Makefile for subcommands
4. Update project creation to not copy modules/

### Phase 6: Installer Update

1. Change install target to ~/.zzcollab/
2. Create symlink ~/bin/zzcollab → ~/.zzcollab/bin/zzcollab.sh
3. Add migration from old location
4. Update install.sh

### Phase 7: Documentation

1. Update ZZCOLLAB_USER_GUIDE.md
2. Update docs/README.md
3. Add subcommand examples
4. Update help.sh content

### Phase 8: Testing

1. Test all subcommands
2. Test help system
3. Test fresh install
4. Test migration from old structure
5. Test project creation

---

## Part 8: Testing Plan

### Unit Tests

| Test | Description |
|------|-------------|
| lib/*.sh sourcing | Each lib file sources without errors |
| bin/*.sh --help | Each tool shows help |
| Subcommand routing | Each subcommand routes correctly |
| ZZCOLLAB_HOME detection | Path detection works |

### Integration Tests

| Test | Description |
|------|-------------|
| Fresh install | ~/.zzcollab/ created correctly |
| Project creation | No modules/ in new projects |
| zzcollab validate | Works in project |
| zzcollab uninstall | Removes files correctly |
| zzcollab config | All subcommands work |

### Help System Tests

| Test | Description |
|------|-------------|
| zzcollab help | Shows categories |
| zzcollab help validate | Shows validate help |
| zzcollab validate --help | Delegates to help |
| zzcollab help --all | Lists all topics |

---

## Part 9: Success Criteria

1. ✅ `~/.zzcollab/` contains framework
2. ✅ `~/bin/zzcollab` is symlink
3. ✅ No `~/bin/zzcollab-support/`
4. ✅ New projects have no `modules/`
5. ✅ New projects have no `.zzcollab/uninstall.sh`
6. ✅ All subcommands work
7. ✅ Help system unified
8. ✅ Documentation current
9. ✅ All tests pass
10. ✅ Vestigial code removed

---

## Appendix A: Complete Flag Reference (Target State)

### Setup Flags (used with default action)

```
-t, --team NAME           Team name for Docker Hub namespace
-p, --project-name NAME   Project name (defaults to directory name)
-g, --github-account NAME GitHub account for repository
-r, --profile-name NAME   Docker profile (default: ubuntu_standard_analysis_vim)
-b, --base-image IMAGE    Custom Docker base image
-l, --libs BUNDLE         System library bundle
-k, --pkgs BUNDLE         R package bundle
-a, --tag TAG             Docker image tag variant
-u, --use-team-image      Pull existing team image
-x, --with-examples       Include example files
    --r-version VERSION   R version for Docker
    --build-docker        Build Docker during setup
-n, --no-docker           Skip Docker build (default)
-P, --prepare-dockerfile  Prepare Dockerfile only
-f, --dockerfile PATH     Custom Dockerfile path
-G, --github              Auto-create GitHub repository
    --force               Skip directory validation
    --add-examples        Add examples to existing project
```

### Behavioral Flags (global)

```
-y, --yes                 Skip confirmation prompts
-q, --quiet               Quiet output
-v, --verbose             Verbose output
-vv, --debug              Debug mode with logging
-w, --log-file            Enable log file
```

### Subcommands

```
validate                  Package dependency validation
uninstall                 Remove zzcollab from project
nav                       Navigation shortcuts
config                    Configuration management
list                      List profiles/libs/pkgs
help                      Help system
migrate                   Migrate old project structure
```

---

## Appendix B: Removed Items

### Variables Removed ✅

- ~~`DOCKERHUB_ACCOUNT`~~ (cli.sh:237) - DONE
- ~~`MULTIARCH_VERSE_IMAGE`~~ (cli.sh:229) - DONE
- ~~`FORCE_PLATFORM`~~ (cli.sh:230) - DONE
- ~~`INIT_BASE_IMAGE`~~ (cli.sh:244) - DONE

### Functions Removed ✅

- ~~`validate_cli_arguments()`~~ (cli.sh:480-483) - DONE

### Files Removed

- ~~`modules/help_core.sh`~~ (orphaned dispatcher) - DONE
- ~~`modules/help_guides.sh`~~ (broken references) - DONE
- `templates/modules/` (no longer copied) - PENDING
- `templates/zzcollab-uninstall.sh` (replaced by subcommand) - PENDING

### Flags to Remove (after subcommand implementation)

- `--config` → replaced by `zzcollab config` subcommand
- `--list-profiles` → replaced by `zzcollab list profiles`
- `--list-libs` → replaced by `zzcollab list libs`
- `--list-pkgs` → replaced by `zzcollab list pkgs`
- `--help` → replaced by `zzcollab help`
- `--next-steps` → replaced by `zzcollab help workflow`
