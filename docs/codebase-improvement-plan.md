# zzcollab Codebase Improvement Plan
*2026-05-30 15:05 PDT*

Synthesis of a deep review across the bash CLI (`zzcollab.sh`, `lib/`,
`modules/`), the R package (`R/`, `tests/testthat/`), templates, scripts,
and the shell test suite. Findings were produced by six parallel review
agents and cross-referenced by repo-wide grep. Epistemic status: dead-code
and call-site claims are grep-verified; correctness and quoting claims are
source-inspected (not executed); efficiency counts are inferred from loop
structure, not profiled.

## Priority 0: Correctness bugs (fix first)

These are functional defects, not style.

1. **`cmd_init` guard is silently bypassed.** `zzcollab.sh:220`:
   `[[ "$force" == "false" ]] && assert_safe_init_directory || true`. The
   `|| true` swallows the guard's failure, so `zzc init` proceeds into an
   occupied directory even when the safety check says stop. Replace with
   `if [[ "$force" == "false" ]]; then assert_safe_init_directory || exit 1; fi`.

2. **System-dep derivation drops short package names.** `docker.sh:~391`
   `${#p} -lt 3` filters out `sf`, `sp`, `V8`, `XML`, `gsl`, `gmp`, `png`,
   `bz2`, `fs`, `BH` — several of which are exactly the packages
   `profiles.sh` has system-dependency rules for. The length filter,
   intended to suppress noise from the heuristic code scan, also discards
   exact names from `renv.lock`/DESCRIPTION. Do not apply the length filter
   to names sourced from `renv.lock`/DESCRIPTION.

3. **R `get_config(key)` shell-injection gap.** `R/config.R:~61` builds
   `paste(zzcollab_path, "config get", key)` with `key` NOT shQuote'd,
   while `set_config` quotes both. Quote `key`.

4. **R `init_project(profile)` shell-injection gap.** `R/project.R:~313`
   `paste(zzcollab_path, profile)` — `profile` is neither validated nor
   shQuote'd; it flows straight to the shell. Validate against the known
   profile set and/or shQuote.

5. **config path injection into yq.** `config.sh:~97,104` interpolate the
   config `$path` (user-supplied via `zzc config set <key>`) directly into
   the `yq eval` program string. The value is hardened via `strenv`, the
   key is not. Validate keys against `^[A-Za-z0-9_.]+$` before building the
   expression. (Naturally enforced by the table-driven refactor in P3.)

6. **`zzc config validate` reports malformed YAML as valid.** The live path
   (`zzcollab.sh:~792`) treats `load_config 2>/dev/null` success as valid,
   but `load_config` returns 0 unconditionally and `yq` parse errors are
   swallowed. Restore a real syntax check (`yq eval '.' file`). The deleted
   `config_validate()` did this correctly.

7. **`sed -i.bak` on user `.Rprofile`.** `zzcollab.sh:~1424` (`cmd_rm_renv`)
   edits `.Rprofile` in place in the user's project directory, which is
   frequently a cloud-synced path — the documented 0-byte-truncation
   hazard. Use copy-to-tmp-then-`mv`, or
   `grep -v 'renv/activate.R' .Rprofile > .Rprofile.new && mv ...`.

8. **doctor.sh count/case bugs.** `total_issues` is decremented on fix
   paths and can go negative, making `-eq 0` report failure after a clean
   fix and printing `-1 issue(s) found`; `print_version_status` has a
   non-exhaustive `case` with no default, silently reporting "ok" on
   unexpected `semver_cmp` output. Clamp the count; add a `*)` arm.

9. **Unquoted array expansions (SC2068).** `zzcollab.sh:1599`
   `set -- ${_filtered[@]+...}` and `:1664` `cmd_docker ${docker_args[@]+...}`
   use the unsafe idiom; word-splits/globs on any arg with whitespace or a
   glob char. Use `set -- "${_filtered[@]}"` / `cmd_docker "${docker_args[@]}"`.

## Priority 1: Dead code removal (large, low-risk)

Roughly 600+ lines of confirmed-unreachable code. All call-site claims
grep-verified.

- **`modules/github.sh` — ~150 lines, two-thirds of the module.** The
  entire `create_github_repository_workflow` chain (plus
  `validate_github_prerequisites`, `prepare_github_repository`,
  `create_and_push_repository`, `show_collaboration_guidance`) is dead —
  `cmd_github` reimplements repo creation inline. Also dead:
  `create_github_templates`, `show_cicd_summary`. (The dead chain also
  hardcodes private repos, contradicting live `--public/--private`.)
