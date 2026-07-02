# Migrating a zzcollab Compendium to the Publishing Profile
*2026-07-02 07:38 PDT*

A repo-agnostic playbook for refurbishing any zzcollab research compendium
under `~/prj` so that it builds on the `publishing` profile (rocker/verse),
renders PDF reproducibly in CI, and passes the two-layer dependency-manifest
gate. It generalises the concrete refurbishment first performed on the `peng1`
compendium.

The playbook is organised as an audit (Phase A) that classifies a repo and
produces a work list, followed by execution phases (0 through 5). Each phase is
idempotent: re-running the Phase A audit after any phase confirms convergence.

## Preconditions and guards

- Applies to zzcollab-scaffolded compendia (a `Dockerfile` with
  `ARG BASE_IMAGE`, a `renv.lock`, an `.Rprofile`, and `.github/workflows`).
- Confidentiality guard: any repo under `~/prj/srv/` (or its symlinked target)
  must never gain a GitHub remote. In this playbook, Phase 5 publish steps are
  skipped unconditionally for `srv` repos; they are verified locally only.
- All edits on cloud-mounted paths (`~/Library/CloudStorage/...`) use an
  editor that does not race the file provider. Never use `sed -i`, `perl -i`,
  or other in-place CLI editors on those paths.

## Governing convention: report.Rmd is canonical

`report.Rmd` is the canonical document. In every report unit (a numbered
subdirectory under `analysis/report/`) exactly one `report.Rmd` is the single
source of truth that CI renders and that the dependency manifest must cover.
Every other Rmd is subordinate to it and outside the sealed scope: draft
variants (`report-slim.Rmd`, `report_short.Rmd`), a host-rendered submission
manuscript (`paper.Rmd`, `supplement.Rmd`) with its own author toolchain,
working scripts, and vignettes. This is why the render workflow discovers
`^report[.]Rmd$` and nothing else, and it is the anchor for the discovery
(A3), manifest-scope (A4), and landmine (A5) rules below: a package or a
runtime-install pattern matters to the migration only insofar as it reaches a
`report.Rmd` on the sealed path. Migrating a non-conforming repo means making
its canonical output a `report.Rmd`, not teaching CI to render everything.

## Per-repo parameters

Resolve these once per repo; they drive every phase.

| parameter | how to resolve | example |
|---|---|---|
| `REPO_PATH` | the compendium root (git worktree) | `~/prj/res/01-.../proj` |
| `R_VERSION` | `renv.lock` top-level `R.Version` | `4.6.0` |
| `UBUNTU_CODENAME` | the rocker base for `R_VERSION` | `noble` |
| `PPM_SNAPSHOT` | chosen Posit Package Manager date | `2026-06-29` |
| `BASE_PROFILE` | current `FROM` in Dockerfile | `rocker/tidyverse` |
| `NEEDS_PDF` | any report YAML targets a LaTeX output | `true` |
| `IS_SRV` | is `REPO_PATH` under `~/prj/srv/` | `false` |

`UBUNTU_CODENAME` and `PPM_SNAPSHOT` must be identical across the Dockerfile
(`RENV_CONFIG_REPOS_OVERRIDE`), the `.Rprofile` repos option, and the base of
the regrown `renv.lock`. Version coherence matters because
`zzrenvcheck (>= 0.4.0)` now reconciles versions, not just presence.

## Phase A. Audit and classify

Produce a work list; make no edits. This can be run by two parallel review
agents (one for build/CI infrastructure, one for the dependency manifest), as
was done for the reference migration.

- A1. Profile. Read `Dockerfile` `ARG BASE_IMAGE` / `FROM`. Classify as
  minimal, tidyverse, rstudio, or verse. If already verse, Phase 0 is a
  refresh rather than a base swap.
- A2. Render need (`NEEDS_PDF`). Scan `analysis/**/*.Rmd` and `*.qmd` YAML
  `output:` fields. Any `pdf_document`, `bookdown::pdf_document2`, or
  `latex_engine` implies a LaTeX toolchain and therefore the verse base. If
  every report is HTML-only, verse is optional.
