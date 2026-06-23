# Modifying and Debugging the fzf Integration in zzcollab
*2026-06-23 08:30 PDT*

## 1. Purpose and scope

This document describes how the `fzf` fuzzy finder is used inside the
zzcollab command-line framework, and how to modify and debug that
integration safely. It is scoped to zzcollab's own use of `fzf`; it is
not a guide to the upstream `junegunn/fzf` source. The intended reader
is a contributor working on the shell side of the project (the 2.x CLI
track) who needs to change an interactive menu or diagnose why one is
misbehaving.

The integration is small and deliberately contained. `fzf` is referenced
in exactly two files:

- `lib/core.sh` — two reusable wrapper functions and a pinned colour
  theme.
- `modules/toggle.sh` — the two callers (the package-backend chooser and
  the feature checklist) plus their per-option information text.

Everything else in the framework is unaware of `fzf`. This containment
is intentional and should be preserved: new interactive menus should call
the existing wrappers rather than invoke `fzf` directly.

## 2. The two surfaces

`fzf` provides the interactive front end for `zzc toggle` (and the
feature step of `zzc init`, which shares the same wizard). Two distinct
widgets are involved:

- A single-select chooser with a live preview pane, implemented by
  `fzf_choose_preview` (`lib/core.sh:440`) and used for the package
  backend by `_toggle_choose_backend` (`modules/toggle.sh:70`).
- A stateful multi-toggle checklist, implemented by
  `fzf_checklist_preview` (`lib/core.sh:460`) and used for the feature
  set by `_toggle_choose_features` (`modules/toggle.sh:142`).

Both widgets render a right-hand 'info box' that re-renders as the cursor
moves, giving per-option guidance next to the list.

## 3. Architecture of the wrappers

### 3.1 Capability guard and fallback chain

`fzf` is an optional dependency. The guard is a one-line predicate:

```bash
has_fzf() { command -v fzf >/dev/null 2>&1; }   # lib/core.sh:424
```

The dispatcher in `run_feature_wizard` selects a front end by
precedence, with `fzf` preferred, `gum` next, and a plain
`zzc_read` prompt as the floor (`modules/toggle.sh:280-286`):

```bash
local use_gum=false
has_gum && [[ -t 0 ]] && use_gum=true
local use_fzf=false
has_fzf && [[ -t 0 ]] && use_fzf=true
```

Two consequences follow directly from this and must be kept in mind when
debugging:

- The `[[ -t 0 ]]` test means that when standard input is not a terminal
  (a pipe, a CI job, a captured subshell), neither `fzf` nor `gum` is
  used at all; the text `zzc_read` path runs instead. A menu that
  'works by hand but not in a script' is usually this gate, not a bug.
- Because there are three independent code paths, a defect in the `fzf`
  path can be masked on a machine where `fzf` is absent. Always confirm
  which path executed before attributing a symptom.

### 3.2 fzf_choose_preview (single-select)

The single-select wrapper is a thin, declarative `fzf` invocation
(`lib/core.sh:440-449`):

```bash
fzf_choose_preview() {
    local header="$1" info_dir="$2"; shift 2
    printf '%s\n' "$@" | fzf \
        --height=14 --reverse --no-multi --no-info --cycle \
        --color="$ZZCOLLAB_FZF_COLORS" \
        --pointer='>' --prompt='> ' \
        --header="$header  (esc to cancel)" \
        --preview="cat -- '$info_dir'/{}" \
        --preview-window='right:62%:wrap:border-rounded'
}
```

The contract is:

- The caller passes a header, an information directory, and the items as
  positional arguments.
- For each item there must exist a file `INFO_DIR/<item>` whose name
  equals the item exactly; the preview command is `cat` of that file,
  with `{}` expanding to the highlighted item.
- The first item is highlighted initially, so callers list the default
  first. `_toggle_choose_backend` reorders `renv nix none` to put the
  configured default at the front (`modules/toggle.sh:77-81`).
- Output is the chosen item on stdout; a non-zero return signals
  cancellation (Esc), which callers translate into 'no changes'.

### 3.3 fzf_checklist_preview (stateful multi-toggle)

The checklist is the more intricate of the two, because it does not use
`fzf`'s native multi-select. The reason is recorded in the source
(`lib/core.sh:452-457`): native multi-select falls back to the cursor
line when nothing is ticked, which is wrong for a checklist where 'all
off' is a legitimate result. The wrapper therefore keeps checkbox state
in a caller-owned file and drives it with key bindings.

The mechanism has three parts:

- A state file, one line per item, of the form `<name> on|off`. The
  caller pre-populates it and reads it back after the call; the wrapper
  only edits it.
- Two helper scripts written to a private temporary directory: `render`
  turns the state file into tab-separated `[x]\t<name>` lines for `fzf`
  input, and `toggle` flips one name's state in place via an atomic
  rename (`lib/core.sh:465-481`).
- A key binding that, on Tab or Space, runs `toggle` silently and then
  reloads the list from `render` (`lib/core.sh:483`):