- **`modules/config.sh` — ~80 lines.** `handle_config_command()` (the real
  dispatcher is `cmd_config` in `zzcollab.sh`) and `config_validate()` are
  dead; plus `yaml_set_bool`, `yaml_set_array`, `validate_percentage`,
  `_interactive_cleanup`. Several config keys are write-only (mapped +
  templated, never read): `docker.default_base_image`, `docker.platform`,
  `github.create_issues`, `github.create_wiki`, `style.indent_size`,
  `style.naming_convention`, `rpackage.roxygen_version`,
  `rpackage.encoding`, `rpackage.language`. Either consume or drop.
- **`lib/core.sh` — ~70 lines.** `validate_files_exist`,
  `validate_directories_exist`, `validate_commands_exist` never called
  (keep `command_exists`).
- **`lib/templates.sh`.** Exported template vars with no placeholder in any
  template: `AUTHOR_LAST`, `AUTHOR_ORCID`, `MANUSCRIPT_TITLE`, `TEAM_NAME`,
  `DOCKERHUB_ACCOUNT`, `R_PACKAGES_INSTALL_CMD`, `SYSTEM_DEPS_INSTALL_CMD`,
  `LIBS_BUNDLE`, `PKGS_BUNDLE`, `USERNAME`. Drop exports + envsubst
  allowlist entries.
- **`zzcollab.sh`.** `_reverse_lines()` (unused); `profile_changed` local in
  `cmd_docker` (set, never read).
- **`modules/cli.sh`.** Five unused interface vars: `DOCKERFILE_PATH`,
  `IMAGE_TAG`, `PREPARE_DOCKERFILE`, `ADD_EXAMPLES`, `USE_TEAM_IMAGE`.
- **`modules/docker.sh`.** Leftover `publishing`/`shiny`/`analysis_pdf`
  profile inference contradicting the three-profile model;
  `prompt_r_version_selection` backward-compat wrapper; stale SC2120
  suppression.
- **R package.** `inst/tinytest/` (7 files) — a stale parallel test suite
  using an undeclared framework that ships inside the installed package
  (not in `.Rbuildignore`); `validate_path()` defined but never called;
  `jsonlite` in Suggests is unused.
- **Tests.** `tests/shell/test-validation.sh` tests the deleted
  `validation.sh` module (breaks CI); `tests/testthat/fixtures/mock_project/`
  contains stale copies of removed `validation.sh` and
  `zzcollab-uninstall.sh` and is referenced by no active test.
- **Unwired scripts/templates.** `scripts/check-readonly.sh`,
  `check-function-sizes.sh`, `shellcheck-local.sh`,
  `scripts/check_rprofile_options.R`, `templates/wrap_dockerfile.sh`,
  `templates/update-renv-version.sh` — invoked by nothing. Delete or wire
  into Makefile/CI/CONTRIBUTING.

## Priority 2: Repository hygiene

- **Root clutter (NOT code, but pollutes the repo root):** `nytimes.pdf`
  (8.4 MB), `rsos.180448.pdf`, `s41562-018-0399-z.pdf`,
  `silberzahn-et-al-2018-*.pdf`, `stodden-et-al-2018-*.pdf`,
  `manifest-retrofit-session.pdf`, `notes.txt`. Confirm tracking status;
  if tracked, remove from the repo (and add a `.gitignore` rule) — these
  bloat clones and will be flagged by `R CMD check` if not Rbuildignored.
- **CI coverage gap:** `shellcheck.yml` lints `zzcollab.sh`, `modules/`,
  `install.sh`, `templates/` but NOT `scripts/` or `tests/shell/` — the very
  files CLAUDE.md says must pass shellcheck. Add them, or delete the unused
  `scripts/`.
- **`test-integration.sh` false positives:** uses removed `-t/-p` flags;
  every command is suffixed `|| true` with assertions guarded by
  `if [[ -f DESCRIPTION ]]`, so a rejected flag silently skips the
  assertion. Fix the flags and assert exit codes.
- **Stray `ZZCOLLAB_CONSTANTS_LOADED` guard** (`core.sh:31`/`constants.sh:79`)
  is the lone survivor of the removed `_LOADED` system; harmless but
  inconsistent with documented architecture.

## Priority 3: Efficiency

- **`config.sh` `_load_file` spawns ~39 `yq` subprocesses per file** (≈78+
  per `load_config`), and `load_config` runs on essentially every config
  operation. Read each file once with a single `yq` emitting `path=value`
  pairs and parse in bash. Also cache the `yq`-available check once instead
  of per-key `_require_yq`.
- **`check-binaries.py` makes ~1 HTTP call per package** in
  `fetch_compilation_flags` (~100 serial calls at a 15 s timeout) while
  `fetch_sysreqs` correctly batches 75/call. Batch the `/packages` query —
  the dominant cost of the pre-build audit.
