# Help Documentation Audit - Obsolete Config References

**Date**: 2025-10-12
**Status**: 🔍 **AUDIT COMPLETE** - Issues identified, remediation needed

## Executive Summary

Comprehensive audit of `modules/help.sh` and `modules/help_guides.sh` identified **obsolete configuration references** that no longer exist in the current ZZCOLLAB design. The `--config` flag usage is **correct throughout** - no bare `config` word patterns were found.

## Audit Scope

**Files Audited**:
- `modules/help.sh` (1,073 lines)
- `modules/help_guides.sh` (3,591 lines)

**Search Patterns**:
1. ✅ Config flag format (`--config`, `-c`, bare `config`)
2. ❌ `renv-mode` references (OBSOLETE)
3. ❌ `build-mode` references (OBSOLETE)

## Findings Summary

| Category | Status | Count | Files |
|----------|--------|-------|-------|
| **Config flag format** | ✅ Correct | All uses | Both files |
| **renv-mode references** | ❌ Obsolete | 10 instances | help.sh |
| **build-mode references** | ❌ Obsolete | 28 instances | help_guides.sh |

## Current ZZCOLLAB Design (Context)

**What Changed**:
- **Old system**: Pre-configured package modes (`renv-mode`, `build-mode`)
- **New system**: Dynamic package management via `renv::install()`
- **Docker profiles**: Control base environment (14+ specialized profiles)
- **Package installation**: Added as needed inside containers
- **No modes**: Eliminated pre-configured package bundles

**Correct Current Patterns**:
```bash
# Configuration system (CORRECT)
zzcollab --config init
zzcollab --config set team-name "myteam"
zzcollab --config set profile-name "rstudio"  # Docker profile
zzcollab --config list

# Dynamic package management (CORRECT)
make r
renv::install("tidyverse")
renv::snapshot()
```

---

## Detailed Findings

### 1. Config Flag Format - ✅ ALL CORRECT

**Result**: No issues found. All config commands use proper format.

**Verified Patterns**:
- `zzcollab --config SUBCOMMAND` ✅ (long form)
- `zzcollab -c SUBCOMMAND` ✅ (short form)
- No bare `zzcollab config SUBCOMMAND` patterns found ✅

---

### 2. renv-mode References - ❌ OBSOLETE (10 instances in help.sh)

**Problem**: `renv-mode` configuration no longer exists. Package management is now dynamic.

**Impact**: Users following these instructions will encounter errors or set configuration values that have no effect.

#### Instances Found in modules/help.sh:

| Line | Context | Obsolete Reference | Recommended Fix |
|------|---------|-------------------|-----------------|
| 276 | Config examples | `zzcollab -c set renv-mode fast` | Remove entire example |
| 284 | Settings list | `Settings: team-name, github-account, renv-mode, dotfiles-dir,` | Remove `renv-mode` from list |
| 503 | GitHub workflow | `zzcollab --config set renv-mode "standard"` | Remove line |
| 774 | Quickstart simplest setup | `zzcollab --config set renv-mode "standard"` | Remove line |
| 805 | First project walkthrough | `zzcollab --config set renv-mode "standard"` | Remove line |
| 891 | FAQ - slow laptop | `zzcollab --config set renv-mode "fast"` | Replace with profile-based approach |
| 896 | FAQ - need more packages | `--config set renv-mode "comprehensive"` | Replace with dynamic installation |
| 906 | Complete command reference | `zzcollab --config set renv-mode "standard"` | Remove line |
| 968 | Semester workflow | `zzcollab --config set renv-mode "standard"` | Remove line |
| 1031 | Quick reference card | `zzcollab --config set renv-mode "standard"` | Remove line |

#### Detailed Examination:

**Line 276 (show_help_config function)**:
```bash
zzcollab -c set renv-mode fast                      # Set default build mode
```
**Issue**: `renv-mode` no longer exists
**Fix**: Remove this example line entirely

**Line 284 (show_help_config function)**:
```bash
Settings: team-name, github-account, renv-mode, dotfiles-dir,
          dotfiles-nodot, auto-github, skip-confirmation
```
**Issue**: `renv-mode` listed as valid setting
**Fix**: Remove `renv-mode` from settings list

**Lines 503, 774, 805, 906, 968, 1031**:
Multiple workflow examples showing:
```bash
zzcollab --config set renv-mode "standard"
```
**Issue**: Non-existent configuration setting
**Fix**: Remove all instances; users should use `--profile-name` instead

**Line 891 (FAQ - slow laptop)**:
```bash
Q: "My laptop is slow - can I use a faster mode?"
A: Yes! Use Fast mode:
     zzcollab --config set renv-mode "fast"
   Only 9 packages, builds in 2-3 minutes.
```
**Issue**: Fast mode no longer exists
**Fix**: Suggest lightweight Docker profile:
```bash
Q: "My laptop is slow - can I use a lighter environment?"
A: Yes! Use a minimal Docker profile:
     zzcollab --config set profile-name "minimal"
   Then install only the packages you need with renv::install()
```

