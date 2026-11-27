# zzcollab Changelog

Version history for the zzcollab CLI and template framework. R package
release notes are in `NEWS.md`. History prior to the 0.1.0 re-baseline is
archived in `CHANGELOG-2.x.md`.

---

## Unreleased

### Fixed

- **`make docker-build PLATFORM=...` now builds for that platform.** The
  Makefile documented 'Override with make PLATFORM=linux/amd64', but the
  build (`zzc rebuild`) chose `--platform` from `uname -m` and ignored
  it, so an amd64 image could not be built through `make` on an arm64
  Mac, and the build and later `make r` could disagree. An explicit
  `PLATFORM` (command line or environment) is now passed to the build
  as `ZZCOLLAB_PLATFORM`, honored by both the build and its cache key;
  the auto-detected default is not passed, so the build still chooses
  per base image. Requesting arm64 for `rocker/verse` (amd64 only) is
  refused. A native arm64 build warns that CI builds `linux/amd64` and
  names the CI-matching command.
- **Run targets match a `rocker/verse` image on arm64 hosts.** The
  `PLATFORM` default was `linux/arm64` on any arm64 host, while a verse
  image is always built `linux/amd64`, so `make r` and the other run
  targets requested a platform the local image did not have. The
  default now follows the Dockerfile's base image. `make docker-rstudio`,
  which omitted `--platform`, now passes it like the other run targets.
- **An unresolved base-image digest stops Dockerfile generation.** When
  the pull failed (Docker absent, daemon down, no network),
  `generate_dockerfile` logged a warning and wrote a tag-only `FROM`,
  so the project looked pinned but was not. It now refuses and writes
  nothing; the new global flag `--allow-unpinned`
  (`ZZCOLLAB_ALLOW_UNPINNED=true`) writes the tag-only `FROM` with a
  warning for deliberate offline use, and `tooling.lock` records
  `base_image_digest: null`. `zzc verify` warns on any tag-only `FROM`.
  Commands that regenerate the Dockerfile in passing (`zzc renv`, `zzc
  update`) keep the existing Dockerfile and warn when this happens.
