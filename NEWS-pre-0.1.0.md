# zzcollab 0.9.2

## Bug fixes

- Completed the R wrapper repair begun in 0.9.1. Six exported functions
  still targeted the removed `--config` flag form or a removed help
  topic and failed silently against the current CLI:
  - [`get_config()`](https://rgt47.github.io/zzcollab/reference/get_config.md),
    [`set_config()`](https://rgt47.github.io/zzcollab/reference/set_config.md),
    [`list_config()`](https://rgt47.github.io/zzcollab/reference/list_config.md),
    [`init_config()`](https://rgt47.github.io/zzcollab/reference/init_config.md)
    now call `config <subcommand>` instead of the removed
    `--config <subcommand>`.
  - [`validate_config()`](https://rgt47.github.io/zzcollab/reference/validate_config.md)
    now calls the new `config validate` subcommand (added to the CLI),
    instead of the nonexistent `--config validate`.
  - [`zzcollab_next_steps()`](https://rgt47.github.io/zzcollab/reference/zzcollab_next_steps.md)
    now resolves: the `next-steps` help topic was re-added to the CLI
    after the help reorganisation removed it.
  - [`find_zzcollab_script()`](https://rgt47.github.io/zzcollab/reference/find_zzcollab_script.md)
    fallback probe now uses `config list` rather than the stale
    `--config list`.
- Stale profile names (`bioinformatics`, `geospatial`, `publishing`)
  removed from configuration roxygen examples; profiles are now
  `minimal`, `analysis`, `rstudio`.

## Internal

- Added CLI round-trip tests (`tests/testthat/test-config.R`) that
  exercise the exact command strings the wrappers build, so future CLI
  interface drift fails in tests instead of silently in production.
- `utils` added to `Imports` (was only `@importFrom`); DESCRIPTION
  trailing whitespace removed.

# zzcollab 0.9.1

## Bug fixes

- Repaired the R wrapper functions, which constructed commands for the
  removed monolithic CLI interface and failed against the current
  command model:
  - [`init_project()`](https://rgt47.github.io/zzcollab/reference/init_project.md)
    now records the DockerHub account via `zzcollab config set` and
    scaffolds the compendium in the working directory through the
    profile quickstart, rather than emitting the removed
    `-t`/`-p`/`--github-account` flags. It gains a `profile` argument
    (default `"analysis"`).
  - [`join_project()`](https://rgt47.github.io/zzcollab/reference/join_project.md)
    now builds the project image via `make docker-build` in the cloned
    repository, rather than emitting the removed `--use-team-image`
    flag.
  - [`zzcollab_next_steps()`](https://rgt47.github.io/zzcollab/reference/zzcollab_next_steps.md)
    and
    [`zzcollab_help()`](https://rgt47.github.io/zzcollab/reference/zzcollab_help.md)
    now route through the `help <topic>` subcommand instead of the
    removed `--next-steps` flag and `--help <topic>` form.
  - [`find_zzcollab_script()`](https://rgt47.github.io/zzcollab/reference/find_zzcollab_script.md)
    now probes installed binaries with `config list` instead of the
    removed `--config list` flag.

# zzcollab v0.9.0

- Initial public release.
