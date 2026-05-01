# Multi-Language Reproducibility in ZZCOLLAB

## The Problem: ZZCOLLAB's R-Centric Design

ZZCOLLAB's Five Pillars of Reproducibility are fundamentally **R-centric**:

1. **Dockerfile** - R version, system dependencies
2. **renv.lock** - R package versions only
3. **.Rprofile** - R session configuration
4. **Source Code** - Analysis scripts
5. **Research Data** - Empirical foundation

When documents include **non-R languages** (Python, Observable JS, Julia), ZZCOLLAB's reproducibility guarantees break down.

---

## Language-Specific Analysis

### Python in R Markdown/Quarto

**What happens:**
- Python chunks execute via `reticulate` package
- `reticulate` is tracked in renv.lock
- Python packages (pandas, numpy, scikit-learn) are **NOT tracked**

**The gap:**
```r
# renv.lock tracks this:
library(reticulate)

# But NOT this (Python side):
import pandas as pd  # Which version? 1.5.3? 2.0.0? 2.1.0?
import numpy as np   # Which version?
```

**Failure scenarios:**
1. Collaborator has different pandas version → different behavior
2. Six months later, `pip install pandas` gets newer version → results change
3. No `requirements.txt` or `environment.yml` auto-generated
4. No validation that Python environment matches

### Observable JS in Quarto

**What happens:**
- OJS chunks load libraries from CDN at runtime
- No version pinning by default
- Libraries float to latest version

**The gap:**
```javascript
// This loads whatever version is "latest" today:
Plot = require("@observablehq/plot")
d3 = require("d3")

// Six months from now, "latest" is different
// Your visualization may break or behave differently
```

**Failure scenarios:**
1. Plot API changes in new version → code breaks
2. D3 v7 vs v6 incompatibilities
3. No lockfile equivalent for JS dependencies
4. CDN availability/caching issues

### Mixed R + Python + OJS

**Compounding risks:**
- R packages: tracked (renv.lock)
- Python packages: untracked
- JS libraries: untracked, floating versions
- Cross-language data passing: additional failure points

---

## Risk Matrix

| Document Type | Reproducibility Risk | ZZCOLLAB Coverage |
|--------------|---------------------|-------------------|
| Pure R | Low | Complete |
| R + Python (reticulate) | Medium-High | Partial (R side only) |
| R + Observable JS | High | Partial (R side only) |
| R + Python + OJS | Very High | Minimal |

---

## Concrete Failure Scenario

**Today (working):**
```
renv.lock: reticulate 1.34.0
Python: pandas 2.0.3, numpy 1.24.0
OJS: Plot 0.6.11, d3 7.8.5
```

**Six months later (broken):**
```
renv.lock: reticulate 1.34.0 ✓ (still works)
Python: pandas 2.2.0 ✗ (API changed, deprecations)
OJS: Plot 0.7.0 ✗ (breaking changes)
```

The R side reproduces perfectly. The Python and JS sides silently produce different results or fail.

---

## Potential Solutions

### 1. Extend ZZCOLLAB (Architectural Change)

Add Python environment tracking:
```yaml
# Hypothetical zzcollab.yaml extension
languages:
  r:
    lockfile: renv.lock
  python:
    lockfile: requirements.txt  # or environment.yml
    version: 3.11.0
  javascript:
    lockfile: package-lock.json
```

**Pros:** Unified tracking
**Cons:** Major architectural change, scope creep

### 2. Docker-First for Non-R Languages

Pin everything in Dockerfile:
```dockerfile
# R environment (existing)
RUN R -e "renv::restore()"

# Python environment (add this)
COPY requirements.txt /tmp/
RUN pip install -r /tmp/requirements.txt

# Or use conda
COPY environment.yml /tmp/
RUN conda env create -f /tmp/environment.yml
```

**Pros:** Works now, complete control
**Cons:** Manual maintenance, two tracking systems

### 3. Separate Environments

Keep R-only documents for reproducible research:
- Use ZZCOLLAB for R analysis (reproducible)
- Use separate Python projects with their own tooling
- Avoid mixing languages in reproducibility-critical documents

**Pros:** Clear boundaries
**Cons:** Less convenient for polyglot workflows

### 4. Language-Agnostic Tools

Consider tools designed for multi-language reproducibility:
- **pixi** (from prefix.dev): Conda-based, multi-language
- **conda-lock**: Cross-platform lockfiles
- **nix**: Complete environment specification

**Pros:** Designed for this problem
**Cons:** Different tooling, learning curve

---

## Recommendations

### For Strict Reproducibility

1. **Avoid multi-language documents** for reproducibility-critical research
2. **If Python needed**, add explicit `requirements.txt` and document Python version in Dockerfile
3. **If OJS needed**, pin library versions explicitly:
   ```javascript
   Plot = require("@observablehq/plot@0.6.11")
   d3 = require("d3@7.8.5")
   ```
4. **Document the gap** - acknowledge in your methods that non-R dependencies are manually tracked

### For Educational/Demonstration Content

Multi-language documents are fine when:
- Exact reproducibility isn't critical
- You're demonstrating concepts, not research findings
- The document is for teaching/comparison purposes
- You accept that future readers may need to troubleshoot version issues

---

## The Bottom Line

ZZCOLLAB provides excellent R reproducibility. For multi-language documents:

| If You Need | Then |
|------------|------|
| Strict reproducibility | Stay R-only or manually track other languages |
| Quick demos/teaching | Multi-language is acceptable |
| Production research | Pin all versions explicitly, document gaps |
| Full multi-language reproducibility | Consider language-agnostic tools |

**Current ZZCOLLAB scope:** R reproducibility (complete), multi-language (user responsibility)
