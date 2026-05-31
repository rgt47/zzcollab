# Deep Review: Init, Config, and Help Systems
*2026-05-31 09:29 PDT*

## Scope

A critical review of the three subsystems most affected by the recent
refactor (manifest and `require_module` removal, the directory-safety guard,
the yq config migration, `validation.sh` removal, profile reduction, and the
CLI UX changes). Findings were produced by three parallel deep reads and the
highest-severity ones were independently verified by reading the source and by
running the CLI in throwaway `/tmp` directories with `HOME` redirected (so the
real `~/.zzcollab` was never touched). Each finding records severity, status,
evidence, why it matters, and a fix.

Fixed and verified so far: the init CRITICAL cluster (I1 through I4) and the
config key-merge (C1, C2; M1 partly). The remaining items are open.

## What is sound (so it is not re-audited)

- The refactor removals are clean: no dangling references to the manifest or
  `require_module` remain.
- Config *value* handling is secure: `yaml_set` uses `strenv`, so shell
  metacharacters and yq expressions in values are stored literally; the key
  injection guard (`^[A-Za-z0-9_.]+$`) closes yq-program injection via keys.
- The Docker Hub dual-key resolution (`dockerhub_account` / `docker_account`)
  round-trips correctly.
- The F4 cross-profile change is correct and non-destructive.

## CRITICAL — init safety guard cluster (FIXED 2026-05-31)

The `assert_safe_init_directory` guard replaced the manifest as the thing that
prevents accidental scaffolding. It was enforced inconsistently; the pieces
interacted, so they were fixed together.

### I1. Guard bypassed entirely on the lazy-init path — FIXED

- **Problem**: `ensure_workspace_initialized` called `setup_project` with no
  guard, so `zzc docker` / `zzc renv` (which auto-initialize) scaffolded over a
  populated directory silently. Verified: `zzc renv` in a 2-subdirectory dir
  created the full compendium.
- **Fix**: `ensure_workspace_initialized` now calls
  `assert_safe_init_directory` before `setup_project` (`zzcollab.sh`). Verified:
  the lazy path now hard-stops and creates no `DESCRIPTION`.

### I2. No rollback on partial scaffold — FIXED

- **Problem**: `setup_project` runs eight `create_* || return 1` steps with no
  cleanup; one transient failure left a half-built tree that the guard then
  treated as "occupied", blocking every entry point.
- **Fix**: a `setup_project_safe` wrapper snapshots the top-level entries before
  scaffolding and, on failure, removes only the entries that were newly created
  (pre-existing files are never removed, even under `--force`). No manifest is
  reintroduced. All three `setup_project` call sites use it. Verified in
  isolation: a simulated scaffold-then-fail leaves only the pre-existing file.

### I3. `--force` (the documented escape) was unreachable for `init` — FIXED

- **Problem**: `main()` called `cmd_init` with no arguments, so
  `zzcollab init --force` ran the guard anyway and then errored on `--force` as
  an unknown command. Every "Override with: `zzc init --force`" message was
  wrong.
- **Fix**: the `init` dispatch now forwards trailing flags to `cmd_init` and
  consumes the leading flags it parsed. Verified: `init --force` is accepted
  (no "Unknown command: --force").

### I4. `-y` made the guard block instead of proceed — FIXED

- **Problem**: under `ZZCOLLAB_ACCEPT_DEFAULTS=true`, the soft (>3 items) prompt
  defaulted to "no", so non-interactive init in any non-pristine directory
  failed, with no working `--force` to combine.
- **Fix**: the soft prompt now proceeds under accept-defaults (the hard
  >1-subdirectory stop still requires an explicit `--force`). Verified: `-y`
  prints "proceeding (--yes)" and continues.

## HIGH — open

### C1. `config set KEY` and `config get KEY` disagree for many keys

- **Status**: FIXED (2026-05-31). `config get` now resolves the key through
  `_key_to_yaml_path` and reads the merged value via `_yaml_path_to_var`
  (driven by `_CONFIG_MAP`, the same table the loader uses), so get is
  symmetric with set. `_get_config_value` was deleted. Verified: every
  previously-empty key (`docker-registry`, `github.default_visibility`,
  `style.line_length`, ...) now round-trips, in both kebab and dotted forms.
