# zzcollab Simplification Plan

*2026-05-29 07:57 PDT*

Current total: **9,528 lines** across 13 shell files.
Target total: **~5,800 lines** -- a 39% reduction.

The plan is three independent phases ordered by risk. Each phase is fully
testable before the next begins. The config system (YAML + yq + gum prompts)
is **not changed** -- it was just rebuilt and is working correctly.

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

## Phase 1 -- Lossless cleanup (~1,400 lines removed)

No user-visible changes. Pure internal simplification. Low risk.
Run `shellcheck --severity=warning` and the full test suite after each item.

### 1A. Source all modules at startup; drop the module loading system

**Remove from `zzcollab.sh`:**
- The `require_module()` function (~30 lines, around line 62).
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
- `readonly ZZCOLLAB_CORE_LOADED=true` and `ZZCOLLAB_UTILS_LOADED=true`
  from `lib/core.sh`

**Remove from every module's top:** any `require_module "..."` declarations
(e.g., `require_module "core" "templates"` at the top of `project.sh`).

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

**Estimated saving:** ~100 lines. Eliminates the bug class of missing LOADED
flags (the `cli.sh` crash we fixed during testing).

---

### 1B. Replace manifest/tracking with a directory guard

**The real problem the manifest solved:** accidental `zzc init` in a
non-project directory (e.g., `~/prj`, `~/Documents`) which scatters the full
zzcollab scaffold across unrelated files. The manifest was built to reverse
this. A directory guard prevents it from happening.

**Add `assert_safe_init_directory()` to `lib/core.sh`:**

```bash
# Purpose: prevent accidental zzc init in occupied directories.
# Call at the start of cmd_init and cmd_quickstart.
# Bypass with --force flag.
assert_safe_init_directory() {
    # Count non-hidden subdirectories (ignoring .git)
    local subdirs
    subdirs=$(find . -maxdepth 1 -mindepth 1 -type d ! -name '.*' | wc -l)

    # Count non-hidden files/dirs (the total footprint)
    local items
    items=$(find . -maxdepth 1 -mindepth 1 ! -name '.*' | wc -l)

    if [[ $subdirs -gt 1 ]]; then
        log_error "This directory has $subdirs existing subdirectories."
        log_error "zzc init is intended for new, empty project directories."
        log_error "Create a subdirectory first:  mkdir myproject && cd myproject"
        log_error "Or bypass with:               zzc init --force"
        return 1
    fi

    if [[ $items -gt 3 ]]; then
        log_warn "This directory has $items existing items."
        confirm "Run zzc init here?" || return 1
    fi

    return 0
}
```

**Add `--force` to `cmd_init` and `cmd_quickstart`:** when `--force` is
present, skip `assert_safe_init_directory`.

**Add call** to `assert_safe_init_directory` at the top of `cmd_init`
(before `load_config`) and at the top of `cmd_quickstart` (before the
existing-project check).

**Remove from `lib/core.sh`:**
- `init_manifest()` (lines 239-281, ~42 lines).
- `track_item()` (lines 288-415, ~130 lines) -- the jq/txt branching tracker.
- `track_directory()`, `track_file()`, `track_template_file()`,
  `track_symlink()`, `track_docker_image()` (lines 418-422, 5 wrappers).
- `MANIFEST_FILE` and `MANIFEST_TXT` exported variables (lines 229-231).
- `JQ_AVAILABLE` constant (line 44 in the fallback branch) -- no longer
  needed for manifest; `jq` is still required for `parse_renv_lock` in
  validation so keep it as a soft check there.

**Remove `track_directory` call from `safe_mkdir()`** -- simplify to
just `mkdir -p` with a `log_info`.

**Remove all `track_*` call sites:**
- `modules/project.sh`: 6 calls in `create_directory_structure`,
  `create_r_package_files`, `create_devtools`.
- `modules/docker.sh`: 3 calls (`track_file "Dockerfile"`, etc.).
- `zzcollab.sh`: 7 calls in `cmd_docker` and build step.

