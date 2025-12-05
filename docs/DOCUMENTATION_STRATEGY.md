# zzcollab Documentation Strategy

## Overview

This document explains zzcollab's three-tier approach to documenting problems and solutions discovered during development:

1. **Lessons Learned** (`docs/TESTING_LESSONS_LEARNED.md`) - Narrative documentation of issues and solutions
2. **Architecture Decision Records (ADRs)** (`docs/adr/`) - Formal records of significant decisions
3. **GitHub Issues** - Project tracking and discussion of specific problems

Each serves a different purpose. This guide explains when and how to use each.

---

## The Three-Tier System

### Tier 1: Lessons Learned (Quick Documentation)

**What**: Narrative documentation of problems discovered during development, testing, or early use with their solutions and generalizable insights.

**Where**: `docs/TESTING_LESSONS_LEARNED.md`

**When to Use**:
- You discover a problem during development or testing
- You find a solution that works
- The solution is generalizable to other projects/developers
- The insight is tactical (how to solve a specific problem)

**Structure**:
```markdown
## N. [Problem Title]

### The Problem
- Context: When/where did this happen?
- What happened: Specific example
- Why it matters: Impact

### The Solution
- What to do: Step-by-step or code example
- How it works: Explanation

### Generalizable Lessons
1. [Lesson 1]: Explanation
2. [Lesson 2]: Explanation
3. [Etc.]

### zzcollab Pattern
- Reusable code pattern or template
```

**Example**: Section 11 - R Version Mismatches in Multi-Environment Development

**Duration**: As soon as you've tested a solution (same day or next day)

---

### Tier 2: Architecture Decision Records (ADRs)

**What**: Formal records of significant architectural or design decisions, including context, options considered, chosen approach, and consequences.

**Where**: `docs/adr/` directory with numbered files (0001-name.md, 0002-name.md, etc.)

**When to Use**:
- The decision affects the system architecture or multiple components
- Multiple viable options exist with different tradeoffs
- The decision will have long-term implications
- Future developers need to understand *why* something was designed this way
- The decision is strategic (not tactical)

**When NOT to Use**:
- It's a straightforward bugfix with only one obvious solution
- It's a minor implementation detail
- It's already documented in code comments

**Structure** (see `docs/adr/0000-TEMPLATE.md`):
- Status (Proposed/Accepted/Deprecated/Superseded)
- Context and background
- Problem statement
- Options considered (pros/cons for each)
- Decision and rationale
- Consequences (positive/negative/risks)
- Implementation details
- Related decisions
- Revision history

**Example**: ADR-0001 - R Version Detection and Mismatch Handling

**Duration**: Should be completed before or during implementation of the decision (1-3 days)

---

### Tier 3: GitHub Issues

**What**: Lightweight project tracking and discussion of specific problems, features, or investigations.

**Where**: GitHub Issues (`.github/ISSUE_TEMPLATE/`)

**When to Use**:
- You discover a bug that needs fixing
- You want to request a feature
- You want to track work across multiple PRs
- You want to discuss a problem with team/collaborators
- You've discovered something during development that needs investigation

**Issue Types**:

#### Bug Report (`bug_report.md`)
Use when: You've found something broken that should be fixed

Includes:
- System information
- Steps to reproduce
- Expected vs actual behavior
- Error messages
- Workarounds (if any)

#### Feature Request (`feature_request.md`)
Use when: You want to suggest a new feature or improvement

Includes:
- Summary of the feature
- Problem it solves
- Proposed solution
- Use cases
- Impact assessment

#### Investigation (`investigation.md`)
Use when: You've discovered a problem during development and want to document the solution process

Includes:
- What was discovered
- How to reproduce it
- Root cause analysis
- Solution options (with pros/cons)
- Related documentation needs
- Follow-up items

**Duration**: Create immediately when issue is discovered; update as it progresses

---

## When to Use Which System

### Scenario 1: Found a bug in the test suite

**What happened**: Tests fail with a cryptic error about "object not found"

**Action**:
1. **Create GitHub Issue** (type: Investigation) to track the problem
2. **Document the solution** in Lessons Learned once you've found it
3. **Create/Update ADR** only if it involves a major architectural change to how tests are structured

### Scenario 2: Need to decide between different approaches for a new feature

**What happened**: You're implementing a new feature but there are 3 different valid architectural approaches

**Action**:
1. **Create ADR** to document the decision process (before implementation)
2. **Create GitHub Issue** (type: Feature Request) to discuss and track the work
3. **Document in Lessons Learned** only if the implementation reveals unexpected challenges

### Scenario 3: Upgrade R version causes all projects to fail

**What happened**: You upgraded local R and now several projects don't initialize

**Action**:
1. **Create GitHub Issue** (type: Investigation) immediately to track the problem
2. **Document the solution** in Lessons Learned (quick win, generalizable)
3. **Create ADR** if this leads to architectural changes in how zzcollab handles versions
4. **Create/Update feature request** if it reveals a needed feature

### Scenario 4: Discover that a test pattern works well

**What happened**: You find a way to test bootstrap resampling that avoids environment scoping issues

**Action**:
1. **Document in Lessons Learned** immediately (this is learning!)
2. **Create GitHub Issue** (type: Investigation) only if it should be tracked separately
3. Create or update ADR only if it affects system-wide testing architecture

---

## Writing Effective Documentation

### Lessons Learned

**Be specific and practical**:
- ❌ "Environment issues are hard"
- ✅ "When using bootstrap resampling, formulas defined in local scope fail with 'object not found'"

