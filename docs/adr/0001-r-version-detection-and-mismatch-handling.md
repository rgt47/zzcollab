# ADR 0001: R Version Detection and Mismatch Handling

**Status**: Accepted

**Date**: 2025-12-05

**Deciders**: zzcollab development team

**Affected Components**: zzcollab CLI, renv integration, project initialization

---

## Context

zzcollab manages reproducible research environments for R-based analysis. A critical aspect of reproducibility is ensuring that the exact R version used for analysis is consistent across different machines and over time. The `renv` package pins exact versions of R and packages in `renv.lock`.

During early-stage testing, developers encountered situations where:
- Their local R version had been upgraded (e.g., 4.5.1 → 4.5.2)
- Existing projects were pinned to a different R version in `renv.lock`
- The zzcollab CLI could not determine which version to use
- Project initialization failed with a cryptic error

This created friction in the development workflow, especially when multiple projects with different version requirements existed on the same machine.

**Background**:
- R version mismatches can cause binary package incompatibility, renv restoration failures, and different numerical results
- Reproducible research requires explicit version tracking
- Developers sometimes upgrade R for new features or bugfixes, but existing projects may not be ready for the upgrade
- Multiple concurrent projects may have different R version requirements

---

## Problem Statement

How should zzcollab handle situations where the system R version differs from the version specified in `renv.lock`? Should it fail, prompt for a decision, or automatically select one?

**Key Decision Points**:
1. Should zzcollab enforce strict version matching or allow flexibility?
2. How should users resolve version mismatches?
3. Should there be a configuration file for project-level R version preferences?

---

## Options Considered

### Option A: Silent Fallback
Use the system R version and issue a warning.

**Pros**:
- Minimal friction for users
- Projects "just work"

**Cons**:
- May produce incorrect results if R version-dependent code is executed
- Violates reproducibility principle
- Silent failures are dangerous in research computing

---

### Option B: Strict Enforcement
Fail immediately if versions don't match; require user to explicitly specify version.

**Pros**:
- Enforces reproducibility
- No silent failures
- Makes version mismatches visible

**Cons**:
- High friction for development workflow
- Requires users to remember/type version flags
- May create workflow bottlenecks

---

### Option C: Detect and Prompt (Chosen)
Detect the mismatch, fail with clear error message, provide both resolution options, and support configuration file for project-level defaults.

**Pros**:
- Enforces reproducibility (no silent failures)
- Educates users about version importance
- Provides escape hatches for development workflows
- Allows project-level configuration to reduce friction
- Clear error messages prevent confusion

**Cons**:
- Slightly more complex than strict failure
- Requires users to make a decision first time

---

## Decision

**Chosen Option**: Option C - Detect and Prompt

When zzcollab detects an R version mismatch, it will:

1. **Display a clear error message** indicating:
   - System R version
   - `renv.lock` R version
   - Why this matters

2. **Provide two resolution paths**:
   - **Path 1**: Use R version from `renv.lock` (recommended for reproducibility)
     ```bash
     zzcollab --r-version 4.5.2
     ```
   - **Path 2**: Update `renv.lock` to match system R (for development)
     ```bash
     R -e "renv::init(force = TRUE)"
     zzcollab --r-version 4.5.1
     ```

3. **Support project-level configuration** via `.zzcollab-rc`:
   ```bash
   # .zzcollab-rc (checked into version control)
   R_VERSION=4.5.2
   PROFILE=ubuntu_standard_minimal
   ```

4. **Provide clear guidance** in error message about implications

**Rationale**:
- Reproducibility is fundamental to zzcollab's mission; silent failures are unacceptable
- Users need to understand why versions matter, especially in research computing
- Flexibility for development workflow is important (don't block productivity)
- Configuration file support removes friction for repeated use
- Clear error messages with actionable steps improve developer experience

---

## Consequences

**Positive Consequences**:
- Prevents silent reproducibility failures
- Educates developers about version importance
- Supports both strict reproducibility workflows and active development
- Reduces confusion from cryptic errors
- Configuration file support creates smooth workflow

**Negative Consequences**:
- First-time use requires understanding R version management
- Additional one-time setup step for projects
- Users must choose between reproducibility and convenience (though we recommend reproducibility)

**Risks**:
1. **Risk**: Users ignore version warnings and proceed with mismatches
   - **Mitigation**: Clear error message explains computational consequences
   - **Mitigation**: Documentation and training emphasize importance

2. **Risk**: Configuration file goes out of sync with actual `renv.lock`
   - **Mitigation**: Store `.zzcollab-rc` in version control alongside renv.lock
   - **Mitigation**: CI/CD validation that files are in sync

---

## Implementation

### Phase 1: Core Functionality
- [x] Implement R version detection from system and `renv.lock`
- [x] Create clear, actionable error messages
- [x] Implement `--r-version` flag for explicit version selection
- [x] Document in user guide

### Phase 2: Configuration Support
- [ ] Implement `.zzcollab-rc` parsing
- [ ] Add validation that config matches `renv.lock`
- [ ] Add `--config` command for managing settings

### Phase 3: Documentation & Education
- [ ] Update README with R version management section
- [ ] Create troubleshooting guide
- [ ] Add to testing lessons learned (DONE)

**Timeline**:
- Phase 1: Completed in initial development
- Phase 2: Next development cycle
- Phase 3: Ongoing

**Success Criteria**:
- No silent R version mismatches (all detected)
- Users understand why versions matter (based on feedback)
- Workflow friction is acceptable for both development and reproducibility workflows
- Reduced support issues related to version mismatches

---

## Related Decisions

- None yet (this is foundational)

---

## References

- [Reproducible Research: A Tragedy of Errors](https://doi.org/10.1038/nature.2015.18127) - Why versions matter
- [renv Documentation](https://rstudio.github.io/renv/articles/renv.html)
- Testing Lessons Learned: Section 11 - R Version Mismatches in Multi-Environment Development
- GitHub Issues: [Link to related issues when created]

---

## Notes

This decision emerged from practical experience with collaborative research environments where multiple projects with different requirements exist on the same machine. The key insight is that **reproducibility cannot be silent** - making version mismatches visible is more important than frictionless initialization.

Future enhancement: Provide Docker integration to automatically isolate project environments, removing need for per-project R version management on the host machine.

---

## Revision History

| Date | Status | Changes |
|------|--------|---------|
| 2025-12-05 | Accepted | Initial ADR from R version mismatch experience |