**Simplify `cmd_rm` in `zzcollab.sh`** (~100 lines of manifest-reading
logic → ~20 lines of hardcoded cleanup):
```bash
cmd_rm() {
    local known_dirs=(R/ analysis/ tests/ man/ vignettes/ docs/ .github/ renv/)
    local known_files=(DESCRIPTION NAMESPACE LICENSE Makefile Dockerfile
                       renv.lock .Rprofile .gitignore .Rbuildignore .zzcollab/)
    log_warn "This will remove the zzcollab scaffold from: $(pwd)"
    log_warn "Directories: ${known_dirs[*]}"
    confirm "Proceed?" || return 0
    rm -rf "${known_dirs[@]}" "${known_files[@]}"
    log_success "zzcollab scaffold removed"
}
```

**Estimated saving:** ~320 lines. Eliminates `jq` as an optional dependency
(the fallback txt-manifest path was the only reason it was optional).

---

### 1C. Drop CRAN R version auto-detection

**Remove from `modules/docker.sh`:**
- `get_cran_r_version()` (lines 78-109, ~32 lines) -- queries
  `https://cran.r-project.org/src/base/` via curl.
- `get_buildable_r_version()` (lines 110-178, ~68 lines) -- validates
  against Docker Hub registry tags.
- The `_CACHED_CRAN_R_VERSION` cache variable.

**Replace all call sites** with `${CONFIG_R_VERSION:-$ZZCOLLAB_DEFAULT_R_VERSION}`.
`ZZCOLLAB_DEFAULT_R_VERSION` is already `4.5.2` in `lib/constants.sh`.
Update it with each zzcollab release -- one line vs. a network call.

Users who need a specific version set it once: `zzc config set r-version 4.4.2`.

**Estimated saving:** ~100 lines. Eliminates `curl` from the happy path.

---

### 1D. Trim `modules/help.sh` to command reference

**Current state:** 1,108 lines. Contains extended workflow descriptions,
collaboration narratives, and troubleshooting guidance that is fully
duplicated in the vignettes and `ZZCOLLAB_USER_GUIDE.md`.

**Keep:**
- `show_help_main()` -- one-line synopsis per subcommand (~30 lines).
- `show_help_docker()`, `show_help_config()`, `show_help_validate()` --
  one paragraph each with flag reference (~20 lines each).
- `show_help_profiles()` -- list of three profiles with sizes (~10 lines).
- `show_help_init()` -- replace two-screen narrative with five-line synopsis
  pointing to `vignette("quickstart1")` (~10 lines).

**Remove:** all extended narrative sections (~800 lines). Deep explanations
belong in the vignettes; the CLI help should be a quick reference.

**Estimated saving:** ~900 lines.

---

## Phase 2 -- Profile reduction (~500 lines removed)

### 2A. Reduce `templates/bundles.yaml` to three profiles

**Remove from `profiles:`:**
- `analysis_pdf` -- users needing PDF rendering: `install.packages("tinytex")`
  inside the container.
- `modeling` -- covered by `analysis` plus `install.packages("tidymodels")`.
- `publishing` -- niche; available via `--libs publishing` bundle flag.
- `manuscript-package` -- variant of publishing; same path.
- `shiny` -- niche; `install.packages("shiny")` inside any profile.

**Keep:**
- `minimal` -- `rocker/r-ver`, ~650MB, command-line only.
- `analysis` -- `rocker/tidyverse`, ~1.2GB, data analysis (recommended).
- `rstudio` -- `rocker/rstudio`, ~980MB, RStudio Server.

**Remove from `package_bundles:`:** `modeling`, `publishing`, `shiny`, `gui`.

**Remove from `library_bundles:`:** `modeling`, `publishing`, `gui`.

**Keep in bundles:** `minimal`, `tidyverse`, `none`, `terminals`.

### 2B. Update `zzcollab.sh` routing

**Remove from both hardcoded profile case arms** (lines ~1729 and ~1822):
- Profiles: `analysis_pdf`, `modeling`, `publishing`, `shiny`,
  `manuscript-package`.
