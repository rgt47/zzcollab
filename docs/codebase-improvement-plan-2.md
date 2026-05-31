# zzcollab Codebase Improvement Plan (Round 2)
*2026-05-31 09:58 PDT*

Second-round review of the codebase after the Round 1 cleanup (P0-P5 of
`codebase-improvement-plan.md`) and the template-machinery fixes. Findings
were produced by four parallel review agents over disjoint surfaces (the bash
CLI core, the bash modules, the R package, and templates/CI/tests) and
cross-referenced by repo-wide grep. Epistemic status: every Priority 0 item
below was independently re-verified by the orchestrator (grep + file
inspection); dead-code and stale-file claims are grep-verified against all
generators and call sites; efficiency claims are inferred from structure, not
profiled; test-quality claims are from reading, not from a coverage run. No
code was executed end to end.

One Priority 0 item (CI step running a deleted test) is a regression
introduced by the Round 1 cleanup itself.

## Priority 0: Correctness and CI-breaking defects (fix first)

1. **CI runs a deleted test (regression from Round 1).**
   `.github/workflows/shell-tests.yml:32` runs
   `bash tests/shell/test-validation.sh`, which was deleted in Round 1 (P1).
   The step fails on every push/PR to main/develop. The Round 1 work updated
   `shellcheck.yml` but missed this second workflow. Remove the step;
   `run_all_tests.sh` already globs `test-*.sh`.

2. **Integration CI matrix tests non-existent profiles.**
   `.github/workflows/integration-tests.yml:26,28` includes `publishing` and
   `shiny` in the profile matrix. Only `minimal`/`analysis`/`rstudio` exist;
   the dropped names fall through to the unknown-command handler, so those
   matrix legs fail or assert nothing. Reduce the matrix to the three real
   profiles.

3. **R `create_pr()` shell-injection on `base`.** `R/git.R:73`
   `paste('gh pr create --title', shQuote(title), '--base', base)` quotes
   `title`/`body` but not `base`. A crafted `base` injects shell. shQuote it.

4. **R `create_pr()` can skip its CLI-availability check.** `R/git.R:64`
   gates the `which gh` check on `!nzchar(system.file(package = 'gh'))`. The
   intent is the **gh CLI**, but `system.file(package='gh')` probes for an R
   package named `gh`; if that unrelated CRAN package is installed, the whole
   CLI check is skipped. Drop the wrapper and gate on the CLI directly
   (`nzchar(Sys.which('gh'))`).

