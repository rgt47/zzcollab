# Glossary: zzcollab and Reproducible-Research Terms

This glossary collects the terms you meet across the zzcollab vignettes,
written for a practicing statistician who is software-engineering
literate but not an expert. Each vignette opens with a short ‘Key terms’
box listing only the terms it uses; this page is the full reference
behind those boxes.

It is organized in two parts: **framework terms** specific to zzcollab,
and **general terms** from reproducible research and R software
engineering that zzcollab builds on.

## Part I. zzcollab framework terms

### Core model

- **Compendium**: your project folder, holding data, code, environment,
  and write-up together so the whole thing can be re-run as a unit.
- **Capture level (L0 to L3)**: how locked-down a project is. L0
  locatable (a valid compendium, packages not pinned), L1 pinned
  packages (a backend present), L2 pinned environment (a container or
  Nix), L3 verified (rebuilt and re-run, matching a baseline).
- **Capture feature vs validation feature**: capture features (the
  backend, the Docker environment) pin the environment and set the
  capture level; validation features (tests, CI, code quality) only
  check the result without changing the level.
- **‘The artifact is the state’**: zzcollab’s design principle that a
  feature is on exactly when its primary file is present, so toggling a
  feature means creating or removing one file, not editing scattered
  configuration.
- **Five Pillars (of reproducibility)**: the five artifacts zzcollab
  treats as jointly sufficient for reproducibility: the `Dockerfile`,
  `renv.lock`, `.Rprofile`, the source code, and the research data.
- **Feature**: an independently switchable capability (package backend,
  Docker, CI, data-integrity hashing, code-quality hooks, unit tests,
  cloud launch).

### Project shape

- **Archetype**: the project type chosen at `zzc init` (analysis,
  manuscript, package, simulation, blog), which shapes the starter
  layout.
- **Profile**: the Docker image bundle the environment is built from.
  The four canonical profiles are `minimal` (command-line, ~650MB),
  `tidyverse` (tidyverse, ~1.2GB), `rstudio` (RStudio Server, ~980MB),
  and `publishing` (manuscript rendering on `rocker/verse`, ~4.2GB).
  `tidyverse` was formerly named `analysis`; the `analysis` alias is
  still accepted. For other specialised needs (modeling, Shiny), extend
  the closest profile. Distinct from the archetype: the profile is the
  image, the archetype is the layout.
- **Render gate**: a CI check tied to the archetypes that scaffold a
  report, failing the build if the manuscript will not render.
- **Self-adapting generated files**: generated files (Dockerfile, CI
  workflows) that adjust to whichever feature artifacts are present.

### Commands and state

- **`zzc` / `zzcollab`**: the framework’s command-line interface; `zzc`
  is an alias for `zzcollab`.
- **`zzc init`**: scaffold a new compendium; asks for an archetype and
  runs the feature wizard (`--yes` skips prompts).
- **`zzc toggle`** / **`zzc add <f>`** / **`zzc rm <f>`**: turn features
  on or off, interactively or by name.
- **`zzc status`**: read-only report of the project’s current feature
  state and capture level.
- **`zzc verify`**: confirm the declared level; coherence checks
  artifacts agree, `--full` rebuilds and re-runs to earn L3.
- **`zzc doctor`** (`--fix`): diagnose an older project and back-fill
  its `.zzcollab-state` record without touching primary artifacts.
- **`zzc update`**: a minor maintenance command that refreshes the
  project’s framework-managed template files to the installed zzcollab
  version (and back-fills state).
- **`.zzcollab-state`**: a generated record (base image, digest, install
  mode, archetype) that `status` and `verify` read instead of re-parsing
  the `Dockerfile`.
