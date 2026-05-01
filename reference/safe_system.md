# Safe system call with error handling

Wrapper around system() with comprehensive error handling via tryCatch.
Provides consistent error messages and behavior across all zzcollab
functions.

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