- **`docker.sh` re-reads `renv.lock` three times** (`extract_r_version`,
  `parse_renv_lock`, `compute_dockerfile_hash`) and `extract_code_packages`
  runs four `grep|sed` passes per file. Read once; single-pass scan.
- **R `find_zzcollab_script()` spawns an extra probe process per wrapper
  call.** Cache the resolved path in a package-level environment for the
  session.
- **`basename "$(pwd)"` recomputed 10+ times** across `zzcollab.sh` (twice
  adjacently in `cmd_build`). Compute `project_name` once per function.

## Priority 4: Simplifications (structural)

- **config.sh has four parallel representations of the same key set** (load
  map, getter case, set/get path-mapping case, list block) — the direct
  cause of the write-only-key and partial-getter bugs above. Consolidate to
  one declarative table (yaml.path, CONFIG_VAR, alias, list section) driving
  load/get/set/list. Removes ~150 lines and an entire class of drift bugs.
  Folds in the key-validation fix (P0 #5).
- **doctor.sh `check_version_stamps`** (127 lines) has three near-identical
  copy-from-template blocks with a repeated `mktemp`/`cat`/`rm` dance.
  Extract `install_template_stamped <src> <dest> <version>`. Also dedupe the
  interactive-fix loop vs `apply_fixes`, and the version-stamp `sed` regex
  duplicated in `extract_version`/`warn_if_templates_outdated`/
  `check_and_prompt_outdated_templates` (hoist to `lib/core.sh`).
- **R config/project wrapper boilerplate.** Factor `zzc_config(args)` for
  the six config wrappers (also fixes the `get_config` quoting gap in one
  place) and `resolve_team_project()` for the duplicated
  `init_project`/`join_project` validation (~25 lines).
- **profiles.sh three `list_*` functions** collapse into one
  `_list_yaml_section <section> <format>` (~60→~25 lines). Pass `$profile`
  to yq as data (`env(profile)`), not query text; guard for missing `yq`.
- **Two parallel shell test runners** (`tests/shell/run_all_tests.sh` and
  `tests/run-all-tests.sh`) plus two divergent in-file harness idioms
  (manual `tests=(...)` array vs `declare -F` auto-discovery). Standardize
  on auto-discovery; extract the FAIL/SKIP parser to `test_helpers.sh`.
  Remove the dead `_LOADED` guard logic in `load_module_for_testing`.
- **Long functions over the 60-line guideline:** `cmd_quickstart` (175),
  `prompt_new_workspace_setup` (~170), `cmd_init` (120),
  `config.sh:_setup_change_existing` (95), `config_interactive_setup` (82),
  `generate_dockerfile` (80). Split by responsibility. Extract a single
  `prompt_build_now()` (the "Build now? [Y/n]" prompt is hand-rolled ~4x).

## Priority 5: R house-style conformance (pervasive, mechanical)

The R sources systematically violate the stated house style. Largely
mechanical but broad:

- Explicit `return()` on final expressions throughout (`git.R`, `project.R`,
  `config.R`) — use implicit returns, keep `return()` only for early exit.
- Double quotes everywhere — convert to single quotes.
- `sapply`/`for` where purrr is preferred (`project.R:team_images`,
  `add_package`, `validate_repro`).
- Base `stop()`/`warning()` with inconsistent `call.=` — standardize on
  `cli::cli_abort`/`cli_warn` (add `cli` to Imports) or at least uniform
  `call.=FALSE`.
- Missing roxygen `@examples`/`@details` on git + project wrappers;
  escaped `\"` in `config.R` examples (renders literally under markdown);
  no `_PACKAGE` doc stub; over-documentation in `config.R` (403 lines for 6
  thin wrappers).
- Undeclared test dep: `withr` used in tests, not in Suggests.
- Redundant `%||%` export collides with `base::%||%` (R ≥ 4.4).

## Suggested execution order

1. P0 correctness bugs (each is small and independently testable).
2. P1 dead-code deletions + P2 hygiene (high churn, zero behavior change;
   land before refactors so the diff is clean).
3. P3 efficiency wins that are localized (`check-binaries.py` batching,
   `find_zzcollab_script` caching).
4. P4 structural simplifications (config table-drive is the keystone; it
   subsumes several P0/P1 items — sequence it after the dead-key deletions).
5. P5 R style sweep (one mechanical pass, ideally with styler + manual
   review of the quoting/return changes).

Each priority block is independently shippable. P0 and the test-suite fixes
(P1/P2) should land together so CI is green before the larger refactors.

---
*Source: ~/prj/sfw/07-zzcollab/zzcollab/docs/codebase-improvement-plan.md*
