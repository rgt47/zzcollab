# Setting Up a Documentation System for Early-Stage Development

**Date**: 2025-12-05
**Project**: zzcollab
**Conversation**: Problem/Solution Documentation Setup

---

## Overview

This document captures the conversation and work involved in setting up a comprehensive documentation and issue tracking system for zzcollab during early-stage development.

---

## The Question

During testing of zzcollab, I encountered a problem and needed a solution:

> I'm working on a system for collaborative research called zzcollab. As I'm testing the system I'm running into problems that need solutions and I want to document the problem and the solution used. What is the industry standard strategy/method for recording problems and solutions that arise during early stage development?

### Context

The specific problem encountered:
```
❌ R version MISMATCH detected!
❌
❌   Specified R version:  4.5.1
❌   renv.lock R version:  4.5.2
```

This occurred when upgrading R from 4.5.1 to 4.5.2 while running zzcollab for the first time on a new version.

---

## Industry Standard Approaches

After analysis, I learned that there are **several industry-standard approaches** for documenting problems and solutions during early-stage development:

### 1. **Architecture Decision Records (ADRs)**
Lightweight markdown files recording *why* decisions were made. Stored sequentially with the format:
- **Status**: Proposed/Accepted/Deprecated
- **Context**: Problem description
- **Decision**: What was chosen and why
- **Consequences**: Tradeoffs and impact

Typically stored in `docs/adr/` with sequential numbering (0001-*, 0002-*, etc.)

### 2. **Lessons Learned Documents**
Narrative documentation capturing pain points and solutions discovered during development:
- Captures tribal knowledge
- Helps new contributors avoid same pitfalls
- Accumulates practical insights
- Less formal than ADRs

### 3. **Issue Tracking + Labels**
GitHub Issues (or similar) with structured metadata:
- `kind/bug`, `kind/investigation`, `kind/lesson-learned`
- Link to relevant code locations
- Reference solutions found
- Track decisions made

### 4. **Postmortems / Root Cause Analysis**
For significant problems:
- What happened
- Why it happened
- How it was resolved
- What to do differently

### 5. **Runbooks/Troubleshooting Guides**
Executable documentation for recurring issues:
- Problem identification
- Step-by-step resolution
- Verification steps

---

## Recommended Approach for zzcollab

For early-stage development of a collaborative research tool, a **three-tier approach** was chosen:

1. **Lessons Learned Doc** - Primary capture point for investigation findings and generalizable insights
2. **Lightweight ADRs** - For architectural decisions with future implications
3. **GitHub Issues** - As a searchable index/backlog, linking to lessons learned docs

This avoids process overhead while capturing knowledge for future reference.

---

## Implementation

### 1. Updated Lessons Learned Document

**File**: `docs/TESTING_LESSONS_LEARNED.md`

**What Was Added**: Section 11 - R Version Mismatches in Multi-Environment Development

**Content**:
- The Problem: Context and what happened
- The Solution: Two options with code examples
- Generalizable Lessons: Principles that apply beyond this specific issue
- zzcollab Pattern: Reusable pattern for handling version compatibility

**Key Learning**:
Version pinning in `renv.lock` is intentional and critical for reproducibility. When R versions mismatch, users should either:
1. Use the pinned version from `renv.lock` (recommended for reproducibility)
2. Update `renv.lock` if doing active development on new R version

### 2. Architecture Decision Records (ADRs)

**Directory**: `docs/adr/`

#### ADR Template (`0000-TEMPLATE.md`)
Created a standardized template for future ADRs with sections for:
- Status (Proposed/Accepted/Deprecated/Superseded)
- Context and background
- Problem statement
- Options considered (pros/cons for each)
- Decision and rationale
- Consequences (positive/negative/risks)
- Implementation details
- Related decisions
- Revision history

#### ADR-0001: R Version Detection and Mismatch Handling (`0001-r-version-detection-and-mismatch-handling.md`)

**Status**: Accepted

**Decision**: Detect R version mismatches and prompt users with clear options rather than silently failing or strictly enforcing.

**Options Considered**:
1. **Silent Fallback**: Use system R with warning
   - Pros: Minimal friction
   - Cons: Violates reproducibility, silent failures are dangerous

