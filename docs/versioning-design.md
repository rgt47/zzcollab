# Versioning in zzcollab: Design and Implementation

## The Problem

zzcollab generates template files---Makefile, .Rprofile, Dockerfile---into
user workspaces at creation time. Once generated, these files live in the
user's project directory and are no longer connected to the zzcollab
source. When the framework evolves (for instance, changing the renv cache
mount strategy or adding new Make targets), every previously generated
workspace silently falls behind. There is no mechanism to detect which
workspaces are outdated, nor any indication of *how far* behind they are.

This became concrete when a change to the Docker volume mount strategy
required bulk-updating 97 Makefiles across all research projects. The
updates were performed manually because there was no programmatic way to
(a) identify which workspaces existed, (b) determine what version of
the template each one was generated from, or (c) distinguish files that
needed attention from those that were already current.

## Two Distinct Version Identities

The solution introduces a separation between two version numbers that
serve fundamentally different purposes:

### Tool version: `ZZCOLLAB_VERSION`

This is the version of the zzcollab CLI tool itself. It is reported by
`zzc --version` and is set during installation via `install.sh`. It
tracks releases of the framework as a whole---new commands, bug fixes,
behavioral changes. A user running `zzc --version` and seeing `2.0.0`
knows which release of the tool is installed.

This version is **not** embedded into generated files. It describes the
tool, not the artifacts the tool produces.

### Template version: `ZZCOLLAB_TEMPLATE_VERSION`

This is the version of the template *output*. It is defined once in
`lib/constants.sh` as a readonly variable and is embedded as a comment
into every file that zzcollab generates:

```
# zzcollab Makefile v2.1.0        (line 1 of Makefile)
# zzcollab .Rprofile v2.1.0       (line 2 of .Rprofile)
# zzcollab Dockerfile v2.1.0      (line 2 of Dockerfile)
```

The template version answers a different question: *what generation of
template content does this workspace contain?* Two workspaces created a
month apart might contain identical template content if no templates
changed between tool releases, and so they would carry the same template
version despite different tool versions at creation time. Conversely, a
single tool release might bump the template version if it modifies
generated output.

The decision to separate these two versions is deliberate. Coupling them
would create noise: a tool update that adds a new CLI command but does
not touch any template would still require regenerating workspace files.
Decoupling them means the template version changes only when the
*content of generated files* actually changes.

## The Stamp Mechanism

Template files follow two different generation paths, and the stamping
mechanism differs accordingly.

### Makefile and .Rprofile: envsubst path

These files are stored as literal templates in the `templates/`
directory. They contain shell-style `$VARIABLE` placeholders that are
resolved at generation time by the `substitute_variables()` function in
`lib/templates.sh`. The function exports a set of variables and runs
them through `envsubst` with an explicit variable list.

The version stamp is embedded as a placeholder in the template source:

```
# zzcollab Makefile v$ZZCOLLAB_TEMPLATE_VERSION
```

At generation time, `substitute_variables()` exports
`ZZCOLLAB_TEMPLATE_VERSION` (falling back to `0.0.0` if unset for
defensive safety) and includes `$ZZCOLLAB_TEMPLATE_VERSION` in the
`envsubst` variable list. The generated file receives the resolved
version:

```
# zzcollab Makefile v2.1.0
```

### Dockerfile: heredoc path

The Dockerfile is not a static template. It is generated inline by
`generate_dockerfile_inline()` in `modules/docker.sh` using a shell
heredoc (`cat > Dockerfile << EOF`). Because this heredoc uses unquoted
`EOF`, shell variables are interpolated directly. The stamp line:

```bash
# zzcollab Dockerfile v${ZZCOLLAB_TEMPLATE_VERSION}
```

resolves to the current value of the constant at generation time, with
no additional machinery required.

## Detection: `zzc check-updates`

The `check-updates` module (`modules/check-updates.sh`) reads version
stamps from workspace files and compares them against the current
`ZZCOLLAB_TEMPLATE_VERSION`. The extraction uses portable `sed` rather
than Perl-compatible regex (`grep -oP`), since macOS ships with BSD grep
which lacks PCRE support.

The extraction pattern for each file type is:

```bash
sed -n "s/^# zzcollab ${label} v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p"
```

