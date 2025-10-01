# CONFIGURATION.md Updates Required for Unified Paradigm

This document outlines all changes needed to `docs/CONFIGURATION.md` to remove paradigm references and update for the unified paradigm system.

## Global Find/Replace Operations

### 1. Remove Paradigm from Example Hierarchies
**Lines 83-86**:
```markdown
# OLD:
# System config: paradigm: analysis
# User config: paradigm: manuscript
# Project config: paradigm: package
# Command-line: --paradigm analysis

# NEW:
# System config: build_mode: standard
# User config: build_mode: fast
# Project config: build_mode: comprehensive
# Command-line: --fast
```

### 2. Remove Paradigm from Command Examples
**Line 89**:
```bash
# OLD:
zzcollab -i -p research --paradigm analysis

# NEW:
zzcollab -i -p research --standard
```

### 3. Update User Config Example
**Line 115**:
```yaml
# OLD:
defaults:
  team_name: "myteam"
  paradigm: "analysis"          # analysis, manuscript, package
  build_mode: "standard"

# NEW:
defaults:
  team_name: "myteam"
  build_mode: "standard"        # fast, standard, comprehensive
  github_account: "myusername"
```

### 4. Remove Paradigm-Specific Package Overrides Section
**Lines 193-250** (entire section):
```markdown
# OLD: Section title
# Override default packages for research paradigms

paradigms:
  analysis:
    docker_packages: [...]
    renv_packages: [...]
  manuscript:
    docker_packages: [...]
    renv_packages: [...]

# REMOVE ENTIRE SECTION
```

Replace with note:
```markdown
## Package Customization

You can override default packages for each build mode. See "Custom Package Lists" section below for examples.

**Note**: The unified paradigm supports data analysis, manuscript writing, and package development all in one structure. Use build modes (fast/standard/comprehensive) to control package selection.
```

### 5. Update System Config Example
**Line 327**:
```yaml
# OLD:
system:
  # Research paradigm
  paradigm: "analysis"
  # Docker platform
  platform: "linux/amd64"

# NEW:
system:
  # Build mode
  build_mode: "standard"
  # Docker platform
  platform: "linux/amd64"
```

### 6. Remove Paradigm from Configuration Commands
**Lines 431, 445, 509, 701**:
```bash
# REMOVE all instances of:
zzcollab --config set paradigm "manuscript"
zzcollab --config get paradigm

# These are no longer valid commands
```

### 7. Update Configuration Keys List
**Line 509** (in "Available Configuration Keys" section):
```markdown
# OLD:
**paradigm**
- Type: string
- Values: `analysis`, `manuscript`, `package`
- Description: Research paradigm

# REMOVE THIS ENTRY COMPLETELY
```

### 8. Remove Paradigm Overrides Section
**Lines 588-620**:
```markdown
# OLD: Section header
Override default packages for research paradigms:

```yaml
paradigms:
  analysis:
    docker_packages: [renv, tidyverse, targets]
    renv_packages: [renv, tidyverse, targets, plotly]
```

# REMOVE ENTIRE SECTION
```

### 9. Update Command-Line Examples
**Line 715**:
```bash
# OLD:
zzcollab -i -p manuscript-project --paradigm manuscript --github

# NEW:
zzcollab -i -p research-project --standard --github
```

### 10. Update R Interface Examples
**Line 781**:
```r
# OLD:
set_config("paradigm", "manuscript")

# REMOVE - no longer valid
```

**Line 801**:
```r
# OLD comment:
# Team initialization (uses config for team_name, build_mode, paradigm)

# NEW comment:
# Team initialization (uses config for team_name, build_mode)
```

## New Section to Add

Add after "Build Mode Configuration" section:

```markdown
## Unified Paradigm System

The zzcollab unified paradigm consolidates the previous three-paradigm system (analysis, manuscript, package) into a single flexible structure based on Marwick et al. (2018).

**Key Changes from Previous Versions**:
- ❌ No more `paradigm` configuration key
- ✅ One structure supports entire research lifecycle
- ✅ Build modes control package selection (fast/standard/comprehensive)
- ✅ Comprehensive mode includes ALL packages (analysis + manuscript + package)

**Migration from Previous Versions**:
If your config files contain `paradigm:` keys, they will be ignored. Remove them manually:

```yaml
# OLD config (will be ignored):
defaults:
  paradigm: "manuscript"  # ← Remove this line
  build_mode: "standard"

# NEW config:
defaults:
  build_mode: "standard"
```

**Package Selection Philosophy**:
- **Fast mode** (9 packages): Core workflow tools
- **Standard mode** (17 packages): Balanced for most research
- **Comprehensive mode** (51 packages): Everything (analysis + manuscript + package)

See [Unified Paradigm Guide](./UNIFIED_PARADIGM_GUIDE.md) for complete documentation.
```

## Updated Package Count

Update all references to package counts:

**Lines mentioning package counts**:
```markdown
# OLD:
- Fast: 9 packages
- Standard: 17 packages
- Comprehensive: 47 packages

# NEW:
- Fast: 9 packages
- Standard: 17 packages
- Comprehensive: 51 packages (includes all old paradigm packages)
```

## Section Removals Summary

Complete sections to remove:
1. ✅ "Override default packages for research paradigms" (lines ~193-250)
2. ✅ "Paradigm-specific package configurations" example (lines ~588-620)
3. ✅ All paradigm command-line examples throughout
4. ✅ `paradigm` from Available Configuration Keys list

## Section Additions Summary

New sections to add:
1. ✅ "Unified Paradigm System" - Explain consolidation
2. ✅ "Migration from Previous Versions" - Help users update configs
3. ✅ Link to UNIFIED_PARADIGM_GUIDE.md

## Testing Changes

After updates, verify:
```bash
# Check no paradigm references remain
grep -i "paradigm" docs/CONFIGURATION.md

# Should only find:
# - References to "unified paradigm" (explanation)
# - References to "old paradigm system" (historical context)
# - Link to UNIFIED_PARADIGM_GUIDE.md

# Should NOT find:
# - paradigm: "analysis"
# - --paradigm flag
# - set_config("paradigm", ...)
```

---

## Implementation Checklist

- [ ] Remove all `paradigm:` key references from YAML examples
- [ ] Remove `--paradigm` from command-line examples
- [ ] Remove `paradigm` from configuration keys list
- [ ] Remove paradigm-specific package override sections
- [ ] Update package counts (47 → 51 for comprehensive)
- [ ] Add "Unified Paradigm System" section
- [ ] Add migration guidance
- [ ] Update all R interface examples
- [ ] Test grep for remaining unwanted paradigm references
- [ ] Add link to UNIFIED_PARADIGM_GUIDE.md

---

**Note**: This is a comprehensive breaking change. No backward compatibility needed per user request.