2. **Strict Enforcement**: Fail immediately, require explicit version specification
   - Pros: Enforces reproducibility
   - Cons: High friction for development workflow

3. **Detect and Prompt** (Chosen)
   - Detect mismatch
   - Display clear error with implications
   - Provide both resolution paths
   - Support `.zzcollab-rc` config file
   - Educate users about version importance

**Rationale**: Reproducibility is fundamental; users need to understand why versions matter.

**Implementation Path**:
- Phase 1 (Complete): Core detection and error messaging
- Phase 2: `.zzcollab-rc` configuration file support
- Phase 3: Documentation and education

### 3. GitHub Issue Templates

**Directory**: `.github/ISSUE_TEMPLATE/`

Created four structured templates:

#### Bug Report (`bug_report.md`)
Use when: Something is broken and needs fixing
Includes:
- System information
- Steps to reproduce
- Expected vs actual behavior
- Error messages
- Workarounds

#### Feature Request (`feature_request.md`)
Use when: Suggesting new functionality or improvements
Includes:
- Summary and problem solved
- Proposed solution
- Use cases
- Impact assessment
- Complexity estimation

#### Investigation (`investigation.md`)
Use when: Documenting a problem discovered during development with the solution process
Includes:
- What was discovered
- How to reproduce
- Root cause analysis
- Multiple solution options with pros/cons
- Recommended approach
- Related documentation needs
- Follow-up items

#### Pull Request Template (`.github/PULL_REQUEST_TEMPLATE.md`)
Standardized structure for PRs:
- Summary and related issues
- Type of change
- Testing completed
- Documentation updates
- Architecture/design notes

#### Config File (`config.yml`)
- Disables blank issues (forces template selection)
- Provides contact links for help

### 4. Documentation Strategy Guide

**File**: `docs/DOCUMENTATION_STRATEGY.md`

Created a comprehensive guide explaining:
- When to use each of the three systems
- Structure and writing guidelines for each format
- Workflow examples for common scenarios
- Best practices and maintenance tips
- File structure and quick reference table

---

## How the Systems Work Together

### Lessons Learned
- **Purpose**: Capture tactical problem/solution discoveries
- **Timing**: Same day as finding solution
- **Format**: Narrative + code examples + generalizable lessons
- **Audience**: All developers on zzcollab projects

### ADRs
- **Purpose**: Record strategic architectural decisions
- **Timing**: Before or during implementation
- **Format**: Formal structure with options analysis
- **Audience**: Maintainers and future developers making similar decisions

### GitHub Issues
- **Purpose**: Track work, discuss problems, manage projects
- **Timing**: Immediately when issue discovered
- **Format**: Structured templates
- **Audience**: Team members and external contributors

### Linking Everything
- **Lessons Learned** → References related ADRs
- **ADRs** → Link to GitHub issues and related PRs
- **GitHub Issues** → Reference lessons learned that solved them

---

## Concrete Example: The R Version Problem

Here's how the three systems worked together for the R version mismatch:

### 1. GitHub Issue (Investigation Type)
Created to track discovery and discuss resolution

### 2. Lessons Learned Document
Section 11 added with:
- The exact error message
- Two solution options
- When to use each approach
- Best practices for multi-project environments
- CI/CD implications

### 3. ADR-0001
Formal record of the decision to detect and prompt rather than fail silently

### 4. Linking
- ADR-0001 references the Lessons Learned section
- GitHub issue links to ADR for context
- Future issues can reference both

---

## Files Created

### Documentation Files
```
docs/
├── TESTING_LESSONS_LEARNED.md      (Updated: Added Section 11)
├── DOCUMENTATION_STRATEGY.md       (New)
└── adr/
    ├── 0000-TEMPLATE.md            (New)
    └── 0001-r-version-detection-and-mismatch-handling.md (New)
```

### GitHub Templates
```
.github/
├── ISSUE_TEMPLATE/
│   ├── bug_report.md               (New)
│   ├── feature_request.md          (New)
│   ├── investigation.md            (New)
│   └── config.yml                  (New)
└── PULL_REQUEST_TEMPLATE.md        (New)
```

