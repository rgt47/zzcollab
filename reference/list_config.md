# List all configuration values from zzcollab configuration system

Displays all configuration values from the zzcollab configuration
hierarchy, showing the effective configuration that would be used for
zzcollab operations. This includes values from project, user, and system
configuration files with proper precedence resolution.

## Usage

``` r
list_config()
```

## Value

Character vector containing the formatted configuration listing. Each
element represents a configuration key-value pair in the format "key:
value". The output shows the effective configuration after resolving the
hierarchy of project \> user \> system configuration files. Returns
empty character vector if no configuration is found.

## Details

This function provides a comprehensive view of your zzcollab
configuration, making it easy to understand what settings are active and
where they come from. It's particularly useful for:

- **Debugging configuration issues**: See exactly what values are being
  used

- **Understanding precedence**: See which configuration level is
  providing each value

- **Setup verification**: Confirm your configuration changes took effect

- **Team coordination**: Share configuration examples with team members

The output format is human-readable and suitable for documentation or
sharing configuration examples with team members.

## See also

[`get_config`](https://rgt47.github.io/zzcollab/reference/get_config.md)
for retrieving specific configuration values
[`set_config`](https://rgt47.github.io/zzcollab/reference/set_config.md)
for setting configuration values
[`validate_config`](https://rgt47.github.io/zzcollab/reference/validate_config.md)
for validating configuration files

## Examples

``` r
if (FALSE) { # \dontrun{
# View all current configuration
config <- list_config()
cat("Current zzcollab configuration:\n")
cat(paste(config, collapse = "\n"), "\n")

# Check if specific keys are configured
config <- list_config()
if (any(grepl("team_name:", config))) {
  cat("Team name is configured\n")
} else {
  cat("Team name needs to be set\n")
}

# Save configuration for documentation
config <- list_config()
writeLines(config, "my-zzcollab-config.txt")
} # }
```