- **Problem**: `config_set` resolves the key through `_key_to_yaml_path`
  (snake_case to dotted path) and writes it; `config_get` reads via a separate
  `_get_config_value` case whose labels do not cover everything `set` accepts,
  so unmatched keys fall through to empty. Verified:
  `config set docker-registry ghcr.io` succeeds, `config get docker-registry`
  returns empty (while `dockerhub-account` and `github-account` round-trip).
  Same failure for `github.default_visibility`, `github.default_branch`, and
  `style.*`. The value still loads into `CONFIG_*` and affects builds, so `get`
  misreports live settings.
- **Evidence**: `modules/config.sh` `_get_config_value` (~:582-616),
  `_key_to_yaml_path` (~:1226-1248), `config_get` divergence (~:1289-1305).
- **Fix**: make `config_get` symmetric with `config_set` by reading the dotted
  `yaml_path` directly, or drive both from one key table (see Root causes).

### C2. `config set` silently accepts unknown keys

- **Status**: FIXED (2026-05-31). `_key_to_yaml_path` is now driven by
  `_CONFIG_MAP` + a small alias table and returns non-zero for unrecognized
  keys; `config set`/`config get` reject them with "Unknown config key" and a
  pointer to `config list`. Verified.
- **Problem**: `_key_to_yaml_path` has a catch-all `*) echo "defaults.$1"`, so a
  typo (`dockerhub-acount`) is written under `defaults.` and then unreadable
  (C1). Misconfiguration is undetectable.
- **Fix**: validate keys against an allowlist (the key table already enumerates
  them); reject unknown keys with a non-zero exit and a "did you mean" hint.

### H1. `config set-local` / `get-local` advertised but not implemented

- **Status**: Open. **Verified**.
- **Problem**: the post-`init` message (`zzcollab.sh:262`), `help.sh:144`, and
  the user guide advertise `config set-local KEY VALUE`, but `cmd_config`
  handles only `init|list|get|set|validate`; running it errors. The capability
  exists one layer down (`config_set` takes a `local_only` arg) but is never
  wired to the CLI. This is the documented project-override mechanism.
- **Fix**: wire a `set-local` / `get-local` case (or `set --local`) into
  `cmd_config`, or remove the two references.

### H2. The rebuild hint advises a command that errors