- **zzrenvcheck is pinned, and `tooling.lock` tells the truth about
  it.** `tooling.lock` recorded `rgt47/zzrenvcheck@v0.3.1`, but the
  image never installed zzrenvcheck: `make ensure-zzrenvcheck` (and
  `make r`'s post-session install) installed GitHub `main` unpinned,
  requiring only `>= 0.9.0`. The default tag is now `v0.11.0`; the
  Makefile reads the tag from the project's `tooling.lock` and installs
  exactly that release, replacing any other installed version, so the
  record and the tool that runs agree. `tooling.lock` now states that
  the tool is installed by `make ensure-zzrenvcheck`, not into the
  image. Unused `zzrenvcheck_tag`/`zzrenvcheck_version` variables in the
  Dockerfile generator, and a generated comment naming a nonexistent
  `make install-zzrenvcheck` target, are removed.
- **Generated Dockerfiles pin OpenBLAS and MKL threads.** Only
  `OMP_NUM_THREADS=1` was set, which does not reach pthreads builds of
  OpenBLAS or MKL; `OPENBLAS_NUM_THREADS=1` and `MKL_NUM_THREADS=1` are
  now set too, so their reduction order, and hence floating-point
  results, does not depend on the host's core count.
- **`zzc verify` reports a malformed `renv.lock` instead of aborting.**
  The validity check's nonzero return ended `verify` under `set -e`
  before its result could be reported.

- **Test gates fail when no expectation ran.** `TINYTEST_RUN` (both
  Makefiles, so `make test`, `make docker-test`, `make test-container`,
  and `zzc verify --full`) and the test steps in `r-package.yml` and
  `.gitlab-ci.yml` exited 0 for a suite whose files ran no expectation,
  because `all(logical(0))` is `TRUE`. They now print 'No expectations
  ran' and exit 1. Scaffolded projects ship `inst/tinytest/test-basic.R`
  with one unconditional expectation, so a new project still passes.
- **GitLab test steps are blocking.** Both test steps in
  `.gitlab-ci.yml` ended in `|| echo "tests reported failures
  (non-blocking)"`, so a failing suite never failed the pipeline. The
  suffix is removed.
- **`zzc verify` credits a baseline only when it compared something.**
  L3 was awarded when a `test-baseline*.R` file name appeared in the test
  log; a file that called `exit_file()` before any comparison is listed
  there with '0 tests'. A baseline now counts only when its final log
  line shows at least one test and no '[Exited at' marker, so a file
  that exits part way also leaves the result at L2.
- **`zzc verify` coherence no longer aborts on generated Dockerfiles.**
  The R-version check read `ARG R_VERSION=`, which generated Dockerfiles
  no longer write. The failed `grep` ended an assignment with status 1
  under `set -e`, so with a `renv.lock` present `zzc verify` exited 1
  mid-check, and the Dockerfile side of the comparison could never be
  read. The version is now taken from the `FROM <image>:<version>` tag
  (the `ARG` is still read for older Dockerfiles), so a Dockerfile whose
  R version disagrees with `renv.lock` fails coherence. `zzc doctor`
  reads the same tag when there is no `renv.lock`, and its state
  back-fill no longer aborts under `set -euo pipefail` when a read finds
  nothing (for example a `renv.lock` without an `R` section).
- **`make lint` fails when lintr reports anything.** It printed the
  lints and exited 0, so it could not serve as a gate. It now exits 1
  when any lint remains in `R/` or `analysis/`; the new `make
  lint-report` keeps the old print-only behavior. A project whose code
  has outstanding lints will see `make lint` fail after `zzc doctor
  --force` refreshes its Makefile.

### Changed

- **`make check-renv` no longer edits files; `make fix-renv` repairs.**
  `check-renv`, `check-renv-no-strict`, and `check-renv-slim` ran
  `zzrenvcheck` with `auto_fix = TRUE`: they rewrote `DESCRIPTION` and
  `renv.lock` and then passed, which made the target users reach for
  unsuitable as a CI or pre-commit gate. They now run with
  `auto_fix = FALSE, error_on_fail = TRUE`, edit nothing, exit nonzero
  on any finding, and name the matching repair target (`fix-renv`,
  `fix-renv-no-strict`, or `fix-renv-slim`). The repairing
  behavior moves to `fix-renv`, `fix-renv-no-strict`, and
  `fix-renv-slim`. `check-renv-no-fix` remains as a deprecated alias of
  `check-renv`; `docker-check-renv` and `docker-check-renv-fix` alias
  `check-renv` and `fix-renv`. `make r`'s post-session validation, which
  relies on the repair, now calls `fix-renv` when the host has no R.
  `zzc validate` already defaulted to no auto-fix and is unchanged.
  **Behavior change for existing projects:** after `zzc doctor --force`
  refreshes the Makefile, `make check-renv` fails where it used to
  repair silently; run `make fix-renv` instead.
- **Dependency checks skip a bare compendium.** `zzc init --bare`
  omits `DESCRIPTION` by design, and zzrenvcheck (from the release that
  fails a project without `DESCRIPTION`) cannot validate one. The
  `check-renv*`, `fix-renv*`, `snapshot` (its check step), and
  `reset-lock` targets, `make r`'s post-session hook, `zzc validate`,
  and `zzc verify` now detect a missing `DESCRIPTION` and report
  'No DESCRIPTION (bare compendium): dependency check skipped' with
  exit 0, instead of failing or passing silently. `ensure-zzrenvcheck`
  does not install the tool for a bare project. `zzc verify` also now
  runs the dependency check in the verified directory rather than the
  caller's working directory.

- `render-report.yml` is part of a workspace's expected workflow set only
  when the workspace has a report, defined once in `zzc_has_report`
  (`lib/core.sh`): an `.Rmd` or `.qmd` file in `analysis/report/`, a
  `report.Rmd` anywhere under `analysis/`, or an `.Rmd` in
  `analysis/posts/`. Previously every non-book, non-blog workspace
  received it; five R-package repositories with no report spent about
  three minutes per CI run installing R and dependencies to log
  'Found 0 manuscripts to render'. `zzc_workflow_pairs` and
  `zzc_workflow_expected` take an optional workspace directory. `zzc init`
  scaffolds the archetype's report before installing workflows, so a
  manuscript or analysis workspace still gets the render workflow and a
  `package` or `simulation` workspace does not. `zzc toggle` and
  `zzc add cicd` follow the same rule; enabling CI without a report offers
  to scaffold `report.Rmd` before the workflows are installed, so
  accepting it also installs the render workflow. `zzc doctor` no longer
  reports `render-report.yml` as missing when there is no report, and
  reports a copy found without a report as unneeded (informational, not
  counted as an issue, and not deleted). `zzc status` shows
  `CI render off (no report)` or `on (no report: unneeded)` in those
  cases, distinct from `off` when a report exists but the workflow is
  missing. When neither an R package nor a report applies, no empty
  `.github/workflows/` directory is created.
- `r-package.yml`, `render-report.yml`, and `render-book.yml` set
  `GITHUB_PAT` from the workflow's `GITHUB_TOKEN`, so renv and pak
  resolve GitHub-hosted packages with the authenticated API rate limit
  rather than the 60-request hourly limit per runner IP. The token is not
  passed into `docker build`, so container image restores remain
  unauthenticated.
- `render-report.yml` reads an optional `timeout:` (minutes, default 120)
  from `.github/report-ci.yml` and applies it to every render step, so a
  hung render fails in bounded time instead of holding the runner for the
  6-hour job limit. A non-integer value fails the job with an annotation.
- `render-book.yml` uses `actions/cache@v6` (v4 runs on the deprecated
  Node 20 runtime).

### Fixed (zzc update pins)

- `zzc update` regenerated the Dockerfile from the `renv.lock` R version,
  the config profile, and today's Posit snapshot, ignoring the pins in
  `.zzcollab-state`. On a publishing project it could swap `rocker/verse`
  for `rocker/tidyverse` (dropping TeX Live), downgrade R, and re-pin every
  package, despite the help text promising to keep the snapshot. It now
  takes the base image, R version, and snapshot from `.zzcollab-state`,
  falling back to the `.Rprofile` snapshot for projects without one.

### Fixed (r-package.yml package repository)

- The container check job in `r-package.yml` restored packages from
  Posit's `noble/latest` binaries even when the project's Dockerfile pins a
  dated snapshot, so the check could run against a different library than
  the image. Binaries are rebuilt against current dependencies: in
  missforest, `Rfast 2.1.5.2` from `latest` is compiled against
  `RcppParallel 6.2.1`, and failed to load (undefined TBB symbol) beside the
  `RcppParallel 5.1.11-2` that the lockfile pins to match its 2026-06-29
  image. The job now takes the snapshot date from the Dockerfile's Posit
  URL and uses `noble/<date>`, falling back to `noble/latest` when the
  Dockerfile pins none or is absent. The renv cache key includes the
  repository, so a cache filled from one snapshot does not seed another.

### Fixed

- The shell test suite can no longer write to the owner's real
  `~/.zzcollab/config.yaml`. A new `tests/shell/test_isolation.sh`, sourced
  by `test_helpers.sh` (so every `test-*.sh` run on its own) and by
  `run_all_tests.sh`, points `HOME`, `ZZCOLLAB_CONFIG_USER_DIR`,
  `ZZCOLLAB_CONFIG_USER`, the `XDG_*` directories, and `GIT_CONFIG_GLOBAL`
  into a per-process temp dir before any module loads, and removes it on
  exit. It also records the real config's checksum and mtime (from the
  pre-isolation `HOME`) and fails the run with exit 3 if either changed.
  The leak was in `test-config.sh`: `CONFIG_USER` is readonly once
  `modules/config.sh` loads, so its `export CONFIG_USER=<temp>` lines failed
  and the fixtures and `config_set` calls wrote the real config. Those
  tests now write to the sandboxed `$CONFIG_USER`. `run_all_tests.sh` no
  longer aborts under `set -e` at the first failing suite, so it reports
  every suite and its summary.