- Aliases: `verse`, `tidyverse` from both arms.

**Remove capability conditions** that only existed for dropped profiles:
- `[[ "$profile" =~ ^(analysis|analysis_pdf|publishing)$ ]]` (lines 1259
  and 1337) -- zzvim-R install gate. Simplify to `[[ "$profile" == "analysis" ]]`.
- `analysis_pdf|publishing|manuscript-package)` case arm (line 1331) --
  PDF tools install. Remove entirely.

### 2C. Update dependent files

**`modules/config.sh`:** narrow the `prompt_select` profile list to
`minimal,analysis,rstudio`.

**`modules/profiles.sh`:** data-driven via `bundles.yaml`; no logic changes.

**`modules/help.sh`:** update profile listings (already reduced in Phase 1D).

**Estimated saving across Phase 2:** ~500 lines (bundles.yaml ~150,
`zzcollab.sh` routing ~150, help text ~150, `profiles.sh` minor ~50).

---

## Phase 3 -- Doctor and validation (~1,800 lines removed)

### 3A. Hand `validation.sh` entirely to `zzrenvcheck`

`zzrenvcheck` (sfw/08) is a dedicated R package that implements everything
`validation.sh` does using proper R tooling (`desc`, `jsonlite`, `httr`)
with a test suite. The bash version is a fragile reimplementation: notably,
`_renv_hash_from_crandb()` (line 208) hand-rolls renv's internal hash
algorithm in awk -- it will silently produce wrong results if renv's algorithm
changes.

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

**Move `create_renv_lock()`** (8 lines, currently at `validation.sh:360`)
to `modules/docker.sh` where it is called. This is the only function in
`validation.sh` that has no equivalent in `zzrenvcheck`.

**Estimated saving: 941 lines.**

**Note on zzrenvcheck availability:** `make check-renv` and `zzc validate`
now require R. Most validation runs happen inside the container via
`make docker-test` where R is always present. For host-side validation,
`zzrenvcheck` must be installed: `install.packages("zzrenvcheck")`. Add it
to the `analysis` and `minimal` profile renv.lock seeds.

### 3B. `modules/doctor.sh` -- keep core, remove peripheral

The primary purpose of `zzc doctor` is confirming that a project's template
files (Makefile, .Rprofile, Dockerfile, GitHub workflows) are current with
the installed zzcollab version and that the five-pillars file structure is
intact. The version stamp machinery is the heart of the command and stays.

**Keep:**
- `check_required_files()` (line 141) -- five-pillars file existence check.
- `check_required_dirs()` (line 160) -- scaffold directory structure check.
- `check_ignore_files()` (line 259) -- .gitignore / .Rbuildignore correctness;
  misconfigured ignore files cause silent CI failures.
- `check_version_stamps()` (line 329) -- compares template version stamps in
  Makefile, .Rprofile, Dockerfile, r-package.yml, and .Rprofile.local.
  This is the primary value of `zzc doctor`.
- `extract_version()`, `extract_md_version()`, `extract_zzvimr_version()`
  (lines 108-138) -- stamp readers used by check_version_stamps.
- `_maybe_record_fix()`, `bump_stamp()`, `apply_fixes()` (lines 634-695) --
  auto-update machinery invoked by `zzc doctor --fix`.
- `print_version_status()`, `print_info_status()` (lines 696-740) -- status
  display helpers.
- `check_workspace()` (line 558) -- the main orchestrator.

**Remove:**
- `check_ci_status()` (line 459, ~66 lines) -- wraps `gh run list`; not a
  workspace health check. Users run `gh run list` directly.
- `quiet_check_workspace()` (line 525, ~33 lines) -- `--porcelain`
  machine-readable output mode. Niche tooling use, complexity not justified.
- `scan_directory()` (line 743, ~36 lines) -- walks parent directories
  looking for zzcollab workspaces. Niche; remove `--scan` flag.
