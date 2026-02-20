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
zzcollab template files and, if present, the zzvim-R `.Rprofile.local`:

```
Checking: ~/prj/res/08-mmrmrobust/
  Makefile       v2.0.0 -> v2.1.0  (outdated)
  .Rprofile      v2.0.0 -> v2.1.0  (outdated)
  Dockerfile     v2.1.0             (current)
  .Rprofile.local v1.9.0            (zzvim-R)
```

The `.Rprofile.local` line is informational: it reports the version
found and attributes ownership to zzvim-R, but does not contribute to
the exit code. zzcollab cannot judge whether a zzvim-R template is
current because it does not know zzvim-R's expected version. The
actual currency check for `.Rprofile.local` occurs inside Vim when an
R terminal starts (see below).

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

## Unified Stamp Format Across the zz* Ecosystem

The template staleness problem is not unique to zzcollab. The zzvim-R
plugin encountered an identical challenge with its `.Rprofile.local`
file---a template that provides the unified graphics system (plot and
table display in kitty terminal panes). The file is copied into each
workspace at plugin setup time and subsequently lives outside the
plugin's control. When the graphics system evolves (e.g., the v7-to-v8
transition from dual-PNG to PDF-master architecture, or the v8-to-v9
addition of table support), workspace copies silently fall behind.

zzvim-R originally solved this with its own versioning system using
bare integers (`# zzvim-R template version: 9`). That system has now
been migrated to the same stamp format used by zzcollab, establishing
a shared convention across the zz* ecosystem:

```
# <tool> <filename> v<major>.<minor>.<patch>
```

Concrete examples:

```
# zzcollab Makefile v2.1.0
# zzcollab .Rprofile v2.1.0
# zzcollab Dockerfile v2.1.0
# zzvim-R .Rprofile.local v1.9.0
```

Each tool owns its own version number. The format is shared; the
authority is not. `ZZCOLLAB_TEMPLATE_VERSION` governs the three
zzcollab files. `s:template_version` in `plugin/zzvim-R.vim` governs
`.Rprofile.local`. Neither tool needs to know the other's current
version. The shared format simply ensures that a human or script
reading any zz* generated file encounters the same pattern.

### zzvim-R's update mechanism

zzvim-R goes beyond detection into **interactive update with backup**:

1. **Check on terminal start.** Every time an R terminal opens
   (`s:ConfigureTerminal()`), the function `s:CheckTemplateVersion()`
   runs. It reads the first 20 lines of the workspace's
   `.Rprofile.local`, extracts the semver string via regex, and
   compares it against the plugin's expected version using
   `s:CompareSemver()`.

2. **Legacy compatibility.** The parser also recognizes the old
   integer format (`# zzvim-R template version: N`) and maps it to
   `0.0.N`, so workspaces predating the format migration still
   trigger an update prompt.

3. **Interactive prompt.** If the local copy is behind, the user is
   prompted:
   ```
   .Rprofile.local is v0.0.8, plugin has v1.9.0. Update? (y/n):
   ```

4. **Backup and replace.** On confirmation, the old file is backed up
   to `.Rprofile.local.bak` and the plugin's template is copied in. A
   manual `:RUpdateTemplate` command is also available.

This design works because `.Rprofile.local` has a specific property:
**it contains no user customizations**. The file is entirely
framework-controlled R code (graphics functions, terminal detection,
history management). Users do not edit it. Therefore, wholesale
replacement is safe.

### Cross-tool visibility

When `zzc check-updates` runs in a workspace, it reports
`.Rprofile.local` as an informational line:

```
  .Rprofile.local v1.9.0            (zzvim-R)
```

This line does not affect the exit code. zzcollab reports what it
finds but defers the currency judgment to zzvim-R, which performs the
actual comparison at R terminal start.

## The Customization Boundary Problem

zzcollab's generated files do not all share this property. Each file
falls on a different point of the customization spectrum:

### `.Rprofile`: safe to regenerate

The zzcollab `.Rprofile` template already delegates user customizations
to `.Rprofile.local` (sourced at line 202 of the template). The
framework-controlled `.Rprofile` handles renv activation, auto-snapshot,
container detection, and reproducibility options. Users who need
project-specific R configuration place it in `.Rprofile.local`.

Because the customization boundary is explicit and enforced by the
sourcing mechanism, `.Rprofile` is architecturally safe to regenerate.
An `update-templates` command could overwrite it without data loss,
exactly as zzvim-R does with its `.Rprofile.local`.

### Dockerfile: safe to regenerate

The Dockerfile is generated entirely by `generate_dockerfile_inline()`
from profile parameters and system dependency lists. Users are not
expected to hand-edit it; customization occurs through zzcollab's
profile system, custom dependency bundles, and `CUSTOM_SYSTEM_DEPS`
sections that are themselves generated. Regeneration from the current
profile would produce a correct, up-to-date file.

### Makefile: not safe to regenerate

The Makefile is the problematic case. Users routinely append
project-specific targets (custom render commands, data download
scripts, deployment targets). There is no `Makefile.local` or
`-include` mechanism to separate framework targets from user targets.
Overwriting the Makefile would destroy these additions.

## Toward Safe Regeneration

The `.Rprofile.local` pattern from zzvim-R and the `.Rprofile` /
`.Rprofile.local` split in zzcollab point toward a general principle:
**files that can be regenerated are files where user customizations
live elsewhere**.

Applying this principle to the Makefile would require introducing a
separation mechanism. The most natural approach in Make is:

```makefile
# zzcollab Makefile v2.1.0
# Framework-generated targets (do not edit)

# ... all zzcollab-generated targets ...

# Project-specific targets
-include Makefile.local
```

With this structure, `zzc update-templates` could safely overwrite
`Makefile` while preserving user targets in `Makefile.local`. The
`-include` directive (with leading hyphen) silently ignores the missing
file in workspaces that have no custom targets.

This refactoring is not yet implemented. It would require:

- Adding `-include Makefile.local` to the Makefile template
- Migrating existing user-added targets in active workspaces
- Documenting the convention

Once all three generated files have clean customization boundaries,
a `zzc update-templates` command becomes viable---modeled directly on
zzvim-R's `s:CheckTemplateVersion()` pattern: detect, prompt, backup,
replace.

## Current Scope: Detection Only

The current implementation is deliberately limited to detection and
advisory. It identifies *that* a workspace is behind but does not
automatically update files. The reasoning:

- The Makefile does not yet have a customization boundary, so
  overwriting it would destroy user work in existing workspaces.
- The advisory system provides the information needed for manual
  updates while the regeneration infrastructure matures.
- The version stamps are forward-compatible: once `Makefile.local`
  separation is in place, the same stamps will drive the automated
  update command.

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
*Rendered on 2026-02-19 at 16:47 PST.*
*Source: /Users/zenn/prj/sfw/07-zzcollab/zzcollab/docs/versioning-design.md*
