# Where R Package Dependencies Belong: Dockerfile, renv.lock, or DESCRIPTION
*2026-06-30 16:07 PDT*

## Abstract

A zzcollab research compendium pins its computational environment in several
files at once: a generated `Dockerfile` (the platform), an `renv.lock`
(the exact package manifest), and a `DESCRIPTION` (the declared package
contract). A recurring practical question is which of a project's R packages
belongs in which file, and in particular which packages should be installed in
the image but kept out of the reproducibility manifest. This paper gives a
decision procedure. The governing test is whether a package's version can
change the analytical or rendered output; a second, renv-specific filter is
whether the package is referenced by the analysis code at all. Packages that
fail both tests, of which `languageserver` is the canonical example, are
development tooling: install them in the Dockerfile and keep them out of
renv.lock. The paper sets out the two-layer model, the roles of the three
files, a categorised reference list, the mechanics that capture and enforce
the split, a worked example, and the anti-patterns that reinflate the
manifest.

## 1. The problem: three homes for one package

When a compendium uses a package, that package can be recorded in up to three
places, and the three are not interchangeable:

- the **Dockerfile**, which installs packages into the image at build time
  against a dated Posit Package Manager (PPM) snapshot;
- **renv.lock**, which pins the exact version, source, and hash of every
  package in the project's renv library, for `renv::restore()`;
- **DESCRIPTION**, which declares the project's direct dependencies by role
  (`Imports`, `Suggests`, `Depends`) with optional version floors.

Put a package in the wrong place and one of two failures follows. Put a
genuine analysis dependency only in the Dockerfile, and renv.lock no longer
describes the environment; a collaborator who restores the lock gets an
incomplete library. Put a development tool into renv.lock, and the manifest
bloats with packages whose versions are irrelevant to the result, obscuring
the dependencies that actually matter. The cost is not hypothetical: a single
`devtools::load_all()` in a report pulls roughly eighty packages
(`testthat`, `roxygen2`, `pkgdown`, and the rest of the dev toolchain) into a
naive snapshot.

## 2. The two-layer model

The clean mental model separates the environment into two layers with
different purposes and different sources of truth.

The **platform layer** is the operating system, system libraries, the R
installation, the document toolchain (pandoc, LaTeX), and development tooling.
It is defined by the Dockerfile and pinned by the dated PPM snapshot and the
base image digest. Its job is to make the project *buildable and editable*.

The **reproducibility layer** is the set of R packages whose exact versions
determine the computed and rendered output. It is defined by renv.lock
(exact versions) and DESCRIPTION (the declared contract). Its job is to make
the project's *results restorable* by anyone, independent of the particular
image.

A package belongs to whichever layer matches its function. The error to avoid
is treating the two layers as one list. They answer different questions and
are consumed by different machinery: the Dockerfile by `docker build`,
renv.lock by `renv::restore()`, DESCRIPTION by `R CMD check` and installers.

## 3. The decision procedure

Two questions, applied in order, place any package.

**Test 1 (the reproducibility test): could this package's version change the
analytical or rendered output?** If yes, it belongs in the reproducibility
layer (renv.lock, and declared in DESCRIPTION). Data manipulation, statistics,
modelling, and plotting packages always pass this test. So does the rendering
toolchain (`rmarkdown`, `knitr`, `bookdown`), because a version change there
can alter the produced artifact. If a package fails Test 1, it is a platform
or development concern and has no place in renv.lock.

**Test 2 (the capture test): is the package referenced by the analysis code?**
This is an renv-specific reality, not a preference. renv discovers
dependencies by scanning code for `library()`, `require()`, `pkg::`, and the
DESCRIPTION fields. A package the editor, a git hook, or CI invokes, but the
analysis code never calls, is invisible to `renv::dependencies()`, so
`renv::hydrate()` will not copy it and `renv::snapshot()` will not record it.
Such packages can only enter renv.lock if forced there, against the grain of
the tool.

`languageserver` is the canonical case because it fails both tests: its
version never affects output, and it is launched by the editor rather than
called from code. It is therefore the one R package that unambiguously belongs
in the Dockerfile and nowhere else.

## 4. The three files and their distinct roles