- `render-book.yml` (book archetype) consolidates the fixes that had been
  applied piecemeal across downstream books, so one unedited workflow
  serves every book. R packages now install only from Posit's binary
  repository (an explicit CRAN `repos` forced source builds, and `fs`
  failed to compile for want of libuv headers, leaving `rmarkdown`
  uninstalled); a verify step, run with the project `.Rprofile` loaded
  as Quarto's own R session is, fails the job by name when a required
  package is missing, since `install.packages()` only warns. Books
  without a `renv.lock` install `knitr`, `rmarkdown`, and any
  `DESCRIPTION` dependencies with pak (plus `downlit` and `xml2` when
  `code-link` is on). renv books restore into the runner library with
  system requirements looked up per lockfile package (without
  re-solving the lockfile, which failed on GitHub-sourced and
  recommended packages), and the renv autoloader is disabled for the
  rest of the job so a plain `source("renv/activate.R")` profile cannot
  switch the render session to an empty project library. Install
  sessions run with `--no-init-file`, since the zzcollab `.Rprofile`
  sets CRAN source as the repository on a host. Engine detection matches only chunk fences at the
  start of a line, so a chunk header quoted in prose no longer
  provisions R. The workflow also gains the PDF edition (TinyTeX, a
  single all-format render, the 'Latest PDF' release) when a `pdf`
  format is declared, Chrome Headless Shell for Mermaid in PDF, a job
  timeout (90 min) and render timeout (30 min) in place of GitHub's
  360-minute default, a concurrency group, full-history checkout, a
  weekly scheduled run, and current action majors. Per-book differences
  move to an optional `.github/book-ci.yml` (`quarto`, `engines`, `apt`,
  `backend`) and optional `tools/ci/pre-render` and `tools/ci/post-deploy`
  hooks. Verified on 2026-11-11 across 13 Quarto books (prose, knitr
  with and without renv, Jupyter, Mermaid, and a Dockerfile book on the
  host backend): every pull request and deploy run passed.