```bash
local toggle_act="execute-silent(bash '$helper/toggle' \
'$state' {2})+reload(bash '$helper/render' '$state')"
```

Several `fzf` options are load-bearing here and should not be changed
without understanding their role (`lib/core.sh:487-497`):

- `--delimiter='\t' --with-nth='1,2'` parse the input into a checkbox
  field and a name field, and display both.
- `--id-nth='2'` together with `--track` keeps the cursor on the same
  logical item across reloads, even though the checkbox field text
  changes when an item is toggled. Without these, the cursor would jump
  on every toggle.
- `{2}` in the binding and in the preview command is the name field; it
  is what `toggle` mutates and what the preview `cat`s.

The function returns 0 on commit (Enter) and non-zero on Esc; the caller
inspects the state file only on a zero return.

### 3.4 The pinned theme

Both widgets pass an explicit colour string rather than inheriting the
user's `FZF_DEFAULT_OPTS`, so the menu looks the same regardless of
personal configuration (`lib/core.sh:432`). The value is a single
unbroken single-quoted string of `key:colour` pairs (shown here wrapped
only for the page; do not introduce line breaks, as backslash
continuations are not honoured inside single quotes):

```
pointer:bright-magenta, marker:bright-magenta, hl:bright-magenta,
hl+:bright-magenta, fg+:bright-white, prompt:bright-magenta,
header:bright-black, border:bright-black,
preview-border:bright-black, gutter:-1
```

The colours are named ANSI values, not 256-index numbers, so the menu
tracks the terminal's own sixteen-colour palette. The accent
`bright-magenta` is chosen to match `gum`'s accent, which is set as
foreground index 13 in `gum_header` (`lib/core.sh:358-363`); the two
front ends are meant to read as one interface. If you retheme one, you
must retheme the other.

## 4. The caller contract in modules/toggle.sh

### 4.1 Information-box convention

Per-option text is produced by `_toggle_backend_info`
(`modules/toggle.sh:46`) and `_toggle_feature_info`
(`modules/toggle.sh:91`). Each emits a short fixed-width paragraph for
one option. The caller writes one such file per option into the
information directory before invoking the wrapper, naming each file
exactly as the option (`modules/toggle.sh:75` and `:150-151`). The
filename-equals-item rule is the entire coupling between the list and
the preview; a mismatch yields an empty or wrong info box rather than an
error.

### 4.2 State-file convention

`_toggle_choose_features` builds the state file from the desired-default
set, writing `<feature> on` or `<feature> off` per line
(`modules/toggle.sh:152-156`), calls the wrapper, and on success reads
the result back with a single `awk` filter
(`modules/toggle.sh:161`):

```bash
awk '$2 == "on" { print $1 }' "$state"
```

This deliberately yields the same one-per-line shape that
`gum_multichoose` returns, so the caller's downstream `grep -qx` parse
is shared across the `fzf` and `gum` paths
(`modules/toggle.sh:344-349`).

### 4.3 Temporary-directory lifecycle

Every caller creates its working directory with `mktemp -d` and removes
it on every exit path (`modules/toggle.sh:73,85` and `:146,163`). The
wrappers do the same for their private helper directory
(`lib/core.sh:463,498`). When debugging, this cleanup is the first thing
to suspend (see Section 5.4); otherwise the evidence is gone by the time
the function returns.

## 5. Debugging techniques

### 5.1 Identify which front end ran

Because of the three-way fallback, begin every investigation by
establishing the path. Temporarily echo the decision, or run under a
shell trace:

```bash
bash -x zzcollab.sh toggle 2>/tmp/zzc-toggle.trace
```

Inspect the trace for the assignments to `use_fzf` and `use_gum`. If
both are false, the `[[ -t 0 ]]` gate or a missing binary sent control
to the text path, and no amount of `fzf` debugging will help.

### 5.2 The terminal-capture asymmetry

`fzf` draws its full-screen interface on the controlling terminal
(`/dev/tty`), while its *result* goes to stdout. This is why
`chosen=$(fzf_choose_preview ...)` captures the selection without
capturing the menu. The practical implications for debugging are:

- You cannot meaningfully pipe a live `fzf` session into a file to see
  what it drew; redirect specific data instead (the input list, the
  state file, the trace).
- A wrapper invoked inside a command substitution whose stdout you have
  redirected will still render, because rendering uses the tty, not
  stdout. Do not be misled into thinking the menu 'leaked'.

### 5.3 Logging inside execute-silent and reload

The checklist's `toggle` and `render` helpers run in subshells launched
by `fzf` bindings, and `execute-silent` discards their output by design.
A bug in toggling (for example, state not flipping) is therefore
invisible from the parent. To observe it, have the helper append to a
log instead of relying on stdout. Edit the generated `toggle` script in
`lib/core.sh:473-481` to add, inside the loop body, a line such as:

```bash
printf '%s -> %s\n' "$name" "$st" >> /tmp/zzc-toggle.log
```

