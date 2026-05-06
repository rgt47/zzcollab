# Continuous Integration Strategy for Research Compendia: A Tiered Model for zzcollab

*2026-05-05 17:54 PDT*

## Abstract

The default Continuous Integration (CI) configuration in zzcollab inherits
conventions developed for distributing R packages to CRAN. Those
conventions are tangentially related to the framework's actual purpose,
which is the construction and verification of reproducible research
compendia. This white paper identifies the category error embedded in the
current `r-package.yml` workflow, characterizes the regressions a research
compendium plausibly cares about, and proposes a three-tiered CI model
that aligns the checking strategy with the framework's reproducibility
claims. The recommendation is not to abandon `R CMD check`, but to demote
it from sole gatekeeper to one of three independent jobs, each serving a
distinct verification purpose with appropriate cadence and cost.

## 1. Problem Statement

A zzcollab project is a research compendium. Its success criterion is
that an analyst on a fresh machine, possibly years after original
publication, can clone the repository, build the documented Docker image,
restore the locked package versions, and reproduce the figures, tables,
and report contained in the work. The Five Pillars of zzcollab
(Dockerfile, renv.lock, .Rprofile, source code, data) jointly serve this
goal.

The current default CI workflow runs two operations:

1. `renv::restore()` against the project lockfile, inside a pinned
   container.
2. `R CMD check` against the R package metadata.

These operations are necessary but insufficient. They verify that the
package metadata is well-formed and that the locked packages are
installable. They do not verify that the analysis itself runs to
completion or that the report renders correctly. They also conflate two
distinct verification concerns into a single brittle step, with the
result that infrastructure issues (network state, cache state, URL
mismatches) can produce false negatives that do not reflect genuine
project unhealth.

This paper argues that the conventional R-package CI idiom is the wrong
default for a research-compendium framework. It proposes a model in which
CI is structured around the regressions a compendium author actually
cares about, rather than around the conventions of CRAN distribution.

## 2. The Category Error

`R CMD check` is a tool for verifying that an R package, taken as an
artifact, is well-formed for distribution. It checks that documentation
matches code, that exported names are documented, that examples run
without error, that the NAMESPACE is consistent, and that tests pass. All
of these are necessary properties for a CRAN-bound package and remain
useful for any R codebase.

A research compendium has a different success criterion. The artifact of
interest is not a tarball deposited to CRAN; it is a body of work whose
inputs, methods, and outputs travel together and can be regenerated on
demand. The questions a reader asks of a compendium are: does the
analysis pipeline run end-to-end, does the report render to its expected
form, are the locked dependencies still recoverable, are the declared
package imports actually used, and are the actually-used packages
declared.

`R CMD check` does not directly answer any of these. It is possible for
`R CMD check` to pass cleanly while the analysis script errors at the
first chunk and the rendered report is broken. The two checks are
substantively different.

The current zzcollab default CI runs the check that is conventional for R
packages, not the check that maps to the framework's purpose. This is the
category error.

## 3. What CI Should Detect

A useful frame for CI design is to ask: what regression would I be
unhappy to ship, and what test would catch it? Different regressions
require different tests, and most do not subsume each other.

The table below enumerates the regressions a zzcollab compendium author
plausibly cares about, the test that detects each, and a rough cost.

| Regression | Detection mechanism | Cost |
|------------|--------------------|------|
| Code change broke a function or test | `R CMD check` plus the test runner | medium |
| New `library()` call without DESCRIPTION update | `renv::status()` or zzrenvcheck audit | cheap |
| Lockfile drifted from declared dependencies | `renv::status()` | cheap |
| Fresh clone cannot restore the environment | `docker build` plus `renv::restore()` from clean cache | medium |
| Report no longer renders end-to-end | `rmarkdown::render()` or `quarto render` in CI | high |
| Output figures or tables changed unexpectedly | hash or diff outputs against a baseline | high, fragile |
| Upstream dependency broke compatibility | restore against current CRAN, no date pin | cheap, schedulable |
| Snapshot date too old to download packages | timed restore on schedule | cheap |

