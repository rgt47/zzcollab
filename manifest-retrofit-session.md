# Manifest Retrofit Session

*2026-05-04 16:55 PDT*

Session notes documenting an investigation into the zzcollab project
manifest system, three small code patches, and a scan of `~/prj` for
repositories that would benefit from manifest backfill.

## 1. Findings from initial investigation

### 1.1 `.zzcollab_project` is dead code

The string `.zzcollab_project` appears in three files, all as detectors
inside `[[ -f "$dir/.zzcollab_project" ]]` checks:

- `templates/navigation_scripts.sh:27`
- `tests/testthat/fixtures/mock_project/navigation_scripts.sh:27`
- `tests/testthat/fixtures/mock_project/zzcollab-entrypoint.sh:94`

No code in `zzcollab.sh`, `modules/`, `lib/`, or any template ever
creates the file. The detectors are unreachable. The de facto
project-root markers are `DESCRIPTION` and `.zzcollab/manifest.json`.

### 1.2 `.zzcollab/` is created on every scaffolded repo

Verified call chain:

- `zzcollab.sh:154`, `:311`, `:1403` are the three entry points; each
  calls `setup_project`.
- `setup_project` at `modules/project.sh:246` calls `init_manifest`
  before any other file creation.
- `init_manifest` in `lib/core.sh:239` does `mkdir -p .zzcollab` and
  writes `manifest.json` (or `manifest.txt` when `jq` is missing).

Hand-built repos that were never run through `zzc init` will not
have the directory. Doctor treats it as optional rather than required.

### 1.3 Doctor's treatment is asymmetric

`modules/doctor.sh:74-78` lists `.zzcollab` in `OPTIONAL_DIRS`, so
its absence prints a yellow warning but does not increment the issue
counter. The required-file contract is `DESCRIPTION`, `renv.lock`,
`.Rprofile`, `Makefile`, `Dockerfile`, `.gitignore`. Required dirs
are `R/` and `analysis/`.

Scan-mode (`zzc doctor --scan`) uses a different heuristic: the
presence of the string `zzcollab` inside a `Makefile`, parsed at
`modules/doctor.sh:683`. This is the closest thing the codebase has
to an 'is this scaffolded?' detector.

## 2. Tracking gap discovered in `create_file_if_missing`

### 2.1 The bug

Two template installers in `lib/templates.sh`:

- `install_template` (line 211) calls `track_template_file` after
  `copy_template_file` returns 0, including the
  skipped-because-exists case. Existing files DO get tracked.
- `create_file_if_missing` (line 179) calls `track_file` only after
  successfully writing. The early-return at line 186-189 bypasses
  tracking. Existing files do NOT get tracked.

### 2.2 Files affected

Routed through `create_file_if_missing` and therefore not tracked
when they already exist:

- `NAMESPACE` (`project.sh:75`)
- `LICENSE` (`project.sh:80`)
- `tests/testthat.R` (`project.sh:117`)
- `tests/testthat/test-basic.R` (`project.sh:123`)
- `.gitignore` (`project.sh:171`)
- `.Rbuildignore` (`project.sh:184`)
- GitHub PR and issue templates (`github.sh:150, 178, 198`)

`Dockerfile` and `renv.lock` are written outside `setup_project`
entirely (`modules/docker.sh:565` and `:108`, `validation.sh:282`)
and were never tracked anywhere.

### 2.3 Consequence

A user who hand-builds a zzcollab-shaped repo, then runs `zzc init`
to adopt it, then later runs `zzc uninstall`, would find
`.gitignore`, `.Rbuildignore`, `NAMESPACE`, `LICENSE`, `Dockerfile`,
`renv.lock`, and the test scaffolding files left behind because
they were never recorded in the manifest.

## 3. Patches applied

### 3.1 Symmetric tracking in `create_file_if_missing`

`lib/templates.sh:188`. Add `track_file` to the skip path so it is
symmetric with `install_template`.

```bash
if [[ -f "$file_path" ]]; then
    log_info "$description already exists, skipping creation"
    track_file "$file_path"
    return 0
fi
```

### 3.2 Track `renv.lock` on retrofit

`modules/project.sh:200`. The early-return in `create_renv_setup`
now records the pillar before exiting.

```bash
if [[ -f "renv.lock" ]]; then
    log_info "renv.lock already exists, skipping renv init"
    track_file "renv.lock"
    return 0
fi
```

### 3.3 Track `Dockerfile` on retrofit

