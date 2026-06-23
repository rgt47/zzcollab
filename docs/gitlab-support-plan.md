# GitLab Support Plan
*2026-06-23 09:00 PDT*

Scoping document for adding GitLab as a first-class alternative to GitHub
across zzcollab's source-forge, CI, cloud-launch, and container-registry
layers. This records the agreed scope, the touch-point inventory, the
phased work breakdown, and the open verification risks.

## 1. Motivation and current state

zzcollab treats GitHub implicitly. There is no forge concept; instead there
are hardcoded `.github/` paths, `gh` CLI calls, `github.*` config keys, and
GitHub Actions workflow templates. The container-registry layer is declared
(`docker.registry`) but only partially wired: `cmd_dockerhub` ignores it and
always pushes to Docker Hub, and `zzc status` prints a literal registry value.

Adding GitLab cleanly requires making the forge explicit and consulting it in
the CI, remote-creation, cloud-launch, and registry layers.

## 2. Agreed scope decisions

- Forge model: a project selects a single forge (`github | gitlab | none`).
  No simultaneous GitHub and GitLab CI in one project.
- Remote creation: implemented with the `glab` CLI, supporting both
  `gitlab.com` and self-hosted instances via a `gitlab.host` config key.
- Cloud launch: GitLab Workspaces is in scope for v1 (a GitLab counterpart to
  the GitHub Codespaces devcontainer flow).
- Container registry: GitLab Container Registry is bundled. The registry layer
  is generalised to honour `docker.registry` end-to-end, and the existing
  inconsistencies are fixed as part of the work.
- Default coupling: when `forge = gitlab`, the registry defaults to the GitLab
  Container Registry, whose CI authentication is provided by GitLab's built-in
  `$CI_REGISTRY` and `$CI_REGISTRY_IMAGE` variables.

## 3. Touch-point inventory

References are `file:line` at the time of writing.

### 3.1 Forge configuration

- `modules/config.sh:25-93` declares `CONFIG_*` variables; YAML mapping at
  `:307`, CLI alias at `:321`, reset block at `:215-253`.
- `modules/help.sh:164-166` lists configurable keys.

New keys (mirroring the `github.*` set):

- `forge` = `github` (default, back-compatible) | `gitlab` | `none`.
- `gitlab.account`, `gitlab.host` (default `gitlab.com`),
  `gitlab.default_visibility`, `gitlab.default_branch`.

### 3.2 CI workflow templates

- `templates/workflows/r-package.yml` (159 lines) and
  `templates/workflows/render-report.yml` (221 lines) are GitHub Actions.
- Install: `modules/github.sh:24` (`create_github_workflows`),
  `modules/toggle.sh:23` (`_toggle_add_ci`),
  `modules/project.sh:321` (`setup_project`).
- Remove: `zzcollab.sh:2184` (`cmd_rm_cicd`) deletes `.github/workflows`.

A new `templates/gitlab/.gitlab-ci.yml` is required, reproducing the
self-adapting nix / Docker / renv backend detection in GitLab's `stages` and
`rules` model. It must carry the `v$ZZCOLLAB_TEMPLATE_VERSION` stamp and be
registered with the template-regeneration machinery so `zzc update` keeps it
current.

### 3.3 CI artifact detection

Three sites assume `.github/workflows/r-package.yml` presence:

- `modules/status.sh:130-131`.
- `modules/toggle.sh:241`.
- `modules/doctor.sh:418-508` (also parses the version stamp).

These become forge-aware: 'CI on' means GitHub workflows present or
`.gitlab-ci.yml` present, and the doctor stamp check reads whichever file
exists.

### 3.4 Remote creation

- `zzcollab.sh:1565-1662` (`cmd_github`) uses `gh auth`, `gh api user`,
  `gh repo view/create/delete`, and hardcoded `https://github.com/...` URLs.
- `zzcollab.sh:2173-2182` (`cmd_rm_github`) removes the `origin` remote.

Plan: add `cmd_gitlab` using `glab`, with a host-aware remote URL, and factor
the shared git-init, initial-commit, and remote-wiring logic into a helper
reused by both. `zzc github` is preserved unchanged.

