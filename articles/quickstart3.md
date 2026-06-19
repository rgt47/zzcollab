# Quickstart: Reproducibility Feature Toggles

## Overview

A zzcollab compendium is not all-or-nothing. Reproducibility is built
from independent features that can be added or removed at any time: a
package backend, a containerised environment, continuous integration,
data-integrity hashing, code-quality hooks, unit tests, and cloud
launch. This guide exercises the machinery that creates a compendium and
changes those features afterwards.

Two ideas organise everything below.

- **The artifact is the state.** A feature is on when its primary file
  is present (`renv.lock`, `Dockerfile`, `flake.nix`,
  `data-manifest.sha256`, and so on). The generated files self-adapt to
  what they find, so toggling a feature is a matter of creating or
  removing one artifact, not editing scattered configuration.

- **Capture versus validation.** Capture features pin the computational
  environment and set the reproducibility level; validation features
  (CI, tests, code quality) check the result without changing the level.

| Level | Meaning                                            |
|-------|----------------------------------------------------|
| L0    | Locatable: a valid compendium, packages not pinned |
| L1    | Packages pinned (a backend present)                |
| L2    | Environment pinned (a container or Nix)            |
| L3    | Verified: rebuilt and re-run, matching a baseline  |

## Creating a compendium

`zzc init` scaffolds the compendium and asks two creation-time
questions: the research archetype and which reproducibility features to
enable.

``` bash
mkdir penguins-study && cd penguins-study
zzc init
```

The first question is the **archetype**, which shapes the starter layout
and the render gate:

    Archetype [analysis/manuscript/package/simulation/blog] (default analysis):

- `manuscript`, `analysis`, and `blog` scaffold a report
  (`analysis/report/report.Rmd`) and carry a render gate; `blog`
  additionally gets an `analysis/posts/` directory.
- `package` and `simulation` do not scaffold a report; `simulation` gets
  a seeded, parallel-ready starter script instead.

The second is the **feature wizard** (the same wizard that `zzc toggle`
uses, described below). At creation it recommends the full L2 setup,
renv plus Docker, which you may untick. Non-interactive callers skip the
wizard entirely:

``` bash
# Fully non-interactive: scaffold only, add features later.
zzc init --yes --archetype package
```

The archetype can also be supplied as a flag or read from configuration:

``` bash
zzc init --archetype manuscript
zzc config set archetype simulation   # default for future projects
```

## Seeing the current state: `zzc status`

`zzc status` is read-only. It prints the user-level defaults (what new
projects start from) and the live state of the current compendium,
derived from artifact presence, with each feature tagged as a capture or
validation concern.

``` bash
zzc status
```

    GLOBAL  ~/.zzcollab/config.yaml   (defaults for new projects)
      profile        analysis
      registry       ghcr
      dockerhub      (unset)
      runtime        docker

    LOCAL   /path/to/penguins-study   (level: L2, verified: no)
      archetype      analysis
      backend        renv  (capture)
      environment    docker on  (capture)   base: rocker/tidyverse:4.6.0@sha256:a95c...   install: renv
      CI check       on   (validation)   r-package.yml
      CI render      on   (validation)   render-report.yml
      unit tests     on   (validation)   inst/tinytest/
      code quality   off  (validation)   .pre-commit-config.yaml
      data hash      off  (capture)      data-manifest.sha256
      cloud          devcontainer on  binder off
      git            on

    Levels: L0 locatable, L1 pinned packages, L2 pinned environment, L3 verified.
    verified: no  (run 'zzc verify' for coherence, 'zzc verify --full' for L3)

The facts come from a generated `.zzcollab-state` record (the base
image, its digest, the install mode, the archetype), so `status` never
re-parses the `Dockerfile`.

## Changing features interactively: `zzc toggle`

`zzc toggle` presents the backend (a single-select choice) and the
feature checklist (multi-select), diffs the desired state against the
current one, confirms once, and applies the change set by reusing the
per-feature commands. Cancelling makes no changes.