The split is easier to apply once the three files are understood as carrying
non-overlapping information.

**DESCRIPTION** is the abstract contract: direct dependencies only, grouped by
role, with optional version floors (`dplyr (>= 1.1.0)`). It is human-authored
intent, read by `R CMD check`, `install.packages(dependencies = TRUE)`, and
CRAN. Because a compendium is also an R package, DESCRIPTION is what makes it a
valid, checkable, installable package.

**renv.lock** is the exact, machine-generated snapshot: the full transitive
closure at precise versions, with source and hash. It is read by
`renv::restore()` to rebuild the environment identically. It carries no notion
of role and is never hand-edited.

**The Dockerfile** is the platform: base image, system dependencies, the
document toolchain, the editor tooling, and the bootstrap that restores
renv.lock. Its R-package installs are for tools that are not part of the
reproducible result.

A package in renv.lock but not DESCRIPTION is pinned but undeclared, and reads
as an undocumented dependency. A package in DESCRIPTION but not renv.lock is
declared but unpinned, so a restore is incomplete. A reproducibility-relevant
package therefore belongs in both; a platform tool belongs in neither, only in
the Dockerfile.

## 5. Categorised reference

The following placement follows directly from Section 3.

### 5.1 Development tooling: Dockerfile only, never renv.lock

These fail both tests. Their versions do not affect the output, and the
analysis code does not call them. Pin them in the Dockerfile (dated PPM
snapshot) if a reproducible development environment is wanted; keep them out
of the manifest.

- Editor, LSP, and style: `languageserver`, `lintr`, `styler` (when run by the
  editor or a pre-commit hook rather than from a script).
- Package development: `devtools`, `usethis`, `roxygen2`, `pkgbuild`,
  `sessioninfo`, `remotes`, `pak`.
- Documentation site: `pkgdown`.
- Profiling and debugging: `profvis`, `bench`, `lobstr`.
- Version-control helpers: `gert`, `gh`, `credentials`, `gitcreds`.
- Build and check: `rcmdcheck`.

### 5.2 Reproducibility-relevant: renv.lock and DESCRIPTION

These pass Test 1, and the analysis code references them, so renv captures
them and they must be pinned and declared.

- Data, statistics, modelling: `dplyr`, `tidyr`, `data.table`, `lme4`,
  `survival`, and the rest of the analytical stack.
- Graphics: `ggplot2`, `patchwork`, `scales`.
- Tabular and reporting helpers used in the analysis: `gt`, `kableExtra`.
- Path resolution used by analysis code: `here`.
- The rendering toolchain: `rmarkdown`, `knitr`, `bookdown`. A version change
  here can alter the produced document, so they are reproducibility-relevant
  despite feeling like tooling. On a `rocker/verse` base they are baked into
  the image, and `renv::hydrate()` copies the ones the report uses into the
  manifest.

### 5.3 Borderline cases: decide deliberately

- `testthat`, `tinytest`: test infrastructure. They do not produce the
  analysis output, but a test's pass or fail is part of reproducing your
  verification. The convention is to declare them in `Suggests` and let renv
  pin them; either inclusion or exclusion is defensible, but choose
  explicitly.
- `pkgload`: it loads the compendium package at render time (`load_all`), so
  it is code-referenced and does touch the run. It is not pure tooling; keep
  it in the manifest (typically `Suggests`). It is also the lightweight
  alternative to `devtools` for loading: preferring `pkgload::load_all()` over
  `devtools::load_all()` in a report keeps the closure small.
- `yaml`: not analysis tooling and not directly called, but a transitive
  dependency of `rmarkdown` and `knitr`, and required by renv's own dependency
  parser to read `.Rmd` files. It is therefore present in the manifest by way
  of the rendering toolchain, and only needs an explicit Dockerfile install on
  a base that lacks the rendering stack.

### 5.4 Placement versus provisioning, and the no-host-R consequence

The categories above answer *where* a package goes if it is installed. They do
not say *whether* to install it. Those are separate decisions, and conflating
them reinflates the image the way putting tooling in renv.lock reinflates the
manifest. The placement rule is fixed (dev tooling to the Dockerfile, never
renv.lock); the provisioning rule is lean by default: install a dev tool only
when a workflow actually invokes it.