- `find_git_root()` (line 779, ~11 lines) -- helper for scan_directory only.
- `check_misplaced_files()` and `print_misplaced_header()` (line 191,
  ~70 lines) -- auto-moves misplaced files. Risky from a script; users
  can move files manually if doctor reports them.
- `main()` (line 790, ~60 lines) -- replace the multi-flag parser with a
  simple two-flag dispatcher keeping only `--fix` and `--dry-run`
  (~30 lines saved).

**Estimated saving:** ~250 lines. Target: ~625 lines.

---

## Dependencies eliminated

| Dependency | Eliminated by | Notes |
|---|---|---|
| `curl` | Phase 1C | Was used for CRAN version query at init time |
| `jq` (optional) | Phase 1B | Manifest was the only optional use; `jq` remains required for `zzc validate` (via zzrenvcheck) |

`yq` remains required (config system is unchanged). `jq` changes from
optional (manifest fallback) to required-for-validate only.

---

## Target line counts after all phases

| File | Current | Target | Notes |
|---|---|---|---|
| `zzcollab.sh` | 1,887 | ~1,100 | Routing cleanup, cmd_rm simplification |
| `modules/config.sh` | 1,597 | 1,597 | **Unchanged** -- recently refactored |
| `modules/doctor.sh` | 878 | ~625 | Remove ci_status, scan, misplaced, porcelain |
| `modules/validation.sh` | 941 | **deleted** | → zzrenvcheck |
| `modules/help.sh` | 1,108 | ~200 | Command reference only |
| `modules/docker.sh` | 810 | ~600 | Remove CRAN detection |
| `modules/profiles.sh` | 494 | ~200 | 3 profiles only |
| `lib/core.sh` | 687 | ~350 | Remove manifest tracking |
| `modules/project.sh` | 307 | ~260 | Remove track_* calls |
| `modules/github.sh` | 221 | ~200 | Minimal changes |
| `modules/cli.sh` | 241 | ~150 | Remove dropped profile aliases |
| `lib/templates.sh` | 233 | ~200 | Minimal changes |
| `lib/constants.sh` | 124 | ~100 | Minor cleanup |
| **Total** | **9,528** | **~5,500** | |

**Reduction: ~4,000 lines (42%).**

---

## What is NOT changed

- Config system (`modules/config.sh`, `~/.zzcollab/config.yaml`,
  `./zzcollab.yaml`) -- recently refactored with gum TUI; working correctly.
- Five Pillars model and the project scaffold it creates.
- Dockerfile generation logic (beyond removing dropped profiles).
- `make r` / `make docker-build` workflow.
- `zzc github` -- unchanged.
- `zzc renv` -- unchanged.
- The gum TUI integration (identity gate, project prompt).
- `lib/templates.sh` -- template installation and envsubst substitution.
- R package surface (`R/`, vignettes, NEWS.md, DESCRIPTION).

---

## Recommended execution order

1. **Phase 1A** (module loading) -- 30 min, very low risk.
2. **Phase 1B** (manifest → directory guard) -- 1.5 hr, low risk.
   Verify `zzc rm` still works; verify guard fires on `~/prj`.
3. **Phase 1C** (R version detection) -- 30 min, low risk.
   Verify `zzc docker` uses config default.
4. **Phase 1D** (help.sh trim) -- 1 hr, low risk.
   Verify `zzc help` and `zzc help docker`.
5. **Phase 2** (profiles) -- 2 hr, low risk.
   Verify all three profiles init and build. Verify dropped profile names
   give a clear "unknown profile" error.
6. **Phase 3A** (validation → zzrenvcheck) -- 2 hr, medium risk.
   Verify `make check-renv` on a known-good and known-bad workspace.
   Verify `zzc validate` exit codes.
7. **Phase 3B** (doctor slim-down) -- 2 hr, medium risk.
   Verify `zzc doctor` reports correctly on good/bad workspace.
   Verify removed functions are not called anywhere.

---
*Rendered on 2026-05-29 at 08:03 PDT.*<br>
*Source: ~/prj/sfw/07-zzcollab/zzcollab/docs/simplification-plan.md*
