# zzcollab CLI Changelog

Version history for the zzcollab bash CLI and template framework (2.x line).
R package release notes are in `NEWS.md`.

---

## 2.8.0 — 2026-06-08

### r-package.yml template (v2.8.0)

- `Sys.glob('renv/library/*/*')[1]` now wrapped in `normalizePath(...,
  mustWork = FALSE)` before being added to `.libPaths()`. The bare glob
  returns a relative path; when `rcmdcheck::rcmdcheck()` spawns `R CMD
  check` in a temp directory, relative library paths resolve to nothing
  and packages installed by `renv::restore()` (e.g. `markdown`,
  `rmarkdown`) are invisible to the vignette-building subprocess. The
  absolute path survives the working-directory change.
- `Rscript --no-init-file` added to the Run R CMD check step, consistent
  with the deployed majority and with the explicit `.libPaths()` setup
  that follows.

### Version alignment

- `ZZCOLLAB_TEMPLATE_VERSION` bumped from `2.5.0` to `2.8.0` to exceed
  the `v2.7.0` stamp previously deployed to all 35 render-report.yml
  files. At `2.5.0`, doctor reported deployed files as forward-newer
  than the template and never offered replacement; at `2.8.0`, doctor
  correctly identifies both workflow files as outdated and offers
  interactive replacement.

---

## 2.5.0 — 2026-06-08

### render-report.yml template (v2.5.0)

- CI now renders manuscripts to **HTML** via
  `output_format = "html_document"` rather than PDF. HTML output validates
  all R code execution and package reproducibility without requiring a
  LaTeX installation inside the Docker container. PDF rendering remains on
  the host using the local xelatex toolchain.
- Removed the `Install TinyTeX on host runner` and
  `Make TinyTeX tree accessible and writable to container` steps entirely.
- Removed the `-v $HOME/.TinyTeX:/opt/tinytex` and `-e PATH=...` bind
  mounts from the `docker run` invocation.
- Renamed artifact from `rendered-manuscripts` / `*.pdf` to
  `rendered-html` / `*.html`.
- The `output_format` argument uses R double-quotes (`"html_document"`)
  rather than single quotes, which is required because the R code is
  wrapped in a `Rscript -e '...'` single-quoted shell argument.
- Version stamp added to template header so `zzc doctor` can track and
  propagate future updates.

### doctor.sh

- Added version-stamp tracking for `.github/workflows/render-report.yml`.
  `zzc doctor` now reports the render-report.yml version alongside
  r-package.yml, Makefile, .Rprofile, and Dockerfile.
- Outdated or missing render-report.yml triggers a `[y/N]` replacement
  prompt (same behaviour as r-package.yml), so the full template body is
  replaced rather than just the stamp line.
- Help text updated to list render-report.yml in the version-stamps
  section.

### security-scan.yml

- `trivy-scan` job marked `continue-on-error: true` so intermittent
  Docker Hub pull timeouts do not block other CI jobs.
- Docker build step gains a 3-attempt retry loop with a 30-second
  backoff between attempts.
- Step-level `timeout-minutes: 15` added to bound worst-case wall time.

---

## 2.4.0 and earlier

See git log for pre-CHANGELOG history.
