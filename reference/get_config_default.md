# Get configuration value with fallback default

Retrieves a configuration value from the zzcollab configuration system,
returning a specified default value if the configuration key is not set.
This function provides a convenient way to handle optional configuration
with sensible fallbacks.

## Usage

``` r
get_config_default(key, default = NULL)
```

## Arguments

- key:

  Character string specifying the configuration key to retrieve. Should
  match keys used in the zzcollab configuration system (e.g.,
  "team_name", "profile_name", "github_account").

- default:

  Default value to return if the configuration key is not set or if
  [`get_config()`](https://rgt47.github.io/zzcollab/reference/get_config.md)
  returns NULL. Can be any type, but typically a character string to
  match configuration values. Default is NULL.

## Value

The configuration value if set, otherwise the default value. The return
type matches the type of the configuration value or default.

## Details

This internal function implements the "null-coalescing" pattern commonly
used throughout zzcollab for configuration management. It provides a
clean way to specify fallback values when configuration keys might not
be set.

The function is particularly useful in other zzcollab functions that
need to handle optional configuration parameters gracefully. It
eliminates the need for repeated NULL checking and provides consistent
behavior across the codebase.

**Usage Pattern:** This function is typically used internally by other
zzcollab functions to provide sensible defaults when users haven't
configured specific values.

## See also

[`get_config`](https://rgt47.github.io/zzcollab/reference/get_config.md)
for basic configuration retrieval `%||%` for the null-coalescing
operator used internally

## Examples

``` r
if (FALSE) { # \dontrun{
# Internal usage pattern in zzcollab functions
team_name <- get_config_default("team_name", "defaultteam")
profile_name <- get_config_default("profile_name", "analysis")

# Equivalent to using the %||% operator
team_name <- get_config("team_name") %||% "defaultteam"

# Common usage with multiple fallbacks
github_account <- get_config_default("github_account", team_name)
} # }
```