`modules/project.sh:262-264`. The Docker pillar is written by
`modules/docker.sh`, not `setup_project`, so retrofit-track it at
the end of `setup_project` if it exists.

```bash
[[ -f "Dockerfile" ]] && track_file "Dockerfile"
```

### 3.4 Idempotent appends in `track_item`

`lib/core.sh:288-402`. The original implementation used
`'.files += [$file]'` with no dedup, so re-running `zzc init` on
an existing manifest produced duplicate entries.

Changes for each array case:

- `'.directories |= (. + [$dir] | unique)'`
- `'.files |= (. + [$file] | unique)'`
- `'.template_files |= (. + [{...}] | unique)'`
- `'.symlinks |= (. + [{...}] | unique)'`

The text-fallback branches (used when `jq` is missing) gained a
`grep -qxF` guard before each `echo >>`. The `docker_image` text
branch was switched from append to overwrite so it matches the
JSON path's `=` semantics.

Audit confirmed every consumer iterates manifest arrays without
order or count dependence (`zzcollab.sh:938-975`,
`tests/testthat/fixtures/mock_project/zzcollab-uninstall.sh:108-117`).
The two vignette mentions of 'manifest' refer to Docker multi-arch
manifests, not the zzcollab manifest.

### 3.5 `--porcelain` mode for `zzc doctor`

`modules/doctor.sh`. Added a machine-readable per-repo line of
the form:

```
<path>\t<errors>\t<warnings>\t<comma_sep_codes>
```

Codes emitted: `missing-file:<f>`, `missing-dir:<d>`,
`no-manifest`. The flag was named `--porcelain` (the git
convention) rather than `--quiet` to avoid colliding with the
top-level `-q|--quiet` at `zzcollab.sh:1646`, which sets
`VERBOSITY_LEVEL=0`.

Implementation adds a `quiet_check_workspace` function that
bypasses the human-formatted check pipeline and runs only the
checks needed for the adoption-finding workflow. The verbose
pipeline is unchanged.

## 4. Verification

### 4.1 Static and lint

- `bash -n` on all modified files: OK
- `shellcheck --severity=warning` (CI level): clean

### 4.2 Test suites

| Suite | Result |
| --- | --- |
| `tests/shell/test-cli.sh` | 22/22 |
| `tests/shell/test-config.sh` | 28/28 |
| `tests/shell/test-core.sh` | 16/16 |
| `tests/shell/test-docker.sh` | 17/17 |
| `tests/shell/test-integration.sh` | 15/15 |

`tests/shell/test-docs.sh` has four pre-existing failures about
documentation drift on obsolete CLI flags (`-i`, `-I`,
`--build-mode`, `interface=`) in `docs/archive/zzcollab-user-guide-v3.md`.
Unrelated to these changes; failure messages name only
documentation files.

### 4.3 Manual retrofit verification

Pre-created `DESCRIPTION`, `.gitignore`, `.Rbuildignore`,
`tests/testthat.R`, `renv.lock`, and `Dockerfile` in an empty
directory, then ran `zzc init`. All six pillars appeared in
`.zzcollab/manifest.json`.

### 4.4 Manual dedup verification

Three successive `zzc init` runs on the same directory: manifest
remained unique (8 files, 16 directories, 6 templates with no
duplicates).

## 5. Scan of `~/prj` for adoption candidates

Detector: any directory containing `DESCRIPTION` plus `Makefile`
plus `Dockerfile`, found via `find -L ~/prj -maxdepth 5`. Each
match was passed to `zzc doctor --porcelain`.

### 5.1 Aggregate counts

| Category | Count |
| --- | --- |
| Total scanned | 123 |
| Clean (manifest present, no errors) | 77 |
| Adoption candidates (no manifest, structurally sound) | 46 |
| Errors needing investigation | 2 |

### 5.2 Distribution of adoption candidates

- `qblog/posts/*` (35 repos): blog post workspaces
- `sfw/*` (5 repos): `zztable1`, `zzpower`, `zzedc`, `zzcollab`,
  `zzworld`
- `res/*` (4 repos): three `archive/` snapshots plus
  `fisherexacttestrx2`
- `alz/*` (2 repos): `06-adniml/archive` and `pmsimstats-ng`

### 5.3 Repos with errors

```
prj/alz/06-adniml/archive  E=2 W=1
  codes=missing-file:.Rprofile,missing-file:.gitignore,no-manifest

prj/sfw/09-zzworld/zzworld  E=1 W=1
  codes=missing-dir:analysis,no-manifest
```

