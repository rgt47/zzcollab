# ZZCOLLAB CLI Command and Flag Improvement Plan
*2026-05-29 18:36 PDT (revised 2026-05-31 08:38 PDT)*

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

A parallel simplification effort landed first (commits `56ae900` 'Fix P0
correctness bugs' and `890528c` 'Remove dead code (P1)', among others); that is
the maintainer's own P0/P1 track. This plan's Phase 0 and the D1 documentation
sweep were then implemented on 2026-05-30. The current status of each finding:

| Finding | Status | Note |
|---------|--------|------|
| F1, F2 (`docker -n`/`--no`) | Done | Flag removed from `cmd_docker`; the `uninstall -n` collision is gone. |
| F5 (`-Y`/`--yes-all`) | Done | Removed from the pre-scan and help; `-Y` now errors. |
| F3 (quickstart trailing flags) | Done | Option B: `zzcollab <profile>` hard-errors on a trailing flag before any filesystem work, naming the supported alternatives. |
| F9b (duplicate global parsing) | Done | Dead local cases removed; the build decision now honors `ZZCOLLAB_NO_BUILD`, which also fixed a latent bug where `docker --no-build` did not skip the build. |
| F10 (`-t` help note) | Done | Help footer clarifies `-t` is the tag, not team. |
| D1 (docs name removed profiles) | Done | Swept ~15 files to `minimal`/`analysis`/`rstudio` or `--base-image`; guarded by `test_no_removed_profiles`. |
| F6 (flag-vs-config rule) | Done | 'Where settings live' subsection added to `docs/CONFIGURATION.md`. |
| F7 (`build` vs `docker --build`) | Done | `build` renamed to `rebuild`; `build` kept as a deprecated alias with a warning. |
| F8 (`validate` vs `doctor`) | Done (reframed) | The maintainer's zzrenvcheck refactor already removed the overlap: `validate` now checks package dependencies and `doctor` checks workspace files. Only the stale help label remained, now corrected. |
| F4 (profile-token overload) | Scoped, decided | Profiles reduced and the `cmd_init` guard hardened (commit `56ae900`). The remaining verb split is now fully scoped and decided (B1 + D-break); ready to implement. |
| F9a (flag-binding doc) | Done | Help notes that a per-command option binds to the command immediately before it. |

Phase 0 (F1, F2, F3, F5, F9b, F10), Phase 1 (F6, F7, F8), F9a, and D1 are
complete and verified (`shellcheck` clean; `test-cli`, `test-docs`,
`test-profiles`, `test-config` pass). The single remaining open item is F4's
verb split (the state-dependent profile token), which is a behavior change held
for a coordinated release. D1 is described below.

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

- **Status**: Done (2026-05-30). `-n` / `--no` removed from `cmd_docker`; the collision with `uninstall -n` is gone.
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

- **Status**: Done (2026-05-30). `-Y` / `--yes-all` removed from the pre-scan and help; `-Y` now errors.
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

- **Status**: Done (2026-05-30), option B. `zzcollab <profile>` hard-errors on a trailing flag before any filesystem work and names the supported alternatives. Verified: `analysis --r-version 4.4.0` errors with zero files created. Option A (forwarding the flags) remains a possible future enhancement.
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

- **Status**: Done (2026-05-30). The dead local `--no-build` / `-y` cases were removed and the build decision now reads `ZZCOLLAB_NO_BUILD`. This also fixed a latent bug: because the pre-scan stripped `--no-build` before `cmd_docker`, the build decision had been ignoring it, so `zzcollab docker --no-build` did not actually skip the build. It does now.
- **Problem**: `cmd_docker` re-parses `--no-build` and the `-y` family that
  the global pre-scan already handled (`zzcollab.sh:338-339`). Duplicated
  parsing can drift from the canonical pre-scan.
- **Change**: Delete the redundant local cases now that the pre-scan owns the
  globals. Verify the pre-scan exports reach `cmd_docker` (they do, via
  `ZZCOLLAB_ACCEPT_DEFAULTS` and `ZZCOLLAB_NO_BUILD`).
- **Files**: `zzcollab.sh` (`cmd_docker`).
- **Impact**: Internal only; no user-visible change.

### F10. Add a help note clarifying `-t`

- **Status**: Done (2026-05-30). The help footer now states `-t` is the tag, not team.
- **Problem**: `-t` now means `--tag` on `dockerhub`, but meant 'team' across
  years of older documentation and user muscle memory.
- **Change**: Add a single line to the help footer: '`-t` is the DockerHub
  tag, not team; set the team with `config set dockerhub-account`'.
- **Files**: `zzcollab.sh` (`show_usage`).

## Phase 1: consistency (deprecation window advised)

### F6. State and enforce one flag-versus-config rule

- **Status**: Done (2026-05-30). A 'Where settings live' subsection in `docs/CONFIGURATION.md` documents the rule: per-build overrides are flags; durable identity is config; the project name is the directory.
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

- **Status**: Done (2026-05-30), option A. `build` renamed to `rebuild`; `build` kept as a deprecated alias that warns and forwards. Updated the template `Makefile`, the user guide, the help command list, and the `CONFIGURATION.md` flag table. Already-generated project Makefiles continue to work via the alias.
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

- **Status**: Done (2026-05-30), reframed. The original recommendation (merge
  the two) was overtaken by the maintainer's refactor: `validation.sh` was
  deleted and `validate` now delegates package-dependency checking to the
  `zzrenvcheck` R package, while `doctor` checks that workspace files are
  current with templates. The two commands are now genuinely distinct, so a
  merge would be wrong. The only residue was a stale help label
  (`validate` described as 'Check project structure'), now corrected to
  'Validate package dependencies (renv / zzrenvcheck)'.
- **Original problem**: Both appeared to answer 'is my project healthy?', with
  an invisible split between them.
- **Files**: `zzcollab.sh` (help command list).
- **Impact**: Labels now disambiguate; no behavior change.

## Phase 2: structural (coordinate with the simplification plan)

### F4. Reduce the overload of a bare profile token

- **Status**: Partially done.
- **Problem**: `zzcollab analysis` means 'scaffold a new compendium' in an
  empty directory but 'switch profile' in an existing project, and in a
  populated non-project directory it could scaffold unexpectedly.
- **Already addressed**: Two of the three concerns have landed. The profile
  set is now reduced to `minimal`, `analysis`, `rstudio`, which shrinks the
  overloaded token surface; and the `cmd_init` safety guard was hardened
  (commit `56ae900`) so that an occupied directory hard-stops unless `--force`
  is given, closing the accidental-scaffolding footgun.
#### Scope of the remaining work (2026-05-31)

**Current behavior (`cmd_quickstart`).** A bare profile token does three
different things depending on directory state:

1. Uninitialized directory: scaffold init + renv + docker (create). Correct.
2. Initialized, same profile, Dockerfile present: print an idempotent
   'already configured' status. Harmless.
3. Initialized, different profile: silently switch. This path
   (`zzcollab.sh:1196-1220`) rewrites `.Rprofile` and `Makefile` from the
   templates via `safe_cp` and regenerates the Dockerfile. Because it
   overwrites `.Rprofile`/`Makefile` unconditionally, a switch silently
   clobbers user customizations. This is the defect.

**Relevant existing path.** `zzcollab docker --profile X` already switches a
project's profile (`zzcollab.sh:357-390`): it sets the base image, writes
`profile-name` to config, and regenerates the Dockerfile only. It does NOT
touch `.Rprofile`/`Makefile`, so it is the non-destructive switch.

**Target behavior.**

- `zzcollab <profile>` becomes create-or-idempotent only:
  - uninitialized → create (unchanged);
  - initialized, same profile → idempotent status (unchanged);
  - initialized, different profile → refuse and direct the user to the
    switch path, rather than silently overwriting files.
- Switching uses one canonical, non-destructive path. Two options:
  - **B1 (reuse, recommended):** `zzcollab docker --profile X`. No new
    command; relies on the existing non-destructive switch.
  - **B2 (dedicated verb):** add `zzcollab profile <name>` as sugar for the
    switch. More discoverable, but adds surface against the maintainer's
    simplification direction.
- Remove the destructive `.Rprofile`/`Makefile` overwrite from the switch
  entirely. If a template refresh is ever wanted it should be a separate,
  explicit, confirmed action (it is closer to `doctor`'s remit).

**Deprecation path (decision required).**

- **D-warn (one-release window):** in this release, a different-profile bare
  token still switches but prints a deprecation warning naming the new path;
  the next release turns it into a hard error. Safest for existing users.
- **D-break (clean break):** the different-profile bare token errors
  immediately. Justified by the pre-1.0 CLI line and the fact that the
  removed behavior was also destructive.

**Files.** `zzcollab.sh` (`cmd_quickstart`; dispatch and `show_usage` if B2);
`docs/CONFIGURATION.md` and the profile docs; `NEWS.md` / `CHANGELOG.md`.

**Tests (`test-cli.sh`).** Create in an empty dir; idempotent same-profile;
different-profile refusal (or warning under D-warn); the switch path leaves a
customized `.Rprofile`/`Makefile` untouched.

**Impact.** Behavior change for the 'bare token switches an existing project'
case; removes a silent data-loss path. Needs a release note regardless of the
deprecation choice.

**Decided (2026-05-31).** B1 (switching stays `zzcollab docker --profile X`;
no new verb) and D-break (a different-profile bare token errors immediately,
directing the user to `docker --profile X`, with no warning window). The
destructive `.Rprofile`/`Makefile` overwrite is removed either way. Ready to
implement:

- In `cmd_quickstart`, replace the different-profile branch
  (`zzcollab.sh:1196-1220`) with a hard error that names the switch path; keep
  the create and idempotent-same-profile branches.
- No change to `cmd_docker --profile`, which is already the non-destructive
  switch.
- Add `test-cli` cases and a `NEWS.md`/`CHANGELOG.md` release note recording
  the behavior change.

### F9a. Document the flag binding rule for combined commands

- **Status**: Done (2026-05-31). The help text now states that a per-command option binds to the command immediately before it, with `zzcollab docker -b github` as the worked example. The optional stricter validation pass was not added.
- **Problem**: Commands are combinable (`docker -b github`), but per-command
  flag scoping makes binding positional and non-obvious: `docker -b github`
  works while `-b docker` does not.
- **Change**: If combinability is retained, document the rule explicitly in
  help: 'a flag binds to the command immediately preceding it'. Consider a
  validation pass that rejects a per-command flag appearing before any
  command with a targeted error.
- **Files**: `zzcollab.sh` help and the main parse loop; `docs/`.
- **Impact**: Clarifies an existing behavior; optional stricter validation.

## Related: documentation follow-up (not a CLI change)

### D1. Active docs reference removed profiles

- **Status**: Done (2026-05-30). Swept ~15 active files; removed-profile invocations now use `minimal`/`analysis`/`rstudio` or `docker --base-image`, guarded by `test_no_removed_profiles` in `test-docs.sh`.
- **Problem**: Reducing the profile set to `minimal`, `analysis`, `rstudio`
  removed `modeling`, `publishing`, `shiny`, `analysis_pdf`, and
  `manuscript-package`. Roughly fifteen active files (README, several guides
  and vignettes, `docs/CONFIGURATION.md`, and `templates/`) still name those
  profiles in commands and tables, so their examples no longer resolve. This
  is downstream of the earlier old-interface documentation migration, which
  used the then-current eight-profile set.
- **Change**: Sweep the active docs and replace removed profile names with
  one of the three current profiles, or with the `docker --base-image` form
  for specialized domains. Then extend `test-docs.sh` with a guard asserting
  that only live profile names appear in `zzcollab <profile>` and `--profile`
  invocations, so the profile list cannot drift again.
- **Files**: README and `docs/`, `vignettes/`, `templates/` per the grep
  inventory.
- **Impact**: Documentation accuracy; no CLI change.

## Sequencing and effort

| Phase | Items | Status | Risk | Functional loss | Timing |
|-------|-------|--------|------|-----------------|--------|
| 0 | F1, F2, F3, F5, F9b, F10 | Done | Low | None | Done 2026-05-30 |
| Docs | D1 | Done | Low | None | Done 2026-05-30 |
| 1 | F6, F7, F8 | Done | Medium | None (aliased) | Done 2026-05-30 |
| 2 | F4, F9a | F9a done; F4 partial | Higher | Behavior change | With profile reduction |

## Verification for every change

- `shellcheck --severity=warning zzcollab.sh modules/*.sh` passes.
- `tests/shell/test-cli.sh`, `test-docs.sh`, and `test-profiles.sh` pass.
- `test_help_flags_documented` confirms `zzcollab --help` matches the
  `docs/CONFIGURATION.md` flag table.
- For F3 and F4, add explicit cases: the quickstart with a trailing flag
  must not create any file unless the flag is forwarded; profile switching in
  an existing project follows the documented path.

## Open decisions

- F3: resolved as option B (hard-error). Option A (forwarding the flags from
  the quickstart so `analysis --r-version` works) remains a possible future
  enhancement.
- F7: resolved as option A (`build` renamed to `rebuild`, with `build` kept as
  a deprecated alias).
- Deprecation policy as applied: removed flags (`-n`/`--no`, `-Y`/`--yes-all`)
  were cut outright, since the framework is pre-1.0 on the CLI line and they
  were exact synonyms; the renamed `build` command kept an alias-with-warning
  because already-generated project Makefiles still call it.
- F4: decided 2026-05-31 as B1 (reuse `zzcollab docker --profile X`) and
  D-break (immediate error for a different-profile bare token). Scoped above and
  ready to implement; no decisions remain.

---
*Rendered on 2026-05-31 at 08:44 PDT.*<br>
*Source: ~/prj/sfw/07-zzcollab/zzcollab/docs/cli-ux-improvement-plan.md*
