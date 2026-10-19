# Dockerfile Generator Variable Reference

*2026-10-19 10:56 PDT*

**Status:** descriptive, not prescriptive. This document records how
`modules/docker.sh` behaves as read from source on the date above. It is
not a design spec; if the code changes, this document is stale until
someone updates it. Line numbers cite the file as of this writing and will
drift.

## Scope

zzcollab does not ship a static Dockerfile. Every project's Dockerfile is
produced by one function, `generate_dockerfile()` in `modules/docker.sh`
(1508 lines total), which calls `generate_dockerfile_inline()` to emit the
final text. This document enumerates every variable that function and its
callees read, states what each one controls, and works through the
interactions between them that are not obvious from reading any single
variable in isolation.

For the build-time cost optimization of the content these variables
produce (caching, layer order, binary vs. source installs), see
`dockerfile-template-optimization-whitepaper.md`. That paper predates the
`pdf`/archetype capability-gating system described here; it has no
coverage of `CONFIG_PDF`, `needs_pdf`, `needs_quarto`, or `has_texlive`.

## 1. The generation pipeline

`generate_dockerfile()` (docker.sh:949) runs in this order:

1. Resolve `r_version` — explicit `R_VERSION` env var, else
   `extract_r_version()` (reads `renv.lock` or triggers the interactive
   wizard if none exists and the shell is a TTY).
2. Resolve `base_image` — explicit `BASE_IMAGE` env var, else
   `get_profile_base_image("${CONFIG_PROFILE_NAME:-minimal}")`.
3. Scan the project for R packages (`extract_r_packages()`: code files +
   `DESCRIPTION` + `renv.lock`, deduplicated).
4. Derive system library dependencies from that package list
   (`derive_system_deps()`), then filter out libraries already present on
   the resolved base (`generate_system_deps_install()`).
5. Build the tools-install block (`generate_tools_install()`) — pandoc,
   Quarto, TeX Live, dev tooling. This is where `pdf` and `archetype`
   interact; see Section 3.
6. Resolve the base image's content-addressed digest
   (`resolve_image_digest()`), network call, best-effort.
7. Call `generate_dockerfile_inline()` to assemble and write the file.
8. Write `tooling.lock` (pinned non-renv tool versions: `zzrenvcheck`,
   PPM snapshot, base digest).

Steps 3–6 run in sequence but do not depend on each other's output; they
only converge at step 7. The one real dependency in this list is that step
5 depends on the `base_image` resolved in step 2 — every capability check
in `generate_tools_install` takes `base_image` as an argument and
string-matches it.

## 2. Variable catalogue

### 2.1 Settings — read from outside the generator

| Variable | Set via | Values | Effect |
|---|---|---|---|
| `BASE_IMAGE` | `--base`/`--base-image` CLI flag, or exported before calling `generate_dockerfile` directly | any string matching `^[a-zA-Z0-9][a-zA-Z0-9.:/_-]*$`, no doubled `/` or `:` | Overrides profile-based resolution entirely. Fed into every `*base_image*` string match below. |
| `R_VERSION` | `--r-version` CLI flag | strict `X.Y.Z` | R version tag in `FROM`; also drives `get_ubuntu_codename()`, which selects the PPM binary repository. |
| `CONFIG_PROFILE_NAME` | `zzc config set profile_name <name>` (aliases: `profile_name`, `profile` → `docker.default_profile`) | `minimal`, `tidyverse`, `rstudio`, `publishing` (`analysis` accepted as deprecated alias for `tidyverse`) | Resolves `base_image` via `get_profile_base_image()` against `templates/bundles.yaml`, only when `BASE_IMAGE`/`--base` was not given. |
| `CONFIG_PDF` | `zzc config set pdf <value>` / `set-local` | `true`/`yes`/`on`, `false`/`no`/`off`, or unset | See Section 3. Overrides the archetype-derived default for `needs_pdf`. |
| `CONFIG_ARCHETYPE` | `zzc init --archetype A` | `manuscript`, `book`, `blog`, `analysis`, `package`, `simulation`, or unset | Supplies the *default* for `needs_pdf`/`needs_quarto` when `CONFIG_PDF` is unset. See Section 3. |
| `CONFIG_LANGUAGESERVER` | `zzc config set languageserver <bool>` | `true` (default), `false` | Whether `languageserver` is added to the dev-tooling `install.packages()` call. |
| `CONFIG_FEAT_CODE_QUALITY` | `zzc config set features.code_quality <on|off>` | `on`, `off` (default) | Adds `styler`, `lintr` to the same install call. Also triggered automatically if `.pre-commit-config.yaml` exists in the repo — this is an OR, not a replacement: either condition alone is sufficient. |
| `PPM_SNAPSHOT` | exported env var only, no config path | `YYYY-MM-DD` | Dated Posit Package Manager snapshot baked into `RENV_CONFIG_REPOS_OVERRIDE` and `tooling.lock`. Defaults to yesterday's date (`date -d '1 day ago'` / `date -v-1d`). |
| `ZZCOLLAB_QUARTO_VERSION` | exported env var only | semver, e.g. `1.6.43` | Quarto CLI version installed when the base lacks it. |
| `ZZRENVCHECK_TAG` | exported env var only | `vX.Y.Z` | `zzrenvcheck` version baked into `tooling.lock`; not otherwise read by the Dockerfile generator. |
| `--no-renv` (CLI flag, not an env var) | CLI flag to `zzc docker` | present/absent | Switches `install_mode` between `renv` (restore from `renv.lock`) and `description` (install from `DESCRIPTION` against the PPM snapshot). Only takes effect if no `renv.lock` exists; if one exists, the flag is a no-op with a warning. |

