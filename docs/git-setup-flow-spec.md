# Git and Remote Setup Flow Specification
*2026-06-27 17:55 PDT*

## Purpose

Bring version control into the `zzc init` flow. A scaffolded research
compendium should be a git repository with an initial commit by the end
of setup, satisfying the version-control requirement of the Five Pillars.
Remote creation remains opt-in and deliberate.

## Background: current behavior

- `zzc init` and `zzc analysis` do not run `git init`. They write
  `.gitignore` and CI workflow files, but leave the directory
  un-versioned until the user separately runs `zzc git`, `zzc github`,
  or `zzc gitlab` (`zzcollab.sh:1532` `cmd_git`).
- The feature wizard (`modules/toggle.sh` `run_feature_wizard`, invoked
  at `zzcollab.sh:342`, after `setup_project`) already asks for the
  forge (github / gitlab / none), which only selects which CI files are
  installed. It does not init git or create a remote.
- Removal already exists as an explicit add/remove model: `zzc rm git`
  (`cmd_rm_git`, `zzcollab.sh:2344`, deletes `.git` after a typed
  confirmation), `zzc rm github` (`cmd_rm_github`), `zzc rm gitlab`, and
  the symmetric `zzc add <feature>` (`cmd_add`, `zzcollab.sh:2137`).

Two consequences motivate the change: a new project is not under version
control, and CI workflow files exist before any repository does.

## Design principles

- The init checklist means 'what to do as I finish setup'. The
  `zzc add` / `zzc rm` commands mean 'change it later'. These are
  distinct mechanisms and must not be duplicated.
- Creation in the wizard; reversal via the existing `zzc rm` commands.
  The wizard never deletes a repository or a remote.
- Remote creation is opt-in, defaults to off, and is suppressed entirely
  for confidential projects.

## Changes

### 1. `git` checklist item (init-mode only)

- Added to the wizard feature checklist, default on.
- Init mode only: it does not appear when `run_feature_wizard` runs in
  toggle mode on an existing project, because reversal is owned by
  `zzc rm git`.
- Apply step: when on and no `.git` exists, run `git init`, write
  `.gitignore`, and create an initial commit, reusing `cmd_git` and
  `_ensure_initial_commit` (`zzcollab.sh:1532`, `:1590`). Idempotent:
  a present `.git` is left untouched.
- When unticked, git is skipped; the project is left un-versioned and
  the user may run `zzc add git` later.

### 2. `remote` checklist item (init-mode only)

- Added to the wizard feature checklist, default off.
- Init mode only.
- Apply step: when on, dispatch to `cmd_github` or `cmd_gitlab`
  according to the selected forge. These already ensure git, create the
  initial commit, check authentication, and create the remote with
  private default visibility. `cmd_github` / `zzc github` now resolves to
  the repository root before operating, so it publishes the whole
  compendium rather than a subdirectory (see
  `docs/remote-guard-whitepaper.md` for the implementation record).
- Gating: the item is forced off and hidden when any of the following
  hold, so it never fires unexpectedly.

  - The selected forge is `none`.
  - The forge CLI is absent (`gh` for github, `glab` for gitlab).
  - Standard input is not a TTY, or `--yes` / accept-defaults is set.
  - The confidential-repo guard denies remotes (see section 3).

### 3. Confidential-repo remote guard

A portable mechanism, not a hardcoded path. A helper `remote_allowed`
returns non-zero (remotes denied) when any of the following hold.

- A marker file `.zzcollab-no-remote` exists in the project root. This
  travels with the project and needs no configuration.
- The config key `remote.allow` is `false` (user or project level).
- The project directory, resolved through symlinks with `realpath`,
  has a prefix listed in the user-level config key
  `remote.blocked_paths` (a space-separated list of path prefixes).
  This serves a confidential subtree, for example `~/prj/srv`, set once
  in `~/.zzcollab/config.yaml` rather than per project.

When the guard denies remotes:

- The `remote` checklist item is forced off and hidden.
- `cmd_github` and `cmd_gitlab` refuse with a clear message naming the
  triggering mechanism, before any `gh` or `git remote` call.

The guard is fail-closed: any positive signal denies remotes.

## Out of scope

- No change to `cmd_github` / `cmd_gitlab` remote-creation internals
  beyond adding the guard refusal at their entry points.
- No change to CI workflow installation, which continues to follow the
  forge selection at `setup_project` time.
- No git removal from the wizard. Reversal stays with `zzc rm git`.

## Affected files

- `modules/toggle.sh`: checklist items, info-pane text, apply logic,
  init-mode gating.
- `zzcollab.sh`: `cmd_github` / `cmd_gitlab` guard refusal at entry.
- `lib/core.sh` or `modules/config.sh`: `remote_allowed` helper.
- `modules/config.sh`: read `remote.allow` and `remote.blocked_paths`.
- `templates/config.yaml` and documentation: new config keys.

## Verification

- Shellcheck clean on all edited shell files.
- Init with defaults yields a git repository with one commit and no
  remote.
- Unticking `git` leaves an un-versioned directory and no commit.
- `remote` item hidden when forge is none, when the CLI is absent, and
  when the guard denies remotes.
- Guard denies via each of the three signals independently; `cmd_github`
  refuses under each.
</content>