- One GitHub workflow set per archetype, defined once
  (`zzc_workflow_pairs` in `lib/core.sh`) and used by `zzc init`, the CI
  toggle, `zzc doctor`, and `zzc update`: a book carries
  `render-book.yml`, a blog post `blog-render.yml`, and every other
  compendium `r-package.yml` (omitted for `--bare`) and
  `render-report.yml`. Blog posts previously received `r-package.yml` and
  `render-report.yml` from `zzc init`, although 58 of 67 existing posts
  ran `blog-render.yml` alone; `R CMD build` of a post followed its
  dangling root `figures` symlink and failed. Workspaces that record no
  archetype are classified by the workflow they already carry, and
  `zzc_ci_forge` recognizes any of the four workflows, not only
  `r-package.yml`.
- `blog-render.yml` was invalid: its `check-deps` job called `hashFiles()`
  in a job-level `if`, which GitHub rejects, so every push failed at
  startup. The job is removed (the render already fails on a missing
  package), and the workflow gains the template version header, job and
  step timeouts, a concurrency group, and current action majors.
- `render-report.yml` reads an optional `.github/report-ci.yml` for
  reports whose data is not in git: `render: skip` skips every render
  step, `skip:` lists reports (paths or globs) to leave out, and `reason:`
  is shown in the run notice. The environment is still built and checked,
  and each skip is reported as a notice and in the step summary.
