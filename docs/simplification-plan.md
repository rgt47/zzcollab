# zzcollab Simplification Plan

*2026-05-29 07:57 PDT*

Current total: **9,528 lines** across 13 shell files.
Target total: **~3,900 lines** -- a 59% reduction.

The plan is divided into four independent phases ordered by risk.
Each phase is fully testable before the next begins.

---

## Baseline by file

| File | Lines |
|---|---|
| `zzcollab.sh` | 1,887 |
| `modules/config.sh` | 1,597 |
| `modules/doctor.sh` | 878 |
| `modules/validation.sh` | 941 |
| `modules/help.sh` | 1,108 |
| `modules/docker.sh` | 810 |
| `modules/profiles.sh` | 494 |
| `lib/core.sh` | 687 |
| `modules/project.sh` | 307 |
| `modules/github.sh` | 221 |
| `modules/cli.sh` | 241 |
| `lib/templates.sh` | 233 |
| `lib/constants.sh` | 124 |
| **Total** | **9,528** |

---

## Phase 1 -- Lossless cleanup (~750 lines removed)

No user-visible changes. Pure internal simplification. Low risk.
Run `shellcheck --severity=warning` and the full test suite after each item.

### 1A. Source all modules at startup; drop the module loading system

**Remove from `zzcollab.sh`:**
- The `require_module()` function (~30 lines, starting around line 62).
- All `require_module "..."` calls inside every `cmd_*` function (~20 call sites).

**Remove from every module file** (the footer boilerplate):
- `readonly ZZCOLLAB_CLI_LOADED=true` from `modules/cli.sh`
- `readonly ZZCOLLAB_CONFIG_LOADED=true` from `modules/config.sh`
- `readonly ZZCOLLAB_DOCKER_LOADED=true` from `modules/docker.sh`
- `readonly ZZCOLLAB_DOCTOR_LOADED=true` from `modules/doctor.sh`
- `readonly ZZCOLLAB_GITHUB_LOADED=true` from `modules/github.sh`
- `readonly ZZCOLLAB_HELP_LOADED=true` from `modules/help.sh`
- `readonly ZZCOLLAB_PROFILES_LOADED=true` from `modules/profiles.sh`
- `readonly ZZCOLLAB_PROJECT_LOADED=true` and aliases from `modules/project.sh`
- `readonly ZZCOLLAB_VALIDATION_LOADED=true` from `modules/validation.sh`
- `readonly ZZCOLLAB_CORE_LOADED=true` and `ZZCOLLAB_UTILS_LOADED=true` from `lib/core.sh`

**Remove from every module's top:** any `require_module "..."` calls that modules
make to declare their own dependencies (e.g., `require_module "core" "templates"`).

**Add to `zzcollab.sh`** after the existing lib/ sourcing block:
```bash
source "$ZZCOLLAB_MODULES_DIR/cli.sh"
source "$ZZCOLLAB_MODULES_DIR/config.sh"
source "$ZZCOLLAB_MODULES_DIR/profiles.sh"
source "$ZZCOLLAB_MODULES_DIR/project.sh"
source "$ZZCOLLAB_MODULES_DIR/docker.sh"
source "$ZZCOLLAB_MODULES_DIR/github.sh"
source "$ZZCOLLAB_MODULES_DIR/validation.sh"
source "$ZZCOLLAB_MODULES_DIR/doctor.sh"
source "$ZZCOLLAB_MODULES_DIR/help.sh"
```

**Estimated saving:** ~100 lines.

---

### 1B. Drop the manifest/tracking system

**Remove from `lib/core.sh`:**
- `init_manifest()` (lines 239-281, ~42 lines) -- initialises `.zzcollab/` and creates
  `manifest.json` or `manifest.txt`.
- `track_item()` (lines 288-415, ~130 lines) -- the core tracker with full
  jq/txt branching for five item types.
- `track_directory()`, `track_file()`, `track_template_file()`, `track_symlink()`,
  `track_docker_image()` (lines 418-422, 5 one-liner wrappers).
- The `MANIFEST_FILE` and `MANIFEST_TXT` exported variables (lines 229-231).
- The `JQ_AVAILABLE` constant (line 44 in the non-constants branch) -- no longer
  needed once the manifest is gone and config switches to a shell file (Phase 3).

