# Documentation Fixes - November 2025

## Summary

Comprehensive documentation update to reflect current ZZCOLLAB framework features and eliminate outdated concepts (build modes, paradigms, old validation system).

## COMPLETED FIXES

### 1. **DEVELOPMENT.md** ✅ (CRITICAL - Most referenced by users)

**Changes Made**:
- ✅ Replaced `Rscript validate_package_environment.R` with `make check-renv` (pure shell)
- ✅ Added "Pure Shell Validation System" section explaining modules/validation.sh
- ✅ Added comprehensive "Auto-Snapshot Architecture" section with workflow examples
- ✅ Updated "Dynamic Package Installation" to show auto-snapshot (no manual `renv::snapshot()`)
- ✅ Removed all build mode references (lines 31-32, 81, 111-115)
- ✅ Fixed "Related Documentation" section - removed BUILD_MODES.md reference
- ✅ Added auto-snapshot configuration options (ZZCOLLAB_AUTO_SNAPSHOT env vars)

**Impact**: HIGH - This is the primary developer reference document

---

### 2. **TESTING_GUIDE.md** ✅ (CRITICAL - Foundational testing docs)

**Changes Made**:
- ✅ Line 8: Changed "all three research paradigms" → "unified research compendium architecture"
- ✅ Lines 538-673: Completely replaced "Paradigm-Specific Testing" section with "Unified Research Compendium Testing"
- ✅ New section uses **progressive disclosure** approach:
  - Phase 1: Data Analysis Testing (Day 1)
  - Phase 2: Manuscript Integration Testing (Week 2)
  - Phase 3: Function Extraction Testing (Month 1)
  - Phase 4: Package Distribution Testing (Month 3)
- ✅ Line 1055: Removed "Build Modes Guide" reference from Related Guides
- ✅ Added references to DEVELOPMENT.md and CONFIGURATION.md instead

**Impact**: HIGH - Core testing philosophy document

---

### 3. **docs/guides/config.md** ✅ (User-facing guide)

**Changes Made**:
- ✅ Line 239: "Change Build Mode" → "Change Docker Profile"
- ✅ Updated description to clarify Docker profiles vs build modes

**Impact**: MEDIUM - User configuration guide

---

## REMAINING WORK

### CRITICAL Priority (User-Facing Documents)

**Files with Build Mode References** (13 remaining):

1. **docs/README.md** - Documentation directory index
2. **docs/guides/renv.md** - Package management guide
3. **docs/guides/docker.md** - Docker architecture guide
4. **docs/guides/troubleshooting.md** - Common issues and fixes
5. **docs/guides/cicd.md** - CI/CD configuration guide
6. **docs/DOCKER_ARCHITECTURE.md** - Technical Docker details
7. **docs/DOCKER_RENV_SYNERGY_MOTIVATION.md** - Architecture rationale
8. **docs/R_PACKAGE_INTEGRATION_SUMMARY.md** - R package integration
9. **docs/RENV_MOTIVATION_DATA_ANALYSIS.md** - Package management motivation
10. **docs/UNIFIED_PARADIGM_GUIDE.md** - Unified paradigm documentation
11. **docs/VALIDATE_PACKAGE_ENV_IMPROVEMENTS.md** - Validation system docs
12. **docs/VARIANTS.md** - Docker profile system
13. **docs/BASH_IMPROVEMENTS_SUMMARY.md** - Shell improvements

**Archive Files** (3 files - SKIP):
- docs/archive/FIX4_DOCUMENTATION_MIGRATION_PLAN.md
- docs/archive/MARWICK_COMPARISON_ANALYSIS.md
- These are archived, no need to update

---

### ENHANCEMENT Priority (Add Current Features)

#### A. **Auto-Snapshot Documentation** (Missing from most docs)

**Needs Addition To**:
- vignettes/getting-started.Rmd
- vignettes/configuration.Rmd
- docs/guides/renv.md
- docs/guides/workflow.md
- Any other workflow-focused docs

**Content to Add** (reference from quickstart.Rmd lines 199-207):
```markdown
**✨ Auto-Snapshot Architecture** (October 2025):

When you exit the container, ZZCOLLAB automatically:
1. Runs `renv::snapshot()` to capture package dependencies
2. Adjusts timestamp for RSPM binary package availability (10-20x faster Docker builds)
3. Validates package consistency (pure shell, no host R required!)
4. Restores timestamp to current time for accurate git history

**You no longer need to manually run `renv::snapshot()`!** Just work and exit.
```

#### B. **Short Flag Documentation** (Missing comprehensive reference)

**Needs Addition To**:
- docs/CONFIGURATION.md - Add complete short flag table

**Content to Add** (reference from CLAUDE.md):