- A3. Report discovery. Enumerate the manuscript files and compare against the
  render workflow's discovery rule (`^report[.]Rmd$` recursively under
  `analysis/`, plus any `.Rmd` under `analysis/posts/`). This rule is a naming
  convention, not a limitation: the canonical manuscript in each subdirectory
  is named exactly `report.Rmd`, and everything else (draft variants such as
  `report-slim.Rmd`, working scripts under `analysis/scripts/`, package
  vignettes) is named otherwise so it is deliberately excluded. The convention
  scales to many manuscripts cleanly; it is in production use across the fleet
  at 4, 6, and 11 manuscripts per repo, one `report.Rmd` per numbered
  subdirectory under `analysis/report/`. Flag any manuscript that is a
  co-equal peer of `report.Rmd` in the same directory (for example a
  `paper.Rmd` and `supplement.Rmd` alongside `report.Rmd`, all intended as
  outputs): it will be silently skipped. The remedy is to restructure to the
  convention (one `report.Rmd` per subdirectory), not to broaden the discovery
  glob. Broadening would also sweep in every intentionally excluded draft
  variant and script, so it is the wrong move (see Phase 0, CI).
  Distinguish two legitimate classes of manuscript. A CI-rendered report is
  named `report.Rmd`, renders in the sealed container image, and its packages
  belong in the manifest. A host-rendered manuscript (a submission paper with a
  personal LaTeX preamble, a `knit:` hook routing through a host tool such as
  `stamp-render.R`, absolute host-path includes like `~/shr/preamble.tex`, or a
  runtime `pacman::p_load`) is deliberately not a container report: it renders
  on the host with the author's toolchain and is correctly skipped by CI. Such
  a manuscript, and the packages it alone uses, are out of the sealed-manifest
  scope. Do not delete it, do not de-landmine it, and do not treat its
  dependencies as manifest gaps. Classify each skipped manuscript as draft
  variant, host-rendered manuscript, or genuinely-missing report, and act only
  on the last.
- A4. Manifest health. Cross-reference every non-base package used by code
  against `DESCRIPTION` and `renv.lock`. Split by role: `R/` usage maps to
  `Imports`, `analysis/` (and tests/vignettes) usage maps to `Suggests`.
  Produce two lists: packages missing from `renv.lock` (restore breakers) and
  packages misdeclared (an analysis-only package sitting in `Imports`, which
  `R CMD check` would hard-require). Scope this to code on the sealed path:
  packages used only by a host-rendered manuscript (A3) or by scaffold
  boilerplate (see below) are not manifest gaps. Before locking a package,
  confirm it is referenced by a CI-rendered report, by `R/`, or by a real test.
  A package that appears only in a skipped manuscript's `p_load`, or only in a
  leftover scaffold test (for example a `palmerpenguins` data-pipeline test in
  a project that has nothing to do with penguins), should be excluded, and the
  boilerplate test deleted, rather than added to the manifest.
- A5. Runtime-install landmines. Grep analysis and render code for
  `pacman::p_load`, `p_load`, `install.packages`, and `pak::` used at render
  time. Grep report and preamble sources for absolute host paths (`~/`,
  `/Users/`) that will not exist in the image. In a CI-rendered report these
  defeat both a sealed render and renv's static dependency discovery and must
  be fixed in Phase 1. In a host-rendered manuscript (A3) the same patterns are
  expected and are left in place; a landmine is only a landmine on the sealed
  path.
- A6. Vendored drift. Diff `Dockerfile`, `Makefile`, `.Rprofile`,
  `renv/activate.R`, and both CI workflows against the current zzcollab
  templates. Specifically check: does `.Rprofile` still contain unsubstituted
  `$UBUNTU_CODENAME` / `$PPM_SNAPSHOT`; does `Makefile` have `snapshot` /
  `style` / `lint`; does the render workflow resolve the renv library with the
  shallow `/opt/renv/library/*/*` glob; does CI pin `zzrenvcheck (>= 0.4.0)`.

Output of Phase A is a per-concern gap list and the resolved parameter table.

## Phase 0. Refresh vendored infrastructure

Bring the four vendored artifacts to the current templates. Adopt the
canonical templates, not another project's copy, so no project-specific cruft
is inherited.

- Dockerfile. If `NEEDS_PDF`, set `FROM rocker/verse:<R_VERSION>@sha256:<digest>`
  (digest-pinned). Keep the single bulk LaTeX warm-up
  (`R -e "tinytex::tlmgr_install(c(...closure...))"`) followed by a smoke-test
  render; do not use lazy per-package discovery. Install only dev tooling that
  is not in the manifest (`languageserver`); analysis packages such as `yaml`
  and `here` come from `renv::restore()`. Set `RENV_CONFIG_REPOS_OVERRIDE` to
  the `UBUNTU_CODENAME`/`PPM_SNAPSHOT` PPM URL.
- Makefile. Replace with the current template so `snapshot`, `style`, and
  `lint` exist. `make snapshot` runs, in the container,
  `renv::hydrate(); renv::snapshot(prompt = FALSE);
  zzrenvcheck::check_packages(auto_fix = TRUE, strict = TRUE)`.
