# Run a zzcollab config subcommand

Internal helper shared by the config wrappers: resolves the zzcollab
script once and runs `zzcollab config <args>` via
[`safe_system()`](https://rgt47.github.io/zzcollab/reference/safe_system.md).

## Usage

``` r
zzc_config(args, intern = FALSE, error_msg = NULL)
```

## Arguments

- args:

  Character vector of arguments following `config`, already shell-quoted
  where needed (e.g. `c("get", shQuote(key))`).

- intern:

  Passed to
  [`safe_system()`](https://rgt47.github.io/zzcollab/reference/safe_system.md);
  `TRUE` captures stdout.

- error_msg:

  Passed to
  [`safe_system()`](https://rgt47.github.io/zzcollab/reference/safe_system.md).

## Value

The
[`safe_system()`](https://rgt47.github.io/zzcollab/reference/safe_system.md)
result: captured lines when `intern = TRUE`, otherwise the integer exit
status.
