# Contributing to zzcollab

Thank you for your interest in contributing. zzcollab combines a bash
CLI (`zzcollab.sh` and `modules/`) with an R package (`R/`, `man/`,
`vignettes/`). Both must stay in step.

## Reporting issues

Before opening an issue, please search existing issues at
<https://github.com/rgt47/zzcollab/issues> to confirm the problem has
not already been reported. When opening a new issue, include:

- A minimal reproducible example. For CLI bugs, the exact command and
  the surrounding shell context. For R bugs, a `reprex::reprex()`.
- The output of `zzcollab --version` and `bash --version` (CLI side)
  or `sessionInfo()` (R side).
- The Docker profile in use, if applicable.
- The expected behaviour and the observed behaviour.

## Proposing a change

For non-trivial changes, please open an issue first to discuss the
approach. zzcollab has well-defined extension points (Docker profiles
in `bundles.yaml`, configuration layers, the auto-snapshot pipeline);
a brief design discussion saves rework.

## Pull request workflow

1. Fork the repository and create a topic branch off `main`.
2. Install development dependencies. zzcollab uses `renv` for the R
   package side:
   ```r
   renv::restore()
   ```
   For shell development, ensure `shellcheck`, `bats-core`, `jq`, and
   `curl` are installed.
3. Make your changes. Keep commits focused; prefer many small commits
   over one large one.
4. Update tests:
   - R changes: `tests/testthat/`
   - CLI changes: `tests/integration/` (bats) and `tests/shellcheck/`
5. Run the relevant local checks:
   ```r
   devtools::document()
   devtools::check()
   ```
   ```bash
   make test
   make check-renv
   make style          # format R code with styler (in container)
   make lint           # lint R code with lintr (in container)
   shellcheck zzcollab.sh modules/*.sh
   ```
6. Update `NEWS.md` (R package side) or `CHANGELOG.md` (CLI/framework
   side) depending on which surface changed. Use both if both are
   affected.
7. Open a pull request against `main`. Reference any related issues.

## Coding style

### R code

- Use the native R pipe (`|>`); avoid `%>%` in new code.
- Use `<-` for assignment, never `=`.
- Use `snake_case` for functions and variables.
- Prefer implicit returns; reserve `return()` for early exits.
- Document all exported functions with `roxygen2`. Each must have
  `@title`, `@description`, `@param`, `@return`, and `@examples`.
- Two-space indentation. Single quotes for character literals.

### Shell code

- POSIX-compatible where feasible; `bash` features only when needed
  (declare with `#!/usr/bin/env bash`).
- `shellcheck` must pass. The CI runs `shellcheck.yml` workflow.
- Two-space indentation, snake_case variables.
- Quote all variable expansions: `"${var}"`, never `$var`.
- Modules in `modules/` follow the existing `core.sh` / `cli.sh`
  pattern: each function is documented at the top with purpose,
  inputs, and outputs.

## NEWS.md vs CHANGELOG.md

- `NEWS.md` tracks the R package version line (unified at 0.1.0 after
  the re-baseline). It follows tidyverse style (`# zzcollab X.Y.Z`
  headers + bullet lists) and is what `R CMD check` reads.
- `CHANGELOG.md` tracks the CLI/framework version line (also unified at
  0.1.0). It uses date-headed sections. The frozen 2.x history is kept
  in `CHANGELOG-2.x.md`.

When a change touches both surfaces, add a bullet to each. When it
touches only one, edit only that file.

## Code of Conduct

By participating in this project, you agree to abide by the
[Code of Conduct](CODE_OF_CONDUCT.md).
