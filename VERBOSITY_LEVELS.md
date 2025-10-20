# ZZCOLLAB Verbosity System

## Overview

ZZCOLLAB now supports 4 verbosity levels to control output detail:

| Level | Flag | Output Lines | Use Case |
|-------|------|--------------|----------|
| 0 | `--quiet` / `-q` | ~0 (errors only) | CI/CD, scripts |
| 1 | (default) | ~8-10 | Daily usage |
| 2 | `-v` / `--verbose` | ~25-30 | Troubleshooting |
| 3 | `-vv` / `--debug` | ~400+ | Development, debugging |

## Usage Examples

### Level 0: Quiet Mode (--quiet / -q)
**Only shows errors. Silent success.**

```bash
$ zzcollab -t team -p project --quiet
# (no output on success)

# On error:
❌ Failed to create directory: R
```

**Use for:**
- CI/CD pipelines
- Automated scripts
- When you only care about failures

---

### Level 1: Default (no flag)
**Concise, actionable output (~8-10 lines)**

```bash
$ zzcollab -t team -p project
Creating project 'project'...
✅ Structure (16 dirs, 40 files)
✅ R package
✅ Docker environment
✅ Analysis templates
✅ CI/CD workflows
Done! Next: make docker-build
```

**Use for:**
- Normal daily usage
- Quick project creation
- When you know what you're doing

---

### Level 2: Verbose Mode (-v / --verbose)
**Moderate detail (~25-30 lines)**

```bash
$ zzcollab -t team -p project -v
🚀 Starting modular rrtools project setup...
📦 Package name: 'project'

ℹ️  Creating directory structure...
ℹ️  Creating core R package files...
ℹ️  Creating Docker configuration...
ℹ️  Creating analysis framework...
ℹ️  Creating CI/CD workflows...

✅ Structure (16 dirs, 40 files)
✅ R package
✅ Docker environment  
✅ Analysis templates
✅ CI/CD workflows

Done! Next: make docker-build

📁 PROJECT STRUCTURE CREATED (rrtools framework):

├── R/                     # Package functions
├── man/                   # Manual pages
├── tests/testthat/        # Unit tests
├── analysis/              # Research workflow
│   ├── data/              # Research data
│   ├── paper/             # Manuscript
│   ├── figures/           # Plots
│   └── scripts/           # Analysis scripts
├── docs/                  # Documentation
└── .github/workflows/     # CI/CD

📚 Run 'zzcollab --next-steps' for guidance
📖 See ZZCOLLAB_USER_GUIDE.md for documentation
```

**Use for:**
- Learning the system
- Verifying what was created
- Troubleshooting issues

---

### Level 3: Debug Mode (-vv / --debug)
**Everything (~400+ lines, full detail)**

```bash
$ zzcollab -t team -p project -vv
🔍 Loading all zzcollab modules...
🔍 Loading core module...
🔍 Loading config module...
🔍 Configuration loading complete
🔍 Applied configuration defaults to CLI variables
🔍 Configuration system initialized
🔍 Loading templates module...
🔍 Loading utils module...
🔍 Loading structure module...
🔍 Package name determined: project
🔍 Loading rpackage module...
🔍 Loading docker module...
🔍 Loading analysis module...
🔍 Loading cicd module...
🔍 Loading devtools module...
...
(400+ more lines)
...
Done! Next: make docker-build
```

**Also creates:** `.zzcollab.log` file with timestamped entries

**Use for:**
- Debugging issues
- Understanding internals
- Filing bug reports
- Development

---

## Log File Support

Debug mode (`-vv`) automatically writes detailed logs to `.zzcollab.log`:

```
[2025-10-20 08:45:12] DEBUG: Loading core module...
[2025-10-20 08:45:12] DEBUG: Configuration loading complete
[2025-10-20 08:45:13] DEBUG: Created directory: R
[2025-10-20 08:45:13] DEBUG: Created directory: man
[2025-10-20 08:45:13] SUCCESS: Structure (16 dirs, 40 files)
...
```

