# Safe system call (string form, internal)

Legacy wrapper around [`system()`](https://rdrr.io/r/base/system.html)
retained for literal-string callers that do not pass user-controlled
data. New code should use `safe_system2(cmd, args)` instead.

## Usage

``` r
safe_system(
  command,
  intern = FALSE,
  ignore.stdout = FALSE,
  ignore.stderr = FALSE,
  error_msg = NULL
)
```

## Arguments

- command:

  Character string command to execute

- intern:

  Logical, capture output (default: FALSE)

- ignore.stdout:

  Logical, suppress stdout (default: FALSE)

- ignore.stderr:

  Logical, suppress stderr (default: FALSE)

- error_msg:

  Custom error message prefix (optional)

## Value

For intern=FALSE: exit status (0 for success) For intern=TRUE: character
vector of output