**Remove the `track_directory` call from `safe_mkdir()`** (currently line 207
in `lib/core.sh`) -- simplify to just `mkdir -p` with logging.

**Remove all `track_*` call sites:**
- `modules/project.sh`: 6 calls (`track_directory` in `create_directory_structure`,
  `track_file` in `create_r_package_files`, `create_devtools`, etc.).
- `modules/docker.sh`: 3 calls (`track_file "Dockerfile"` and related).
- `zzcollab.sh`: 7 calls (`track_file "Dockerfile"` in `cmd_docker`,
  `track_docker_image` in build step, etc.).

**Replace `cmd_rm` in `zzcollab.sh`** (~100 lines of manifest-reading logic)
with a simple hardcoded cleanup:
```bash
cmd_rm() {
    # Known files and directories created by zzc init
    local known_dirs=(R/ analysis/ tests/ man/ vignettes/ docs/ .github/ renv/)
    local known_files=(DESCRIPTION NAMESPACE LICENSE Makefile Dockerfile
                       renv.lock .Rprofile .gitignore .Rbuildignore)
    echo "This will remove: ${known_dirs[*]} ${known_files[*]}"
    confirm "Remove zzcollab scaffold from this directory?" || return 0
    rm -rf "${known_dirs[@]}"
    rm -f  "${known_files[@]}"
    rm -rf .zzcollab/
    log_success "zzcollab scaffold removed"
}
```

**Estimated saving:** ~350 lines.

---

### 1C. Drop CRAN R version auto-detection

**Remove from `modules/docker.sh`:**
- `get_cran_r_version()` (lines 78-109, ~32 lines) -- queries
  `https://cran.r-project.org/src/base/` via curl.
- `get_buildable_r_version()` (lines 110-178, ~68 lines) -- validates the version
  against Docker Hub registry tags for the chosen base image.
- The `_CACHED_CRAN_R_VERSION` local cache variable.

**Replace all call sites with `${CONFIG_R_VERSION:-$ZZCOLLAB_DEFAULT_R_VERSION}`.**
The default is already `4.5.2` in `lib/constants.sh`. Users who need a different
version set it in config with `zzc config set r-version 4.4.2`.

Update `lib/constants.sh` to keep `ZZCOLLAB_DEFAULT_R_VERSION` current with each
zzcollab release -- a one-line change at release time is far simpler than a
network call at every `zzc init`.

**Estimated saving:** ~100 lines. Eliminates the `curl` network call on the
happy path.

---

### 1D. Trim `modules/help.sh` to command reference

**Current state:** 1,108 lines. Includes extended workflow descriptions, profile
deep-dives, collaboration narratives, and troubleshooting guidance that is
duplicated in the vignettes and `ZZCOLLAB_USER_GUIDE.md`.

**Keep:**
- `show_help_main()` -- a concise synopsis of every subcommand (~30 lines).
- `show_help_docker()`, `show_help_config()`, `show_help_validate()` -- one
  paragraph each with flag reference (~20 lines each).
- `show_help_profiles()` -- list of the three profiles with sizes (~10 lines).

**Remove:**
- All extended narrative sections (workflow tutorials, profile descriptions,
  collaboration patterns, troubleshooting). Total: ~800 lines.
- `show_help_init()` -- the init help expands to two screens and duplicates the
  quickstart vignette. Replace with a five-line synopsis pointing to the vignette.

**Estimated saving:** ~900 lines.

---

## Phase 2 -- Profile reduction (~500 lines removed)

### 2A. Reduce `templates/bundles.yaml` to three profiles

**Remove from the `profiles:` section:**
- `analysis_pdf` -- marginal variant of `analysis`; users needing PDF rendering
  install tinytex inside the container with `install.packages("tinytex")`.
- `modeling` -- covered by `analysis` plus `install.packages("tidymodels")`.
- `publishing` -- LaTeX/Quarto users are a niche; handled via `--libs publishing`
  bundle flag on an `analysis` base.
- `manuscript-package` -- a variant of `publishing` with minimal packages.
- `shiny` -- niche; users can add shiny to any profile.