5. **`cmd_quickstart` advertises a non-existent command.** `zzcollab.sh:1234`
   prints `To rebuild:  zzc docker --force`, but `cmd_docker` has no `--force`
   case (and `main`'s docker arg-loop does not recognise it). The instruction
   is broken. Replace with a real command (`zzc rebuild --no-cache` or
   `zzc docker -b`).

6. **Vacuous CI assertions.** `integration-tests.yml:515-516` greps the
   generated Makefile for `docker-run`/`docker-r`, which match
   `docker-rstudio`/`docker-render` by substring and so pass regardless;
   `tests/run-all-tests.sh:117-119` evaluates `$?` after an assignment under
   `set -e`, masking or aborting on failures; the non-verbose path discards
   all R test output. These let real failures pass silently. Assert on real
   target names and capture output once.

## Priority 1: Dead code removal

All call-site claims grep-verified.

- **`modules/cli.sh`.** `require_arg()` (zero call sites, only its own
  doc/comment + a test); the three flags `USER_PROVIDED_BASE_IMAGE`,
  `USER_PROVIDED_LIBS`, `USER_PROVIDED_PKGS` (never read/written);
  `BUILD_DOCKER` (set, never read).
- **`modules/config.sh`.** `USER_PROVIDED_R_VERSION` is write-only (set in
  `apply_config_defaults`, read nowhere). The `LIBS_BUNDLE`/`PKGS_BUNDLE`
  chain is vestigial (bundles were collapsed into the three profiles):
  the vars, their `CONFIG_*` siblings, the two `apply_config_defaults` lines,
  the `_CONFIG_MAP` rows, and `list_library_bundles`/`list_package_bundles`
  if `zzc list libs/pkgs` is no longer advertised.
- **Config-template keys that cannot round-trip.** `_create_default_config`
  writes `r_package.language`, `style.indent_size`, `style.naming_convention`,
  `docker.default_base_image`, `docker.platform`, `github.create_issues`,
  `github.create_wiki` to disk, but none are in `_CONFIG_MAP`, so
  `config get` can never read them back. Drop from the template or add map
  rows. (Round 1 removed these from the loader; the default-writer still
  emits them.)
- **`modules/docker.sh`.** The empty `# R VERSION DETECTION` banner (orphan
  from removed R-version probing).
- **R package.** `validate_path()` (`R/utils.R`) is never called by any
  package code; it exists only to be tested (~45 lines of tests). Either
  delete it and its tests, or wire it into `run_script`/`render_report`
  (which take path args but use bare `file.exists`). `desc` and `BiocManager`
  in Suggests are unused (no `desc::` calls; `BiocManager` only in vignette
  comments).
- **`lib/templates.sh` / `lib/core.sh`.** Leftover stub/banner comments with
  no following code (`# Validate core library is loaded`, the
  `TEMPLATES LIBRARY VALIDATION` banner, the duplicate
  `CORE LIBRARY VALIDATION` header, trailing `# Set ... loaded flag` lines).
- **Stale template files (none installed by any generator; verified against
  `install_template`/`copy_template_file`/`get_workflow_template`).**
  Eight unused workflow templates in `templates/workflows/`
  (`analysis-paradigm.yml`, `manuscript-paradigm.yml`, `package-paradigm.yml`,
  `r-package-minimal.yml`, `render-report.yml`) plus `templates/workflows/optional/`;
  `templates/.zshrc_docker`; `templates/test.R` (+ `test.Rmd`, uses `pacman`
  contradicting renv); `templates/index.qmd` (placeholders not in the
  allowlist; would render literally); `templates/R/utils.R` and
  `templates/R/data_prep.R`; `templates/.Rbuildignore` and
  `templates/.gitignore` (project.sh writes both inline; the templates list
  removed files); `templates/renv.lock`; `templates/update-renv-version.sh`
  and `templates/wrap_dockerfile.sh`; `templates/DATA_WORKFLOW_GUIDE.md`;
  `templates/tools/__pycache__/` (add to .gitignore); the duplicate
  `templates/tests/integration/test-data_pipeline.R` vs `test-data-pipeline.R`.

## Priority 2: Efficiency

- **`load_config` re-parses YAML 3+ times per command.** It runs on
  `config_get`, `config_list`, `init_config_system`, and again in
  `generate_dockerfile`/`prompt_new_workspace_setup`; each call re-runs the
  full single-`yq` pass over both files. Add a `_CONFIG_LOADED` memo flag
  (mirroring the Round 1 `_YQ_AVAILABLE` memo), reset in `config_set`. This is
  the dominant repeated cost on config-touching paths.
- **`extract_code_packages` double-traverses.** `docker.sh:434` passes
  `. R scripts analysis`, so `find` walks `R/`, `scripts/`, `analysis/` twice
  (once under `.`); correct only because `sort -u` dedupes. Pass just `.`.
- **`_is_valid_pkg` is redefined on every `extract_r_packages` call.** Hoist
  to file scope (pass or globalise the `base_pkgs`/`skip_pkgs` it closes over).
- **Makefile `r: check-renv`.** `make r` runs a full `docker run` validation
  before the interactive shell and a second after each session. Drop the
  pre-shell prerequisite (keep the post-session check) or gate it behind a flag.
- **`shell-tests.yml` runs the suite twice** (once for pass/fail, once to
  regenerate identical report output). Capture once with `tee`.

## Priority 3: Best practices and latent correctness

- **`docker.sh:377` uses `eval` to build a `find` command** with an unquoted
  `${dirs[*]}`. Inputs are internal today, but the `eval`/string-splicing is
  fragile (paths with spaces/globs break it). Build a `find` argument array
  and run it directly - bash 3.2 supports this.
- **`docker.sh:754` `docker build $platform_args $label_args $cache_args`**
  relies on unquoted word-splitting (SC2086 pattern). Use an args array.
- **R operator-precedence readability.** `(attr(result, 'status') %||% 0) == 0`
  is correct but unparenthesised at `project.R:147,483,561`; add explicit
  parens.
- **`safe_cp` is destructive-on-missing-source.** `lib/core.sh` does
  `rm -f "$dest"; cat "$src" > "$dest"` with no `-f "$src"` check; under
  `set -e` a missing source aborts after the destination is already removed.
  Make it self-contained with a source-exists guard.
- **`AUTHOR_INSTITUTE`/`AUTHOR_INSTITUTE_FULL`** are in the envsubst allowlist
  and used in `report.Rmd`, but exported empty (never populated from config),
  so they always render blank. Wire them to `CONFIG_*` or remove them.
- **`report.Rmd` CSL path.** The installed report points at
  `../templates/statistics-in-medicine.csl`, a path that will not exist in a
  generated project; the CSL is not installed alongside the report.
- **Stale 'CRAN-probing' language.** `cmd_renv` help and the workspace prompt
  say the R version comes from 'CRAN' (`cran_version`), but it comes from
  config/default - no network probe occurs (contradicts the documented
  design). Reword and rename the variable.
- **CI hygiene.** `benchmarks.yml` installs renv from a `focal` PPM URL while
  the framework standardises on `noble`; `security-scan.yml` uses
  `aquasec/trivy:latest` (unpinned in a reproducibility project); both scan
  the framework's own root Dockerfile, not generated-project output.

## Priority 4: Test quality

- **R tests are largely structural, not behavioural.** `test-r-functions.R`
  (220 lines) and `test-utils.R:14-34` are dominated by
  `expect_true(is.function(...))`, `expect_true('x' %in% names(formals(...)))`,
  and `expect_true(exists(...))` - they pass as long as a name exists and
  catch no logic regression. Many files use
  `tryCatch(..., error = function(e) expect_true(TRUE))`, a tautology.
  Replace with the `local_mocked_bindings(safe_system = ...)` command-assertion
  pattern already used well in `test-project.R`/`test-git.R`/`test-help.R`.
- **`team_images()` parsing is untested.** Its tab-split/`vapply` parser is
  never exercised with mocked rows; a short row would error. Add a mocked test
  with known `repo\ttag\tsize\tdate` lines plus a malformed-row case.
- **Stale test text.** `test-git.R` references 'Claude Code attribution' the
  function does not add (and policy forbids); `test-help.R` references a
  `--help TOPIC` pattern the code does not use (it uses the `help` subcommand);
  the `%%||%%` test names contain an escaping artifact.
- **Shell test runner masks failures** (see P0 #6): `run-all-tests.sh` and the
  integration vacuous greps.

## Priority 5: Simplifications (structural)

- **Two shell test runners.** `tests/run-all-tests.sh` (root, R+shell+dead
  BATS branches, not used by CI) duplicates `tests/shell/run_all_tests.sh`
  (used by CI). Keep one canonical runner.
- **Three divergent `report.Rmd` variants** (`templates/report.Rmd` installed,
  `templates/analysis/report/report.Rmd` and
  `templates/unified/analysis/report/report.Rmd` unreferenced). Keep one.
- **`templates/unified/` is dead but for one file.** Only
  `unified/.github/workflows/render-report.yml` is used. Relocate it to
  `templates/workflows/` and delete the rest of `unified/`.
- **Long functions over the 60-line guideline.** `main` (~247 lines, with
  per-command flag sub-loops that duplicate the `cmd_*` parsers - push parsing
  into each `cmd_*` and forward `"$@"`), `cmd_quickstart` (~147),
  `prompt_new_workspace_setup` (~150, extract the profile/R-version steps),
  `config.sh:_setup_change_existing` (~95).
- **Duplicated scaffold inventories.** `cmd_uninstall` and `cmd_rm_all` keep
  two overlapping hardcoded dir/file lists that will drift; extract shared
  constants and reconcile the intentional differences.
- **`config.R` over-documentation.** Five one-line `zzc_config(...)` wrappers
  carry 40-70 lines of roxygen each, including a **stale `@details` block**
  documenting eliminated build modes (`'minimal','fast','standard',
  'comprehensive'`) in `validate_config`. Trim to substantive content.
- **Small R helpers.** A `report_status(result, ok_msg, fail_msg)` collapses
  the repeated `if (result == 0) { message(ok); TRUE } else ...` in the five
  git wrappers; a `require_makefile()` collapses the duplicated
  `if (!file.exists('Makefile')) stop(...)` in `rebuild`/`run_script`/
  `render_report`/`join_project`. `get_config_default()` is redundant with
  `%||%` (both real call sites already use `get_config(x) %||% default`);
  consider removing it and its 50-line roxygen.
- **Template-engine and config dedup.** `copy_template_file` vs
  `regenerate_template_file` are ~90% identical (share a private core with an
  `overwrite` flag); the `github.account` + `defaults.github_account`
  dual-write is repeated at three sites (centralise in one helper);
  `warn_if_templates_outdated` and `check_and_prompt_outdated_templates`
  each re-implement the same version-stamp `sed` probe (factor one helper).

## Suggested execution order

1. P0 - the CI-breaking steps (#1, #2, #6) and the two R `create_pr` bugs
   (#3, #4) first; they are small, independently testable, and #1/#2 turn CI
   green. Land with the test-suite fixes so CI is trustworthy.
2. P1 dead-code and stale-template deletion (high churn, zero behaviour
   change) - land before the structural work so diffs stay clean.
3. P2 efficiency wins that are localized (the `load_config` memo is the
   highest-value single change).
4. P3 best-practice hardening (the `eval`/unquoted-`docker build` array
   conversions, the `safe_cp` guard, the `create_pr` defence-in-depth).
5. P4 test-quality rework (replace structural/tautology tests with mocked
   command assertions; add `team_images` coverage).
6. P5 structural simplifications last.

Each priority block is independently shippable. P0 and the test-runner fixes
should land together so CI is green and meaningful before the larger work.

---
*Source: ~/prj/sfw/07-zzcollab/zzcollab/docs/codebase-improvement-plan-2.md*