- The `r-package.yml` test step loads the package (`pkgload::load_all()`,
  or a temporary-library install where pkgload is absent) before
  `tinytest::run_test_dir()`, which does not load it. Without this, any
  test calling a package function failed with 'could not find function'.
  Deployed copies hid failures of this step behind `continue-on-error`:
  on 2026-11-12 the latest run of 34 of 71 such repositories had failed
  it (the one log examined, zzpower's, failed for this reason).
- `r-package.yml` runs an optional `tools/ci/pre-check` script before
  `R CMD check`, for per-repository setup (zzedc warms its DuckDB `icu`
  extension there) that previously required editing the workflow.
  `render-report.yml` installs libcurl, OpenSSL, and libxml2 headers on
  the host backend, a fix three package repositories had applied to their
  own copies.
- Test targets are gates. `make test`, `make docker-test`, and the cached
  `.make/tests-passed` target now exit nonzero when any tinytest assertion
  fails; `tinytest::run_test_dir()` returns results rather than signalling,
  so these targets previously exited 0 (and the cached target stamped a
  pass) on failing tests. The CI template no longer marks the test steps
  `continue-on-error`.
- `zzc verify --full` stamps L3 only when the image rebuilds, the suite
  passes, and a baseline test (`inst/tinytest/test-baseline*.R`) exists and
  ran. Otherwise it reports "rebuilt and tested (L2); no baseline
  comparison, so not L3". A `--full` run that does not reach L3 removes any
  earlier `verified=` stamp, and the stamp is written to the target
  directory's `.zzcollab-state` rather than the current directory's.
- `get_ubuntu_codename()` (and `templates/tools/check-binaries.py`) now
  follow rocker/r-ver's actual bases: focal to 4.2.1, jammy 4.2.2 to
  4.4.1, noble from 4.4.2. R 4.4.0 and 4.4.1 were mapped to noble, so the
  generated Dockerfile pointed PPM at binaries built for a different
  Ubuntu release than the image.
- The generated Dockerfile sets `OMP_NUM_THREADS=1`.
- The generated Dockerfile no longer embeds a build timestamp. The
  `org.opencontainers.image.created` label was written at generation time,
  so regenerating the file changed its text, and any hash of it (such as a
  simrun image tag), even when nothing else had changed. `zzcollab rebuild`
  now adds that label at build time instead. The default package snapshot
  ('one day ago') is still computed at generation time; set `PPM_SNAPSHOT`
  to pin it.
- `make sh` and `make r` pass `--no-home` to Apptainer, so the host home
  directory (its `~/.Rprofile`, user library and caches) is no longer
  mounted into the container. The project folder is still bound through the
  working directory. Not yet run against a real Apptainer install; renv's
  cache under `$HOME` may need a writable location in that mode.
- R started in a project subfolder now loads the project `.Rprofile`.
  `make sh` sets `R_PROFILE_USER` to the root profile, which runs from the
  project root while it executes and then restores the starting directory.
  Previously R read `./.Rprofile` only from the folder it started in, so a
  session opened in `analysis/scripts` skipped the profile entirely.
- Dependency gates pass `error_on_fail = TRUE` to
  `zzrenvcheck::check_packages()` (`check-renv-no-fix`, `zzc verify`'s
  advisory check, which previously always reported a pass), and
  `ensure-zzrenvcheck` upgrades installs older than zzrenvcheck 0.9.0.
  The pre-session check in the repository Makefile's `r` target only
  reports.

### Added

- New projects get a `.gitkeep` in `analysis/` subfolders (and `docs/`)
  that are still empty when setup ends, so a clone keeps the folders that
  scripts write into (`derived_data/`, `figures/`, `tables/`).
- Declarative archetype scaffolding. Per-archetype scaffolding is now driven
  by an `archetype_spec` table and a single engine (`apply_archetype_scaffold`)
  with `_scaffold_*` entry functions, replacing ad-hoc conditionals. Adds the
  missing symlink primitive (`create_archetype_symlinks`): `blog` is now a
  single-post compendium with `analysis/report/index.qmd` surfaced at the root
  via an `index.qmd` symlink plus `data`/`figures`/`media` symlinks (matching
  real usage); `analysis` scaffolds a Quarto `index.qmd` (report.Rmd is now
  manuscript-only); `book` is standalone with its own `media/images`. New
  `--bare` flag (env `ZZCOLLAB_BARE`) omits the R-package skeleton and its CI
  workflow for prose-only compendia.
- `book` research archetype for multi-chapter Quarto books. `zzc init
  --archetype book` scaffolds `analysis/book/` with a book-type `_quarto.yml`,
  a preface (`index.qmd`), a first chapter, and `references.bib`; the book is
  excluded from the single-`report.Rmd` scaffold since it renders as a Quarto
  project. Adds a `docker-render-book` Makefile target and a container-backend
  step in `render-report.yml` that runs a project-level `quarto render`. The
  generated image now bakes a cwd-independent `.libPaths()` shim into
  `Rprofile.site` so the renv library is visible to the R sessions `quarto
  render` spawns inside `analysis/book/` (which has no project `.Rprofile`).
- `zzc init` now back-fills an existing `~/.zzcollab/config.yaml` to the
  current schema. Older or hand-trimmed configs that lack whole sections
  (`author`, `license`, `r_package`, `style`, `github`) gain those sections
  with their default values and comments, while every value already set is
  preserved. Implemented as an idempotent deep-merge of the default skeleton
  under the existing file (`config_backfill_schema`); the merge runs only when
  a schema key is genuinely missing.
- `languageserver` config key (default `true`) and a matching feature-wizard
  checkbox ('R language server in Docker image (in-container LSP)') install the
  R language server into the image for in-container completion and diagnostics.
  Opt out with `zzc config set languageserver false` for REPL-only workflows.
- `styler` and `lintr` are installed in the image when the code-quality feature
  is active, alongside two new in-container targets: `make style` (format R code
  with styler) and `make lint` (lint R code with lintr).
- `publishing` profile (base image `rocker/verse`) for manuscript rendering.
  It renders PDF by default when a LaTeX toolchain is present and falls back to
  HTML otherwise (capability-adaptive); the LaTeX package closure is pre-baked
  into the image at build time, so PDF rendering requires no runtime install.
- `make snapshot`: capture code dependencies into `renv.lock` and `DESCRIPTION`
  by running, in the container, `renv::hydrate()`, `renv::snapshot(prompt =
  FALSE)`, and `zzrenvcheck::check_packages(auto_fix = TRUE, strict = TRUE)`.
  The R-package CI workflow gains a 'Validate dependency manifest (renv.lock +
  DESCRIPTION)' step that fails the build when code references a package that is
  not declared in `DESCRIPTION` or not locked in `renv.lock`.
