# zzcollab Configuration Cheatsheet

*2026-10-19 — verified against modules/config.sh, modules/docker.sh,
modules/cli.sh as of this date. See `vignette("configuration")` for
explanations and `docs/dockerfile-variable-reference.md` for the full
pdf/archetype mechanics.*

## Where settings live (priority: project wins over user)

| File | Scope | Set with |
|---|---|---|
| `./zzcollab.yaml` | this project, committed | `zzc config set-local KEY VALUE` |
| `~/.zzcollab/config.yaml` | you, all projects | `zzc config set KEY VALUE` |

No system-wide (`/etc/zzcollab/...`) layer and no generic env-var
override — despite a leftover constant suggesting otherwise. CLI flags
(`--profile`, `--base`, `--r-version`, `--no-renv`) beat both files but
only exist for a few settings.

## Config keys

| Key (kebab or snake, either works) | Values | Default | Effect |
|---|---|---|---|
| `team-name` | any string | — | identity only |
| `github-account` | any string | — | identity only |
| `dockerhub-account` | any string | team-name | image namespace |
| `profile-name` | `minimal`, `tidyverse`, `rstudio`, `publishing`, `analysis` (deprecated alias → `tidyverse`) | `minimal` | **base image only** |
| `archetype` | `manuscript`, `book`, `blog`, `analysis`, `package`, `simulation` | `analysis` | scaffolding; `manuscript`/`book` default `pdf=true`; `blog`/`book` default Quarto on |
| `pdf` | `true`/`yes`/`on`, `false`/`no`/`off`, unset | unset | **always wins** over archetype default; `true` also forces Quarto on, no way to decline it |
| `languageserver` | `true`/`false` | `true` | in-container LSP |
| `features.code_quality` | `on`/`off` | `off` | adds `styler`/`lintr`; also auto-on if `.pre-commit-config.yaml` exists |
| `auto_github` | `true`/`false` | `false` | pre-selects GitHub-remote creation in init wizard |
| `docker_runtime` | `docker`/`podman`/`apptainer` | `docker` | which binary `zzc rebuild` calls |
| `docker.registry` | registry URL | — | push target |
| `forge` | `github`/`gitlab`/`none` | — | which forge commands target |

> ⚠️ **`analysis` means two different things.** A deprecated alias for
> the `tidyverse` *profile*, and a valid, separate *archetype* value.
> `profile-name: analysis` and `archetype: analysis` do unrelated
> things.

## Profiles → base image only (verify before relying on anything else)

| Profile | Base image | Size | arm64? |
|---|---|---|---|
| `minimal` | `rocker/r-ver` | ~650MB | yes |
| `tidyverse` ⭐ default | `rocker/tidyverse` | ~1.2GB | yes |
| `rstudio` | `rocker/rstudio` | ~980MB | yes |
| `publishing` | `rocker/verse` | ~4.2GB | **no** |

A profile's advertised package/library bundle in `bundles.yaml` is
**not installed** by choosing it — the generator reads `base_image`
only. Packages always come from `renv::restore()` against `renv.lock`
(or `DESCRIPTION` in `--no-renv` mode). Switching profile down (e.g.
`tidyverse` → `minimal`) can break code that relied on packages the old
base happened to ship but that were never pinned in `renv.lock`.

For anything else (Shiny, Bioconductor, geospatial): `--base`/
`--base-image <any valid docker ref>`, packages added via renv.

## pdf / archetype — decision shortcut

```
Does the project render to PDF?
├─ no  → leave pdf unset; pick archetype: analysis/package/simulation
└─ yes → is the base rocker/verse (publishing profile)?
         ├─ yes → TeX already there; pdf/archetype only control the
         │         LaTeX warm-up (package pre-bake), not the install
         └─ no  → set pdf: true EXPLICITLY (don't rely on archetype
                   alone — it's what .zzcollab-state remembers across
                   a bare `zzc docker` regeneration)
```

No `CONFIG_QUARTO` key exists. Quarto only turns on via `archetype:
blog`/`book`, or as a forced side effect of `pdf: true`.

## Commands

```bash
# Setup
zzc config init                          # create ~/.zzcollab/config.yaml
zzc config set KEY VALUE                 # user default
zzc config set-local KEY VALUE           # project override (./zzcollab.yaml)
zzc config get KEY
zzc config list                          # merged config
zzc config list --local                  # project file only, raw
zzc config validate                      # YAML syntax only, no semantic checks

# New project
zzc tidyverse | minimal | rstudio | publishing   # init + renv + docker
zzc init --archetype manuscript                  # scaffold only

# Existing project
zzc docker --profile minimal             # switch profile, regenerate Dockerfile
zzc docker --base rocker/shiny           # custom base image
zzc docker --no-renv                     # DESCRIPTION-install mode (only if no renv.lock)
zzc rebuild --verbose                    # regenerate + build, verbose log
zzc list profiles | libs | pkgs          # inspect bundles.yaml

# Team
zzc github                               # create private repo
zzc dockerhub                            # push team image
make docker-build && make docker-push-team    # lead
git clone ... && make docker-build            # member

# Package hygiene (run before commit)
make snapshot                            # grow renv.lock from running image
make check-renv                          # strict validate + auto-fix
```

## Global flags (any command)

```
-v / --verbose      -q / --quiet      -y / -Y (accept defaults)
--no-build           (skip Docker build prompt)
```

## Gotchas verified this session

- `rocker/verse` has **no arm64 image** — QEMU emulation breaks pandoc
  outright, not just slow. Default base is `rocker/tidyverse` for this
  reason.
- `install_texlive.sh`'s `apt-get update` only runs if it detects empty
  apt lists, which misses the state left by the pandoc/Quarto steps
  immediately before it — fixed upstream in this repo by making the
  update unconditional; if you see `Package 'perl' has no installation
  candidate` on a minimal+pdf build, you're on an old checkout.
- `tinytex::install_tinytex()` is **not** used for TeX Live — it
  validates against `~/.TinyTeX` regardless of the `dir=` you pass it,
  so it reports failure on an otherwise-complete install. TeX Live goes
  in via rocker's own `install_texlive.sh`, pinned to a frozen
  `tlnet-final` snapshot (not the rolling `mirror.ctan.org` redirector).
- No `config list --verbose`, no per-key source annotation anywhere.
  To find out whether a value comes from user or project config,
  diff the two files yourself.

---
*Rendered on 2026-10-19 at 11:18 PDT.*<br>
*Source: ~/prj/sfw/07-zzcollab/zzcollab/docs/zzcollab-cheatsheet.md*
