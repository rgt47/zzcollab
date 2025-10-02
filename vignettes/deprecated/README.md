# Deprecated Vignettes

**Date Deprecated**: October 1, 2025
**Reason**: Transition to unified paradigm system

---

## Why These Vignettes Are Deprecated

These vignettes document the **OLD three-paradigm system** (analysis, manuscript, package) which was consolidated into a **unified paradigm** on October 1, 2025.

The unified paradigm (based on Marwick et al. 2018) provides a single flexible structure that supports the entire research lifecycle without requiring upfront paradigm selection or structural migrations.

---

## Deprecated Files (9 total, 421K)

### Solo Workflows (3 files)
- `solo-analysis-workflow.Rmd` (107K) - Analysis-specific workflow
- `solo-manuscript-workflow.Rmd` (19K) - Manuscript-specific workflow
- `solo-package-workflow.Rmd` (44K) - Package-specific workflow

### Team Workflows (4 files)
- `team-analysis-workflow.Rmd` (58K) - Team analysis workflow
- `team-biostat-collaboration.Rmd` (25K) - Biostat team example
- `team-manuscript-workflow.Rmd` (43K) - Team manuscript workflow
- `team-package-workflow.Rmd` (51K) - Team package workflow

### R Interface (1 file)
- `team-r-interface.Rmd` (16K) - R interface for teams

---

## Current Documentation

For current workflows using the unified paradigm, see:

### Primary Vignettes
- **`vignettes/configuration-system.Rmd`** - Comprehensive configuration guide
- **`vignettes/r-solo-workflow.Rmd`** - R-only solo workflow
- **`vignettes/data-analysis-testing.Rmd`** - Data testing framework

### Documentation Guides
- **`docs/UNIFIED_PARADIGM_GUIDE.md`** - Complete unified paradigm guide
- **`docs/MARWICK_COMPARISON_ANALYSIS.md`** - Comparison with Marwick framework
- **`README.md`** - Quick start and overview

### Example Code
- **`examples/`** directory - Practical examples for different research stages

---

## Historical Reference

These files remain available for:
- Understanding the evolution of zzcollab
- Migrating old projects from three-paradigm system
- Historical context for design decisions

**Last three-paradigm version**: zzcollab 1.x (pre-October 2025)
**Current unified version**: zzcollab 2.0+ (October 2025+)

---

## Migration Guide

If you have existing projects using the old three-paradigm system:

### From Analysis Paradigm
Your project structure already closely matches the unified paradigm. Simply:
1. Move `data/` to `analysis/data/`
2. Move `analysis/` scripts to `analysis/scripts/`
3. Continue working - no other changes needed

### From Manuscript Paradigm
Your project already uses research compendium structure:
1. Ensure functions are in `R/`
2. Ensure tests are in `tests/testthat/`
3. Move manuscript to `analysis/paper/` if needed
4. Continue working with unified structure

### From Package Paradigm
Your project structure is package-first:
1. Add `analysis/` directory for data analysis
2. Keep `R/`, `tests/`, `man/`, `vignettes/` as-is
3. Continue package development with unified structure

**Key insight**: The unified paradigm is a superset - it contains all directories from all three old paradigms, so migration is typically additive, not destructive.

---

## Why Unified Paradigm?

### Problems with Three-Paradigm System
- ❌ Forced upfront choice (analysis, manuscript, or package)
- ❌ Migration friction when research evolved
- ❌ 16 possible combinations (3 paradigms × 3 build modes + interactions)
- ❌ Incompatible with Marwick/rrtools conventions
- ❌ Template proliferation (different templates per paradigm)

### Benefits of Unified Paradigm
- ✅ One structure for entire research lifecycle
- ✅ No migration needed as research evolves
- ✅ 3 clear choices (build modes: fast/standard/comprehensive)
- ✅ Marwick/rrtools compatible directory layout
- ✅ Clean starting point (empty `analysis/scripts/` - user creates code)
- ✅ Examples separated from projects (in zzcollab repo)

### Progressive Disclosure
1. **Start**: Use `analysis/scripts/` for data analysis
2. **Write**: Add `analysis/paper/paper.Rmd` for manuscript
3. **Reuse**: Extract functions to `R/` when needed
4. **Package**: Add `man/`, `vignettes/` for distribution

**No structural changes required** - research evolves organically.

---

**For questions or migration assistance**, see:
- `docs/CONSOLIDATION_COMPLETE.md` - Detailed consolidation summary
- `docs/UNIFIED_PARADIGM_GUIDE.md` - Complete unified paradigm guide
- GitHub Issues: https://github.com/rgt47/zzcollab/issues