### 2.2 Derived capability/need flags — computed every run, not stored as settings

| Variable | Computed by | Logic |
|---|---|---|
| `has_pandoc` | `get_base_image_tools()` | string match on `base_image` |
| `has_quarto` | `get_base_image_has_quarto()` | matches `*tidyverse*`, `*verse*`, `*rstudio*`, `*shiny*` |
| `has_texlive` | `get_base_image_has_texlive()` | matches `*verse*`, with an explicit `*tidyverse*` case checked **first** and set to `false` — `tidyverse` contains the substring `verse`, so without that ordering a naive `*verse*` glob would misreport a tidyverse base as already having TeX Live |
| `needs_pdf` | `get_needs_pdf()` | see Section 3 |
| `needs_quarto` | inline in `generate_tools_install()` | see Section 3 |

### 2.3 Static lookup tables — code, not configuration

| Variable | Role |
|---|---|
| `BASE_PROVIDED_SYSLIBS` | Hardcoded list of apt packages assumed present on any "full" rocker base (`tidyverse`/`verse`/`rstudio`/`shiny`) because those images build the tidyverse from source. Used by `filter_base_provided_deps()` to avoid redundant installs. |
| `_DOCKER_BASE_PKGS`, `_DOCKER_SKIP_PKGS`, `_DOCKER_SKIP_FILES`, `_DOCKER_FILE_EXTENSIONS` | Supporting tables for the package/file scan in `extract_r_packages`/`extract_code_packages`. |

These are not settable through config. A profile built on a base image
not covered by the `*tidyverse*|*verse*|*rstudio*|*shiny*` match in
`generate_system_deps_install()` (docker.sh:874) falls through to the
"minimal base" branch and gets the full toolchain preamble even if the
actual base already ships it — over-installation, not failure, but a
real layer-size cost that this table doesn't catch for an uncovered base.

## 3. The interaction that matters: `pdf` × `archetype` × base image

This is the one piece of real cross-variable logic in the file
(docker.sh:67–83, 128–203), and it is worth walking through explicitly
because the precedence is not symmetric between `needs_pdf` and
`needs_quarto`.

### 3.1 `needs_pdf` resolution (`get_needs_pdf()`, docker.sh:67)

Three-tier precedence, each tier short-circuiting the next:

1. **Explicit `CONFIG_PDF`.** `true`/`yes`/`on` → `true`.
   `false`/`no`/`off` → `false`. Either way, resolution stops here.
2. **Remembered state.** If `CONFIG_PDF` is unset, check `.zzcollab-state`
   for a line `pdf=<value>` from the last generation. This exists
   specifically because `zzc docker` can regenerate the Dockerfile from a
   shell that has not loaded the project's `zzcollab.yaml` — without this
   fallback, a bare regeneration could silently drop the TeX Live block
   from a manuscript project that never set `CONFIG_PDF` explicitly, only
   relied on its archetype.
3. **Archetype default.** If neither of the above resolved a value:
   `manuscript` or `book` → `true`; everything else (`blog`, `analysis`,
   `package`, `simulation`, unset) → `false`.

### 3.2 `needs_quarto` resolution (inline, docker.sh:145–151)

A different, and asymmetric, precedence:

1. `CONFIG_ARCHETYPE` of `blog` or `book` → `true`.
2. **Unconditionally**, regardless of step 1's result:
   `[[ "$needs_pdf" == "true" ]] && needs_quarto="true"`.

There is no explicit `CONFIG_QUARTO` setting. Quarto installation cannot
be requested independently of archetype or `pdf` — the only two paths to
`needs_quarto=true` are "archetype says so" or "pdf said so." A project
that wants Quarto rendering without the TeX Live stack and without the
`blog`/`book` archetype (e.g. HTML-only Quarto output on `analysis`) has
no config-level way to say that; it would need `--base` pointed at an
image that already bundles Quarto, or a code change.

Also note the asymmetry in direction: `needs_pdf` can be forced `false`
by explicit config even under a `manuscript`/`book` archetype (tier 1
above wins outright), but there is no equivalent override to force
`needs_quarto` false once `needs_pdf` is true — the `&&` at docker.sh:151
is unconditional. Setting `pdf: true` on any archetype always drags in
Quarto, with no escape hatch in config.

### 3.3 Combined truth table

Holding base image and archetype's other scaffold effects aside, and
assuming `CONFIG_PDF` is left unset so archetype supplies the default:

| Archetype | `needs_pdf` | `needs_quarto` | TeX Live block emitted | Quarto block emitted |
|---|---|---|---|---|
| `manuscript` | `true` | `true` | if base lacks TeX Live | if base lacks Quarto |
| `book` | `true` | `true` | if base lacks TeX Live | if base lacks Quarto |
| `blog` | `false` | `true` | never | if base lacks Quarto |
| `analysis` | `false` | `false` | never | never |
| `package` | `false` | `false` | never | never |
| `simulation` | `false` | `false` | never | never |
| *(unset)* | `false` | `false` | never | never |

Consequence verified in this project's working session: `manuscript` and
`book` produce Dockerfiles identical to each other in this respect, and
`analysis`/`package`/`simulation`/unset collapse to one identical group.
Only `blog` is distinguishable from both.

Setting `CONFIG_PDF` explicitly erases all six rows above and replaces
them with exactly two: `pdf: true` (both blocks gated only by what the
base already has) or `pdf: false` (neither block, ever, regardless of
archetype).

### 3.4 Base-image gating within each branch

Each "if needed" cell above is itself gated a second time by the base
image's existing capability, so the actual emitted content is a 2×2, not
a binary:

- **`needs_pdf=true`, `has_texlive=true`** (e.g. `publishing` profile on
  `rocker/verse`): no TeX Live install block, but the LaTeX-package
  warm-up block (`tlmgr_install` + three warm-up renders) still runs
  unconditionally whenever `needs_pdf=true` — it pre-bakes the package
  closure as root even on a base that already has the engine, because the
  closure itself (not the engine) is what's missing.
- **`needs_pdf=true`, `has_texlive=false`** (e.g. `minimal`/`rocker/r-ver`
  with `pdf: true`): full TeX Live install (mirror-pinned
  `install_texlive.sh` run) plus the same warm-up block.
- **`needs_pdf=false`**: neither block, regardless of `has_texlive`.
  A `publishing`-profile project that later sets `pdf: false` keeps
  `rocker/verse`'s pre-installed TeX Live sitting unused in the image;
  nothing strips it back out.

The Quarto gate works the same way: `needs_quarto=true` with
`has_quarto=true` emits nothing; `needs_quarto=true` with
`has_quarto=false` emits the `TARGETARCH`-aware `.deb` install.

## 4. Other interactions worth flagging

- **`derive_system_deps` runs independently of the pdf/quarto gate.** It
  scans actual R package usage (code + `DESCRIPTION` + `renv.lock`) and
  derives apt dependencies from *that*, entirely separate from the
  capability logic in Section 3. A project needing `sf` (spatial) gets
  `libgdal-dev` etc. regardless of its `pdf`/`archetype` settings, and
  that install is filtered against `BASE_PROVIDED_SYSLIBS` using the same
  `*tidyverse*|*verse*|*rstudio*|*shiny*` base-image match used for the
  TeX/Quarto probes — so a change to that match pattern affects three
  unrelated decisions at once (TeX Live presence, Quarto presence, and
  system-library redundancy filtering), not just one.
- **`install_mode` (renv vs. description) does not interact with
  Section 3 at all.** It only changes how project R *packages* are
  installed, not whether TeX/Quarto/dev-tooling are installed. The two
  systems are orthogonal; `pdf: true` with `--no-renv` is a valid,
  untested-in-this-session combination.
- **`PPM_SNAPSHOT` affects both `RENV_CONFIG_REPOS_OVERRIDE` (used by
  `install_mode=description` AND by `renv::restore()` in renv mode,
  since the `ENV` is set regardless of mode) and `tooling.lock`.** It is
  one value read in two places that don't otherwise interact.
- **`resolve_image_digest` is best-effort and silent on failure.** If
  Docker isn't installed or the pull fails, `image_digest` is empty and
  the generator falls back to `FROM base:tag` with no digest pin — this
  degrades reproducibility (R-2 in the codebase's own numbering) without
  failing the build. It runs after all the capability/need resolution in
  Section 3, so a failed digest pull never affects which install blocks
  get emitted, only the `FROM` line's precision and the `tooling.lock`
  record.

## 5. What this document does not cover

- The scaffold/symlink side of `archetype` (`project.sh`'s
  `archetype_spec()`), which determines what files `zzc init` creates —
  orthogonal to Dockerfile generation, covered nowhere in this doc.
- `build_docker_image()`, `compute_dockerfile_hash()`,
  `find_cached_image()` — these execute or cache the build, they do not
  change generated *content*, so they're out of scope here.
- The interactive wizard path (`prompt_new_workspace_setup()`) — it only
  prompts for values that then flow through the same variables tabulated
  above; it introduces no additional generation logic.
- Whether any of this design is *correct* — this document is a map of
  current behavior, not an argument for it. The two open design gaps
  flagged above (no `CONFIG_QUARTO` escape hatch; `BASE_PROVIDED_SYSLIBS`
  blind to uncovered bases) are observations, not recommendations.
