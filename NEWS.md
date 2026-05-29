# zzcollab 0.9.1

## Bug fixes

* Repaired the R wrapper functions, which constructed commands for the removed
  monolithic CLI interface and failed against the current command model:
    * `init_project()` now records the DockerHub account via
      `zzcollab config set` and scaffolds the compendium in the working
      directory through the profile quickstart, rather than emitting the removed
      `-t`/`-p`/`--github-account` flags. It gains a `profile` argument
      (default `"analysis"`).
    * `join_project()` now builds the project image via `make docker-build` in
      the cloned repository, rather than emitting the removed `--use-team-image`
      flag.
    * `zzcollab_next_steps()` and `zzcollab_help()` now route through the
      `help <topic>` subcommand instead of the removed `--next-steps` flag and
      `--help <topic>` form.
    * `find_zzcollab_script()` now probes installed binaries with `config list`
      instead of the removed `--config list` flag.

# zzcollab v0.9.0

* Initial public release.