Conventional R-package CI addresses only the first row. The remaining
rows describe regressions that matter to a research compendium and are
either covered weakly or not at all by the current workflow.

## 4. The Five Pillars and Their CI Coverage

Mapping the zzcollab Five Pillars to CI checks reveals where the current
workflow is strong, where it is weak, and where it is silent.

**Dockerfile.** The environment definition. CI should verify that the
container image either builds from `Dockerfile` or pulls from the
declared registry. A failed build is the loudest signal that the
environment definition has decayed.

**renv.lock.** The package pin. CI should verify two distinct
properties: that the lockfile restores cleanly against the URLs it
records, and that the lockfile matches both DESCRIPTION and the actual
`library()`/`pkg::` references in source. The second property is what
zzrenvcheck exists to enforce. The current workflow attempts the first
property and ignores the second.

**.Rprofile.** The session bootstrap. Difficult to test in isolation.
Best verified indirectly through successful R startup and successful
restore.

**Source code.** The conventional target of `R CMD check`. The current
workflow handles this adequately when the prior steps succeed.

**Data.** Provenance, file hashes, and schemas. Largely a documentation
discipline rather than a CI concern, although CI can hash inputs and
outputs as a regression check.

The Pillar that receives the least CI coverage today is the one closest
to the framework's purpose: end-to-end reproduction of the analysis. If
`analysis/report/report.Rmd` or `index.qmd` renders successfully from a
clean environment, the compendium is much closer to verified than if
`R CMD check` alone passes.

## 5. Proposed Tiered CI Model

CI should be structured as three independent jobs, each gating a
different class of regression at an appropriate cadence.

### Tier 1: Environment Integrity

Cheapest job. Runs on every push to any branch. Verifies that the
framework remains internally consistent.

```r
renv::restore(prompt = FALSE)
renv::status()
zzrenvcheck::check_packages()
```

`renv::restore()` confirms the lockfile is restorable. `renv::status()`
confirms the lockfile, DESCRIPTION, and source code agree on what
packages are in use. `zzrenvcheck::check_packages()` adds a finer-grained
audit (orphaned imports, undeclared usage). Expected duration under
thirty seconds in steady state, with a warm cache. This is the check
that directly addresses the framework's reproducibility claim and is
currently the least enforced part of the workflow.

### Tier 2: Code Correctness

Conventional R-package check. Runs on pull requests. Catches code-level
regressions.

```r
rcmdcheck::rcmdcheck(args = '--no-manual', error_on = 'error')
tinytest::test_package(pkg)
```

This is the current workflow's purpose. Useful, narrow, and well
understood. Expected duration one to five minutes.

### Tier 3: End-to-End Reproduction

The check that maps directly to the compendium's success criterion. Runs
on `main` after merge or on a nightly schedule. Catches reproducibility
regressions.

```r
rmarkdown::render('analysis/report/report.Rmd')
# or
quarto::quarto_render('index.qmd')
```

Optionally, hash the produced outputs and fail if the hash differs from a
recorded baseline. The cost depends on the analysis (potentially many
minutes), so this tier is not appropriate for every push, but it is the
single check that verifies the framework's promise.

## 6. Implications for Reliability

A workflow's pass rate is partly a function of what it is checking. A
workflow that runs `echo hello` will pass routinely and tell the author
nothing. A workflow that runs the full analysis end-to-end will fail
more often, but its failures will be informative.

The goal is not "passes routinely" in isolation. The goal is "passes
routinely when the project is healthy, and fails informatively when the
project is broken." The current v2.4.0-A workflow fails for
infrastructure reasons (curl absence, lockfile URL mismatch, GitHub
Actions cache state) rather than for project-health reasons. That is the
worst of both worlds: false-negative noise that conveys no information
about the research.

Splitting the workflow into the three tiers proposed above has two
benefits. First, each tier becomes reliable on its own terms; an
infrastructure issue in Tier 3 does not prevent Tier 1 from telling the
author that the lockfile drifted. Second, the failure mode of each tier
is informative; a Tier 1 failure means the framework is internally
inconsistent, a Tier 2 failure means code or tests broke, a Tier 3
failure means the analysis pipeline regressed.