**Keep:**
- `minimal` -- `rocker/r-ver`, ~650MB, command-line only.
- `analysis` -- `rocker/tidyverse`, ~1.2GB, data analysis (recommended default).
- `rstudio` -- `rocker/rstudio`, ~980MB, RStudio Server.

**Remove from the `package_bundles:` section:** `modeling`, `publishing`,
`shiny`, `gui`.

**Remove from the `library_bundles:` section:** `modeling`, `publishing`, `gui`.

**Keep all bundles:** `minimal`, `tidyverse`, `none`, `terminals`.

### 2B. Update `zzcollab.sh` routing

**Remove these pattern arms** from both profile routing case statements
(approximately lines 1729 and 1822):
- `analysis_pdf`, `modeling`, `publishing`, `shiny`, `manuscript-package`
  from the standalone-command dispatcher.
- `verse`, `tidyverse` aliases from both dispatchers.

**Remove capability conditions** that only existed because of dropped profiles:
- `[[ "$profile" =~ ^(analysis|analysis_pdf|publishing)$ ]]` (lines 1259
  and 1337) -- zzvim-R install. Simplify to `[[ "$profile" == "analysis" ]]`.
- `analysis_pdf|publishing|manuscript-package)` case arm (line 1331) --
  PDF tools install. Remove entirely; these profiles are gone.

### 2C. Update `modules/profiles.sh`

`get_profile_base_image`, `get_profile_libs`, `get_profile_pkgs` are already
data-driven from `bundles.yaml` -- no changes needed to the logic, only the
YAML data changes.

Remove from `list_profiles()` the size constants that referenced deleted profiles.

**Update `modules/config.sh`** `prompt_select` call for profile to list only
`minimal,analysis,rstudio`.

**Estimated saving across Phase 2:** ~500 lines total (bundles.yaml ~150,
zzcollab.sh routing ~150, help text ~150, profiles.sh minor ~50).

---

## Phase 3 -- Config system replacement (~1,450 lines removed)

This is the highest-value phase. It eliminates `yq` as a hard dependency and
reduces `modules/config.sh` from 1,597 lines to ~150 lines.

### 3A. New config file format

Replace `~/.zzcollab/config.yaml` (YAML, requires yq) with
`~/.zzcollab/config.sh` (shell-sourceable, no dependencies):

```bash
# ~/.zzcollab/config.sh
# Generated by zzcollab. Edit directly or use: zzc config set KEY VALUE
ZZCOLLAB_AUTHOR_NAME=""
ZZCOLLAB_AUTHOR_EMAIL=""
ZZCOLLAB_AUTHOR_ORCID=""
ZZCOLLAB_AUTHOR_AFFILIATION=""
ZZCOLLAB_GITHUB_ACCOUNT=""
ZZCOLLAB_DOCKERHUB_ACCOUNT=""
ZZCOLLAB_PROFILE="analysis"
ZZCOLLAB_R_VERSION="4.4.2"
ZZCOLLAB_LICENSE_TYPE="GPL-3"
```

Replace `./zzcollab.yaml` (project-level YAML overrides) with
`./zzcollab.conf` (same shell-sourceable format, same fields, only
overrides need to be present):

```bash
# ./zzcollab.conf -- project-level overrides. Commit to version control.
ZZCOLLAB_GITHUB_ACCOUNT="genomicslab"
```

### 3B. What to keep in `modules/config.sh`

```
load_config()              # source user config then project config; ~5 lines
config_init()              # create ~/.zzcollab/config.sh if absent; ~20 lines
config_set()               # sed-replace one KEY=VALUE line; ~15 lines
config_get()               # grep+print one variable; ~5 lines
config_list()              # cat the config file; ~5 lines
config_identity_gate()     # existing function, simplified; ~40 lines
config_project_prompt()    # existing function, simplified; ~50 lines
```

Total: ~150 lines.

### 3C. What to remove from `modules/config.sh`

**Remove entirely:**
- `yaml_get()`, `yaml_set()`, `yaml_set_bool()`, `yaml_set_array()` -- yq
  wrappers (lines 114-139, ~25 lines).
