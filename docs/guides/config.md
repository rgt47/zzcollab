# Configuration System Guide

Stop typing the same flags repeatedly! Configure zzcollab once, use everywhere.

---

## Why Use Configuration?

**WITHOUT CONFIG** (repetitive):
```bash
zzcollab -t myname -p project1 --profile-name analysis
zzcollab -t myname -p project2 --profile-name analysis
zzcollab -t myname -p project3 --profile-name analysis
# Typing "myname" and "analysis" every time!
```

**WITH CONFIG** (simple):
```bash
zzcollab --config set team-name "myname"
zzcollab --config set profile-name "analysis"

# Then just:
zzcollab -p project1
zzcollab -p project2
zzcollab -p project3
```

---

## Quick Start: Essential Configuration

**One-time setup** (2 commands):

```bash
zzcollab --config set team-name "yourname"
zzcollab --config set profile-name "analysis"
```

That's it! Now all future projects use these defaults.

---

## Configuration Commands

### Initialize configuration file

```bash
zzcollab --config init
```

### Set a value

```bash
zzcollab --config set SETTING VALUE
```

### Get a value

```bash
zzcollab --config get SETTING
```

### List all settings

```bash
zzcollab --config list
```

### Reset to defaults

```bash
zzcollab --config reset
```

### Validate configuration

```bash
zzcollab --config validate
```

---

## All Configurable Settings

### Team/Project Settings

- `team-name` - Your namespace for Docker images
- `project-name` - Default project name (rarely used)
- `github-account` - GitHub username (defaults to team-name)

### Docker Profile Settings

- `profile-name` - minimal, analysis, modeling, bioinformatics, geospatial, publishing

### Automation Settings

- `auto-github` - Automatically create GitHub repos (true/false)
- `skip-confirmation` - Skip confirmation prompts (true/false)

---

## Configuration File Locations

zzcollab uses a 4-level hierarchy (highest priority first):

### 1. PROJECT CONFIG (highest priority)

- **Location**: `./zzcollab.yaml` (in project directory)
- **Purpose**: Team-specific settings
- **Use for**: Shared team configuration

### 2. USER CONFIG

- **Location**: `~/.zzcollab/config.yaml`
- **Purpose**: Personal defaults across all projects
- **Use for**: Your name, preferences

### 3. SYSTEM CONFIG

- **Location**: `/etc/zzcollab/config.yaml`
- **Purpose**: Organization-wide defaults
- **Use for**: Lab/institution standards

### 4. BUILT-IN DEFAULTS (lowest priority)

- **Location**: Hardcoded in zzcollab
- **Purpose**: Sensible fallbacks

**Example**: If you set team-name in user config (`~/.zzcollab/config.yaml`), it applies to all projects UNLESS a project has its own `zzcollab.yaml`.

---

## Complete Configuration Examples

### Example 1: Solo Researcher (Minimal Setup)

```bash
zzcollab --config set team-name "jsmith"
zzcollab --config set profile-name "analysis"
```

### Example 2: Solo Researcher (Complete Setup)

```bash
zzcollab --config set team-name "jsmith"
zzcollab --config set github-account "jsmith"
zzcollab --config set profile-name "analysis"
zzcollab --config set r-version "4.4.0"
zzcollab --config set auto-github false
```

### Example 3: Team Member

```bash
zzcollab --config set team-name "labteam"
zzcollab --config set github-account "jsmith"
zzcollab --config set profile-name "analysis"

# Now joining team projects is simple:
zzcollab -t labteam -p study --use-team-image
```

### Example 4: Minimal Build for Speed

```bash
zzcollab --config set team-name "myname"
zzcollab --config set profile-name "minimal"

# Projects build in ~30 seconds
# Install additional packages as needed
```

---

## Configuration File Format (YAML)

**Location**: `~/.zzcollab/config.yaml`

**Example complete configuration**:

```yaml
defaults:
  team_name: "jsmith"
  github_account: "jsmith"
  profile_name: "analysis"
  auto_github: false
  skip_confirmation: false
```

You can edit this file directly or use `zzcollab --config` commands.

---

## Common Configuration Workflows

### Workflow 1: First-Time Setup

```bash
# Initialize config file
zzcollab --config init

# Set your essentials
zzcollab --config set team-name "yourname"
zzcollab --config set profile-name "analysis"

# Verify
zzcollab --config list

# Create first project (uses config!)
zzcollab -p myproject
```

### Workflow 2: Check Current Settings

```bash
# See all settings
zzcollab --config list

# Check specific setting
zzcollab --config get team-name
zzcollab --config get profile-name
```

### Workflow 3: Change Docker Profile

```bash
# Switch to different Docker environment (e.g., analysis, geospatial, bioinformatics)
zzcollab --config set profile-name "analysis"

# Applies to all NEW projects
# Existing projects unaffected
```

