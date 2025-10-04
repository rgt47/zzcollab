# Vignette Consolidation Plan for Unified Paradigm

**Date**: October 1, 2025
**Status**: Assessment complete - ready for consolidation

---

## Current Vignette Inventory

### Keep and Updated (1 file)
These vignettes are paradigm-agnostic and have been updated:

1. **configuration-system.Rmd** (34K) - **UPDATED**
   - All paradigm references removed (19 → 1, only "unified paradigm")
   - Package counts updated (47 → 51)
   - Build mode examples updated
   - Ready for use

### Keep As-Is (2 files)
These vignettes do not have paradigm references:

2. **data-analysis-testing.Rmd** (41K) - No paradigm references
3. **r-solo-workflow.Rmd** (12K) - No paradigm references

### ⚠️ Paradigm-Specific Vignettes to Deprecate (9 files, 421K total)

These vignettes represent the OLD three-paradigm system and should be deprecated:

**Solo Workflows** (3 files, 170K):
1. **solo-analysis-workflow.Rmd** (107K, 20 paradigm refs) - Analysis-specific workflow
2. **solo-manuscript-workflow.Rmd** (19K, 14 paradigm refs) - Manuscript-specific workflow
3. **solo-package-workflow.Rmd** (44K, 11 paradigm refs) - Package-specific workflow

**Team Workflows** (4 files, 195K):
4. **team-analysis-workflow.Rmd** (58K, 5 paradigm refs) - Team analysis workflow
5. **team-biostat-collaboration.Rmd** (25K, 3 paradigm refs) - Biostat team example
6. **team-manuscript-workflow.Rmd** (43K, 3 paradigm refs) - Team manuscript workflow
7. **team-package-workflow.Rmd** (51K, 4 paradigm refs) - Team package workflow

**R Interface** (1 file, 16K):
8. **team-r-interface.Rmd** (16K, 3 paradigm refs) - R interface for teams

**Legacy Solo Analysis** (1 file, 40K):
9. **solo-analysis-workflow.Rmd** duplicate or variant

---

## Recommendation: Deprecate Paradigm-Specific Vignettes

### Rationale

1. **Architectural mismatch**: These vignettes document the OLD three-paradigm system (analysis, manuscript, package)
2. **Confusing to users**: Having both unified and paradigm-specific documentation creates confusion
3. **Maintenance burden**: Updating 9 large vignettes (421K of content) is extensive work
4. **Content redundancy**: The unified paradigm covers all use cases these vignettes demonstrate

### Proposed Action

**Move to deprecated directory**:
```bash
mkdir -p vignettes/deprecated
mv vignettes/solo-analysis-workflow.Rmd vignettes/deprecated/
mv vignettes/solo-manuscript-workflow.Rmd vignettes/deprecated/
mv vignettes/solo-package-workflow.Rmd vignettes/deprecated/
mv vignettes/team-analysis-workflow.Rmd vignettes/deprecated/
mv vignettes/team-biostat-collaboration.Rmd vignettes/deprecated/
mv vignettes/team-manuscript-workflow.Rmd vignettes/deprecated/
mv vignettes/team-package-workflow.Rmd vignettes/deprecated/
mv vignettes/team-r-interface.Rmd vignettes/deprecated/
```

**Add deprecation notice**:
Create `vignettes/deprecated/README.md`:
```markdown
# Deprecated Vignettes

These vignettes document the OLD three-paradigm system (analysis, manuscript, package)
which was consolidated into a unified paradigm on October 1, 2025.

## Why Deprecated

The unified paradigm (based on Marwick et al. 2018) provides a single flexible structure
that supports the entire research lifecycle without requiring upfront paradigm selection.

## Current Documentation

For current workflows, see:
- **Unified paradigm guide**: `docs/UNIFIED_PARADIGM_GUIDE.md`
- **Configuration system**: `vignettes/configuration-system.Rmd`
- **R solo workflow**: `vignettes/r-solo-workflow.Rmd`
- **Data analysis testing**: `vignettes/data-analysis-testing.Rmd`

## Historical Reference

These files remain available for:
- Understanding the evolution of zzcollab
- Migrating old projects
- Historical context for design decisions

**Last paradigm-specific version**: zzcollab 1.x (pre-October 2025)
**Current unified version**: zzcollab 2.0+ (October 2025+)
```

---

## Alternative: Update Selected High-Value Vignettes

If deprecation is too aggressive, update **only the most valuable** paradigm-specific vignettes:

### Option A: Update Top 2 (Minimal Effort)
1. **team-biostat-collaboration.Rmd** (25K, 3 refs) - Real-world collaboration example
2. **r-solo-workflow.Rmd** (12K, already done) - R-only interface

**Effort**: 1-2 hours
**Benefit**: Keep best team collaboration example