### 3.5 `gh` CLI convenience detection

- `modules/docker.sh:236-238` auto-detects a username via `gh api user`.
- `modules/config-ui.sh:131-143` and `:169-183` validate an account via
  `gh api users/<name>`.

These gain `glab` equivalents gated on the forge, degrading quietly when the
CLI is absent (mirroring the existing `command -v gh` guards).

### 3.6 Cloud launch (Workspaces)

- `zzcollab.sh:866-913` (`cmd_cloud`) installs `.devcontainer` (Codespaces)
  and `.binder`; removal at `:915-924`; detection at `modules/status.sh:135`
  and `modules/toggle.sh:245`; template at `templates/devcontainer.json`.

Plan: add a GitLab Workspaces configuration template and install it when
`forge = gitlab`. Detection and removal extend to the new artifact.

### 3.7 Container registry

- `modules/config.sh:88` (`CONFIG_DOCKER_REGISTRY`), YAML at `:298`.
- `modules/config-ui.sh:904-906` offers `docker.io,ghcr.io`.
- `zzcollab.sh:1664-1718` (`cmd_dockerhub`) hardcodes a Docker Hub reference
  at `:1701` and ignores `docker.registry`.
- `modules/status.sh:121` prints a literal `ghcr` rather than the config.

Plan: generalise the push command to build the image reference from
`docker.registry` (`docker.io`, `ghcr.io`, `registry.gitlab.com`, and
self-hosted `registry.<host>`), add GitLab CR to the select, and fix the
status line. A `zzc push` alias with `dockerhub` retained for back-compat is
the preferred naming (decision deferred to implementation).

### 3.8 Dispatch, help, and the interactive menu

- Dispatcher `zzcollab.sh:1967` (`github`), `:2000` (`rm github`),
  `:1968` and `:2003` (`cicd`).
- Usage `zzcollab.sh:2239-2286`; interactive menu `:2454-2455`.
- Brief help `modules/help.sh:36-52`, next steps `:100`.
- Feature info text `modules/toggle.sh:100-101` hardcodes 'GitHub Actions'.

These gain `gitlab` registrations and forge-aware wording. The forge itself is
presented as a single-select using the new `fzf_choose_preview` info-box
chooser added for the toggle wizard.

### 3.9 Documentation

`README.md`, `ZZCOLLAB_USER_GUIDE.md`, and several `docs/*.md` reference
GitHub Actions, Codespaces, and `gh`. Updates are largely additive
(GitLab counterparts alongside the GitHub instructions).

## 4. Phased work breakdown

| Phase | Work | Size | Risk |
| ----- | ---- | ---- | ---- |
| P1 | Forge config keys and YAML/CLI mapping | S | Low |
| P2 | `.gitlab-ci.yml` template (CI rewrite) | L | High |
| P3 | Forge-aware CI install / remove / detect | M | Med |
| P4 | `cmd_gitlab` via `glab` (self-hosted) | M | Med |
| P5 | `glab` convenience detection | S | Low |
| P6 | Registry generalisation + GitLab CR | S | Med |
| P7 | GitLab Workspaces cloud launch | M | Med |
| P8 | Toggle wizard, dispatch, help | S-M | Low |
| P9 | Documentation | M | Low |

Suggested order: P1, then P3 and P6 (which depend only on config), then P2,
P4, P7 in parallel, then P8 and P9 last.

## 5. Verification risks

- The `.gitlab-ci.yml` rewrite cannot be verified without a real GitLab
  runner. The self-adapting backend detection is the principal uncertainty.
- `cmd_gitlab` and the registry push cannot be exercised without `glab`
  authentication and registry credentials for each target.
- `glab` is materially less ubiquitous than `gh`; absence must degrade
  gracefully, and the user guide should state the dependency.

## 6. Out of scope for v1

- Simultaneous multi-forge projects (single forge only).
- GitLab API depth beyond what `cmd_github` provides (no merge requests, no
  CI-variable management).
