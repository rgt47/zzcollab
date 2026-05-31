# ZZCOLLAB CLI Command and Flag Improvement Plan
*2026-05-29 18:36 PDT (revised 2026-05-30 18:55 PDT)*

## Purpose

This document proposes a phased set of changes to the zzcollab command line
interface to remove logical defects, reduce redundant surface, and improve
predictability. Each item records the problem, the proposed change, the
affected files, the behavior impact, and a deprecation note. Findings are
labelled F1 through F10 to match the review that produced them.

The plan is sequenced by risk. Phase 0 items are self contained removals with
no functional loss and are safe to apply immediately. Phase 1 items change
naming or consistency and warrant a deprecation window. Phase 2 items are
structural and overlap with the existing simplification effort in
`docs/simplification-plan.md`.

## Status (2026-05-30 codebase review)

A parallel simplification effort has since landed (commits `56ae900` 'Fix P0
correctness bugs' and `890528c` 'Remove dead code (P1)', among others). That
work is the maintainer's own P0/P1 track, distinct from this plan's phases, and
it did not touch this plan's Phase 0 items. The current status of each finding:

| Finding | Status | Note |
|---------|--------|------|
| F1, F2 (`docker -n`/`--no`) | Open | Still at `zzcollab.sh:340`; the short-flag collision with `uninstall -n` remains at `:826`. |
| F5 (`-Y`/`--yes-all`) | Open | Still at `:339` and `:1606`. |
| F3 (quickstart trailing flags) | Open | The worst-case accidental scaffolding is now blunted by the hardened init guard (see F4), but `analysis --r-version` still mis-parses. |
| F9b (duplicate global parsing) | Open | Still at `:338-339`. |
| F10 (`-t` help note) | Open | Help text unchanged. |
| F6 (flag-vs-config rule) | Open | Documentation only. |
| F7 (`build` vs `docker --build`) | Open | Both still present (`cmd_build` at `:413`). |
| F8 (`validate` vs `doctor`) | Open | Both still present (`cmd_validate` `:609`, `cmd_doctor` `:644`). |
| F4 (profile-token overload) | Partially done | Profiles reduced to `minimal`, `analysis`, `rstudio`; the `cmd_init` guard now hard-stops on an occupied directory unless `--force` (commit `56ae900`). The state-dependent verb remains. |
| F9a (flag-binding doc) | Open | Help text unchanged. |

A related documentation issue surfaced from the profile reduction; it is
tracked as D1 below.

## Scope and constraints

- CLI side only (`zzcollab.sh`, `modules/`). No change to the R package
  surface beyond documentation.
- POSIX-compatible bash; `shellcheck --severity=warning` must pass.
- Every change updates `docs/CONFIGURATION.md` (flag reference) and the
  relevant `test-docs.sh` and `test-cli.sh` guards in the same commit.
- The flag reference table in `docs/CONFIGURATION.md` is the single source of
  truth; the `test_help_flags_documented` guard already asserts that
  `zzcollab --help` does not drift from it.

## Phase 0: low risk removals (no functional loss)

### F2, F1. Remove the `docker -n` / `--no` flag

- **Problem**: Within `docker`, both the global `--no-build`
  (`zzcollab.sh:338`) and `-n` / `--no` (`:340`) reach the same skip branch
  (`:397`); they are functionally identical and `--no` is the more cryptic
  name. The short `-n` also collides with `uninstall -n` / `--dry-run`
  (`:826`), where it means the opposite of a behavior modifier.
- **Change**: Delete the `-n) --no)` case from `cmd_docker`. Keep
  `--no-build` as the single 'skip the build' flag. Leave `uninstall`
  `--dry-run` as the long form and, if a short is wanted, rebind it to `-d`.
- **Files**: `zzcollab.sh` (`cmd_docker` parse loop, docker help text);
  `docs/CONFIGURATION.md`.
- **Impact**: A previously valid `zzcollab docker -n` becomes an error.
  Low traffic; `--no-build` is the documented form.
- **Deprecation**: Optional one release of `-n) log_warn` aliasing to
  `--no-build` before removal.

### F5. Collapse `-Y` / `--yes-all` into `-y` / `--yes`

- **Problem**: `-y`, `--yes`, `-Y`, and `--yes-all` set the identical
  variable (`zzcollab.sh:339`, `:1606`). Three of the four spellings are dead
  surface left from a time when `-Y` presumably meant a stronger consent.
- **Change**: Remove `-Y` and `--yes-all` from the pre-scan and from
  `cmd_docker`. Keep `-y` / `--yes`. If a stronger 'consent to destructive
  prompts' tier is later required, introduce it deliberately rather than as a
  silent synonym.
- **Files**: `zzcollab.sh` (pre-scan, `cmd_docker`, help); `docs/`.
- **Impact**: `-Y` / `--yes-all` become errors. Trivial migration.
- **Deprecation**: Optional alias-with-warning for one release.

### F3. Make the quickstart reject trailing flags instead of partially scaffolding

- **Problem**: `zzcollab analysis --r-version 4.4.0` is the natural way to
  create a project pinned to an R version, but the positional profile path
  does not parse trailing flags. It scaffolds with the default, then the
  leftover `--r-version` falls through to 'Unknown command'. The result is a
  half-created directory and a confusing error.
- **Change** (choose one):
  - A. Forward `--r-version`, `--base-image`, and `--profile` from the
    quickstart to its internal `docker` step, so the natural form works.
  - B. Have the quickstart hard-error on any unexpected trailing token
    before performing any filesystem work, naming the supported alternative
    (`config set r-version` or `docker --r-version`).
- **Recommendation**: A is the better user experience; B is the smaller
  change. If A is deferred, apply B now so the command never half-executes.
- **Files**: `zzcollab.sh` (`main` profile dispatch, `cmd_quickstart`).
- **Impact**: Either removes a footgun or closes it safely.

### F9b. Remove duplicate global parsing inside `cmd_docker`

- **Problem**: `cmd_docker` re-parses `--no-build` and the `-y` family that
  the global pre-scan already handled (`zzcollab.sh:338-339`). Duplicated
  parsing can drift from the canonical pre-scan.
- **Change**: Delete the redundant local cases now that the pre-scan owns the
  globals. Verify the pre-scan exports reach `cmd_docker` (they do, via
  `ZZCOLLAB_ACCEPT_DEFAULTS` and `ZZCOLLAB_NO_BUILD`).
- **Files**: `zzcollab.sh` (`cmd_docker`).
- **Impact**: Internal only; no user-visible change.

### F10. Add a help note clarifying `-t`

- **Problem**: `-t` now means `--tag` on `dockerhub`, but meant 'team' across
  years of older documentation and user muscle memory.
- **Change**: Add a single line to the help footer: '`-t` is the DockerHub
  tag, not team; set the team with `config set dockerhub-account`'.
- **Files**: `zzcollab.sh` (`show_usage`).

## Phase 1: consistency (deprecation window advised)

### F6. State and enforce one flag-versus-config rule

- **Problem**: `--base-image`, `--r-version`, and `--profile` exist as both
  flags and config keys; `dockerhub-account` and `github-account` are
  config-only with no flag; the project name is neither. A user cannot
  predict where a setting lives.
- **Change**: Adopt and document the rule 'per-build overrides are flags;
  durable identity is config-only'. Under that rule, the current flags are
  correct and the gap is only documentation. Add a short 'Where settings
  live' subsection to `docs/CONFIGURATION.md` and reflect it in help.
- **Files**: `docs/CONFIGURATION.md`, `zzcollab.sh` help.
- **Impact**: Documentation and mental model only; no behavior change.

### F7. Disambiguate `build` from `docker --build`

- **Problem**: Two build entry points with names that do not signal the
  difference: `docker --build` (generate then build) versus `build`
  (rebuild an existing image, with `--no-cache` / `--log`).
- **Change** (choose one):
  - A. Rename `build` to `rebuild` (keep `build` as a deprecated alias one
    release).
  - B. Fold `--no-cache` / `--log` into `docker` and retire `build`.
- **Recommendation**: A, as the smaller and clearer step.
- **Files**: `zzcollab.sh` (dispatch, help), `templates/Makefile` if it
  invokes `zzcollab build`, `docs/`.
- **Impact**: One renamed command behind an alias.

### F8. Resolve the `validate` versus `doctor` overlap

- **Problem**: Both answer 'is my project healthy?'. The split (validate =
  structure; doctor = files, versions, CI) is invisible at the call site.
- **Change**: Make `validate` a documented subset that `doctor` calls, and
  have `doctor` present validation as one of its sections. Align this with
  the planned slimming of `doctor.sh` in `docs/simplification-plan.md`.
- **Files**: `modules/doctor.sh`, `modules/validation.sh` (or its
  successor), help, `docs/`.
- **Impact**: Consolidation; `validate` remains available.

## Phase 2: structural (coordinate with the simplification plan)

### F4. Reduce the overload of a bare profile token

- **Problem**: `zzcollab analysis` means 'scaffold a new compendium' in an
  empty directory but 'switch profile' in an existing project, and in a
  populated non-project directory it can scaffold unexpectedly. The
  `assert_safe_init_directory` guard mitigates the worst case but the verb
  remains state dependent.
- **Change**: Reserve the bare profile token for creation. Route profile
  switching through an explicit path: either `config set profile-name X`
  followed by `docker`, or a dedicated `profile <name>` verb. Profile
  reduction (Phase 2 of the simplification plan) shrinks the token set and
  is the right moment to make this split.
- **Files**: `zzcollab.sh` (`cmd_quickstart`, dispatch), `docs/`.
- **Impact**: Changes the meaning of a bare profile token in an existing
  project; warrants clear release notes.

### F9a. Document the flag binding rule for combined commands

- **Problem**: Commands are combinable (`docker -b github`), but per-command
  flag scoping makes binding positional and non-obvious: `docker -b github`
  works while `-b docker` does not.
- **Change**: If combinability is retained, document the rule explicitly in
  help: 'a flag binds to the command immediately preceding it'. Consider a
  validation pass that rejects a per-command flag appearing before any
  command with a targeted error.
- **Files**: `zzcollab.sh` help and the main parse loop; `docs/`.
- **Impact**: Clarifies an existing behavior; optional stricter validation.

## Sequencing and effort

| Phase | Items | Risk | Functional loss | Suggested timing |
|-------|-------|------|-----------------|------------------|
| 0 | F1, F2, F3, F9b, F10 | Low | None | Now, one commit |
| 1 | F6, F7, F8 | Medium | None (aliased) | Next minor release |
| 2 | F4, F9a | Higher | Behavior change | With profile reduction |

## Verification for every change

- `shellcheck --severity=warning zzcollab.sh modules/*.sh` passes.
- `tests/shell/test-cli.sh`, `test-docs.sh`, and `test-profiles.sh` pass.
- `test_help_flags_documented` confirms `zzcollab --help` matches the
  `docs/CONFIGURATION.md` flag table.
- For F3 and F4, add explicit cases: the quickstart with a trailing flag
  must not create any file unless the flag is forwarded; profile switching in
  an existing project follows the documented path.

## Open decisions

- F3: forward flags from the quickstart (option A) or hard-error (option B).
- F7: rename `build` to `rebuild` (option A) or fold into `docker` (option
  B).
- Deprecation policy: alias-with-warning for one release, or immediate
  removal given the framework is pre-1.0 on the CLI line.

---
*Rendered on 2026-05-29 at 18:36 PDT.*<br>
*Source: ~/prj/sfw/07-zzcollab/zzcollab/docs/cli-ux-improvement-plan.md*