| Short | Long Flag          | Purpose                    |
|-------|--------------------|----------------------------|
| `-a`  | `--tag`            | Docker image tag           |
| `-b`  | `--base-image`     | Custom Docker base         |
| `-c`  | `--config`         | Configuration management   |
| `-d`  | `--dotfiles`       | Copy dotfiles (with dots)  |
| `-D`  | `--dotfiles-nodot` | Copy dotfiles (no dots)    |
| `-f`  | `--dockerfile`     | Custom Dockerfile path     |
| `-g`  | `--github-account` | GitHub account name        |
| `-G`  | `--github`         | Create GitHub repo         |
| `-h`  | `--help`           | Show help                  |
| `-k`  | `--pkgs`           | Package bundle             |
| `-l`  | `--libs`           | Library bundle             |
| `-n`  | `--no-docker`      | Skip Docker build          |
| `-p`  | `--project-name`   | Project name               |
| `-P`  | `--prepare-dockerfile` | Prepare without build  |
| `-q`  | `--quiet`          | Quiet mode (errors only)   |
| `-r`  | `--profile-name`   | Docker profile selection   |
| `-t`  | `--team`           | Team name                  |
| `-u`  | `--use-team-image` | Pull team Docker image     |
| `-v`  | `--verbose`        | Verbose output             |
| `-vv` | `--debug`          | Debug output + log file    |
| `-w`  | `--log-file`       | Enable log file            |
| `-y`  | `--yes`            | Skip confirmations         |

---

## TECHNICAL DETAILS

### Current Framework Features (November 2025)

**Auto-Snapshot Architecture** (October 27, 2025):
- Docker entrypoint: `templates/zzcollab-entrypoint.sh`
- Automatic `renv::snapshot()` on container exit
- RSPM timestamp optimization for binary packages (10-20x faster)
- Pure shell validation: `modules/validation.sh` (NO HOST R REQUIRED)
- Configurable via `ZZCOLLAB_AUTO_SNAPSHOT` and `ZZCOLLAB_SNAPSHOT_TIMESTAMP_ADJUST`

**Pure Shell Validation System** (October 27, 2025):
- Module: `modules/validation.sh`
- Commands: `make check-renv`, `make check-renv-strict`
- Package extraction: pure shell (grep, sed, awk)
- DESCRIPTION parsing: awk
- renv.lock parsing: jq (JSON)
- No R installation required on host!

**Dynamic Package Management** (September 2025):
- Packages added via `renv::install()` as needed
- No pre-configured "modes" (eliminated concept)
- renv.lock accumulates from all team members

**14+ Docker Profiles** (Current):
- Ubuntu Standard: minimal, analysis, publishing
- Ubuntu Shiny: minimal, analysis
- Ubuntu X11: minimal, analysis
- Alpine Standard: minimal, analysis
- Alpine X11: minimal, analysis
- Legacy: bioinformatics, geospatial, modeling, hpc_alpine

**Unified Research Compendium** (2025):
- Single flexible structure (Marwick et al. 2018)
- Progressive disclosure philosophy
- No upfront paradigm choice
- Organic evolution from analysis → manuscript → package

---

## SEARCH PATTERNS FOR REMAINING WORK

### Build Mode References to Remove:
```bash
grep -rn "build.mode\|BUILD_MODE\|--mode\|fast-bundle\|standard-bundle\|comprehensive-bundle" docs/guides/
grep -rn "build.mode\|BUILD_MODE" docs/*.md
```

### Paradigm References to Check:
```bash
grep -rn "paradigm.*separate\|three.*paradigm\|analysis.*paradigm\|manuscript.*paradigm\|package.*paradigm" docs/
```

### Old Validation References:
```bash
grep -rn "validate_package_environment\.R\|Rscript validate_package" docs/
```

---

## PRIORITY ORDER FOR REMAINING WORK

### Phase 1: Critical User-Facing Guides (HIGH PRIORITY)
1. docs/guides/renv.md - Package management workflow
2. docs/guides/docker.md - Docker usage patterns
3. docs/guides/troubleshooting.md - Error messages
4. docs/guides/cicd.md - CI/CD setup

### Phase 2: Technical Documentation (MEDIUM PRIORITY)
5. docs/DOCKER_ARCHITECTURE.md
6. docs/VARIANTS.md
7. docs/UNIFIED_PARADIGM_GUIDE.md

### Phase 3: Motivational/Context Docs (LOWER PRIORITY)
8. docs/DOCKER_RENV_SYNERGY_MOTIVATION.md
9. docs/RENV_MOTIVATION_DATA_ANALYSIS.md
10. docs/R_PACKAGE_INTEGRATION_SUMMARY.md

### Phase 4: Enhancements
11. Add auto-snapshot docs to vignettes
12. Add short flag table to CONFIGURATION.md

---

## VERIFICATION CHECKLIST

After completing all fixes:

- [ ] No references to "build mode", "BUILD_MODE", "--build-mode"
- [ ] No references to "fast-bundle", "standard-bundle", "comprehensive-bundle"
- [ ] No references to "three paradigms" or separate paradigms
- [ ] No references to `validate_package_environment.R` script
- [ ] All validation references use `make check-renv` or `modules/validation.sh`
- [ ] Auto-snapshot architecture documented in all workflow guides
- [ ] Short flag table added to CONFIGURATION.md
- [ ] All command examples show auto-snapshot (no manual `renv::snapshot()`)

---

## FILES COMPLETED

✅ **DEVELOPMENT.md** - Complete validation + auto-snapshot update
✅ **TESTING_GUIDE.md** - Paradigms → unified research compendium
✅ **docs/guides/config.md** - Build mode → Docker profile
✅ **modules/profile_validation.sh** - Complete documentation (8 functions, 600+ lines)

## NEXT ACTIONS

Systematically work through Phase 1-4 files above, applying:
1. Remove build mode references → replace with dynamic package management
2. Remove old validation → replace with pure shell validation
3. Add auto-snapshot docs where relevant
4. Update any paradigm references to unified approach