This matches only lines that begin with the exact stamp prefix and
extracts the semver triplet. The label parameter (`Makefile`,
`.Rprofile`, `Dockerfile`) ensures each file's stamp pattern is specific
to its own type.

### Single-workspace mode

```
zzc check-updates [DIR ...]
```

Checks one or more named directories (defaulting to the current
directory). For each workspace, it reports the status of all three
template files:

```
Checking: ~/prj/res/08-mmrmrobust/
  Makefile      v2.0.0 -> v2.1.0  (outdated)
  .Rprofile     v2.0.0 -> v2.1.0  (outdated)
  Dockerfile    v2.1.0             (current)
```

### Batch scan mode

```
zzc check-updates --scan <parent-dir>
```

Recursively searches up to three directory levels for Makefiles
containing the string `zzcollab`, treating each match as a workspace.
This heuristic avoids false positives from non-zzcollab projects while
remaining fast (a single `find` + per-file `grep -q`).

### Exit codes

The command exits `0` if all inspected files are current, and `1` if any
file is outdated or unstamped. This makes the command usable in scripts
and CI pipelines:

```bash
zzc check-updates --scan ~/prj/res || echo "Some workspaces need updating"
```

## Passive Advisory on Every Invocation

In addition to the explicit `check-updates` command, a passive advisory
runs at the top of every `zzc` invocation. The function
`warn_if_templates_outdated()` in `zzcollab.sh` performs the same
`sed`-based extraction on Makefile, .Rprofile, and Dockerfile in the
current directory. If any stamped file carries a version that does not
match `ZZCOLLAB_TEMPLATE_VERSION`, a single warning line is emitted to
stderr:

```
⚠  Outdated templates: Makefile (v2.0.0), .Rprofile (v2.0.0) → v2.1.0. Run: zzc check-updates
```

Design properties of this advisory:

- **Silent when current.** No output is produced if all stamps match or
  if no stamped files exist. A user working in a fresh workspace sees
  nothing.
- **Non-blocking.** The warning is informational. It does not alter
  control flow or exit codes. The invoked command proceeds normally.
- **Stderr-only.** Output goes to stderr so it does not interfere with
  piped or captured stdout from zzc commands.
- **Fast.** Three `sed` invocations on small files. No subshells, no
  external modules sourced. The cost is negligible relative to the
  commands that follow.
- **Graceful with pre-stamp workspaces.** Workspaces created before the
  stamping feature was introduced contain no stamp comments. The
  advisory silently skips files without stamps rather than reporting
  false positives. Only files that have an explicit older version trigger
  the warning.

## What the Template Version Does Not Do

The template version is a detection mechanism, not a migration system.
It identifies *that* a workspace is behind, but it does not
automatically update files. This is intentional:

- Generated files are commonly customized by users. A Makefile might
  have project-specific targets appended. An .Rprofile might contain
  local configuration. Automatic overwriting would destroy these
  customizations.
- The nature of template changes varies. Some changes are trivial
  additions; others restructure existing content. A generic merge
  strategy cannot safely handle all cases.
- The user should make a conscious decision about when and how to
  update. The stamp provides the information needed to make that
  decision.

A future `zzc update-templates` command could offer interactive or
selective regeneration, but that is outside the scope of the current
implementation.

## Summary of Touched Files

| File | Role |
|:-----|:-----|
| `lib/constants.sh` | Defines `ZZCOLLAB_TEMPLATE_VERSION` (single source of truth) |
| `lib/templates.sh` | Exports version for envsubst; adds to substitution list |
| `templates/Makefile` | Contains `$ZZCOLLAB_TEMPLATE_VERSION` placeholder |
| `templates/.Rprofile` | Contains `$ZZCOLLAB_TEMPLATE_VERSION` placeholder |
| `modules/docker.sh` | Interpolates version into generated Dockerfile heredoc |
| `modules/check-updates.sh` | Standalone detection module |
| `zzcollab.sh` | CLI dispatch + `warn_if_templates_outdated()` advisory |
| `modules/help.sh` | Help topic for `check-updates` command |

---
*Rendered on 2026-02-19 at 15:19 PST.*
*Source: /Users/zenn/prj/sfw/07-zzcollab/zzcollab/docs/versioning-design.md*
