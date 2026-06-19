# Validate zzcollab configuration files

Checks that each existing configuration file in the hierarchy
(project-level ./zzcollab.yaml and user-level ~/.zzcollab/config.yaml)
parses as valid YAML. Missing files are not errors.

## Usage

``` r
validate_config()
```

## Value

Logical: TRUE when every existing configuration file is syntactically
valid YAML, FALSE if any fails to parse.

## See also

[`list_config`](https://rgt47.github.io/zzcollab/reference/list_config.md)
for viewing current configuration
[`init_config`](https://rgt47.github.io/zzcollab/reference/init_config.md)
for initializing default configuration
[`set_config`](https://rgt47.github.io/zzcollab/reference/set_config.md)
for setting configuration values

## Examples

``` r
if (FALSE) { # \dontrun{
# Validate configuration before important operations
if (validate_config()) {
  cat("Configuration is valid, proceeding...\n")
  init_project(project_name = "my-study")
} else {
  cat("Configuration has errors, please fix before proceeding\n")
  list_config()  # Show current config for debugging
}

# Use in automated workflows
validate_config() || stop("Invalid zzcollab configuration")

# Validation after making changes
set_config("profile_name", "rstudio")
if (!validate_config()) {
  warning("Configuration may have issues")
}
} # }
```