### Workflow 4: Set Default R Version

```bash
# Set default R version for all projects
zzcollab --config set r-version "4.4.0"

# Now all new projects use R 4.4.0 automatically
cd new-project && zzcollab
# ✓ Uses R 4.4.0 from config (no --r-version flag needed!)

# Override for specific project
zzcollab --r-version "4.3.1"  # Uses 4.3.1 instead
```

**Benefits**:
- Set once, use everywhere
- No need to specify --r-version for every project
- Ensures consistent R version across all projects
- Validated against Docker Hub before builds
- Easy to override when needed

**Priority**:
1. `--r-version` flag (highest priority)
2. Config `r-version` (second priority)
3. `renv.lock` R version (third priority)
4. FAIL with error (no defaults to `:latest`)

### Workflow 5: Reset Everything

```bash
# Start over with defaults
zzcollab --config reset

# Reconfigure
zzcollab --config set team-name "newname"
```

---

## Command-Line Flags vs Configuration

**Command-line flags OVERRIDE configuration**:

**Configuration says**:
```yaml
team-name: "jsmith"
profile-name: "analysis"
```

**Command**:
```bash
zzcollab -t different -p project --profile-name bioinformatics
```

**Result**:
- Uses `team="different"` and `profile="bioinformatics"` (flags override config)
- This project only! Config unchanged.

---

## Configuration Best Practices

### 1. Set configuration ONCE at the beginning

```bash
zzcollab --config set team-name "yourname"
```

### 2. Use consistent team-name across projects

- **Don't**: Different names per project
- **Do**: One name for all your projects

### 3. Choose profile-name based on your needs

- **minimal** - Lightweight base, add packages with `install.packages()`
- **analysis** - Includes tidyverse (recommended for most research)
- **modeling** - Statistical modeling packages
- **bioinformatics** - Bioconductor and bioinfo tools
- **geospatial** - Spatial data analysis packages
- **publishing** - Full publishing suite with LaTeX

### 4. Don't set auto-github to true unless you want repos for EVERYTHING

Better: Use `-G` flag when you want GitHub repo

### 5. Keep ~/.zzcollab/config.yaml backed up

Simple: Store in version control

---

## Troubleshooting Configuration

### Issue: "Configuration not being used"

**Check**:
```bash
zzcollab --config list
# Shows what's actually set
```

**Verify file exists**:
```bash
cat ~/.zzcollab/config.yaml
```

**Re-initialize if needed**:
```bash
zzcollab --config init
```

### Issue: "Can't find config file"

**Create it**:
```bash
zzcollab --config init
```

**Check permissions**:
```bash
ls -la ~/.zzcollab/
# Should be readable/writable by you
```

### Issue: "Configuration seems corrupted"

**Validate syntax**:
```bash
zzcollab --config validate
```

**Reset and start over**:
```bash
zzcollab --config reset
zzcollab --config set team-name "yourname"
```

### Issue: "Settings not persisting"

**Check file location**:
```bash
echo ~/.zzcollab/config.yaml
# Should be in your home directory
```

**Ensure yq is installed**:
```bash
which yq
# Required for config management
```

**Install if missing**:
```bash
brew install yq  # macOS
snap install yq  # Linux
```

---

## Advanced: Project-Level Configuration

**Create project-specific config** (for teams):

**Location**: `myproject/zzcollab.yaml`

**Example team configuration**:

```yaml
team:
  name: "labteam"
  project: "study"
  description: "Cancer genomics analysis"

variants:
  minimal:
    enabled: true
  analysis:
    enabled: true
  bioinformatics:
    enabled: true

build:
  use_config_profiles: true
  docker:
    platform: "auto"
```

This overrides user config for THIS PROJECT ONLY.

---

## Quick Reference

### Essential commands

```bash
zzcollab --config init                         # Create config file
zzcollab --config set team-name "name"         # Set your name
zzcollab --config set profile-name "analysis"  # Set Docker profile
zzcollab --config set r-version "4.4.0"        # Set default R version
zzcollab --config list                         # See all settings
zzcollab --config get team-name                # Get one setting
```

### Files

- `~/.zzcollab/config.yaml` - Your personal config
- `./zzcollab.yaml` - Project-specific config

### Hierarchy (high to low priority)

1. Command-line flags
2. Project config (`./zzcollab.yaml`)
3. User config (`~/.zzcollab/config.yaml`)
4. System config (`/etc/zzcollab/config.yaml`)
5. Built-in defaults

---

## See Also

- [Docker Guide](docker.md) - Understanding Docker profiles and variants
- [Workflow Guide](workflow.md) - Daily development workflow
- [Troubleshooting Guide](troubleshooting.md) - Fix configuration issues