In a general setup this is a soft preference, because a developer could run
dev tooling on the host. zzcollab's design removes that escape hatch: it is
built for users **with no R on the host**, so any R-based tool, dev tooling
included, can only run where R runs, which is the container. This turns the
placement rule from a preference into a constraint. There is no host on which
to put `languageserver`, `styler`, or `lintr`, so if they are used at all they
must be in the image.

The reconciliation of "lean by default" with "must be in the image" is to
make each dev tool **conditional on the feature that uses it**:

- `languageserver` is installed unless disabled, gated by a config toggle
  (`zzc config set languageserver false`, or the in-container-LSP checkbox in
  the feature wizard). A user whose editing is REPL-only (zzvim-R sending to
  the container's R) turns it off; a user whose host editor bridges an LSP
  client into the container (the only way to get library-aware completion
  with no host R) leaves it on, which is the default.
- `styler` and `lintr` are installed only when the code-quality feature is
  active (a `.pre-commit-config.yaml` is present), and are run in the
  container via `make style` / `make lint`, because the host pre-commit hooks
  that would otherwise run them need an R the host does not have.

The general rule is therefore: a dev tool belongs in the Dockerfile, gated on
the feature that uses it, and it lives in the image rather than the host
because for a no-host-R design there is no host to fall back on. renv.lock
stays untouched throughout, since none of these affect the result.

## 6. Imports versus Suggests: the package-and-analysis duality

A compendium is simultaneously an R package (`R/`) and an analysis
(`analysis/`). The two have different dependency sets, and conflating them
breaks `R CMD check`.

A package used by `R/` code is a true `Imports`: `R CMD check` treats Imports
as hard requirements and errors if they are absent. A package used only by
`analysis/` (a report, a script) is not part of the package's API and should
be a `Suggests`, which `R CMD check` tolerates (with
`_R_CHECK_FORCE_SUGGESTS_=false`). Declaring an analysis-only dependency as an
Imports forces `R CMD check` to require a package the package itself never
uses.

The validator reconciles the two: `zzrenvcheck::check_packages()` counts the
union of Imports and Suggests as the declared set, so an analysis dependency
placed in `Suggests` still satisfies the manifest gate while sparing
`R CMD check`. The rule is therefore: `R/` dependencies to `Imports`,
`analysis/` dependencies to `Suggests`, and both pinned in renv.lock.

## 7. The mechanics that capture and enforce the split

The placement is not merely advisory; zzcollab provides machinery to capture
and verify it.

**Capture (`make snapshot`).** On a baked-base profile such as
`rocker/verse`, the analysis packages live in the image's site-library, which
renv isolates from its own library. `renv::hydrate()` resolves this: it copies
the packages the code uses from the image into the renv library without
reinstalling, after which `renv::snapshot()` records them in renv.lock and
`check_packages(auto_fix = TRUE)` declares them in DESCRIPTION. The result is a
complete manifest assembled from the image rather than re-downloaded.

**Enforcement (the CI gate).** The R-package workflow runs
`zzrenvcheck::check_packages(strict = TRUE)` and fails the build when a
package referenced in code is missing from renv.lock or DESCRIPTION. This is a
presence check: it guarantees the manifest is complete, not that versions
between DESCRIPTION floors and renv.lock pins agree, which is a separate
concern.

The two together make the rule operational: write analysis, run
`make snapshot` to capture its dependencies into the manifest from the image,
commit, and let CI confirm completeness. Development tooling never enters this
loop, because the code never references it.

## 8. Worked example

The peng1 compendium, built on the `rocker/verse` publishing profile,
illustrates every category.

- `languageserver`: editor LSP, never code-referenced, version irrelevant to
  output. Installed in the Dockerfile; absent from renv.lock. Section 5.1.
- `yaml`: transitive dependency of `rmarkdown`/`knitr` and needed by renv's
  Rmd parser. Present in renv.lock by way of the rendering toolchain; the
  explicit Dockerfile install is redundant on the verse base. Section 5.3.
- `here`: called by the report (`here::here()`), output-relevant. Captured
  into renv.lock; the explicit Dockerfile install is redundant once captured.
  Section 5.2.
- `dplyr`, `ggplot2`: used by the package's `R/` functions. `Imports` in
  DESCRIPTION, pinned in renv.lock. Section 5.2 and Section 6.
- `pkgload`: loads the package in the report; `Suggests`, pinned. Choosing it
  over `devtools` kept the lock at fifty-seven packages rather than one
  hundred and fifteen. Section 5.3.

After capture, peng1's manifest gate passes with six code packages, all
declared and all locked, and `R CMD check` passes because only the two `R/`
dependencies are hard Imports.

## 9. Anti-patterns

- **Snapshotting the whole image.** Pinning every package the base image
  provides, rather than only those the code uses, reinflates renv.lock and
  reintroduces the maintenance and drift it was meant to remove. Capture what
  is used, via `make snapshot`, not the entire site-library.
- **`devtools::load_all()` in a report.** It drags the dev toolchain into the
  manifest. Use `pkgload::load_all()`.
- **Version pins in install calls.** Writing `pak::pak('dplyr@1.1.0')` or
  `remotes::install_version('dplyr', '1.1.0')` in committed analysis code
  places the pin where the validator cannot see it; the scanner records `pak`
  or `remotes`, not `dplyr`, and never the version. Pin versions in renv.lock
  via a snapshot, and use `pak` only to install interactively.
- **Analysis dependencies as Imports.** Declaring a report-only package as an
  Imports makes `R CMD check` hard-require it. Use `Suggests`.
- **Forcing dev tooling into renv.lock.** It pins versions that have no effect
  on the result and obscures the dependencies that do.

## 10. Caveat: two senses of reproducibility

"Does not affect reproducibility" in this paper means reproducibility of the
*results*. A separate, legitimate goal is a reproducible *development*
environment, in which collaborators receive identical `devtools`, `roxygen2`,
and editor tooling. That goal is served by pinning those tools in the
Dockerfile, against the dated PPM snapshot, not by adding them to renv.lock.
Keeping the two layers separate is precisely what prevents the analysis
manifest from reinflating to the bloated state that motivates this paper. The
platform can be as reproducible as one likes; renv.lock should still contain
only what the analysis and its rendering touch.

## 11. Summary

Apply two tests. If a package's version can change the analytical or rendered
output, it belongs in renv.lock and DESCRIPTION. If, in addition, it is never
referenced by the analysis code, it is development tooling and belongs in the
Dockerfile alone. `languageserver` is the clearest instance of the second
case; the rest of the dev-tooling set in Section 5.1 follows the same logic.
The rendering toolchain is the most common false friend: it feels like tooling
but affects the artifact, so it stays in the manifest. Capture the manifest
from the image with `make snapshot`, classify `R/` dependencies as Imports and
`analysis/` dependencies as Suggests, and let the CI gate confirm completeness.
The discipline keeps renv.lock an honest, minimal record of what reproduces the
result, and the Dockerfile the home for everything that merely supports the
work.

## Appendix A. Verification of the conditional-tooling mechanism

The placement-versus-provisioning rule of Section 5.4 is enforced by a config
toggle (`languageserver`) that gates the Dockerfile install list without
touching renv.lock. The following observations, recorded against a freshly
scaffolded project, confirm the mechanism behaves as the rule requires.

The renv library layout was probed in a `rocker/verse:4.6.0` container.
`install.packages` (with `RENV_PATHS_LIBRARY` set), `renv::restore`, and
`renv::hydrate` all deposit packages in one directory,
`renv::paths[['library']]()`, which resolves to
`/opt/renv/library/<platform>/R-<ver>/<arch>`. A glob of the form
`/opt/renv/library/*/*` stops one level short of that directory, which is the
defect the render workflow carried until it was corrected to use
`renv::paths[['library']]()`. This confirms that a single authoritative path
serves restore, hydrate, and install alike, so a package placed in the manifest
is found regardless of which mechanism materialises it.

The toggle was then exercised end to end. A project scaffolded with default
settings produced a Dockerfile whose tooling line read
`install.packages(c('languageserver', 'yaml', 'here'), ...)`. Running the
feature wizard and disabling the language server produced the planned change
`languageserver: on -> off`, persisted `languageserver: "false"` to the
project's `zzcollab.yaml`, and regenerated the Dockerfile with the tooling line
reduced to `install.packages(c('yaml', 'here'), ...)`. Throughout, renv.lock
was untouched, which is the invariant the two-layer model demands: a
development-tooling decision alters the image and nothing else. With the
code-quality feature inactive, `styler` and `lintr` were correctly absent from
the install list, appearing only in the config-gated comment, and the generated
Makefile carried the `style` and `lint` targets that run those linters in the
container.

These observations are structural and behavioural checks of the generation and
toggle path, not a test of the language server or linters themselves. They
establish that the tooling set is governed entirely by config-gated image
generation, leaving the reproducibility manifest invariant under tooling
changes.

## Appendix B. Provisioning cost: bulk versus incremental LaTeX installation

Section 5.4 establishes that provisioning is a decision distinct from placement:
the placement of the LaTeX toolchain (the image, never renv.lock) is fixed, but
*how* the toolchain is materialised in the image is a separate choice with a
large, and initially hidden, cost. Profiling the publishing-profile image build
surfaced a defect in the original warm-up strategy and a simple correction.

The publishing profile is built on `rocker/verse`, which ships a minimal TeX
Live with on-the-fly package installation disabled by default. To render PDFs
for the non-root run user without a runtime install, the Dockerfile pre-bakes
the LaTeX package closure at build time. The original approach rendered a
kitchen-sink document with `options(tinytex.install_packages = TRUE)` and let
tinytex discover missing packages lazily. Measuring the build layer by layer
showed this single `RUN` consumed 326 seconds, 77 per cent of the entire image
build.

The cause was not the package downloads. tinytex installs lazily discovered
packages one at a time, and after each single install it recompiles the whole
document with `pdflatex` to discover the next missing file. The install cadence
was a near-constant 14 seconds per package across 24 packages, yet each `tlmgr`
install itself completed in under one second; the 14 seconds was the repeated
`pdflatex` recompile. Package size was uncorrelated with time: the three
largest downloads (`amsfonts` at 3.5 MB, `pgf` at 702 kB, `pgfplots` at 519 kB)
each fetched in under a second, and packages pulled as dependencies of the same
`tlmgr` call installed together in roughly half a second. The cost was
therefore O(n) full-document recompiles, not O(total bytes) of download.

The correction is to install the known closure in one bulk `tlmgr` pass before
any render, replacing lazy discovery with an explicit list:

```r
tinytex::tlmgr_install(c('amsfonts', 'booktabs', 'setspace', 'multirow',
  'wrapfig', 'float', 'colortbl', 'pdflscape', 'tabu', 'varwidth',
  'threeparttable', 'threeparttablex', 'environ', 'trimspaces', 'ulem',
  'makecell', 'mathtools', 'fancyhdr', 'caption', 'enumitem', 'fp', 'pgf',
  'pgfplots', 'siunitx'))
```

The subsequent kitchen-sink render is retained: with the closure already
present it triggers no further installs, so it serves as a fast smoke test and
self-heals any package the explicit list omits. Measured against the same CI
runner, the warm-up layer fell from 326 seconds to 31 seconds, a factor of ten,
and the whole render image build fell from 7 minutes 1 second to 2 minutes 29
seconds. The final render step was 3 to 4 seconds before and after, confirming
that rendering was never the bottleneck.

The general lesson generalises beyond LaTeX. When an image provisions a
tool whose installer resolves dependencies iteratively (a compile-fail-install
loop, a solver invoked per package, a lockstep resolver), the dominant cost is
often the repeated resolution step rather than the artifacts themselves.
Provisioning the full closure in a single resolver invocation, then verifying
once, converts an O(n)-resolution loop into a single pass. This is a
provisioning optimisation only; it changes neither placement nor the
reproducibility manifest, and the rendered output is bit-for-bit identical.

---
*Rendered on 2026-07-01 at 07:19 PDT.*<br>
*Source: ~/prj/sfw/07-zzcollab/zzcollab/docs/package-placement-whitepaper.md*
