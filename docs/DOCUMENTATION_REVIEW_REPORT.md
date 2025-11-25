# Documentation Review Report
**Date**: 2025-10-07
**Reviewer**: Claude Code
**Scope**: Vignettes, docs/, USER_GUIDE after recent simplifications

## Recent Changes Requiring Documentation Updates

### 1. **Simplified .zshrc Handling**
- **Change**: Eliminated `.zshrc_docker` filtering, now copies `.zshrc` directly
- **Rationale**: User's `.zshrc` already has `darwin` conditionals for cross-platform compatibility
- **Impact**: Simpler workflow, one less file to track

### 2. **New Simplified Personal Dockerfile Template**
- **Change**: Created `Dockerfile.personal.team` (40 lines vs 160+ lines)
- **Rationale**: Team images already have everything, no need for conditionals
- **Impact**: Cleaner, more understandable Dockerfiles

### 3. **Volume Mount Path Correction**
- **Change**: `/project` → `/home/analyst/project` in all Makefile docker commands
- **Rationale**: Match container's WORKDIR so files created in container appear on host
- **Impact**: Files created in container now properly sync to host directory

### 4. **Team Image Fixes**
- **Changes**:
  - `WORKDIR /home/rstudio` → `WORKDIR /home/analyst`
  - `CMD ["/bin/bash"]` → `CMD ["/bin/zsh"]`
  - Analyst user created with `/bin/zsh` shell
  - Node.js installed in all team images
- **Impact**: Consistent user experience, vim plugins work (coc.nvim needs Node.js)

### 5. **Profile vs Variant Terminology** ⚠️ MAJOR INCONSISTENCY
- **Code Standard**: Uses "profile" terminology
  - Files: `profiles.yaml`, `add_profile.sh`, `profile_library` in config
  - Functions: `create_profile_dockerfile()`, `add_profile.sh`
- **Documentation**: Mixed usage of "variant" (old) and "profile" (correct)
- **Impact**: USER CONFUSION - documentation doesn't match code
- **Recommendation**: Global search/replace "variant" → "profile" across all documentation
- **Exception**: Keep "variant" only when referring to Docker build variants (technical Docker term)

## Issues Found

### Critical (Affects Functionality)

#### FIXED ✓
1. **docs/UNIFIED_PARADIGM_GUIDE.md** (lines 355, 359)
   - Had `/project` mount path
   - **Fixed**: Changed to `/home/analyst/project`

2. **templates/ZZCOLLAB_USER_GUIDE.md** (line 2349)
   - Had `/project` mount path in custom Makefile target example
   - **Fixed**: Changed to `/home/analyst/project`

### Minor (Consistency/Clarity)

#### TO REVIEW
1. **vignettes/configuration.Rmd**
   - Uses both "profiles" and "variants" terminology
   - **Location**: Throughout the document
   - **Action Needed**: Standardize to "profiles"
   - **Priority**: Medium (doesn't affect functionality)

2. **Dotfiles Documentation**
   - vignettes/quickstart.Rmd mentions dotfiles without leading dots
   - Code actually handles both (with or without dots)
   - **Action Needed**: Clarify that both formats work
   - **Priority**: Low

### Documentation Not Reviewed

The following files were not fully reviewed but should be checked:

1. **docs/VARIANTS.md** - May reference old terminology or paths
2. **docs/CONFIGURATION.md** - May reference old paths
3. **docs/BUILD_MODES.md** - May reference old workflow
4. **templates/ZZCOLLAB_USER_GUIDE.md** - Full review needed (only checked mount paths)

## Recommendations

### Immediate Actions
1. ✓ Fix volume mount paths (COMPLETED)
2. **PRIORITY: Global terminology standardization** - Replace "variant" with "profile" across all user-facing documentation
3. Update CLAUDE.md to use "profile" terminology consistently

### Terminology Standardization Plan

**Files Requiring Global Replacement** (variant → profile):
- vignettes/configuration.Rmd (~30 instances)
- docs/VARIANTS.md (mixed usage, title is correct)
- docs/CONFIGURATION.md (needs review)
- CLAUDE.md (multiple sections)
- templates/ZZCOLLAB_USER_GUIDE.md (needs review)

**Search Pattern**: `variant` → `profile`
**Exceptions** (keep as "variant"):
- Technical Docker terms: "build variant", "image variant"
- File paths in git history/commits
- When specifically discussing the old terminology for migration context

**Verification**:
```bash
# After replacement, verify no user-facing "variant" references remain:
grep -r "variant" vignettes/*.Rmd docs/*.md templates/ZZCOLLAB_USER_GUIDE.md | \
  grep -v "deprecated" | grep -v "git" | grep -v "# old terminology"
```

### Future Improvements
1. Add automated documentation validation (check for `/project` vs `/home/analyst/project`)
2. Create documentation style guide for terminology consistency
3. Add CI check for broken references in documentation

## Files Updated

### Fixed
- ✓ docs/UNIFIED_PARADIGM_GUIDE.md (2 instances)
- ✓ templates/ZZCOLLAB_USER_GUIDE.md (1 instance)
- ✓ templates/Makefile (9 instances)

### Requires Review
- vignettes/configuration.Rmd (profile/variant consistency)
- docs/VARIANTS.md (full review needed)
- docs/CONFIGURATION.md (full review needed)
- templates/ZZCOLLAB_USER_GUIDE.md (full review beyond mount paths)

## Verification Steps

To verify documentation accuracy:

1. **Test mount paths**: `make docker-zsh` and `touch test.txt` should create file on host
2. **Test workflow**: Follow quickstart.Rmd exactly and verify all steps work
3. **Check terminology**: Search for "variant" in user-facing docs, should be "profile"
4. **Check references**: No references to `.zshrc_docker` should exist