- **make target**: a named `Makefile` command (e.g. `make docker-build`,
  `make docker-test`, `make check-renv`, `make snapshot`) wrapping a
  container operation. `make snapshot` grows the dependency manifest
  ([`renv::hydrate()`](https://rstudio.github.io/renv/reference/hydrate.html),
  then `renv::snapshot(prompt = FALSE)`, then
  `zzrenvcheck::check_packages(auto_fix = TRUE, strict = TRUE)`),
  whereas `make check-renv` validates the manifest without hydrating.

### Backends, environments, and teams

- **Package backend (renv / Nix / none)**: how the project records exact
  package versions; a single mutually-exclusive choice.
- **Auto-snapshot / auto-restore**: zzcollab automatically records
  installed packages to `renv.lock` on container exit, and installs
  missing packages on start, replacing manual
  [`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html)
  /
  [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html).
- **Container runtime**: the engine that runs the image: Docker, Podman
  (daemonless), or Apptainer (HPC, single-file `.sif`).
- **Team image**: a pre-built Docker image shared via a registry so
  every collaborator works from a byte-identical environment.
- **`.team-image-digest`**: a committed file recording the team image’s
  immutable digest so members pull the exact same image.
- **zzrenvcheck**: zzcollab’s dependency check (run by
  `make check-renv`) verifying every package used in code is declared in
  `DESCRIPTION` and pinned in `renv.lock`.
- **Two-layer package management**: shared, image-baked packages (Layer
  1.  versus per-user packages added at runtime (Layer 2).
- **Dependency placement**: the rule governing where a package is
  recorded. Development tooling (`languageserver`, styler, lintr,
  devtools, roxygen2, and similar) belongs in the `Dockerfile` and never
  in `renv.lock`; reproducibility-relevant packages belong in
  `renv.lock` and `DESCRIPTION`. See
  `docs/package-placement-whitepaper.md` for the comprehensive treatment
  of which packages go where.
- **`languageserver` / in-container LSP**: the R language server
  installed into the Docker image (config key `languageserver`, default
  `true`) so that editor completion and diagnostics run inside the
  container. Because zzcollab assumes no R on the host, the language
  server must run in the container; a host editor (vim, VS Code) bridges
  its LSP client into the container. Opt out with
  `zzc config set languageserver false` for REPL-only workflows.

## Part II. General reproducible-research and R terms

### Environment and dependencies

- **renv**: an R package giving each project its own isolated,
  version-pinned package library.
- **Lockfile (`renv.lock`)**: a JSON record of every package version
  needed to rebuild the environment.
- **Version pinning**: recording an exact dependency version so it
  cannot drift between machines or over time.
- **Project library**: a per-project package folder isolated from other
  projects.
- **Nix / `flake.nix`**: a package manager and pinned lockfile that fix
  an entire environment without a container.
- **Docker / container / image / Dockerfile**: a tool that packages
  software with its environment; a running instance, its template, and
  the recipe that builds it.
- **Base image**: the starting Docker image a project builds on
  (e.g. `rocker/tidyverse`, `rocker/verse`).
- **Image digest pinning**: referencing an image by its immutable
  content hash (`sha256:...`) so every pull is byte-identical.

### Quality, testing, and automation

- **Continuous integration (CI)**: automatically building and testing
  code on every push.
- **CI gate / quality gate**: an automated pass/fail check that must
  succeed before code or output is accepted.
- **Pre-commit / git hook**: a script that runs at a Git event (usually
  before a commit) to lint and format code; in R, commonly styler and
  lintr.
- **Unit test / testthat / tinytest**: a focused check that one piece of
  code behaves as intended, and the frameworks for writing such checks.
- **Code coverage**: the fraction of code actually exercised by the
  tests.
- **`R CMD check`**: the standard tool validating package structure,
  documentation, and tests.
- **Checksum / content hash**: a short fingerprint of a file’s bytes
  that changes if the file changes, used for data-integrity checks
  (e.g. `data-manifest.sha256`).

### Reproducibility concepts

- **Computational reproducibility**: getting the same numerical results
  from the same data and the same code.
- **Reproducibility crisis**: the widespread finding that many published
  results cannot be independently reproduced.
- **Code rot / environmental drift**: the gradual breakage of working
  code over time as its dependencies change underneath it.
- **Data provenance / lineage**: a record of where data came from and
  how it was transformed.
- **Raw vs derived data**: immutable original data files versus the
  processed, analysis-ready datasets generated from them.
- **Seed (`set.seed`) / RNG kind**: a fixed starting point making random
  results reproducible; the generator algorithm whose default has
  changed across R versions.
- **Research compendium**: the general term for a single
  version-controlled unit bundling data, code, environment, and
  documentation (conventions from `rrtools`).

## See also

- [`vignette("quickstart3")`](https://rgt47.github.io/zzcollab/articles/quickstart3.md)
  for the feature-toggle and capture-level model in depth.
- [`vignette("reproducibility-layers")`](https://rgt47.github.io/zzcollab/articles/reproducibility-layers.md)
  for the capture/validation model.
- [`vignette("configuration")`](https://rgt47.github.io/zzcollab/articles/configuration.md)
  for the full set of configuration keys.