---

## Quick Reference

| System | Purpose | When to Use | Format | Location |
|--------|---------|------------|--------|----------|
| **Lessons Learned** | Capture tactical discoveries | Same day as solution found | Narrative + code | `docs/TESTING_LESSONS_LEARNED.md` |
| **ADR** | Record strategic decisions | Before/during implementation | Formal structure | `docs/adr/` |
| **GitHub Issue** | Track work & discuss | Immediately on discovery | Structured form | GitHub Issues |
| **PR Template** | Standardize contributions | On every PR | Structured form | `.github/` |

---

## Using This System

### Adding a Lesson to Lessons Learned
```bash
# 1. Edit docs/TESTING_LESSONS_LEARNED.md
# 2. Add new numbered section
# 3. Include: The Problem, The Solution, Generalizable Lessons, zzcollab Pattern
# 4. Commit
git add docs/TESTING_LESSONS_LEARNED.md
git commit -m "docs: Add lesson on [topic]"
```

### Creating a New ADR
```bash
# 1. Copy template
cp docs/adr/0000-TEMPLATE.md docs/adr/000N-my-decision.md

# 2. Fill in complete analysis of options and decision

# 3. Include in PR or commit separately
git add docs/adr/000N-my-decision.md
git commit -m "docs: ADR for [decision]"
```

### Creating a GitHub Issue
```
1. Go to GitHub Issues → New Issue
2. Select appropriate template (Bug, Feature, or Investigation)
3. Fill in details
4. Submit
5. Later: Reference Lessons Learned / ADRs as they're created
```

---

## Best Practices

### 1. Document Immediately
- Add to Lessons Learned same day you find the solution
- Don't wait for "perfect" documentation
- Rough is better than lost knowledge

### 2. Link Everything
- Lessons Learned → Reference related ADRs
- ADRs → Link to GitHub issues
- Issues → Link to Lessons Learned sections

### 3. Keep Lessons Focused
- Document specific problems discovered in *this* project
- Include the actual error message or failing code
- Show both the problem and solution

### 4. Make ADRs About Decisions
- "We decided to do X because of Y"
- Not explanations of how to use X
- Include tradeoff analysis

### 5. Use GitHub Issues for Discussion
- Problems tracked as issues
- Solutions documented in Lessons/ADRs
- Issues reference the documentation

### 6. Maintain Version Control
- Commit all documentation
- Keep histories for future reference
- Don't delete old lessons (mark superseded ADRs clearly)

---

## Key Insights from zzcollab's R Version Problem

1. **Version pinning is intentional, not accidental**
   - `renv.lock` exists for reproducibility
   - Different R versions produce different results
   - Don't casually upgrade without understanding requirements

2. **Clear error messages are critical**
   - Show what went wrong AND why it matters
   - Provide specific actionable solutions
   - Educate users about the underlying principles

3. **Support multiple workflows**
   - Reproducibility-focused: Use pinned versions
   - Development-focused: Update versions when needed
   - Configuration files reduce friction for repeated use

4. **Document the decision**
   - Why did we choose this approach?
   - What alternatives did we consider?
   - What are the consequences?

---

## References

- [Lessons Learned Document](./TESTING_LESSONS_LEARNED.md) - Section 11
- [ADR Template](./adr/0000-TEMPLATE.md)
- [Example ADR](./adr/0001-r-version-detection-and-mismatch-handling.md)
- [Documentation Strategy Guide](./DOCUMENTATION_STRATEGY.md)
- [GitHub Issue Templates](../.github/ISSUE_TEMPLATE/)

---

## Conclusion

By implementing this three-tier documentation system, zzcollab now has:

1. **Accessible documentation** of discovered problems and solutions in Lessons Learned
2. **Formal records** of major decisions in ADRs for future reference
3. **Structured tracking** of work and issues via GitHub templates
4. **Clear guidance** on when and how to use each system

This approach captures knowledge during early-stage development while remaining flexible enough for both research and engineering workflows.

The R version problem became not just a solution, but a teaching moment—documented for all future zzcollab users and developers.