- CI workflows. Adopt the current `r-package.yml` (dependency-manifest gate
  that installs `zzrenvcheck (>= 0.4.0)` and quits non-zero on status `fail`;
  R CMD check library resolved via `renv::paths[['library']]()`) and
  `render-report.yml` (baked library resolved via `renv::paths[['library']]()`
  with a `Sys.glob('/opt/renv/library/*/*/*')[1]` fallback; capability-adaptive
  PDF/HTML). Keep the discovery pattern as-is. If A3 flagged co-equal
  manuscripts skipped by the convention, restructure them to one `report.Rmd`
  per subdirectory rather than broadening the pattern; broadening would also
  render the intentionally excluded draft variants and scripts and would pull
  them all into the Phase 1 de-landmining scope.
- .Rprofile. Regenerate or substitute so the PPM placeholders become literal
  `UBUNTU_CODENAME`/`PPM_SNAPSHOT` values, coherent with the Dockerfile. Note
  the active container hooks: auto-init recreates a bare renv when `renv.lock`
  is absent (which supports Phase 2), auto-restore runs on startup, and the
  `.Last` hook auto-snapshots on exit. Drive Phase 3 through `make snapshot`
  explicitly rather than relying on the exit hook.

## Phase 1. De-landmine analysis and render code

Make the render sealed and the dependencies statically discoverable. These
rules are repo-agnostic.

- Replace `pacman::p_load(a, b, c)` and any render-time
  `install.packages(...)` with explicit `library(a); library(b); library(c)`
  calls. renv's dependency discovery recognises `library()`, `require()`,
  `requireNamespace()`, and `::`, but does not parse `pacman::p_load()` or
  `pak::pak()` argument lists, so a bare pacman-to-pak swap would not fix
  discoverability and pak does not attach packages anyway.
- Where a step genuinely provisions packages (developer setup, seeding a fresh
  lock), use `pak::pak()` rather than `pacman`, consistent with the standard
  toolchain. Provisioning belongs in setup or the Dockerfile, never on the
  render path.
- Vendor into the compendium, or remove, any absolute host-path sources
  (LaTeX preambles, helper R scripts, `knit:` hooks pointing outside the
  repo). Anything the render touches must live inside the image.
- Remove `pacman` from `renv.lock`/`DESCRIPTION` once its last call site is
  gone.

## Phase 2. Reset the lock (recommended)

When the current lock was resolved against a different base image or repo
(for example tidyverse + cloud.r-project.org, now moving to verse + PPM),
regrowing yields a cleaner, version-coherent closure than surgical patching,
and avoids fighting the version-sync gate. Bare the lock (remove `renv.lock`,
or `renv::init(bare = TRUE)`); the `.Rprofile` auto-init recreates a bare renv
on the next container start. Skip this phase only if the existing lock is
already coherent with the target base.

## Phase 3. Build image and regrow the lock

- `make docker-build` (verse base plus the bulk LaTeX warm-up).
- Install packages that the base does not provide (the Phase A4 missing list;
  candidates depend on the repo) via `pak::pak()` or `renv::install()`.
- `make snapshot`. `renv::hydrate()` copies used packages from the image
  site-library into the project library; `renv::snapshot()` writes the lock
  from actual usage; `zzrenvcheck::check_packages()` validates presence and
  version sync. Only packages that are both installed and statically visible
  are captured, which is why Phase 1 precedes this.

## Phase 4. Reconcile DESCRIPTION

Apply the two-layer role convention: packages used by `R/` code go in
`Imports`; packages used only by `analysis/`, tests, or vignettes go in
`Suggests`. Keep compiled-code dependencies (`Rcpp` and its `LinkingTo`) in
`Imports`. Ensure declared version constraints are consistent with the
regrown lock, since `zzrenvcheck (>= 0.4.0)` now enforces this.

## Phase 5. Verify and (conditionally) publish

- Local: `make check`, then `make docker-render` to confirm PDF output.
- CI: confirm R Package Check, the dependency-manifest gate, and Render
  Reports are all green.
- Publish: push only for non-`srv` repos. For `IS_SRV = true`, stop at local
  verification; do not create or push to any remote.

## Convergence check

Re-run Phase A. A converged repo shows: verse base (if `NEEDS_PDF`), no
runtime-install landmines, no unsubstituted `.Rprofile` placeholders, a
`Makefile` with the snapshot loop, CI resolving the renv library via
`renv::paths` with the manifest gate present, and a `renv.lock`/`DESCRIPTION`
pair in which every code-referenced package is both locked and role-declared.