**Line 896 (FAQ - need more packages)**:
```bash
Q: "I need packages not in Standard mode"
A: Either:
   1. Use Comprehensive mode (47 packages): --config set renv-mode "comprehensive"
   2. Just install them as you need them in RStudio
```
**Issue**: Comprehensive mode no longer exists
**Fix**: Emphasize dynamic installation:
```bash
Q: "I need additional packages"
A: Install them dynamically as needed:
     # In RStudio or R console:
     renv::install("package-name")
     renv::snapshot()
```

---

### 3. build-mode References - ❌ OBSOLETE (28 instances in help_guides.sh)

**Problem**: `build-mode` configuration no longer exists. System now uses Docker profiles.

**Impact**: Documentation describes non-existent feature, confusing users about package management.

#### Instances Found in modules/help_guides.sh:

| Line | Context | Obsolete Reference | Recommended Fix |
|------|---------|-------------------|-----------------|
| 707 | Docker workflow | `zzcollab --config set build-mode "fast"` | Use `profile-name` |
| 711 | Docker workflow | `zzcollab --config set build-mode "minimal"` | Use `profile-name` |
| 866 | Config setup | `zzcollab --config set build-mode "standard"` | Remove |
| 880 | Config setup | `zzcollab --config set build-mode "standard"` | Remove |
| 917 | Available settings | `build-mode         minimal, fast, standard, comprehensive` | Remove entry |
| 962 | Solo workflow | `zzcollab --config set build-mode "standard"` | Remove |
| 971 | Team workflow | `zzcollab --config set build-mode "fast"` | Remove |
| 979 | Team workflow | `zzcollab --config set build-mode "standard"` | Remove |
| 989 | Minimal workflow | `zzcollab --config set build-mode "minimal"` | Remove |
| 1024 | Create config | `zzcollab --config set build-mode "standard"` | Remove |
| 1039 | Get setting | `zzcollab --config get build-mode` | Use `profile-name` |
| 1044 | Change setting | `zzcollab --config set build-mode "fast"` | Use `profile-name` |
| 1065 | Config example | `build-mode: "standard"` | Remove from YAML |
| 1089 | Step 4 guidance | `4. Choose build-mode based on your needs:` | Replace with profile selection |
| 1186 | Quick commands | `zzcollab --config set build-mode "standard"` | Remove |
| 2179 | Minimal mode | `zzcollab --config set build-mode "minimal"` | Use minimal profile |
| 2205 | Fast mode | `zzcollab --config set build-mode "fast"` | Use minimal profile |
| 2265 | Comprehensive | `zzcollab --config set build-mode "comprehensive"` | Use analysis profile |
| 2358 | Default mode | `zzcollab --config set build-mode "standard"` | Remove |
| 2373 | Workflow setup | `zzcollab --config set build-mode "standard"` | Remove |
| 2395 | Development | `zzcollab --config set build-mode "standard"` | Remove |
| 2456 | Fast setup | `zzcollab --config set build-mode "fast"` | Use minimal profile |
| 2503 | Minimal mode | `zzcollab --config set build-mode "minimal"` | Use minimal profile |
| 2516 | Check config | `zzcollab --config get build-mode` | Use `profile-name` |
| 2551 | CLI flag | `zzcollab -p geo-analysis --build-mode geospatial` | Use `--profile-name` |
| 2566 | Set mode | `zzcollab --config set build-mode "MODE"` | Use `profile-name` |
| 2567 | Get mode | `zzcollab --config get build-mode` | Use `profile-name` |

#### Key Problem Areas:

**1. Configuration Examples (Lines 707, 711, 866, 880, etc.)**

Old pattern:
```bash
zzcollab --config set build-mode "fast"
zzcollab --config set build-mode "standard"
```

Should be:
```bash
zzcollab --config set profile-name "minimal"
zzcollab --config set profile-name "analysis"
```

**2. Available Settings Documentation (Line 917)**

Old:
```
build-mode         minimal, fast, standard, comprehensive
```

Should be:
```
profile-name       minimal, rstudio, analysis, bioinformatics, etc.
                   (see: zzcollab --list-profiles)
```

**3. Config File Structure (Line 1065)**

Old YAML example:
```yaml
defaults:
  team_name: "rgt47"
  build-mode: "standard"
```

Should be:
```yaml
defaults:
  team_name: "rgt47"
  profile_name: "minimal"
```

**4. CLI Flag Usage (Line 2551)**

Old:
```bash
zzcollab -p geo-analysis --build-mode geospatial
```

Should be:
```bash
zzcollab -p geo-analysis --profile-name geospatial
```

---

## Remediation Plan

### Phase 1: Remove Obsolete References (High Priority)

**File: modules/help.sh**
- Remove all `renv-mode` references (10 instances)
- Update FAQ sections to reflect dynamic package management
- Update settings lists to remove `renv-mode`

**File: modules/help_guides.sh**
- Remove all `build-mode` references (28 instances)
- Replace with `profile-name` where appropriate
- Update YAML examples to show correct structure

### Phase 2: Update Documentation Patterns (Medium Priority)

**Replace Old Pattern**:
```bash
# ❌ OBSOLETE
zzcollab --config set renv-mode "fast"
zzcollab --config set build-mode "minimal"
```

