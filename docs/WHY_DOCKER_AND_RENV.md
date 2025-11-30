# Why Docker AND renv? A Technical Guide to Computational Reproducibility

**Author**: ZZCOLLAB Project
**Date**: October 2025
**Version**: 1.0

---

## Executive Summary

Reproducible research requires controlling **all** sources of computational variation, not just R package versions. This white paper explains why Docker containers and renv dependency management are **both necessary** for complete reproducibility in R-based data analysis, and demonstrates real-world failure scenarios that occur when either component is missing.

**Key Finding**: Neither Docker nor renv alone provides sufficient reproducibility guarantees. Only the combination of both technologies, along with version-controlled `.Rprofile` settings, source code, and data, ensures identical computational results across different machines and time periods.

---

## Table of Contents

1. [The Reproducibility Problem](#the-reproducibility-problem)
2. [The Five Pillars of Reproducibility](#the-five-pillars-of-reproducibility)
3. [Real-World Failure Scenarios](#real-world-failure-scenarios)
4. [Why Each Technology Is Insufficient Alone](#why-each-technology-is-insufficient-alone)
5. [The Complete Solution](#the-complete-solution)
6. [Practical Implementation](#practical-implementation)
7. [Conclusion](#conclusion)

---

## The Reproducibility Problem

A computational analysis is **reproducible** if and only if:

> **Any researcher can execute the identical computational workflow and obtain identical numerical results, regardless of their computing environment or when they run the analysis.**

This seemingly simple requirement is surprisingly difficult to achieve in practice. Computational environments vary across multiple dimensions:

- **R version** (4.3.0 vs 4.4.0)
- **R package versions** (dplyr 1.1.4 vs 1.1.5)
- **System libraries** (OpenBLAS vs Intel MKL, libpng 1.6.37 vs 1.6.39)
- **Operating system** (Ubuntu 22.04 vs macOS 14)
- **Locale settings** (en_US.UTF-8 vs sv_SE.UTF-8)
- **Timezone** (UTC vs America/New_York)
- **R session options** (stringsAsFactors, contrasts, digits)
- **Random number generator** (implementation changes across R versions)

Each of these factors can silently alter computational results, leading to the infamous "works on my machine" problem.

---

## The Five Pillars of Reproducibility

ZZCOLLAB implements a five-pillar model for complete computational reproducibility. These components are **necessary and sufficient** for independent reproduction:

### 1. Dockerfile - Computational Environment Foundation

**Controls**:
- R version (e.g., 4.4.0)
- System libraries (BLAS/LAPACK, libcurl, libxml2, libpng, OpenSSL)
- Operating system (Ubuntu 24.04)
- Environment variables (LANG, LC_ALL, TZ, OMP_NUM_THREADS)

**Why It Matters**: System-level components affect numerical computation, data parsing, text handling, and parallel execution determinism.

### 2. renv.lock - Exact R Package Versions

**Controls**:
- Every R package with exact version
- Complete dependency tree
- Package sources (CRAN, Bioconductor, GitHub)

**Why It Matters**: R packages update frequently on CRAN. Code that works today may break tomorrow with new package versions. renv.lock freezes the entire package ecosystem.

### 3. .Rprofile - R Session Configuration

**Controls**:
- Critical R options:
  - `stringsAsFactors` - affects data frame creation
  - `contrasts` - affects statistical model encoding
  - `na.action` - affects missing data handling
  - `digits` - affects numerical display and rounding
  - `OutDec` - affects decimal separator in output

**Why It Matters**: `.Rprofile` is automatically loaded before your code runs. Different implicit settings lead to different results with **identical code**.

### 4. Source Code - Computational Logic

**Controls**:
- Analysis scripts
- Reusable functions
- Explicit random seeds (`set.seed()`)
- Data processing pipelines

**Why It Matters**: The actual computational workflow must be captured precisely.

### 5. Research Data - Empirical Foundation

**Controls**:
- Raw data (original, unmodified, read-only)
- Derived data (processed, analysis-ready)
- Data documentation (provenance, processing lineage)

**Why It Matters**: Algorithms without data cannot be reproduced.

---

## Real-World Failure Scenarios

### Scenario 1: System Library Mismatch (BLAS/LAPACK)

**Problem**: Different linear algebra libraries produce slightly different numerical results due to precision differences.

```r
# Your machine (OpenBLAS 0.3.20):
set.seed(123)
pca <- prcomp(dataset, scale = TRUE)
pca$rotation[1:5, 1:3]
#          PC1    PC2    PC3
# [1,]  0.432  0.123 -0.234
# [2,]  0.234 -0.432  0.123

# Collaborator's machine (Intel MKL):
set.seed(123)  # Same seed!
pca <- prcomp(dataset, scale = TRUE)
pca$rotation[1:5, 1:3]
#          PC1    PC2    PC3
# [1,]  0.433  0.122 -0.235  # Slightly different!
# [2,]  0.235 -0.431  0.124  # Numerical precision differences
```

**Impact**: Principal component analysis, regression coefficients, clustering results, and machine learning models all affected.

**Solution**: Docker fixes BLAS library version.

---

### Scenario 2: R Version Breaking Change (read.csv behavior)

**Problem**: R 4.0.0 (released April 2020) fundamentally changed how `read.csv()` handles text data, breaking code that relied on automatic factor conversion.

```r
# Sample CSV file:
# name,category,value
# Alice,treatment,10
# Bob,control,8
# Charlie,treatment,12

# ============================================
# R 3.6.3 (default: stringsAsFactors = TRUE)
# ============================================
data <- read.csv("study.csv")
class(data$category)  # "factor"
levels(data$category) # "control" "treatment"

# Statistical model works:
model <- lm(value ~ category, data = data)
summary(model)
# Coefficients:
#             Estimate Std. Error t value Pr(>|t|)
# (Intercept)    8.000      ...     ...      ...
# categorytreatment  3.000  ...     ...      ...

# ============================================
# R 4.0.0+ (default: stringsAsFactors = FALSE)
# ============================================
data <- read.csv("study.csv")  # Same code!
class(data$category)  # "character"  # DIFFERENT!

# Statistical model breaks:
model <- lm(value ~ category, data = data)
# Error in model.frame.default(...):
#   variable lengths differ (found for 'category')
```

**Impact**:
- Code written for R < 4.0 **breaks** on R >= 4.0
- Silent changes in statistical models if not caught
- Thousands of scripts affected when R 4.0 was released

**Real-World Consequence**:
```r
# Researcher's original analysis (R 3.6.3, 2019):
data <- read.csv("patients.csv")
model <- lm(recovery_time ~ treatment_group, data)
# Works: treatment_group automatically converted to factor

# Colleague tries to reproduce (R 4.2.0, 2023):
data <- read.csv("patients.csv")  # Exact same code
model <- lm(recovery_time ~ treatment_group, data)
# Error: treatment_group is character, not factor
# Analysis fails completely
```

**Solution**: Docker fixes R version at 3.6.3 OR 4.0.0+, ensuring consistent behavior.

**Better Solution**: Explicit code that works in both versions:
```r
# Reproducible across R versions:
data <- read.csv("study.csv", stringsAsFactors = TRUE)  # Explicit!
# OR
data <- read.csv("study.csv")
data$category <- factor(data$category)  # Explicit conversion
```

This is a perfect example of why R version matters - a major breaking change that affected millions of scripts worldwide.

---

### Scenario 3: Random Number Generator Changes

**Problem**: R changed the default random number generator in version 3.6.0, and again in 4.4.0, breaking reproducibility of stochastic analyses.

```r
# R 4.3.0:
set.seed(123)
sample(1:10)  # [3, 7, 1, 9, 5, 2, 8, 4, 6, 10]

# R 4.4.0 (changed RNG):
set.seed(123)  # Same seed!
sample(1:10)  # [5, 2, 8, 4, 1, 9, 3, 7, 6, 10]  # Different!
```

**Impact**: Bootstrapping, cross-validation, permutation tests, simulation studies all produce different results.

**Solution**: Docker fixes R version.

**Workaround for multi-version compatibility**:
```r
# Force old RNG algorithm explicitly
RNGversion("3.5.0")  # Use pre-3.6.0 RNG
set.seed(123)
sample(1:10)  # Same results across R versions
```

---

### Scenario 4: Locale Differences (Text Sorting)

**Problem**: Different locale settings cause different sort orders for non-ASCII characters.

```r
# Your machine (en_US.UTF-8):
sort(c("ä", "z", "a"))  # [1] "a" "ä" "z"

# Collaborator's machine (sv_SE.UTF-8 - Swedish locale):
sort(c("ä", "z", "a"))  # [1] "a" "z" "ä"  # Different sort order!
```

**Impact**: Factor level ordering, data merges, and any operation dependent on text sorting produces different results.

**Solution**: Docker fixes locale via `ENV LANG=en_US.UTF-8`.

---

### Scenario 5: Package Version Drift

**Problem**: Installing packages at different times produces different versions with potentially breaking changes.

```r
# Your analysis (2024-01-01):
install.packages("dplyr")  # Gets dplyr 1.1.4
filter(data, x > 5)        # Works as expected

# Collaborator runs code (2024-06-01):
install.packages("dplyr")  # Gets dplyr 1.1.5
filter(data, x > 5)        # Behavior changed in new version!
```

**Impact**: Code that worked previously breaks, or produces different results silently.

**Solution**: renv.lock fixes exact package versions.

---

### Scenario 6: .Rprofile Option Differences

**A Hidden Issue**: `.Rprofile` settings are invisible in code but significantly affect behavior.

#### Example 6a: stringsAsFactors in data.frame()

```r
# Your machine (.Rprofile):
options(stringsAsFactors = FALSE)

df <- data.frame(x = c("a", "b", "c"), y = 1:3)
class(df$x)  # "character"
lm(y ~ x, data = df)  # Error: variable lengths differ

# Collaborator's machine (R < 4.0 default):
# options(stringsAsFactors = TRUE)

df <- data.frame(x = c("a", "b", "c"), y = 1:3)
class(df$x)  # "factor"
lm(y ~ x, data = df)  # Works! Creates dummy variables
```

**Impact**: Same code creates fundamentally different statistical models.

#### Example 6b: Contrasts (Factor Encoding)

```r
# Your .Rprofile:
options(contrasts = c("contr.treatment", "contr.poly"))

# Collaborator's .Rprofile:
options(contrasts = c("contr.sum", "contr.poly"))

# Same model formula, completely different coefficient interpretations!
lm(outcome ~ group)  # Treatment coding vs sum coding
```

**Impact**: Regression coefficients have different meanings across machines.

#### Example 6c: Decimal Separator

```r
# Your .Rprofile (US):
options(OutDec = ".")
write.csv(data, "results.csv")  # Output: 3.14

# Collaborator's .Rprofile (Europe):
options(OutDec = ",")
write.csv(data, "results.csv")  # Output: 3,14

# Excel imports European format as text instead of number!
```

**Impact**: Data export/import breaks, downstream analyses fail.

**Solution**: Version-controlled `.Rprofile` copied into Docker image.

---

### Scenario 7: Matrix Operations (NCOL Changes)

**Problem**: R 4.3.0 changed the behavior of `NCOL(NULL)` for consistency with `cbind()`.

```r
# R 4.2.x and earlier:
NCOL(NULL)  # Returns 1

# R 4.3.0+:
NCOL(NULL)  # Returns 0 (for consistency with cbind())
```

**Real-World Impact**:
```r
# Code that worked in R 4.2.x:
process_data <- function(x) {
  if (NCOL(x) > 0) {
    # Process columns
    apply(x, 2, mean)
  } else {
    return(NULL)
  }
}

# R 4.2.x:
process_data(NULL)  # NCOL(NULL) = 1, condition TRUE, crashes

# R 4.3.0+:
process_data(NULL)  # NCOL(NULL) = 0, condition FALSE, returns NULL
```

**Impact**: Code behavior changes silently, affecting data processing pipelines.

**Solution**: Docker fixes R version.

---

### Scenario 8: Eigenvalue/SVD Sign Changes (LAPACK Updates)

**Problem**: R 4.4.0 updated LAPACK sources, causing sign differences in singular value decompositions and eigendecompositions.

```r
# R 4.3.x:
eigen(matrix(c(1,2,2,1), 2, 2))$vectors
#      [,1]       [,2]
# [1,]  0.7071068  0.7071068
# [2,]  0.7071068 -0.7071068

# R 4.4.0 (updated LAPACK):
eigen(matrix(c(1,2,2,1), 2, 2))$vectors
#      [,1]       [,2]
# [1,] -0.7071068  0.7071068  # Sign flipped!
# [2,] -0.7071068 -0.7071068
```

**Why This Matters**:
- Eigenvalues are mathematically equivalent (eigenvectors are only unique up to sign)
- But downstream analyses comparing specific eigenvector values will differ
- PCA loadings, factor analysis, clustering all affected

**Real-World Impact**:
```r
# Principal component analysis
pca <- prcomp(data, scale = TRUE)

# Extract first PC for further analysis
pc1 <- pca$rotation[, 1]

# R 4.3.x vs 4.4.0: pc1 values have opposite signs!
# Correlations with pc1 flip sign
# Downstream interpretations change
```

**Impact**: Numerically equivalent but **different signs** break exact reproducibility.

**Solution**: Docker fixes R version and LAPACK library version.

---

### Scenario 9: Native Pipe Operator (Backward Incompatibility)

**Problem**: R 4.1.0 introduced the native pipe `|>`, creating code that won't run on older R versions.

```r
# Code written in R 4.1.0+:
result <- mtcars |>
  subset(cyl == 4) |>
  transform(kpl = mpg * 0.425) |>
  head()

# R 4.0.x and earlier:
# Error: unexpected '>' in "mtcars |>"
# Code completely fails to run
```

**Impact**:
- Forward compatibility broken (newer code doesn't run on older R)
- Teams with mixed R versions can't share code
- Older scripts remain compatible, but new scripts aren't

**Solution**: Docker ensures all team members use same R version.

**Workaround**: Use magrittr pipe `%>%` for backward compatibility:
```r
library(magrittr)
result <- mtcars %>%
  subset(cyl == 4) %>%
  head()
# Works in both old and new R versions
```

---

### Summary: R Version Breaking Changes

| R Version | Breaking Change | Reproducibility Impact |
|-----------|----------------|------------------------|
| 3.6.0 | RNG change (`sample.kind`) | Different random sequences |
| 4.0.0 | `stringsAsFactors = FALSE` default | Statistical models break/change |
| 4.1.0 | Native pipe `|>` added | Code won't run on older versions |
| 4.2.0 | Graphics engine updates | Plot rendering differences |
| 4.3.0 | `NCOL(NULL)` returns 0 | Matrix operations change behavior |
| 4.4.0 | LAPACK updates | Eigenvalue/SVD sign changes |

**Key Insight**: Even "minor" version updates (4.3 → 4.4) can break reproducibility. Docker freezes the R version, preventing **all** of these issues.

---

## Why Each Technology Is Insufficient Alone

### renv Alone (❌ Insufficient)

```r
renv.lock specifies: ggplot2 3.4.0
```

**What It Provides**:
- ✅ Fixes R package versions
- ✅ Captures dependency tree
- ✅ Works across different R installations

**What It Misses**:
- ❌ R version itself (4.3.0 vs 4.4.0 behave differently)
- ❌ System libraries (BLAS, libcurl, libxml2, libpng)
- ❌ Locale and timezone settings
- ❌ Operating system differences
- ❌ `.Rprofile` session options

**Failure Mode**: Code runs successfully but produces different numerical results due to system-level variation.

---

### Docker Alone (❌ Insufficient)

```dockerfile
FROM rocker/r-ver:4.4.0
```

**What It Provides**:
- ✅ Fixes R version
- ✅ Fixes system libraries
- ✅ Fixes operating system
- ✅ Fixes locale/timezone
- ✅ Provides consistent `.Rprofile`

**What It Misses**:
- ❌ R package versions (users can install different versions)
- ❌ Package drift over time (CRAN updates constantly)

**Failure Mode**: Different users install different package versions, leading to code breakage or behavioral differences.

---

### Docker + renv (✅ Complete)

```dockerfile
FROM rocker/r-ver:4.4.0          # R version, system libs, OS
ENV LANG=en_US.UTF-8             # Locale
COPY renv.lock ./                # Exact R package versions
RUN renv::restore()              # Install exact versions
COPY .Rprofile ./                # R session options
```

**What It Provides**:
- ✅ Complete computational environment specification
- ✅ Protection against all sources of variation
- ✅ Reproducibility across machines and time
- ✅ One-command execution (`docker run`)

---

## The Complete Solution

### Concrete Example: Journal Submission

**Without Docker + renv**:

```bash
# Your analysis (2024-01-15):
R 4.3.2 + dplyr 1.1.4 + OpenBLAS + stringsAsFactors=FALSE
→ Result: β = 0.42, p = 0.03 (significant)

# Reviewer runs your code (2025-01-15, 1 year later):
R 4.5.0 + dplyr 1.2.0 + Intel MKL + stringsAsFactors=TRUE (default)
→ Result: β = 0.39, p = 0.06 (NOT significant!)
→ Rejection: "Results cannot be reproduced"
```

**With Docker + renv**:

```bash
# Your analysis (2024-01-15):
docker run myrepo/analysis:v1.0
→ Result: β = 0.42, p = 0.03

# Reviewer runs (2025-01-15):
docker run myrepo/analysis:v1.0
→ Result: β = 0.42, p = 0.03  # IDENTICAL
→ Acceptance: "Results successfully reproduced"
```

---

## Practical Implementation

### Team Workflow with ZZCOLLAB

**Initial Setup (Team Lead)**:

```bash
# Create project with specific profile
zzcollab -t mylab -p study -r analysis

# Build and share
make docker-build    # 3-4 minutes with RSPM binaries
git add . && git commit -m "Initial project setup"
git push
```

**Team Member Joins**:

```bash
# Clone and build
git clone https://github.com/mylab/study.git
cd study
make docker-build    # 3-4 minutes (fast RSPM binaries!)
make docker-run      # Start working immediately
```

**Daily Development**:

```bash
make docker-run
# Inside container:
devtools::load_all()                    # Load R package
source("analysis/scripts/01_clean.R")   # Run analysis
renv::install("ggplot2")                # Add new package
exit                                     # Auto-snapshot on exit!
```

**Key Insight**: With RSPM binary packages, builds take only 3-4 minutes. Team members can build from the Dockerfile in the git repo instead of pulling from Docker Hub, ensuring perfect reproducibility with minimal friction.

---

## Comparison with Alternatives

### Alternative 1: Manual Instructions (❌)

```markdown
"Please install R 4.4.0, ensure you have OpenBLAS 0.3.20,
set locale to en_US.UTF-8, install these 50 packages at
these exact versions..."
```

**Problems**:
- Nobody follows instructions perfectly
- Takes hours to set up
- "Works on my machine" syndrome
- Not reproducible in practice

---

### Alternative 2: Conda/Mamba (⚠️ Limited)

```yaml
environment.yml:
  - r-base=4.4.0
  - r-dplyr=1.1.4
```

**Problems**:
- R package versions lag behind CRAN (often months outdated)
- Limited package availability (not all CRAN packages available)
- Mixing conda-forge + CRAN causes dependency conflicts
- Slower than RSPM binaries

**When to Use**: Python-centric workflows with some R components.

---

### Alternative 3: Docker + renv (✅ Best Practice)

**Advantages**:
- ✅ One command: `docker run`
- ✅ Identical environment everywhere
- ✅ All CRAN packages available via renv
- ✅ Fast builds (RSPM binaries, 3-4 minutes)
- ✅ Industry standard
- ✅ Journal-accepted approach

---

## Conclusion

Complete computational reproducibility in R requires controlling **all** sources of variation:

1. **R version and system libraries** → Docker
2. **R package versions** → renv.lock
3. **R session options** → .Rprofile (version controlled)
4. **Computational logic** → Source code
5. **Empirical inputs** → Data

Missing any single component breaks reproducibility. Neither Docker nor renv alone provides sufficient guarantees.

The combination of Docker + renv + version-controlled `.Rprofile` represents current best practices, as increasingly required by journals like *Nature*, *Science*, and *PLOS* for computational papers.

### Recommendation

**For reproducible research in R**:
- Use Docker for environmental consistency
- Use renv for package version control
- Version control your `.Rprofile`
- Document everything
- Make it one-command easy for collaborators

**ZZCOLLAB implements this complete solution**, providing fast builds (3-4 minutes with RSPM binaries), automated workflows, and comprehensive reproducibility guarantees.

---

## References

1. Marwick, B., Boettiger, C., & Mullen, L. (2018). Packaging Data Analytical Work Reproducibly Using R (and Friends). *The American Statistician*, 72(1), 80-88.

2. Nüst, D., et al. (2020). Ten simple rules for writing Dockerfiles for reproducible data science. *PLOS Computational Biology*, 16(11), e1008316.

3. Gentleman, R., & Temple Lang, D. (2007). Statistical Analyses and Reproducible Research. *Journal of Computational and Graphical Statistics*, 16(1), 1-23.

4. Peng, R. D. (2011). Reproducible Research in Computational Science. *Science*, 334(6060), 1226-1227.

5. Wickham, H. (2020). renv: Project Environments for R. R package version 0.12.0.

6. R Core Team. (2020). R 4.0.0 Release Notes. *The R Blog*. https://blog.r-project.org/2020/02/16/stringsasfactors/

---

**Document Information**:
- **Repository**: https://github.com/rgt47/zzcollab
- **Documentation**: See `docs/` directory for implementation guides
- **License**: MIT
- **Maintainer**: ZZCOLLAB Project Team
