# Why Reproducibility Matters: The Case for Docker and renv in Data Analysis

## The Reproducibility Crisis in Science

The scientific community faces a reproducibility crisis. A landmark
study found that only 39% of published psychology experiments could be
successfully replicated (Open Science Collaboration 2015). In cancer
biology, the situation is even more dire—researchers could reproduce
only 11% of landmark studies (Begley and Ellis 2012). While these crises
extend beyond computational reproducibility, the computational
components of modern research add unique challenges that are entirely
preventable with proper tooling.

As Peng (2011) argues, reproducibility represents a **minimum standard**
for judging scientific claims when full independent replication is
impractical. For computational research, this standard is achievable:
given the same data and code, any researcher should obtain identical
numerical results. Yet this seemingly simple requirement remains elusive
in practice.

> **Key terms in this vignette.** New to the vocabulary? These are the
> terms this guide uses; each is defined again on first use. Full
> definitions are in
> [`vignette('glossary')`](https://rgt47.github.io/zzcollab/articles/glossary.md).
>
> - **Computational reproducibility**: getting the same numerical
>   results from the same data and the same code.
> - **Reproducibility crisis**: the widespread finding that many
>   published results cannot be independently reproduced.
> - **Code rot / environmental drift**: the gradual breakage of working
>   code over time as its dependencies change underneath it.
> - **renv**: an R package giving each project its own isolated,
>   version-pinned package library.
> - **Docker / container / image / Dockerfile**: a tool that packages
>   software with its environment; a running instance, its template, and
>   the recipe that builds it.
> - **Five Pillars (of reproducibility)**: the five artifacts treated as
>   jointly sufficient: the `Dockerfile`, `renv.lock`, `.Rprofile`, the
>   source code, and the research data.
> - **Version pinning**: recording an exact dependency version so it
>   cannot drift between machines or over time.

### Why Computational Reproducibility Fails

The “works on my machine” problem plagues computational research.
Stodden et al. (2018) surveyed 204 Science articles and found that 56%
of authors who said they would share materials failed to do so when
asked. Even when materials are shared, reproduction often fails due to
undocumented dependencies, missing software versions, or implicit
environmental assumptions.

The root causes are systematic:

1.  **Dependency hell**: Modern analyses depend on dozens to hundreds of
    software packages, each with their own version histories and
    breaking changes (Wickham 2015)
2.  **Environmental variation**: System libraries, locales, and R
    versions all affect computational results in subtle ways (Gentleman
    and Temple Lang 2007)
3.  **Implicit configurations**: `.Rprofile` settings and other hidden
    configurations create invisible dependencies (Marwick et al. 2018)
4.  **Temporal drift**: Software ecosystems evolve continuously; code
    that works today may break tomorrow without any changes to the
    analysis itself

### The Cost of Non-Reproducibility

#### Personal Costs

Every researcher has experienced the frustration of returning to their
own analysis months later, unable to reproduce their previous results.
Wilson et al. (2014) surveyed scientists and found that 90% reported
spending significant time dealing with “code rot”—the decay of
computational methods over time. This represents real opportunity costs:
time spent debugging environment issues is time not spent doing science.

#### Collaborative Costs

Non-reproducible workflows create friction in collaborative research.
Ram (2013) documents how version conflicts and environment mismatches
slow team productivity. When each team member maintains a different
computational environment, integrating contributions becomes a manual,
error-prone process.

#### Scientific Costs

Most seriously, reproducibility failures undermine scientific validity.
Ioannidis (2005) argues that most published research findings are false,
with computational errors contributing to this problem. Nuijten et al.
(2016) found that 50% of psychology papers contain at least one
statistical reporting error, many traceable to computational issues.

## The Solution: Comprehensive Environmental Control

The solution requires controlling **all** sources of computational
variation. Neither documenting dependencies nor containerization alone
suffices—both are necessary for complete reproducibility.

### The Five Pillars of Computational Reproducibility

Building on the research compendium framework of Marwick et al. (2018),
we identify five necessary and sufficient components:

#### 1. Computational Environment (Dockerfile)

Docker containers provide bit-for-bit identical computational
environments (Boettiger 2015). A Dockerfile specifies:

- R version (e.g., 4.4.0)
- System libraries (BLAS/LAPACK, libcurl, libxml2)
- Operating system (Ubuntu 24.04)
- Environment variables (locale, timezone, thread count)

**Why it matters**: Buckheit and Donoho (1995) established that “an
article about computational science… is **not** the scholarship itself,
it is merely advertising of the scholarship. The actual scholarship is
the complete software development environment and the complete set of
instructions which generated the figures.”

#### 2. R Package Ecosystem (renv.lock)

The `renv` package (Ushey 2020) creates isolated, portable R
environments by recording exact package versions and their dependencies.
This addresses the package versioning problem documented by Trisovic et
al. (2022), who found that 74% of R scripts fail to run after just 2-3
years due to package updates.

#### 3. R Session Configuration (.Rprofile)

Session options like `stringsAsFactors`, `contrasts`, and `OutDec`
silently affect computational results (R Core Team 2020). These settings
are automatically loaded before code execution, creating invisible
dependencies that Gentleman and Temple Lang (2007) identifies as a major
source of irreproducibility.

#### 4. Analysis Code

The computational logic itself must be version controlled and
documented. Wilson et al. (2017) provides best practices for scientific
computing, emphasizing that code is a research product deserving the
same care as manuscripts.

#### 5. Research Data

White et al. (2013) establish principles for data archiving, emphasizing
that data without processing code provides incomplete reproducibility.
The research compendium model (Marwick et al. 2018) integrates data,
code, and documentation into a single reproducible unit.

## Real-World Failure Modes

Understanding how reproducibility fails in practice motivates the need
for comprehensive tooling.

### Case Study 1: The stringsAsFactors Debacle

R 4.0.0 (released April 2020) changed the default behavior of
[`read.csv()`](https://rdrr.io/r/utils/read.table.html) and
[`data.frame()`](https://rdrr.io/r/base/data.frame.html), switching
`stringsAsFactors` from `TRUE` to `FALSE` (R Core Team 2020). This
single change broke thousands of analysis scripts worldwide.

``` r

# R 3.6.3 (pre-April 2020):
data <- read.csv("patients.csv")
class(data$treatment)  # Returns "factor"
model <- lm(recovery ~ treatment, data)  # Works correctly

# R 4.0.0+ (post-April 2020):
data <- read.csv("patients.csv")  # SAME CODE
class(data$treatment)  # Returns "character" - DIFFERENT!
model <- lm(recovery ~ treatment, data)  # ERROR: variable lengths differ
```

A researcher who published results using R 3.6.3 would find that
collaborators using R 4.0.0+ could not reproduce their analysis **using
identical code and data**. This violates the basic promise of
computational reproducibility.

**Impact documented by Trisovic et al. (2022)**: In their survey of
9,000+ R scripts from Harvard Dataverse, 74% failed to run after 2-3
years, with R version incompatibilities being a primary cause.

### Case Study 2: Random Number Generator Changes

R has changed its random number generator multiple times (versions 3.6.0
and 4.4.0), each time breaking the reproducibility of stochastic
analyses (R Core Team 2019).

``` r

# R 4.3.0:
set.seed(123)
sample(1:10)  # [3, 7, 1, 9, 5, 2, 8, 4, 6, 10]

# R 4.4.0 (changed RNG):
set.seed(123)  # SAME SEED
sample(1:10)  # [5, 2, 8, 4, 1, 9, 3, 7, 6, 10]  # DIFFERENT SEQUENCE
```

This affects bootstrapping, cross-validation, permutation tests, and all
simulation-based inference. Patil et al. (2016) documents how seemingly
minor computational details like RNG algorithms critically affect
reproducibility in simulation studies.

### Case Study 3: Numerical Precision and Linear Algebra Libraries

Different BLAS (Basic Linear Algebra Subprograms) implementations
produce numerically equivalent but not identical results due to
precision differences and different optimization strategies (Wang et al.
2021).

``` r

# System with OpenBLAS:
set.seed(123)
pca <- prcomp(data, scale = TRUE)
loadings1 <- pca$rotation[, 1:3]

# System with Intel MKL:
set.seed(123)  # SAME SEED
pca <- prcomp(data, scale = TRUE)
loadings2 <- pca$rotation[, 1:3]

# loadings1 ≈ loadings2, but NOT identical
# all.equal(loadings1, loadings2)  # FALSE
# Downstream analyses differ
```

This affects PCA, eigendecomposition, regression, and essentially all
matrix operations central to modern statistics and machine learning.

## Why Both Docker AND renv Are Necessary

A common misconception is that dependency management (renv) or
containerization (Docker) alone provides sufficient reproducibility.
This is false.

### What renv Alone Cannot Fix

renv provides comprehensive R package version control but cannot
control:

- R version itself (critical for stringsAsFactors, RNG, and other
  breaking changes)
- System libraries (BLAS, libcurl, libxml2, OpenSSL versions)
- Operating system (Ubuntu vs. macOS numerical precision differences)
- Locale settings (affects text sorting, number formatting, factor
  ordering)
- Timezone (affects datetime calculations, especially with daylight
  saving time)

As Gentleman and Temple Lang (2007) note: “Reproducible research
requires that the entire computational environment be captured.” Package
versions alone represent only part of this environment.

### What Docker Alone Cannot Fix

Docker provides bit-for-bit identical system environments but cannot
control:

- R package versions (users can install arbitrary versions after
  container launch)
- Package drift (CRAN updates packages continuously)
- Developer intentions (which packages to install for a given analysis)

Boettiger (2015) acknowledges this limitation, recommending Docker +
package version locking for complete reproducibility.

### The Complete Solution: Docker + renv + .Rprofile

Marwick et al. (2018) provide the theoretical framework for this
integrated approach in their research compendium model. The combination
provides:

1.  **System-level control** (Docker): R version, system libraries, OS,
    locale, timezone
2.  **Package-level control** (renv): Exact R package versions with
    complete dependency trees
3.  **Session-level control** (.Rprofile): R options that affect
    computation but are invisible in code

This three-layer approach addresses all documented sources of
computational variation in R-based research.

## The Effort is Worth It: Benefits Outweigh Costs

### Reduced Time Costs

While implementing reproducible workflows requires upfront investment,
Ram (2013) found that this pays dividends through:

- Faster onboarding of new collaborators
- Elimination of “works on my machine” debugging
- Ability to return to old projects without reconstruction effort
- Reduced time spent on reviewer requests to verify results

Wilson et al. (2014) surveyed scientists and found that those using
reproducible practices spent **less** total time on computational work
despite the initial setup cost.

### Enhanced Scientific Validity

Peng (2011) argues that reproducibility should be the minimum standard
for publication. Journals increasingly require it: *Nature*, *Science*,
and *PLOS* now encourage or mandate sharing of computational
environments (Nature Editorial 2019).

More importantly, reproducible practices reduce errors. Stodden et al.
(2013) found that researchers using version control and environment
management caught more bugs in their own code.

### Career Benefits

Reproducible research enhances scientific impact. Vandewalle et al.
(2009) found that papers with publicly available code and data receive
higher citation rates. Piwowar and Vision (2013) demonstrated that
sharing data increases citation rates by 9% on average.

McKiernan et al. (2016) show that open research practices—including
computational reproducibility—correlate with career advancement, not
hindrance.

### Collaborative Benefits

Modern science is increasingly collaborative. Wuchty et al. (2007)
document that team-authored papers have increased from 17.5% in 1955 to
51.5% in 2000, with continued growth. Reproducible workflows reduce
friction in collaboration by ensuring all team members work in identical
computational environments.

## Practical Implementation with ZZCOLLAB

ZZCOLLAB implements the complete Docker + renv + .Rprofile approach with
minimal friction.

### Fast Builds Enable Git-Based Distribution

A critical insight: with RSPM (RStudio Package Manager) binary packages,
Docker images build in 3-4 minutes instead of 30-60 minutes (Posit team
2023). This changes the distribution model:

``` bash
# Team member joins project
git clone https://github.com/lab/study.git
cd study
make docker-build    # 3-4 minutes
make r      # Start working
```

No Docker Hub required—team members build from the Dockerfile in the
repository, ensuring perfect reproducibility with minimal wait time.

### Automatic Snapshot on Exit

ZZCOLLAB implements an automatic snapshot-on-exit architecture that
eliminates manual
[`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html)
commands:

``` bash
make r
# Inside container:
install.packages("ggplot2")  # Add packages as needed
exit                         # Automatically snapshots renv.lock
```

This addresses Ram (2013)’s finding that manual processes create
reproducibility failures.

### Volume Mounts Enable Iterative Development

Docker containers are often criticized as inflexible for active
development. ZZCOLLAB solves this by mounting the project directory as a
volume:

``` bash
docker run -v $(pwd):/home/analyst/project ...
```

Changes inside the container persist to the host, providing normal
iterative development workflows within a reproducible environment.

## Comparison with Alternatives

### Conda/Mamba

Conda provides cross-language package management but has limitations for
R:

- R package versions lag behind CRAN by months (Anaconda Inc. 2023)
- Not all CRAN packages available
- Mixing conda-forge and CRAN causes conflicts
- Slower than RSPM binaries

**When to use**: Python-centric workflows with some R components.

### Binder/MyBinder

Binder provides cloud-based reproducible environments but:

- Requires internet connection
- Limited computational resources
- Cannot use local data
- Session timeouts

**When to use**: Teaching, demonstrations, lightweight analyses.

### Manual Documentation

Comprehensive installation instructions fail because:

- Nobody follows instructions perfectly (Stodden et al. 2018)
- Hours to set up
- Platform-specific variations
- Not actually reproducible in practice

## Conclusion

The reproducibility crisis in science demands solutions. For
computational research, the technical solutions exist: Docker for
environmental control, renv for package management, and
version-controlled .Rprofile for session configuration.

The evidence shows that reproducible practices:

1.  **Reduce long-term time costs** (Wilson et al. 2014)
2.  **Improve scientific validity** (Stodden et al. 2013)
3.  **Enhance career outcomes** (McKiernan et al. 2016)
4.  **Increase research impact** (Piwowar and Vision 2013)
5.  **Enable effective collaboration** (Ram 2013)

The upfront cost is modest—3-4 minutes for Docker builds with RSPM, plus
initial learning—while the benefits compound over time.

As Buckheit and Donoho (1995) stated: “An article about computational
science in a scientific publication is **not the scholarship itself**,
it is merely **advertising** of the scholarship. The actual scholarship
is the complete software development environment and the complete set of
instructions which generated the figures.”

Docker + renv + .Rprofile represents the current best practice for
achieving this standard. ZZCOLLAB implements this complete solution with
minimal friction, making reproducibility the path of least resistance
rather than a burden.

## References

Anaconda Inc. 2023. *Anaconda Software Distribution*.
<https://docs.anaconda.com/>.

Begley, C Glenn, and Lee M Ellis. 2012. “Raise Standards for Preclinical
Cancer Research.” *Nature* 483 (7391): 531–33.
<https://doi.org/10.1038/483531a>.

Boettiger, Carl. 2015. “An Introduction to Docker for Reproducible
Research.” *ACM SIGOPS Operating Systems Review* 49 (1): 71–79.
<https://doi.org/10.1145/2723872.2723882>.

Buckheit, Jonathan B, and David L Donoho. 1995. “WaveLab and
Reproducible Research.” *Wavelets and Statistics* 103: 55–81.
<https://doi.org/10.1007/978-1-4612-2544-7_5>.

Gentleman, Robert, and Duncan Temple Lang. 2007. “Statistical Analyses
and Reproducible Research.” *Journal of Computational and Graphical
Statistics* 16 (1): 1–23. <https://doi.org/10.1198/106186007X178663>.

Ioannidis, John P A. 2005. “Why Most Published Research Findings Are
False.” *PLOS Medicine* 2 (8): e124.
<https://doi.org/10.1371/journal.pmed.0020124>.

Marwick, Ben, Carl Boettiger, and Lincoln Mullen. 2018. “Packaging Data
Analytical Work Reproducibly Using R (and Friends).” *The American
Statistician* 72 (1): 80–88.
<https://doi.org/10.1080/00031305.2017.1375986>.

McKiernan, Erin C, Philip E Bourne, C Titus Brown, et al. 2016. “How
Open Science Helps Researchers Succeed.” *eLife* 5: e16800.
<https://doi.org/10.7554/eLife.16800>.

Nature Editorial. 2019. “Challenges in Irreproducible Research.”
*Nature*, ahead of print. <https://doi.org/10.1038/d41586-019-00067-3>.

Nuijten, Michèle B, Chris H J Hartgerink, Marcel A L M van Assen, Sacha
Epskamp, and Jelte M Wicherts. 2016. “The Prevalence of Statistical
Reporting Errors in Psychology (1985-2013).” *Behavior Research Methods*
48 (4): 1205–26. <https://doi.org/10.3758/s13428-015-0664-2>.

Open Science Collaboration. 2015. “Estimating the Reproducibility of
Psychological Science.” *Science* 349 (6251): aac4716.
<https://doi.org/10.1126/science.aac4716>.

Patil, Prasad, Roger D Peng, and Jeffrey T Leek. 2016. “A Statistical
Definition for Reproducibility and Replicability.” *bioRxiv*, 066803.
<https://doi.org/10.1101/066803>.

Peng, Roger D. 2011. “Reproducible Research in Computational Science.”
*Science* 334 (6060): 1226–27.
<https://doi.org/10.1126/science.1213847>.

Piwowar, Heather A, and Todd J Vision. 2013. “Data Reuse and the Open
Data Citation Advantage.” *PeerJ* 1: e175.
<https://doi.org/10.7717/peerj.175>.

Posit team. 2023. *RStudio: Integrated Development Environment for R*.
Posit Software, PBC. <http://www.rstudio.com/>.

R Core Team. 2019. *R: A Language and Environment for Statistical
Computing*. R Foundation for Statistical Computing.
<https://www.R-project.org/>.

R Core Team. 2020. *R: A Language and Environment for Statistical
Computing*. R Foundation for Statistical Computing.
<https://www.R-project.org/>.

Ram, Karthik. 2013. “Git Can Facilitate Greater Reproducibility and
Increased Transparency in Science.” *Source Code for Biology and
Medicine* 8 (1): 7. <https://doi.org/10.1186/1751-0473-8-7>.

Stodden, Victoria, Peixuan Guo, and Zhaokun Ma. 2013. “Toward
Reproducible Computational Research: An Empirical Analysis of Data and
Code Policy Adoption by Journals.” *PLOS ONE* 8 (6): e67111.
<https://doi.org/10.1371/journal.pone.0067111>.

Stodden, Victoria, Jennifer Seiler, and Zhaokun Ma. 2018. “An Empirical
Analysis of Journal Policy Effectiveness for Computational
Reproducibility.” *Proceedings of the National Academy of Sciences* 115
(11): 2584–89. <https://doi.org/10.1073/pnas.1708290115>.

Trisovic, Ana, Matthew K Lau, Thomas Pasquier, and Mercè Crosas. 2022.
“A Large-Scale Study on Research Code Quality and Execution.”
*Scientific Data* 9 (1): 60.
<https://doi.org/10.1038/s41597-022-01143-6>.

Ushey, Kevin. 2020. “Renv: Project Environments for R.” *R Package
Version 0.12.0*. <https://CRAN.R-project.org/package=renv>.

Vandewalle, Patrick, Jelena Kovacevic, and Martin Vetterli. 2009.
“Reproducible Research in Signal Processing.” *IEEE Signal Processing
Magazine* 26 (3): 37–47. <https://doi.org/10.1109/MSP.2009.932122>.

Wang, Hanchen, Tianfan Fu, Yuanqi Du, et al. 2021. “Scientific Discovery
in the Age of Artificial Intelligence.” *Nature* 620 (7972): 47–60.
<https://doi.org/10.1038/s41586-023-06221-2>.

White, Ethan P, Elita Baldridge, Zachary T Brym, Kenneth J Locey, Daniel
J McGlinn, and Sarah R Supp. 2013. “Nine Simple Ways to Make It Easier
to (Re)use Your Data.” *Ideas in Ecology and Evolution* 6 (2): 1–10.
<https://doi.org/10.4033/iee.2013.6b.6.f>.

Wickham, Hadley. 2015. *R Packages: Organize, Test, Document, and Share
Your Code*. O’Reilly Media.

Wilson, Greg, D A Aruliah, C Titus Brown, et al. 2014. “Best Practices
for Scientific Computing.” *PLOS Biology* 12 (1): e1001745.
<https://doi.org/10.1371/journal.pbio.1001745>.

Wilson, Greg, Jennifer Bryan, Karen Cranston, Justin Kitzes, Lex
Nederbragt, and Tracy K Teal. 2017. “Good Enough Practices in Scientific
Computing.” *PLOS Computational Biology* 13 (6): e1005510.
<https://doi.org/10.1371/journal.pcbi.1005510>.

Wuchty, Stefan, Benjamin F Jones, and Brian Uzzi. 2007. “The Increasing
Dominance of Teams in Production of Knowledge.” *Science* 316 (5827):
1036–39. <https://doi.org/10.1126/science.1136099>.

## Appendix: Setting Up Reproducible Workflows

### Quick Start

``` bash
# Install ZZCOLLAB
git clone https://github.com/rgt47/zzcollab.git
cd zzcollab && ./install.sh

# Create a reproducible project
mkdir my-analysis && cd my-analysis
zzcollab analysis

# Build environment (3-4 minutes with RSPM)
make docker-build

# Start working
make r
```

### Daily Workflow

``` bash
# Enter reproducible environment
make r

# Inside container:
devtools::load_all()                    # Load your R package
source("analysis/scripts/01_clean.R")   # Run analysis
install.packages("tidymodels")          # Add new packages
exit                                    # Auto-snapshot on exit

# Commit and share
git add . && git commit -m "Analysis update"
git push
```

### Sharing with Collaborators

``` bash
# Collaborator clones and builds
git clone https://github.com/you/project.git
cd project
make docker-build    # 3-4 minutes
make r      # Identical environment
```

### For More Information

- ZZCOLLAB documentation: `docs/` directory
- Docker guide: `docs/docker-architecture.md`
- Testing guide: `docs/testing-guide.md`
- Configuration: `docs/CONFIGURATION.md`
