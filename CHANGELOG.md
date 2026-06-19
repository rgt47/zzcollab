# zzcollab Changelog

Version history for the zzcollab CLI and template framework. R package
release notes are in `NEWS.md`. History prior to the 0.1.0 re-baseline
is archived in `CHANGELOG-2.x.md`.

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