**With New Pattern**:
```bash
# ✅ CURRENT
zzcollab --config set profile-name "minimal"
make r
renv::install("tidyverse")  # Dynamic installation
renv::snapshot()
```

### Phase 3: Add New Documentation Sections (Low Priority)

**New sections needed**:
1. **Docker Profile Selection Guide**
   - List all 14+ available profiles
   - Explain profile characteristics
   - Reference `zzcollab --list-profiles`

2. **Dynamic Package Management Guide**
   - Explain `renv::install()` workflow
   - Show `renv::snapshot()` usage
   - Emphasize flexibility over pre-configuration

3. **Package Management FAQ**
   - "How do I add packages?" → `renv::install()`
   - "Which packages are included?" → "Only what you install"
   - "Can I pre-configure packages?" → "No, install as needed"

---

## Validation Commands

After remediation, verify changes with:

```bash
# Check for remaining obsolete references
cd /Users/zenn/Library/CloudStorage/Dropbox/prj/d07/zzcollab/modules

# Should return NO results:
grep -n "renv-mode" help.sh help_guides.sh
grep -n "build-mode" help.sh help_guides.sh

# Verify correct patterns exist:
grep -n "profile-name" help.sh help_guides.sh
grep -n "renv::install" help.sh help_guides.sh
```

---

## Impact Assessment

**User Impact**: HIGH
- Users following help documentation will encounter errors
- Configuration commands will fail or have no effect
- Confusion about package management approach

**Documentation Debt**: MODERATE
- 38 total obsolete references across 2 files
- Affects multiple help topics (quickstart, config, workflow, troubleshooting)
- Some sections need complete rewrite (package management FAQs)

**Testing Impact**: LOW
- Help documentation has no automated tests
- Manual verification needed after updates
- Consider adding documentation tests in future

---

## Recommendations

### Immediate Actions (This Week)

1. **Remove all obsolete references** from help.sh and help_guides.sh
2. **Replace with current patterns** where appropriate
3. **Test all help commands** to ensure no broken examples

### Short-Term (This Month)

1. **Create dedicated Docker profile guide** in help documentation
2. **Add dynamic package management section** with clear examples
3. **Update all workflow examples** to reflect current design

### Long-Term (Next Quarter)

1. **Add automated documentation tests** to catch obsolete references
2. **Create help documentation style guide** for consistency
3. **Set up documentation review process** during feature changes

---

## Current Correct Configuration Settings

For reference, here are the **valid current settings**:

```yaml
# Valid configuration settings (2025-10-12)
defaults:
  team_name: "myteam"              # Docker Hub team/organization
  github_account: "myaccount"      # GitHub account (defaults to team_name)
  dockerhub_account: "myaccount"   # Docker Hub account (defaults to team_name)
  profile_name: "minimal"          # Docker profile (minimal, rstudio, analysis, etc.)
  dotfiles_dir: "~/dotfiles"       # Dotfiles directory path
  dotfiles_nodot: true             # Dotfiles stored without leading dots
  auto_github: false               # Automatically create GitHub repository
  skip_confirmation: false         # Skip confirmation prompts
```

**Removed settings** (DO NOT use):
- ❌ `renv-mode` - REMOVED (use dynamic `renv::install()`)
- ❌ `build-mode` - REMOVED (use `profile-name`)
- ❌ `libs-bundle` - REMOVED (use `profile-name`)
- ❌ `pkgs-bundle` - REMOVED (use dynamic installation)

---

## Testing Checklist

Before marking audit as resolved:

- [ ] Remove all `renv-mode` references from help.sh
- [ ] Remove all `build-mode` references from help_guides.sh
- [ ] Update FAQ sections with current patterns
- [ ] Update YAML examples with correct structure
- [ ] Verify all config examples use `--config` or `-c` (already correct ✅)
- [ ] Test help commands: `zzcollab --help`, `zzcollab --help config`, etc.
- [ ] Verify no remaining obsolete references: `grep -r "renv-mode\|build-mode" modules/help*.sh`

---

## Appendix: Complete Instance List

### renv-mode instances (help.sh):
```
276:    zzcollab -c set renv-mode fast
284:    Settings: team-name, github-account, renv-mode, dotfiles-dir,
503:    zzcollab --config set renv-mode "standard"
774:    zzcollab --config set renv-mode "standard"
805:   zzcollab --config set renv-mode "standard"
891:     zzcollab --config set renv-mode "fast"
896:   1. Use Comprehensive mode (47 packages): --config set renv-mode "comprehensive"
906:zzcollab --config set renv-mode "standard"
968:zzcollab --config set renv-mode "standard"
1031:  zzcollab --config set renv-mode "standard"
```

### build-mode instances (help_guides.sh):
```
707, 711, 866, 880, 917, 962, 971, 979, 989, 1024,
1039, 1044, 1065, 1089, 1186, 2179, 2205, 2265, 2358,
2373, 2395, 2456, 2503, 2516, 2551, 2566, 2567
```

---

**Created**: 2025-10-12
**Author**: Documentation audit system
**Next Review**: After remediation complete