``` bash
zzc toggle
```

    Current: backend=renv  docker=on  ci=on  data=off  code-quality=off  tests=on  cloud=on

    Backend [renv/nix/none] (default: renv): renv
      Docker environment        [on/off] (current: on): on
      CI workflows              [on/off] (current: on): on
      Data integrity hashing    [on/off] (current: off): on
      Code quality (pre-commit) [on/off] (current: off): on
      Unit testing (tinytest)   [on/off] (current: on): on
      Cloud launch (devcontainer) [on/off] (current: on): on
      Validation: strict (scan tests/ & vignettes/) [on/off] (current: on): on
      Validation: auto-fix DESCRIPTION [on/off] (current: off): off

    Planned changes:
      - data: off -> on
      - code-quality: off -> on

    Apply these changes? [y/N]: y

When a terminal multi-select tool (`gum`) is available the checklist is
a single tickable list; otherwise the prompts above are used. After
applying, `zzc status` is printed so the new state is immediate.

### Couplings and nudges

The wizard enforces a few couplings rather than leaving them to fail
later:

- Enabling **CI** when no report exists offers to scaffold one, since
  the render workflow needs something to render.
- Choosing the **renv** backend while leaving **Docker** off prints an
  advisory that renv alone is L1 and Docker reaches L2.
- Choosing the **Nix** backend defaults Docker off, because Nix already
  pins the environment without a container.

## Changing features non-interactively

Every feature has an explicit command, so scripts and CI never see a
prompt. The bare verbs and the symmetric `add`/`rm` forms are
equivalent:

``` bash
zzc data                 # write data-manifest.sha256
zzc add data             # the same, explicit form
zzc rm data              # remove it

zzc code-quality         # install .pre-commit-config.yaml (styler + lintr)
zzc tests                # scaffold inst/tinytest
zzc cloud                # scaffold .devcontainer
zzc rm cloud
```

`zzc add <feature>` and `zzc rm <feature>` accept `docker`, `renv`,
`nix`, `data`, `code-quality`, `tests`, `cloud`, `cicd`, and `github`.
Per-feature flags pass through, for example
`zzc add docker --base-image rocker/verse`.

## The package backend: renv, Nix, or none

The backend is mutually exclusive, so it is a single choice rather than
a checklist item. Switching backends removes the old artifact before
writing the new one, so `renv.lock` and `flake.nix` never coexist.

``` bash
zzc renv                 # renv.lock (the default backend)
zzc rm renv              # drop to a DESCRIPTION-only project (L0/L1)

zzc nix                  # flake.nix pinned to a nixpkgs revision (L2)
zzc rm nix
```

With a `Dockerfile` present, toggling the backend regenerates the
`Dockerfile` in the matching install mode (restore from `renv.lock`, or
install from `DESCRIPTION` via `pak`), reusing the remembered base image
and R version from `.zzcollab-state` so no question is re-asked.

The Nix backend wires through the generated files the same way: `make r`
enters `nix develop`, the host R targets run via `nix develop -c`, and
CI installs Nix and runs in `nix develop`.

## The container runtime: Docker, Podman, or Apptainer

The runtime is a parameter over the same image, set once in
configuration. The `Makefile` reads it (overridable per invocation):

``` bash
zzc config set docker-runtime podman      # daemonless, drop-in for `make r`
make r                                     # runs via podman

zzc config set docker-runtime apptainer   # HPC: exec a SIF
make sif                                   # build env.sif from the image
make CONTAINER_RUNTIME=apptainer r         # apptainer shell env.sif
```

Multi-arch team publishing uses Docker `buildx` and stays
Docker-specific; the local build and run honour the configured runtime.

## Verifying the claim: `zzc verify`

Where `status` shows the declared level, `verify` confirms it. The
coherence tier needs no build: it checks that the artifacts agree with
`.zzcollab-state` (no backend conflict, the install mode matches
`renv.lock` presence, no dangling `COPY renv.lock`, the base image
matches, R versions agree, the data matches `data-manifest.sha256`).