- `_require_yq()` (lines 99-107, ~8 lines).
- `_CONFIG_MAP` heredoc (lines ~545-595, ~50 lines).
- `_load_file()` (lines ~596-630, ~35 lines).
- `apply_config_defaults()` (lines ~631-660, ~30 lines).
- `_get_config_value()` (lines ~661-670, ~10 lines).
- `config_interactive_setup()` and all four sub-functions:
  `_setup_missing_values`, `_setup_change_existing`, `_setup_advanced`,
  `_setup_full` (~350 lines combined).
- `_save_and_exit()` and `_interactive_cleanup()` (~15 lines).
- `_create_default_config()` -- writes the 100-line YAML template (~120 lines).
- All `CONFIG_*` variable declarations at module top (~50 lines).
- All prompt helpers that were written for the config form:
  `prompt_input`, `prompt_validated`, `prompt_github_account`,
  `prompt_yesno`, `prompt_select`, `print_section` (~200 lines).
  These live in `config.sh` only because of the YAML form; the identity gate
  and project prompt can use `gum_input`/`gum_choose` directly.
- All input validators: `validate_email`, `validate_orcid`,
  `validate_r_version_lenient`, `validate_positive_int`, `validate_percentage`,
  `validate_github_account` (~50 lines). Keep only `validate_email` and
  `validate_r_version` (which is already in `lib/core.sh`).

### 3D. Downstream changes

**`lib/core.sh`:** remove `AUTHOR_NAME`, `AUTHOR_EMAIL`, `AUTHOR_INSTITUTE`,
`AUTHOR_INSTITUTE_FULL` constants from the top block (lines 33-45). These are
set by sourcing `config.sh` via `$ZZCOLLAB_AUTHOR_NAME` etc., which is cleaner
than duplicating them as `readonly` vars in core.

**`lib/constants.sh`:** remove the `ZZCOLLAB_CONFIG_*` constants (the ones
that triggered the env-var override bug we fixed). With a shell config file,
paths are just:
```bash
ZZCOLLAB_CONFIG_USER="$HOME/.zzcollab/config.sh"
ZZCOLLAB_CONFIG_PROJECT="./zzcollab.conf"
```

**All `CONFIG_*` variable references** throughout `zzcollab.sh`, `docker.sh`,
`project.sh`, `templates.sh` must change to `ZZCOLLAB_*` direct variable
references (e.g., `${CONFIG_AUTHOR_NAME:-}` → `${ZZCOLLAB_AUTHOR_NAME:-}`).
This is a mechanical find-and-replace.

**Migration:** on first run after upgrade, if `~/.zzcollab/config.yaml` exists,
auto-migrate by reading the YAML with awk (no yq needed for a one-time read of
a known-structure file) and writing `config.sh`. Emit a one-line notice.

**Estimated saving:** ~1,450 lines.

---

## Phase 4 -- Doctor and validation slim-down (~1,800 lines removed)

### 4A. Hand `validation.sh` entirely to `zzrenvcheck`

`zzrenvcheck` (sfw/08) is an R package that already implements everything
`validation.sh` does -- package usage extraction, DESCRIPTION/renv.lock
comparison, CRAN validation, auto-fix -- using proper R tooling (`desc`,
`jsonlite`, `httr`) with a test suite. The bash version is a fragile
reimplementation, including a hand-rolled version of renv's internal hash
algorithm in awk (`_renv_hash_from_crandb`, line 208) that will silently
produce wrong results if renv changes its algorithm.

**Remove `modules/validation.sh` entirely (941 lines).**

**Replace `make check-renv` target:**
```makefile
check-renv:
    Rscript -e 'zzrenvcheck::validate()'
```

**Replace `cmd_validate` in `zzcollab.sh`:**
```bash
cmd_validate() {
    Rscript -e 'zzrenvcheck::validate()' || exit "$EXIT_ERROR"
}
```

**Keep only `create_renv_lock()`** (8 lines, currently in `validation.sh` at
line 360). Move it to `modules/docker.sh` where it is called.

**Estimated saving: 941 lines.**

### 4B. `modules/doctor.sh` -- keep 4 functions, remove 16

