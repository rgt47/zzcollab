# zzcollab Changelog

Version history for the zzcollab CLI and template framework. R package
release notes are in `NEWS.md`. History prior to the 0.1.0 re-baseline
is archived in `CHANGELOG-2.x.md`.

------------------------------------------------------------------------

## Unreleased

### Added

- `zzc init` now back-fills an existing `~/.zzcollab/config.yaml` to the
  current schema. Older or hand-trimmed configs that lack whole sections
  (`author`, `license`, `r_package`, `style`, `github`) gain those
  sections with their default values and comments, while every value
  already set is preserved. Implemented as an idempotent deep-merge of
  the default skeleton under the existing file
  (`config_backfill_schema`); the merge runs only when a schema key is
  genuinely missing.
- `languageserver` config key (default `true`) and a matching
  feature-wizard checkbox (‘R language server in Docker image
  (in-container LSP)’) install the R language server into the image for
  in-container completion and diagnostics. Opt out with
  `zzc config set languageserver false` for REPL-only workflows.
- `styler` and `lintr` are installed in the image when the code-quality
  feature is active, alongside two new in-container targets:
  `make style` (format R code with styler) and `make lint` (lint R code
  with lintr).
- `publishing` profile (base image `rocker/verse`) for manuscript
  rendering. It renders PDF by default when a LaTeX toolchain is present
  and falls back to HTML otherwise (capability-adaptive); the LaTeX
  package closure is pre-baked into the image at build time, so PDF
  rendering requires no runtime install.
- `make snapshot`: capture code dependencies into `renv.lock` and
  `DESCRIPTION` by running, in the container,
  [`renv::hydrate()`](https://rstudio.github.io/renv/reference/hydrate.html),
  `renv::snapshot(prompt = FALSE)`, and
  `zzrenvcheck::check_packages(auto_fix = TRUE, strict = TRUE)`. The
  R-package CI workflow gains a ‘Validate dependency manifest
  (renv.lock + DESCRIPTION)’ step that fails the build when code
  references a package that is not declared in `DESCRIPTION` or not
  locked in `renv.lock`.
- `auto_github` config key (default `false`) and an init ‘create remote
  now’ wizard checkbox that it pre-selects. `zzc github` now walks up to
  the repository root before creating the remote, so it publishes the
  whole compendium rather than a subdirectory.
- `docs/package-placement-whitepaper.md`: a comprehensive account of
  which packages belong in the Dockerfile versus `renv.lock` versus
  `DESCRIPTION`.

### Changed

- Profile `analysis` renamed to `tidyverse`. `analysis` is retained as a
  deprecated alias.

- `zzc init` identity step no longer silently re-prompts only when
  fields are absent. When name and email are already saved, it displays
  the stored identity and offers an optional update, pre-filling each
  prompt with the current value so a bare Enter keeps it. Because
  `zzc init` is run for every new repository, the default is to keep
  existing values (no prompt churn); only an explicit confirmation walks
  the fields.

### Fixed

- `config_set KEY VALUE --local` (and `zzc init`, which uses it to
  record the archetype) no longer seeds a freshly created project
  `zzcollab.yaml` with an empty `docker.default_profile: ""` stub. The
  placeholder served no purpose — the loader skips empty values and the
  real key is written immediately after — but persisted as a meaningless
  override. The creation template now matches the one used by the
  interactive project prompt (header only).

### Performance

- The LaTeX warm-up for the `publishing` image now bulk-installs the
  package closure in a single `tlmgr` pass, reducing the render image
  build from about 7 minutes to about 2.5 minutes.

------------------------------------------------------------------------

## 0.1.0 — 2026-06-16

Re-baseline. The CLI, the template stamp, and the R package version had
drifted apart (2.8.1, 2.0.0, and 0.9.2 respectively); they are unified
under a single `ZZCOLLAB_VERSION` source of truth in `lib/constants.sh`
and reset to 0.1.0 to mark a new start. The earlier 2.x history is
preserved in `CHANGELOG-2.x.md`.

This release establishes the presence-driven reproducibility-toggle
architecture (see `docs/reproducibility-toggle-plan-whitepaper.md`).

### Added

- `zzc status`: read-only report of the two capture axes (backend,
  environment), the validation toggles, the computed level (L0-L3), and
  the verified stamp, read from a generated `.zzcollab-state` record.
- `zzc verify`: a coherence tier (no build) that confirms the artifacts
  agree with `.zzcollab-state`, and a `--full` reproduction tier that
  rebuilds and tests for level L3.
- `.zzcollab-state`: a generator-written provenance record, emitted by
  both the Dockerfile generator and `zzc init`.

### Changed

- The `Dockerfile`, `.Rprofile`, and the CI workflows (`r-package.yml`,
  `render-report.yml`) self-adapt to artifact presence: install from
  `renv.lock` when present, otherwise from `DESCRIPTION`; the render and
  check workflows fall back to a host environment when no `Dockerfile`
  is present.
- The renv and Docker features toggle symmetrically. `zzc renv` /
  `zzc rm renv` and `zzc docker` / `zzc rm docker` regenerate the
  dependent files and reuse the remembered base image and R version from
  `.zzcollab-state`.
- `zzc doctor` is toggle-aware: `renv.lock` and `Dockerfile` are
  reported as on/off features rather than required files, and
  `doctor --fix` back-fills a missing `.zzcollab-state` from artifact
  presence for repositories created before the record existed.

### Fixed

- `zzc renv` returned a spurious non-zero exit (an unconditional config
  prompt under `set -e`) and left the `.Rprofile` version stamp
  unsubstituted.
- The shell test runner aborted silently on the first failing test; it
  now reports every result.