Then run the menu and watch the log in another pane with `tail -f`.
Remove the line afterwards; it is debugging scaffolding, not a feature.

### 5.4 Inspect the state and info files live

Suspend cleanup to capture the working directory. The simplest approach
is to comment out the relevant `rm -rf` (`modules/toggle.sh:163` for the
feature checklist, `lib/core.sh:498` for the wrapper's helper dir), run
the menu once, then examine the files:

- The state file should have exactly one `<name> on|off` line per
  option; a duplicated or missing name indicates a caller bug in the
  pre-population loop.
- `INFO_DIR/<item>` must exist for every list item. A blank preview pane
  almost always means a filename that does not match its item, often a
  hyphen or case difference (note `code-quality` and `validate-strict`
  in `modules/toggle.sh:91-135`).

### 5.5 Quoting and field-placeholder pitfalls

The most common defects are not logic errors but string-construction
errors, because paths are interpolated into `fzf` option strings:

- The preview and binding commands embed `$info_dir` and `$state` inside
  single quotes within a double-quoted assignment
  (`lib/core.sh:447,483,495`). A path containing a single quote or a
  space will break the generated command. The `mktemp` templates avoid
  this in practice, but a caller that passes an arbitrary directory must
  not assume it is safe.
- `{}`, `{2}` are `fzf` field placeholders, not shell expansions; their
  meaning depends on `--delimiter`, `--with-nth`, and `--id-nth`. If you
  change the delimiter or the column layout, every placeholder and the
  `awk`/`render` field indices must change together. Treat the
  delimiter, the render format, the `--with-nth`/`--id-nth` values, and
  the `{N}` references as a single coupled unit.

### 5.6 Force a specific path for reproduction

To reproduce a `gum` or text-path symptom on a machine that has `fzf`,
make the guard fail for the session rather than editing code. For
example, prepend a directory containing no `fzf` to nothing — instead,
the reliable approach is to run with stdin not a terminal to exercise
the text path:

```bash
printf '\n\n' | bash zzcollab.sh toggle
```

To exercise the `gum` path specifically, temporarily force `use_fzf` to
`false` in `run_feature_wizard`. Document any such edit as temporary and
revert it before committing.

## 6. Recipes for common modifications

### 6.1 Add a feature to the checklist

Adding a feature touches three coordinated locations and nothing else:

- Add a case arm to `_toggle_feature_info` (`modules/toggle.sh:91`) so
  the new option has an info box.
- Add the option name to the list passed to `_toggle_choose_features`
  and to `gum_multichoose`, in display order
  (`modules/toggle.sh:336-342`).
- Add the corresponding default and want variables and the apply logic
  in `run_feature_wizard`, mirroring an existing feature.

The wrappers themselves require no change; they are option-agnostic.

### 6.2 Change layout or theme

Adjust `--height`, `--preview-window`, or `ZZCOLLAB_FZF_COLORS` in
`lib/core.sh`. If you change an accent colour, change `gum_header`'s
foreground index to match (Section 3.4).

### 6.3 Add a key binding

Add a `--bind` to the relevant wrapper. For an action that mutates
checklist state, follow the existing `execute-silent(...)+reload(...)`
form so the displayed list stays in step with the state file
(`lib/core.sh:483`).

## 7. Testing and continuous integration

The interactive paths cannot be exercised by a non-interactive test
runner, because the `[[ -t 0 ]]` gate routes a pipe to the text path.
This has two practical effects:

- `shellcheck --severity=warning lib/core.sh modules/toggle.sh` is the
  primary automated guard and must pass (it is enforced by
  `shellcheck.yml`). Note that the `render` and `toggle` helpers are
  heredoc-quoted bodies; `shellcheck` does not analyse their contents,
  so review them by hand.
- The non-interactive contract is that `ZZCOLLAB_ACCEPT_DEFAULTS=true`
  makes no changes (`modules/toggle.sh:214`). A regression test can
  assert that this path is side-effect free without needing a terminal.

Manual verification remains necessary for the `fzf` and `gum` widgets
themselves: run `zzc toggle` in a real terminal, confirm the preview
tracks the cursor, that Tab and Space toggle the highlighted item, that
the cursor does not jump on toggle, and that Esc cancels with no
changes.

## 8. Invariants and gotchas, in brief

- `fzf` is optional; never remove the `has_fzf` guard or the `gum` and
  text fallbacks.
- The `[[ -t 0 ]]` gate disables `fzf` for non-terminal stdin by design.
- `INFO_DIR/<item>` filenames must match list items exactly.
- The checklist state file is the source of truth, not `fzf`'s native
  selection.
- `--delimiter`, `--with-nth`, `--id-nth`, the `{N}` placeholders, the
  `render` format, and the `awk` field indices are one coupled unit.
- `--track` with `--id-nth=2` is what stops the cursor jumping across
  reloads.
- The `fzf` accent and the `gum` accent are meant to match; retheme both
  together.
- Temporary directories are removed on every exit path; suspend that
  cleanup to debug, and restore it before committing.