### Option B: Update Top 4 (Medium Effort)
1. **team-biostat-collaboration.Rmd** (3 refs) - Team collaboration
2. **solo-analysis-workflow.Rmd** (20 refs) - Comprehensive solo workflow
3. **team-analysis-workflow.Rmd** (5 refs) - Team workflow
4. **team-r-interface.Rmd** (3 refs) - R interface examples

**Effort**: 4-6 hours
**Benefit**: Keep both solo and team examples, R interface

### Option C: Update All 9 (Complete Effort)
Update all paradigm-specific vignettes to remove paradigm references

**Effort**: 8-12 hours (421K of content to review and update)
**Benefit**: No content loss
**Drawback**: Massive effort, still leaves confusion about "analysis workflow" vs unified

---

## Recommended Approach: Deprecate with Selective Content Migration

1. **Deprecate all 9 paradigm-specific vignettes** (move to deprecated/)
2. **Extract best examples** from deprecated vignettes
3. **Enhance existing unified vignettes** with extracted content
4. **Create new consolidated vignettes** if needed

### Content Migration Plan

**From solo-analysis-workflow.Rmd (107K)**:
- Extract: Penguin analysis example → add to r-solo-workflow.Rmd
- Extract: Best practices sections → add to configuration-system.Rmd

**From team-biostat-collaboration.Rmd (25K)**:
- Extract: Real-world team collaboration → create new unified team vignette
- Keep: Entire vignette structure can be template for new unified team vignette

**From team-r-interface.Rmd (16K)**:
- Extract: R interface examples → add to r-solo-workflow.Rmd
- Extract: Configuration examples → already in configuration-system.Rmd

---

## Implementation Steps

### Step 1: Create Deprecation Structure (5 minutes)
```bash
mkdir -p vignettes/deprecated
touch vignettes/deprecated/README.md
# Add deprecation notice (template above)
```

### Step 2: Move Deprecated Files (2 minutes)
```bash
cd vignettes
mv solo-analysis-workflow.Rmd deprecated/
mv solo-manuscript-workflow.Rmd deprecated/
mv solo-package-workflow.Rmd deprecated/
mv team-analysis-workflow.Rmd deprecated/
mv team-biostat-collaboration.Rmd deprecated/
mv team-manuscript-workflow.Rmd deprecated/
mv team-package-workflow.Rmd deprecated/
mv team-r-interface.Rmd deprecated/
```

### Step 3: Update Vignette Index (10 minutes)
Update any references to deprecated vignettes in:
- README.md
- CLAUDE.md
- Package vignette metadata

### Step 4: (Optional) Content Migration (2-4 hours)
Extract best examples from deprecated vignettes and add to:
- r-solo-workflow.Rmd (add penguin analysis)
- configuration-system.Rmd (already comprehensive)
- Create new: unified-team-workflow.Rmd (consolidated team examples)

---

## Final Vignette Structure (Proposed)

```
vignettes/
├── configuration-system.Rmd         # Updated - Comprehensive config guide
├── data-analysis-testing.Rmd        # Keep - Data testing framework
├── r-solo-workflow.Rmd              # Keep - R-only solo workflow
├── unified-team-workflow.Rmd        # 🆕 Create - Consolidated team examples
└── deprecated/
    ├── README.md                    # Deprecation notice
    ├── solo-analysis-workflow.Rmd   # Historical reference
    ├── solo-manuscript-workflow.Rmd
    ├── solo-package-workflow.Rmd
    ├── team-analysis-workflow.Rmd
    ├── team-biostat-collaboration.Rmd
    ├── team-manuscript-workflow.Rmd
    ├── team-package-workflow.Rmd
    └── team-r-interface.Rmd
```

**Result**: 3-4 current vignettes + 1 new consolidated team vignette = Clean, unified documentation

---

## Testing After Consolidation

```bash
# Build vignettes
R CMD build .

# Should build without errors
# Should NOT reference deprecated vignettes in index

# Check for paradigm references in active vignettes
grep -rn "paradigm" vignettes/*.Rmd | grep -v "unified paradigm" | grep -v deprecated

# Should return zero results
```

---

## Summary Statistics

**Current State**:
- 11 total vignettes (450K total)
- 9 paradigm-specific vignettes (421K)
- 82 total paradigm references across vignettes

**Proposed State**:
- 4 active vignettes (87K total)
- 9 deprecated vignettes (moved to deprecated/)
- 1 paradigm reference in active vignettes (only "unified paradigm")

**Effort Saved**: 8-12 hours (by deprecating instead of updating all)
**Clarity Gained**: Single source of truth for unified paradigm

---

**Document Status**: Recommendation ready for implementation
**Last Updated**: 2025-10-01
**Next Action**: User decision - deprecate or update selected vignettes