``` bash
zzc verify
```

    VERIFY  /path/to/penguins-study

    Coherence
      [ ok ] backend unambiguous (renv)
      [ ok ] state record present (.zzcollab-state)
      [ ok ] install mode (renv) consistent with renv.lock presence
      [ ok ] Dockerfile copies renv.lock and renv.lock exists
      [ ok ] Dockerfile base image matches state (rocker/tidyverse)
      [ ok ] renv.lock is valid JSON with a Packages section
      [ ok ] R version consistent across sources (4.6.0)
      [ ok ] raw data matches data-manifest.sha256

    verify: coherence passed (0 warnings, 1 skipped)
      Run 'zzc verify --full' to rebuild and reach L3 (verified).

The reproduction tier rebuilds the image and runs the test suite inside
it. Only this earns L3; on success it stamps `verified` into
`.zzcollab-state`, and any later regeneration drops the stamp so a
changed environment reverts to unverified automatically.

``` bash
zzc verify --full
```

## Defaults for new projects: `zzc toggle --global`

The same wizard, run with `--global`, edits the feature defaults in
`~/.zzcollab/config.yaml` instead of a project. The `zzc init` wizard
then starts new projects from those defaults.

``` bash
zzc toggle --global      # e.g. default Docker off for new projects
```

## Bringing an older compendium up to date: `zzc doctor`

`zzc doctor` is toggle-aware: `renv.lock` and `Dockerfile` are reported
as on/off features rather than required files, so a lower-level project
is not flagged as broken. For a compendium created before the state
record existed, `doctor --fix` back-fills `.zzcollab-state` from
artifact presence without touching any primary artifact.

``` bash
zzc doctor          # report
zzc doctor --fix    # refresh stamps and back-fill the state record
```

## Moving across the option space

The features form a small state space. The two capture axes, **backend**
(`none` / `renv` / `nix`) and **environment** (`Docker` off / on), set
the level; the validation features and the runtime are independent of
it. This section walks selections around that space and shows the effect
of each move.

### Climbing the levels (L0 to L2)

``` bash
zzc init --yes --archetype analysis   # L0: scaffold only, nothing pinned
zzc renv                              # L1: packages pinned (renv.lock)
zzc docker --profile analysis         # L2: environment pinned (Dockerfile)
```

| After    | backend | docker | level |
|----------|---------|--------|-------|
| `init`   | none    | off    | L0    |
| `renv`   | renv    | off    | L1    |
| `docker` | renv    | on     | L2    |

The backend-environment grid and how to move between cells:

| backend \\ docker | off        | on                       |
|-------------------|------------|--------------------------|
| none              | L0         | L2 (DESCRIPTION install) |
| renv              | L1         | L2 (renv restore)        |
| nix               | L2 (flake) | L2 (+ container)         |

### Switching the backend (renv, Nix, none)

The backend is single-select, so a switch removes the old artifact
before writing the new one; `renv.lock` and `flake.nix` never coexist.

``` bash
# renv -> Nix (drops renv.lock, writes flake.nix; still L2 via the flake)
zzc rm renv
zzc nix

# Nix -> none (drops flake.nix; L0 unless Docker is on)
zzc rm nix

# none -> renv
zzc renv
```

With a `Dockerfile` present, each switch regenerates it in the matching
install mode and reuses the remembered base image, so the environment is
preserved across the backend change.

### Switching the container runtime (Docker, Podman, Apptainer)

The runtime is a parameter over the same image, not a capture change, so
the level is untouched:

``` bash
zzc config set docker-runtime podman      # make r / build now use podman
zzc config set docker-runtime apptainer   # HPC
make sif                                   # build env.sif for apptainer
zzc config set docker-runtime docker       # back to the default
```

### Toggling validation features on and off

These flip independently and never move the level (they check, they do
not capture):

``` bash
zzc tests          ; zzc rm tests           # inst/tinytest
zzc code-quality   ; zzc rm code-quality    # .pre-commit-config.yaml
zzc data           ; zzc rm data            # data-manifest.sha256
zzc rm cicd        ; zzc add cicd           # the CI workflows
zzc cloud          ; zzc rm cloud           # .devcontainer
```

After each, `zzc status` shows the feature flip while the `level:` field
holds steady.

### Dependency-validation strictness and auto-fix

