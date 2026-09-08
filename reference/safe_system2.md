# Safe system call with error handling (vector-argument form)

Wrapper around [`system2()`](https://rdrr.io/r/base/system2.html) that
accepts the command and its arguments as separate values, eliminating
the shell-quoting surface that `system(paste(cmd, args))` requires.
Callers should pass each argument as a distinct element of `args`; no
quoting is necessary.

## Usage

``` r
safe_system2(
  cmd,
  args = character(),
  intern = FALSE,
  ignore.stdout = FALSE,
  ignore.stderr = FALSE,
  error_msg = NULL
)
```

## Arguments

- cmd:

  Character scalar: the executable to run (e.g. `'git'`).

- args:

  Character vector of arguments (default:
  [`character()`](https://rdrr.io/r/base/character.html)).

- intern:

  Logical, capture stdout as a character vector (default: FALSE).

- ignore.stdout:

  Logical, discard stdout (default: FALSE).

- ignore.stderr:

  Logical, discard stderr (default: FALSE).

- error_msg:

  Custom prefix for warning/error messages (optional).

## Value

For `intern = FALSE`: integer exit status (0 = success). For
`intern = TRUE`: character vector of captured output.

## Details

Use this function for any invocation where at least one argument is
derived from user input. For backward-compatible literal-string calls
use the lower-level `safe_system_str()` (internal).
