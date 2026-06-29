# zzrenvcheck Validation: Regression Analysis and Remediation Plan
*2026-06-28 17:41 PDT*

## Purpose

zzcollab delegates package-dependency validation to the `zzrenvcheck` R
package. The current wiring is broken in several coupled ways. This document
records what is wrong, the intended design, and a phased plan to reach it.
It is a planning artifact, separate from the Dockerfile build-time
optimization (PR #28), which it does not touch.

## Current state

zzrenvcheck performs a three-way consistency check (the dependency triad):
the packages used in code, the packages declared in `DESCRIPTION`, and the
packages pinned in `renv.lock` must agree. Its single entry point is
`zzrenvcheck::check_packages()`. It is invoked from four places:

- `zzc validate` (`zzcollab.sh`), on the host.
- `zzc verify` (`modules/verify.sh`), on the host.
- the `make check-renv*` targets (`templates/Makefile`), inside the
  container via `DOCKER_RUN`.
- the `make r` post-session validation (`templates/Makefile`), on the host.

It is also referenced by `tooling.lock` (which pins `rgt47/zzrenvcheck@v0.3.1`)
and by a comment in the generated Dockerfile.

## Problems

1. **zzrenvcheck is not installed in the image (regression).** Commit
   `7d5d3ca` installed it in the generated Dockerfile via
   `remotes::install_github('rgt47/zzrenvcheck@...')`. The auto-backup commit
   `05c033b` (2026-06-06) removed that `RUN` and replaced it with a comment
   stating the package is 'installed post-build via make install-zzrenvcheck'.
   That removal was never completed.

2. **The referenced make target does not exist.** No `install-zzrenvcheck`
   target is present in the template Makefile or in scaffolded projects. The
   Dockerfile comment points at a command that was never created.

3. **In-container validation therefore fails.** The `make check-renv*`
   targets run `zzrenvcheck::check_packages()` inside the container via
   `DOCKER_RUN`, but the package is absent from the image, so they error with
   'there is no package called zzrenvcheck'. (Inspected, not executed.)

4. **The host validation paths assume host R, breaking independence.**
   zzcollab is designed to require no R on the host. The `make r`
   post-session validation, and `zzc validate` / `zzc verify`, run bare
   `Rscript` on the host. With no host R, the `make r` path takes its
   else-branch, prints the misleading 'zzrenvcheck not installed on host'
   (the real gap is R itself), offers an install that also cannot run, and
   skips validation. `make r` does not crash (guards absorb the failure), but
   no validation occurs.

5. **Documentation is stale.** The project `CLAUDE.md` still states that
   zzrenvcheck 'is installed into the image via remotes::install_github(...)
   in the generated and template Dockerfiles', describing the pre-`05c033b`
   design.

6. **The dependency is GitHub-only.** zzrenvcheck is not on CRAN or PPM, so
   installing it in the image means a GitHub fetch during the build, the
   network and cloud-filesystem fragility that motivated the `05c033b`
   removal. There is currently no binary install path.

## Target design

- zzrenvcheck is published to CRAN, and therefore mirrored by Posit Package
  Manager, so it installs as a precompiled binary in-container exactly like
  every other dependency: no GitHub at build time, no host R.
- The image installs zzrenvcheck from the pinned PPM snapshot during the
  build.
- All validation runs in-container via `DOCKER_RUN`: `make check-renv*`, the
  `make r` post-session validation, and the `zzc validate` / `zzc verify`
  paths. None require R on the host.
- The Dockerfile comment, the non-existent make target, `tooling.lock`, and
  `CLAUDE.md` are reconciled with the implemented behaviour.

## Plan

### Phase 0: CRAN readiness (done)

`R CMD check --as-cran` on `08-zzrenvcheck/zzrenvcheck` returns 0 errors, 0
warnings, 1 note (the standard 'New submission' note; a second, local-only
'HTML Tidy' note does not occur on CRAN). DESCRIPTION is CRAN-clean (GPL-3,
CRAN-only Imports `desc`/`jsonlite`/`cli`, no `Remotes`). A 'renv vs
zzrenvcheck' vignette and `cran-comments.md` have been prepared.

### Phase 1: Submit zzrenvcheck to CRAN

- Run multi-platform checks (win-builder devel and release, R-hub).
- Finalize the version and `NEWS`; remove the stale root tarball.
- Submit; respond to any CRAN feedback.

### Phase 2: Install zzrenvcheck from PPM in the image

- Once zzrenvcheck is on CRAN (and so on PPM), replace the stale comment in
  `generate_dockerfile_inline` with an actual install from the dated PPM
  snapshot (binary), alongside the other tooling installs.
- Remove the `remotes::install_github` references and the `tooling.lock`
  GitHub pin, or repoint them at the CRAN version.

### Phase 3: Make all validation in-container

- Change the `make r` post-session validation to run via `DOCKER_RUN`, not
  host `Rscript`; drop the host install prompt and the misleading message.
- Review `zzc validate` and `zzc verify`: run validation in the container,
  or clearly mark host execution as an explicit, optional convenience.
- Update `CLAUDE.md` to describe the implemented design.

### Interim stopgap (only if needed before Phase 1 completes)

Restore the in-build `remotes::install_github('rgt47/zzrenvcheck@v0.3.1')` in
the generator. This unbreaks in-container `check-renv` immediately at the
cost of a GitHub fetch during the build. It is a revert to the pre-`05c033b`
behaviour and should be removed once Phase 2 lands.

## Out of scope

- The Dockerfile build-time optimization (PR #28). This plan and that PR are
  independent.

## Verification

- Phase 1: clean multi-platform checks; CRAN acceptance.
- Phase 2: a built image contains zzrenvcheck (`requireNamespace` succeeds
  in-container) installed as a binary, with no GitHub access during the
  build.
- Phase 3: `make check-renv` and the `make r` post-session validation both
  succeed on a host with no R installed.