**Keep:**
- `check_required_files()` (line 141, ~18 lines) -- verifies DESCRIPTION,
  renv.lock, Makefile, Dockerfile exist. This is the core health check.
- `check_required_dirs()` (line 160, ~30 lines) -- verifies R/, analysis/, tests/.
- `check_ignore_files()` (line 259, ~70 lines) -- verifies .gitignore and
  .Rbuildignore have required entries. Worth keeping; misconfigured ignore files
  cause real problems.
- `check_workspace()` (simplified to call only the three above; ~20 lines).

**Remove:**
- `extract_version()`, `extract_md_version()`, `extract_zzvimr_version()` --
  version stamp extraction (~30 lines). The version stamp checking machinery
  exists to detect outdated templates, a niche case.
- `check_misplaced_files()` and `print_misplaced_header()` (~70 lines) --
  detects and moves misplaced files. Nice-to-have, not essential.
- `check_version_stamps()` (~130 lines) -- compares template version stamps in
  Makefile, .Rprofile, Dockerfile, workflows. Complex and fragile.
- `check_ci_status()` (~66 lines) -- wraps `gh run list`. Users can run
  `gh run list` directly.
- `quiet_check_workspace()` (~33 lines) -- machine-readable check output.
  Not needed once the stamp machinery is gone.
- `_maybe_record_fix()`, `bump_stamp()`, `apply_fixes()` (~60 lines) -- the
  auto-fix machinery for updating version stamps.
- `print_version_status()`, `print_info_status()` (~65 lines) -- display
  helpers for stamp status.
- `scan_directory()` (~36 lines) -- walks parent directories for workspaces.
- `find_git_root()` (~11 lines) -- helper for scan_directory.
- `main()` (~60 lines) -- parses `--scan`, `--fix`, `--dry-run`, `--porcelain`
  flags. After removing the machinery these flags serve, `check_workspace()`
  can be called directly without a separate `main()`.

**Estimated saving:** ~650 lines. Target: ~200 lines.

### 4B. `modules/validation.sh` -- keep 13 functions, remove 17

**Keep (core package scanning and reporting):**
- `extract_code_packages()` (line 411) -- scans R/Rmd/qmd files for package uses.
- `clean_packages()` (line 437) -- filters false positives from extracted names.
- `parse_description_imports()`, `parse_description_suggests()` (lines 480-481).
- `parse_renv_lock()` (line 483) -- reads renv.lock via jq.
- `find_missing_from_description()` (line 494) -- gap report.
- `find_missing_from_lock()` (line 502) -- gap report.
- `report_and_fix_missing_description()` (line 511) -- reports and optionally
  fixes via text editing (keep the report path; simplify the fix path).
- `report_and_fix_missing_lock()` (line 530) -- reports missing lock entries
  (keep report only; remove the CRAN-fetch auto-fix path).
- `validate_package_environment()` (line 597) -- orchestrates the above.
- `create_renv_lock()` (line 360) -- creates a minimal renv.lock skeleton;
  used by `cmd_renv`.
- `validate_and_report()` (line 733) -- entry point.
- `parse_description_field()` (line 460) -- shared parsing helper.

**Remove (CRAN API and renv.lock manipulation):**
- `fetch_cran_package_info()` (line 81) -- queries crandb API.
- `validate_package_on_cran()` (line 88), `validate_package_on_bioconductor()`
  (line 92), `validate_package_on_github()` (line 96), `is_installable_package()`
  (line 103) -- package existence checks via HTTP. This machinery is slow,
  network-dependent, and wrong for private packages.
- `add_package_to_description()` (line 116) -- modifies DESCRIPTION from bash.
  R package management belongs in R with `usethis::use_package()`.
- `remove_unused_packages_from_description()` (line 154) -- same concern.
- `_renv_hash_from_crandb()` (line 208) and `_renv_requirements_from_crandb()`
  (line 243) -- reimplements renv's own hash algorithm in bash. ~80 lines that
  will silently produce wrong results if renv changes its algorithm.
- `add_package_to_renv_lock()` (line 259) -- adds entries to renv.lock from
  bash. Use `renv::install()` inside the container instead.