To enable log file without debug output:
```bash
$ export ENABLE_LOG_FILE=true
$ zzcollab -t team -p project
```

---

## Implementation Details

### Log Function Hierarchy

```bash
log_error()   # Always shown (even in --quiet)
log_warn()    # Shown at level ≥ 1 (default)
log_success() # Shown at level ≥ 1 (default)
log_info()    # Shown at level ≥ 2 (-v)
log_debug()   # Shown at level ≥ 3 (-vv)
```

### Examples in Code

```bash
# Always shown (errors)
log_error "Failed to create directory"

# Default output (successes and warnings)
log_success "✅ R package"
log_warn "⚠️  Optional dependency missing"

# Verbose output (-v)
log_info "ℹ️  Creating Docker configuration..."

# Debug output (-vv only)
log_debug "🔍 Created directory: R"
log_debug "🔍 Loading module: core.sh"
```

---

## Comparison: Before vs After

### Before (400+ lines)
```bash
$ zzcollab -t team -p project
ℹ️  Loading all zzcollab modules...
ℹ️  Loading core module...
ℹ️  Loading config module...
ℹ️  Configuration loading complete
ℹ️  Applied configuration defaults
ℹ️  Loading templates module...
ℹ️  Loading utils module...
ℹ️  Loading structure module...
ℹ️  Package name determined: project
ℹ️  Loading rpackage module...
ℹ️  Loading docker module...
ℹ️  Loading analysis module...
ℹ️  Loading cicd module...
ℹ️  Loading devtools module...
ℹ️  Loading help module...
ℹ️  Loading help_guides module...
ℹ️  Loading github module...
ℹ️  Loading profile_validation module...
ℹ️  🚀 Starting modular rrtools project setup...
ℹ️  📦 Package name: 'project'
ℹ️  🔧 All modules loaded successfully
ℹ️  📁 Creating project structure...
ℹ️  Creating directory structure...
ℹ️  Created directory: R
ℹ️  Created directory: man
ℹ️  Created directory: tests/testthat
ℹ️  Created directory: vignettes
ℹ️  Created directory: data
ℹ️  Created directory: analysis
ℹ️  Created directory: analysis/data
ℹ️  Created directory: analysis/data/raw_data
ℹ️  Created directory: analysis/data/derived_data
ℹ️  Created directory: analysis/paper
ℹ️  Created directory: analysis/figures
ℹ️  Created directory: analysis/tables
ℹ️  Created directory: analysis/templates
ℹ️  Created directory: analysis/scripts
ℹ️  Created directory: docs
ℹ️  Created directory: .github/workflows
✅ Directory structure created (16 directories)
ℹ️  Creating data directory templates...
ℹ️  Created data directory README
✅ Data README template created
... (350+ more lines)
```

### After (8 lines)
```bash
$ zzcollab -t team -p project
Creating project 'project'...
✅ Structure (16 dirs, 40 files)
✅ R package
✅ Docker environment
✅ Analysis templates
✅ CI/CD workflows
Done! Next: make docker-build
```

---

## Environment Variables

Control behavior via environment variables:

```bash
# Set verbosity level (0-3)
export VERBOSITY_LEVEL=2
zzcollab -t team -p project  # Uses verbose mode

# Enable log file
export ENABLE_LOG_FILE=true
zzcollab -t team -p project  # Writes to .zzcollab.log

# Custom log file location
export LOG_FILE="setup.log"
zzcollab -t team -p project  # Writes to setup.log
```

---

## Best Practices

1. **Default for normal use**: No flags needed
2. **Quiet for automation**: Use `-q` in CI/CD
3. **Verbose for learning**: Use `-v` when starting out
4. **Debug for issues**: Use `-vv` when filing bug reports

## Summary

- **95% less output** by default (400+ → 8 lines)
- **Flexible verbosity** for different use cases
- **Optional log files** for detailed records
- **Unix-standard behavior** (quiet success, errors always shown)
- **Backward compatible** (`-vv` restores old behavior)