- `auto_github` config key (default `false`) and an init 'create remote now'
  wizard checkbox that it pre-selects. `zzc github` now walks up to the
  repository root before creating the remote, so it publishes the whole
  compendium rather than a subdirectory.
- `docs/package-placement-whitepaper.md`: a comprehensive account of which
  packages belong in the Dockerfile versus `renv.lock` versus `DESCRIPTION`.

### Changed

- Profile `analysis` renamed to `tidyverse`. `analysis` is retained as a
  deprecated alias.

- `zzc init` identity step no longer silently re-prompts only when fields are
  absent. When name and email are already saved, it displays the stored
  identity and offers an optional update, pre-filling each prompt with the
  current value so a bare Enter keeps it. Because `zzc init` is run for every
  new repository, the default is to keep existing values (no prompt churn);
  only an explicit confirmation walks the fields.

### Fixed

- `config_set KEY VALUE --local` (and `zzc init`, which uses it to record the
  archetype) no longer seeds a freshly created project `zzcollab.yaml` with an
  empty `docker.default_profile: ""` stub. The placeholder served no purpose —
  the loader skips empty values and the real key is written immediately after —
  but persisted as a meaningless override. The creation template now matches
  the one used by the interactive project prompt (header only).
- `tools/render.sh` (via `stamp-render.R`) no longer fails on `.qmd` files
  inside a Quarto project. It looked only for `<file>.pdf` beside the source,
  but Quarto writes project output under the project's `output-dir`, and a
  book renders every chapter into one PDF whichever chapter is named. The
  stamp now finds the new PDF under the output directory when it is not beside
  the source, and for a book it names the book (its project directory in the
  footer, its PDF title in the staged filename) rather than the chapter.
  Tested on a book chapter, a standalone document, and a website page.

### Performance

- The LaTeX warm-up for the `publishing` image now bulk-installs the package
  closure in a single `tlmgr` pass, reducing the render image build from about
  7 minutes to about 2.5 minutes.

---

## 0.1.0 — 2026-06-16

Re-baseline. The CLI, the template stamp, and the R package version had
drifted apart (2.8.1, 2.0.0, and 0.9.2 respectively); they are unified under a
single `ZZCOLLAB_VERSION` source of truth in `lib/constants.sh` and reset to
0.1.0 to mark a new start. The earlier 2.x history is preserved in
`CHANGELOG-2.x.md`.

This release establishes the presence-driven reproducibility-toggle
architecture (see `docs/reproducibility-toggle-plan-whitepaper.md`).

### Added

- `zzc status`: read-only report of the two capture axes (backend,
  environment), the validation toggles, the computed level (L0-L3), and the
  verified stamp, read from a generated `.zzcollab-state` record.
- `zzc verify`: a coherence tier (no build) that confirms the artifacts agree
  with `.zzcollab-state`, and a `--full` reproduction tier that rebuilds and
  tests for level L3.
- `.zzcollab-state`: a generator-written provenance record, emitted by both the
  Dockerfile generator and `zzc init`.

### Changed

- The `Dockerfile`, `.Rprofile`, and the CI workflows (`r-package.yml`,
  `render-report.yml`) self-adapt to artifact presence: install from
  `renv.lock` when present, otherwise from `DESCRIPTION`; the render and check
  workflows fall back to a host environment when no `Dockerfile` is present.
- The renv and Docker features toggle symmetrically. `zzc renv` / `zzc rm renv`
  and `zzc docker` / `zzc rm docker` regenerate the dependent files and reuse
  the remembered base image and R version from `.zzcollab-state`.
- `zzc doctor` is toggle-aware: `renv.lock` and `Dockerfile` are reported as
  on/off features rather than required files, and `doctor --fix` back-fills a
  missing `.zzcollab-state` from artifact presence for repositories created
  before the record existed.

### Fixed

- `zzc renv` returned a spurious non-zero exit (an unconditional config prompt
  under `set -e`) and left the `.Rprofile` version stamp unsubstituted.
- The shell test runner aborted silently on the first failing test; it now
  reports every result.