**Show the actual problem**:
```r
# Include the error message or failing code
Error in eval(mf, parent.frame()): object 'med_fmla' not found
```

**Give multiple perspectives**:
- The problem (why it failed)
- The solution (how to fix it)
- Why this solution works
- How to generalize it

**Provide a reusable pattern**:
```r
# zzcollab Pattern:
# [Code template others can copy]
```

### ADRs

**Make decisions explicit**:
- Don't just say what you chose
- Say why you chose it and what you rejected
- Document the tradeoffs

**Write for the future**:
- "Why did we decide this?" should be answerable 6 months from now
- Include context that might not be obvious in the code

**Track changes**:
- Keep revision history
- Mark superseded ADRs clearly

### GitHub Issues

**Be descriptive but concise**:
- Title should be specific: "R version mismatch prevents project initialization" not "R version issue"
- Description should have enough context that someone returning to it 2 weeks later understands what's needed

**Link related items**:
- Link to ADRs that inform the issue
- Link to relevant Lessons Learned sections
- Link to related issues

**Use labels effectively**:
- `kind/bug`, `kind/feature`, `kind/investigation`
- `priority/high`, `priority/medium`, `priority/low`
- `component/cli`, `component/testing`, etc.

---

## Workflow Examples

### Adding a Lesson to Lessons Learned

```bash
# 1. Encounter a problem during development/testing
# 2. Find and test a solution
# 3. Edit docs/TESTING_LESSONS_LEARNED.md and add a new section

# 4. Add to git
git add docs/TESTING_LESSONS_LEARNED.md

# 5. Commit
git commit -m "docs: Add lesson on R version mismatches"

# 6. Create PR for review (optional, but recommended)
```

### Creating a New ADR

```bash
# 1. You're about to make a significant architectural decision
# 2. Copy the template
cp docs/adr/0000-TEMPLATE.md docs/adr/0001-my-decision.md

# 3. Fill in the ADR with proper analysis of options
# 4. Include in a PR or commit it separately

git add docs/adr/0001-my-decision.md
git commit -m "docs: ADR for my decision"
```

### Creating a GitHub Issue

```bash
# 1. Go to GitHub repo
# 2. Click "Issues" → "New issue"
# 3. Select appropriate template (Bug, Feature, or Investigation)
# 4. Fill in details
# 5. Submit

# Later, when you have a solution:
# - Add comment with solution found
# - Reference Lessons Learned doc if applicable
# - Close with reference to PR that fixes it
```

---

## Best Practices

### 1. **Document Immediately**
- Add to Lessons Learned same day you find the solution
- Don't wait for "perfect" documentation
- Rough is better than lost knowledge

### 2. **Link Everything**
- Lessons Learned → Reference related ADRs in "Related Documentation"
- ADRs → Link to GitHub issues
- GitHub Issues → Link to Lessons Learned sections

### 3. **Keep Lessons Learned Focused**
- It's NOT a general knowledge base
- Each section should be about something discovered in *this* project
- Include the specific error/problem that prompted the discovery

### 4. **Make ADRs Decisions, Not Explanations**
- ADR = "We decided to do X because of Y"
- Not = "Here's how to use X" (that's documentation, not a decision record)

### 5. **Use GitHub Issues for Discussion**
- Problems should be tracked as issues
- Solutions get documented in Lessons Learned / ADRs
- Issues can reference the documentation that solved them

### 6. **Review Before Merging**
- Have someone review ADRs before accepting them
- Have someone review Lessons Learned entries (quick review)
- GitHub Issues can be reviewed by commenting

---

## Maintenance

### Updating Lessons Learned
- Add new sections at the end
- Update date at top when you make significant additions
- Never delete old lessons (append a note if something is superseded)

### Updating ADRs
- Mark ADRs as "Superseded by ADR-XXXX" if a later decision replaces it
- Keep old ADRs for historical context
- Add to revision history when status changes

### Cleaning Up Issues
- Close issues when they're resolved
- Reference the Lessons Learned or ADR that captures the solution
- Archive old issues periodically

---

## File Structure

```
zzcollab/
├── docs/
│   ├── TESTING_LESSONS_LEARNED.md      ← Tactical problem/solution documentation
│   ├── DOCUMENTATION_STRATEGY.md        ← This file
│   ├── adr/                             ← Architectural Decision Records
│   │   ├── 0000-TEMPLATE.md             ← ADR template
│   │   ├── 0001-r-version-detection.md  ← Example ADR
│   │   └── ...                          ← Future ADRs
│   └── ... (other docs)
│
├── .github/
│   ├── ISSUE_TEMPLATE/                  ← GitHub issue templates
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   ├── investigation.md
│   │   └── config.yml
│   ├── PULL_REQUEST_TEMPLATE.md         ← PR template
│   └── workflows/
│
└── ... (code)
```

---

## Quick Reference

| Documentation Type | Purpose | Timing | Format | Location |
|---|---|---|---|---|
| **Lessons Learned** | Capture tactical problem/solution for reuse | Same day as discovery | Narrative + code | `docs/TESTING_LESSONS_LEARNED.md` |
| **ADR** | Record major architectural decisions | Before/during implementation | Formal structure | `docs/adr/` |
| **GitHub Issue** | Track work and discuss problems | Immediately | Structured form | GitHub Issues |

---

## See Also

- [Lessons Learned Document](./TESTING_LESSONS_LEARNED.md)
- [ADR Template](./adr/0000-TEMPLATE.md)
- [Example ADR](./adr/0001-r-version-detection-and-mismatch-handling.md)