The dependency check (`zzc validate`, also run by `make check-renv`)
enforces that every package used in code is declared in `DESCRIPTION`
and pinned in `renv.lock`. Two knobs ride the same toggle checklist as
the features above, but they are configuration rather than artifacts:

- **strict** also scans `tests/` and `vignettes/` for package use
  (default on).
- **auto-fix** repairs `DESCRIPTION` in place when a used package is
  missing (default off).

Because they are configuration, the toggle persists them rather than
creating or deleting a file: project-local in `zzc toggle`, user-level
in `zzc toggle --global`. `zzc status` reports the effective values:

    GLOBAL  ~/.zzcollab/config.yaml   (defaults for new projects)
      validate       strict=true  fix=false

Set them without the wizard, or override per invocation with explicit
flags that take precedence over the stored defaults:

``` bash
zzc config set validate-strict false          # persist (user-level)
zzc config set-local validate-fix true        # persist (this project only)
zzc validate --no-strict                       # override for one run
zzc validate --fix                             # override for one run
```

Neither knob moves the reproducibility level; both only affect how the
dependency check behaves.

### Downgrades and re-adds

Removing a capture feature lowers the level and the self-adapting files
follow; re-adding restores the prior configuration without re-asking:

``` bash
zzc rm docker      # L2 -> L1; the render workflow falls back to a host render
zzc status         # environment off; base image no longer shown
zzc docker         # re-add: reuses the remembered base image + R version
zzc status         # back to L2, same base as before
```

### One interactive step changing several selections

`zzc toggle` can move several axes at once. Here the developer switches
to the Nix backend, turns on data integrity and code quality, and turns
off cloud launch, all in one confirmed diff:

    Backend [renv/nix/none] (default: renv): nix
      Note: Nix pins the environment (L2) without a container; Docker is for distribution only.
      Docker environment        [on/off] (current: on): off
      CI workflows              [on/off] (current: on): on
      Data integrity hashing    [on/off] (current: off): on
      Code quality (pre-commit) [on/off] (current: off): on
      Unit testing (tinytest)   [on/off] (current: on): on
      Cloud launch (devcontainer) [on/off] (current: on): off

    Planned changes:
      - backend: renv -> nix
      - docker: on -> off
      - data: off -> on
      - code-quality: off -> on
      - cloud: on -> off

    Apply these changes? [y/N]: y

### A round trip that ends where it began

Toggling a feature off and on returns the compendium to its starting
state, and `verify` confirms coherence at each end:

``` bash
zzc verify                 # coherence passes (renv mode)
zzc rm renv                # Dockerfile flips to DESCRIPTION-install mode
zzc verify                 # coherence still passes (description mode)
zzc renv                   # Dockerfile flips back to renv-restore mode
zzc verify                 # coherence passes again, identical to the start
```

## A complete walkthrough

``` bash
# 1. Create a manuscript compendium (renv + Docker is the recommended default).
mkdir alloc-survival && cd alloc-survival
zzc init --yes --archetype manuscript
zzc renv
zzc docker --profile analysis

# 2. Add data integrity and code quality; confirm the state.
echo "id,arm,time,event" > analysis/data/raw_data/trial.csv
zzc data
zzc code-quality
zzc status

# 3. Build and confirm coherence, then the full reproduction.
make docker-build
zzc verify
zzc verify --full        # rebuild + test -> L3, stamps the state record

# 4. Later: switch to the Nix backend for the same project.
zzc rm renv
zzc nix
zzc status               # backend nix, environment still L2
```

## See also

- [`vignette("quickstart1")`](https://rgt47.github.io/zzcollab/articles/quickstart1.md)
  and
  [`vignette("quickstart2")`](https://rgt47.github.io/zzcollab/articles/quickstart2.md)
  for the collaborative analysis workflow.
- [`vignette("reproducibility-layers")`](https://rgt47.github.io/zzcollab/articles/reproducibility-layers.md)
  for the capture/validation model in depth.
- [`vignette("configuration")`](https://rgt47.github.io/zzcollab/articles/configuration.md)
  for the full set of configuration keys.