## 7. Comparison to v2.2.0

The earlier v2.2.0 workflow template, retained in some zzcollab projects,
already gestures toward this tiered structure. It defines a `check` job
plus three conditional jobs (`render-report`, `validate-data`,
`render-blog`) that fire when `analysis/report/report.Rmd`,
`analysis/data/`, and `index.qmd` are present respectively. The
conditional jobs implement an elementary version of Tier 3.

The v2.4.0-A simplification dropped these conditional jobs in favor of a
single renv-restore-and-check pipeline. From a CI-strategy perspective
this was a regression in scope, not merely an implementation refactor.
The newer workflow is technically more sophisticated (renv-aware, pinned
container, separate CI tools library) but covers strictly less of the
framework's reproducibility surface.

Empirically, this tradeoff produced worse outcomes. Across nine projects
audited in 2026-05, the v2.2.0 workflow passes in three of four projects;
the v2.4.0-A workflow passes in one of five. The newer workflow's
narrower scope did not buy the reliability the trade implied.

## 8. Recommendations

The recommendation is not to revert to v2.2.0, which has its own
reliability issues, nor to abandon the renv-based approach, which is
correct for the framework's purpose. The recommendation is to
restructure the canonical zzcollab `r-package.yml` template along the
following lines.

Provide three jobs, each of which can be enabled independently:

1. `validate`: a fast Tier 1 job that runs on every push. Restores the
   lockfile, runs `renv::status()`, and runs the zzrenvcheck audit if the
   project declares zzrenvcheck as a dev dependency. Should pass under
   thirty seconds with a warm cache.

2. `check`: the Tier 2 job. Runs on pull requests. Performs the
   conventional `R CMD check` plus test execution. The current workflow
   collapsed into this job alone.

3. `render`: the Tier 3 job. Conditionally enabled when
   `analysis/report/report.Rmd` or `index.qmd` is present. Runs on `main`
   after merge or on a weekly schedule. Renders the document and uploads
   the output as a build artifact.

Independent additional changes that improve reliability of any tier:

- Pin `R$Repositories.URL` in `renv.lock` to a date-stamped Posit
  Package Manager URL with the appropriate OS segment, rather than the
  default unqualified `cran/latest`. This eliminates source-build
  fallback, version drift between restores, and the RSPM-tag-without-URL
  resolution problem.

- Set `ZZCOLLAB_AUTO_RESTORE=false` in the workflow environment so the
  workflow controls restore explicitly rather than racing the
  `.Rprofile` auto-restore branch.

- Add `curl` and `ca-certificates` to the system-deps apt line as a
  defensive measure against the renv curl-CLI fallback warning, even
  though the warning has been verified to be non-fatal for download
  success.

These changes are independent. The lockfile URL fix alone substantially
improves reliability of the current single-job workflow. The tiered
restructure is the larger change and addresses the underlying category
error.

## 9. Conclusion

The question this paper addresses is not "how do we make CI pass," but
"what should CI check, given what zzcollab is for." The framework's
purpose is research-compendium reproducibility. The conventional
R-package CI idiom inherited from the broader R ecosystem is a
reasonable starting point but does not align with that purpose. A
three-tier model (environment integrity, code correctness, end-to-end
reproduction) addresses the regressions a compendium author actually
cares about, separates checks by cost and cadence, and produces
informative failures rather than infrastructure noise.

The recommendation for current zzcollab projects is incremental: fix
the lockfile URL pinning first, since that improves reliability without
restructuring; then split the workflow into the three tiers as a
deliberate framework upgrade; and only then consider the secondary
question of whether to retain renv inside CI versus relying on
DESCRIPTION-based dependency installation. The order matters because the
first change is cheap and reduces noise sufficient to evaluate the
later, larger changes on their own merits.

---

*Rendered on 2026-05-05 at 17:57 PDT.*<br>
*Source: ~/prj/sfw/07-zzcollab/zzcollab/docs/ci-strategy-tiered-model.md*