### 5.4 Recommended exclusions

- `prj/sfw/07-zzcollab/zzcollab`: this is the framework source
  itself, not a research workspace, and should never carry a
  manifest. Filter manually.
- `archive/` directories (four total): frozen snapshots of older
  work; adoption is a judgement call.
- `qblog/posts/*` (35 repos): blog post workspaces; adoption
  contract implies later cleanup via `zzc uninstall`. Skip
  unless intentional.

After exclusions, six legitimate adoption candidates remain:

```
prj/alz/10-pmsimstats-ng/pmsimstats-ng
prj/res/01-fisher-exact-rx2/fisherexacttestrx2
prj/sfw/02-zztable1/zztable1
prj/sfw/03-zzpower/zzpower
prj/sfw/05-zzedc/zzedc
prj/sfw/09-zzworld/zzworld
```

## 6. Per-candidate dry-run prediction

Static walk against `setup_project` logic, with one live
verification on `zzworld` (smallest repo, 232K).

The live run revealed one item missing from the static
prediction: `setup_project` installs both `r-package.yml` and
`render-report.yml` workflow templates. The table below has
been corrected.

| Repo | Dirs created | Files preserved + tracked | Files newly created |
| --- | --- | --- | --- |
| `pmsimstats-ng` | 3 | 11 + render-report | 3 (data README, 2 test files) |
| `fisherexacttestrx2` | 1 | 12 + render-report | 2 (test files) |
| `zztable1` | 1 | 10 + render-report | 4 (USER\_GUIDE, LICENSE, 2 test files) |
| `zzpower` | 1 | 10 + render-report | 4 (same as zztable1) |
| `zzedc` | 1 | 10 + render-report | 4 (same as zztable1) |
| `zzworld` | 9 | 9 + render-report | 5 (data README, USER\_GUIDE, LICENSE, 2 test files) |

Universal observations:

- No file overwrite. All existing files preserved.
- `renv.lock` and `Dockerfile` are tracked thanks to the recent
  fixes.
- 16 directories always go in the manifest regardless of
  pre-existing state.

## 7. Open issue: `.Rprofile` is not tracked on retrofit

Discovered during live verification. `create_renv_setup` has
two branches:

- `renv.lock` exists: early-return, tracking `renv.lock` only
  (the recent fix).
- `renv.lock` is missing: proceed to install `.Rprofile` from
  template, which calls `install_template` and tracks it.

For a hand-built repo with both `renv.lock` and `.Rprofile`
already present, the early-return branch fires and `.Rprofile`
is never recorded. All six adoption candidates have this
condition.

Proposed one-line fix in `modules/project.sh`:

```bash
if [[ -f "renv.lock" ]]; then
    log_info "renv.lock already exists, skipping renv init"
    track_file "renv.lock"
    [[ -f ".Rprofile" ]] && track_file ".Rprofile"
    return 0
fi
```

Apply before bulk-adopting any of the six candidates if the
goal is a `zzc uninstall` that fully cleans up.

## 8. Suggested next steps

1. Apply the `.Rprofile` patch from section 7.
2. Re-run a live dry-run against one or two of the six
   candidates to confirm `.Rprofile` now appears in the
   manifest.
3. Bulk-adopt the six identified candidates with `zzc init`,
   relying on the dedup patch to make the operation safely
   idempotent.
4. Decide separately whether to adopt the `qblog/posts/*` and
   `archive/*` directories.

## 9. Limitations of this session

- Live verification ran against `zzworld` only. The other five
  candidates are predicted by static walk, with one live
  cross-check.
- The text-fallback path in `track_item` (active only when `jq`
  is unavailable) was modified by inspection. Not exercised by
  the integration test suite, since `jq` was present in every
  run.
- The `--porcelain` mode emits only three signal categories.
  Version-stamp drift, misplaced files, `.gitignore` content
  gaps, and CI status are not surfaced. The narrow shape was a
  deliberate scope choice for the adoption use case.
- Scan was `find -maxdepth 5` from `~/prj`. Deeper nesting is
  not covered.
- Output paths follow the Dropbox-resolved form
  (`/Users/zenn/Library/CloudStorage/Dropbox/prj/...`) when
  read through symlinks. Downstream tooling may need
  normalisation.

---

*Rendered on 2026-05-04 at 16:55 PDT.*<br>
*Source: ~/prj/sfw/07-zzcollab/zzcollab/manifest-retrofit-session.md*