- `add_github_package_to_renv_lock()` (line 293) -- same concern.
- `prompt_github_remote()` (line 329) -- interactive prompt for package source.
- `update_renv_version_from_docker()` (line 343) -- queries Docker for renv
  version and edits renv.lock.
- `remove_unused_packages_from_renv_lock()` (line 368) -- removes entries
  from renv.lock. Use `renv::clean()` inside the container.
- `sync_packages_to_code()` (line 636) -- syncs DESCRIPTION and renv.lock to
  what code uses. Complex, error-prone, should be done in R.
- `detect_missing_system_deps()` (line 752) -- scans R packages for system
  dependencies. Complex (~80 lines); if needed, provide as a separate
  optional utility, not core validation.
- `add_system_deps_to_dockerfile()` (line 803) -- inserts apt-get layers.
  Belongs with the user, not automated.
- `main()` (line 887) -- CLI dispatcher for many flags. Simplify once the
  above functions are removed.

**Estimated saving (doctor only):** ~650 lines. Target: ~200 lines.

---

## Dependencies eliminated

| Dependency | Eliminated by | Notes |
|---|---|---|
| `yq` | Phase 3 (config) | Was required for all config reads/writes |
| `curl` | Phase 1C (R version) | Was used for CRAN version query |
| `jq` (optional) | Phase 1B (manifest) | Still needed for `parse_renv_lock` in validation |

`jq` becomes a required (not optional) dependency only for `zzc validate`.
The fallback txt-manifest path in `core.sh` -- the main reason jq was optional
-- is gone.

---

## Target line counts after all phases

| File | Current | Target |
|---|---|---|
| `zzcollab.sh` | 1,887 | ~1,000 |
| `modules/config.sh` | 1,597 | ~150 |
| `modules/doctor.sh` | 878 | ~200 |
| `modules/validation.sh` | 941 | **deleted** (→ zzrenvcheck) |
| `modules/help.sh` | 1,108 | ~200 |
| `modules/docker.sh` | 810 | ~600 |
| `modules/profiles.sh` | 494 | ~200 |
| `lib/core.sh` | 687 | ~350 |
| `modules/project.sh` | 307 | ~250 |
| `modules/github.sh` | 221 | ~200 |
| `modules/cli.sh` | 241 | ~150 |
| `lib/templates.sh` | 233 | ~200 |
| `lib/constants.sh` | 124 | ~100 |
| **Total** | **9,528** | **~3,500** |

**Reduction: ~6,000 lines (63%).**

---

## What is NOT changed

- Five Pillars model and the project scaffold it creates.
- Dockerfile generation logic (beyond removing dropped profiles).
- `make r` / `make docker-build` workflow.
- `zzc github` -- unchanged.
- `zzc renv` -- unchanged.
- The gum TUI integration.
- The two-phase `zzc init` identity gate and project prompt.
- `lib/templates.sh` -- template installation and envsubst substitution.
- R package surface (`R/`, vignettes, NEWS.md, DESCRIPTION) -- separate track.

---

## Recommended execution order

1. **Phase 1A** (module loading) -- 30 min, very low risk.
2. **Phase 1B** (manifest) -- 1 hr, low risk. Verify `zzc rm` still works.
3. **Phase 1C** (R version detection) -- 30 min, low risk. Verify `zzc docker`.
4. **Phase 1D** (help.sh trim) -- 1 hr, low risk. Verify `zzc help`.
5. **Phase 2** (profiles) -- 2 hrs, low risk. Verify all three profiles init.
6. **Phase 4** (doctor + validation) -- 3 hrs, medium risk. Verify `zzc validate`
   and `zzc doctor` still report correctly on a known good and known bad workspace.
7. **Phase 3** (config) -- 4 hrs, medium risk. Requires migration path for
   existing `config.yaml` users. Test: new install, upgrade from YAML, all
   config subcommands, identity gate, project prompt.

**Note on zzrenvcheck dependency:** Phase 4A requires `zzrenvcheck` to be
installed in the project's Docker image or on the host. Add it to the
`analysis` and `minimal` profile renv.lock seeds, or install it via
`install.packages("zzrenvcheck")` inside the container. The `make check-renv`
target requires R on the host only for the validation step; all other `zzc`
operations remain shell-only.