- **Status**: Open. **Verified**.
- **Problem**: `cmd_quickstart`'s idempotent branch prints `To rebuild: zzc
  docker --force`, but `cmd_docker` rejects `--force` (verified: it hits the
  `*) Unknown option` arm). The real command is `zzc rebuild`.
- **Evidence**: `zzcollab.sh:1210` (hint); `cmd_docker` parse loop.
- **Fix**: change the hint to `zzc rebuild`.

### H3. Subcommand `--help` is inconsistent

- **Status**: Open. **Verified**.
- **Problem**: `zzc config --help` errors ( `cmd_config` has no help case) and
  `zzc docker --help` does not show help (the `docker` flag-collector in
  `main()` never forwards `--help`, so it triggers the workspace banner or
  starts working). Yet `rebuild`/`validate`/`list`/`uninstall --help` all work.
- **Fix**: add a `help|--help|-h` case to `cmd_config`; forward `--help` in the
  `docker` flag-collector in `main()`.

## MEDIUM — open

### I5. Three divergent `PKG_NAME` derivations, one producing invalid names

- **Status**: Open. **Verified**.
- **Problem**: `cmd_init`/`cmd_quickstart` use `validate_package_name`
  (keeps case, strips hyphens, no lowercase); `ensure_workspace_initialized`
  lowercases and maps hyphen to dot but keeps underscores; the templates
  fallback differs again. Verified: a directory `zzc_lazy` initialized via the
  lazy path yields `Package: zzc_lazy` — underscores are illegal in R package
  names, so the DESCRIPTION is invalid. Non-ASCII names (`café`) also pass and
  produce an invalid `Package:`.
- **Fix**: route every entry point through one canonical sanitizer that
  lowercases, maps hyphen/underscore/space to dot, strips non-`[a-z0-9.]`,
  collapses repeated dots, and enforces the R rule (start with a letter); reject
  rather than coerce names that cannot be made valid.

### I6. Unknown profile via `-r <name>` is not rejected

- **Status**: Open. **Verified**.
- **Problem**: `get_profile_base_image` returns `rocker/r-ver` (exit 0) with a
  warning for any unknown string, so the "Unknown profile" guard in
  `cmd_quickstart` is dead. A typo (`zzc -r anaylsis`) scaffolds with the wrong
  base and persists a bogus `profile-name`. (Bare commands are limited to
  `minimal|analysis|rstudio`, but the `-r/--profile` route accepts anything.)
- **Fix**: have `get_profile_base_image` return non-zero on unknown profiles, or
  add an explicit membership check on the `-r` route.

### I7. A plain R package cannot be onboarded

- **Status**: Open.
- **Problem**: `is_workspace_initialized` is just `[[ -f DESCRIPTION ]]`, so a
  stray DESCRIPTION makes `zzc analysis` take the F4 "no profile set" error and
  direct the user to `docker --profile`, which only regenerates a Dockerfile and
  never creates `R/`/`analysis/`/`tests/`. The "initialized" signal is too weak.
- **Fix**: detect a zzcollab-managed project by a stronger marker (e.g.
  `zzcollab.yaml`) and either complete the scaffold or give an instruction that
  actually scaffolds.

### M1. Documented config keys that nothing consumes

- **Status**: Partly addressed (2026-05-31). Because the key set now drives an
  allowlist, inert keys (`docker.platform`, `style.indent_size`, ...) are
  rejected on `set`/`get` rather than silently stored, and the `docker.platform`
  instructions in the user guide and `CONFIGURATION.md` were corrected to use
  Docker's own `DOCKER_DEFAULT_PLATFORM` env var. The default-config heredoc
  may still seed a few inert lines; trimming it (or wiring real consumers) is
  the remaining work.
- **Problem**: `docker.platform` (the user guide instructs `config set
  docker.platform amd64`), `r_package.language`, `style.indent_size`,
  `style.naming_convention`, `docker.default_base_image`, `github.create_issues`,
  `github.create_wiki` are settable and seeded into the generated config but read
  by no consumer. Following the guide to force an architecture is a silent
  no-op.
- **Fix**: implement consumption or remove them from the docs and the generated
  default config.

## LOW — open

- **I8.** `uninstall` / `rm all` omit `inst/` (created by `setup_project`) and
  reference a `.dockerignore` that is never generated, so "uninstall complete"
  leaves `inst/` behind.
- **I9.** Dead code: `USER_PROVIDED_PROFILE` is never set true, making the legacy
  branches in `cmd_init` and `init_export_config_vars` unreachable.
- **I10.** `safe_cp` and the inline generators `rm -f` the destination before
  writing; on *regeneration* over a cloud-synced file this re-introduces the
  delete-then-write data-loss class. Use temp-file-then-`mv`, as
  `substitute_variables` and `cmd_rm_renv` already do.
- **L1.** The R `validate_config` roxygen promises validation of build modes,
  booleans, and backups that does not exist (`config validate` is a pure
  YAML-syntax check, and build modes are a removed concept). Correct the
  docstring and regenerate `man/`.
- **L2.** The R config wrapper interpolates `zzcollab_path` unquoted; latent
  (the path has no spaces today). `shQuote` it.

## Root causes

1. **The config key set was declared four times** (`_CONFIG_MAP`,
   `_key_to_yaml_path`, `_get_config_value`, and the default-config heredoc) and
   had drifted, spawning C1, C2, and M1. RESOLVED (2026-05-31): `_get_config_value`
   was deleted and `_key_to_yaml_path` now derives from `_CONFIG_MAP` plus a
   four-line alias table, so loading, set, get, and the allowlist share one
   source of truth. Only the default-config heredoc remains separate (default
   generation); see M1.
2. **The init guard was added without covering every creation entry point or its
   own bypass.** This spawned the CRITICAL cluster (now fixed).
3. **Help is maintained independently of the dispatcher with no cross-check**,
   so it can advertise commands that error (H1, H3). The `test-docs` guard checks
   flags against docs but never verifies an advertised *command* exists.

## Recommended priority for the open items

1. ~~Config four-way merge (fixes C1, C2, M1)~~ — DONE 2026-05-31.
2. Wire or remove `config set-local` (H1) and fix the subcommand `--help`s (H3).
3. Fix the rebuild hint (H2) — trivial.
4. Single PKG_NAME sanitizer (I5) and unknown-profile rejection (I6).
5. The remaining LOW items as cleanup, plus two new `test-docs` guards: every
   `zzc <word>` in help resolves in the dispatcher, and `config --help` exits 0.

---
*Rendered on 2026-05-31 at 09:47 PDT.*<br>
*Source: ~/prj/sfw/07-zzcollab/zzcollab/docs/init-config-help-review.md*
