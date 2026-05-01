# Validate zzcollab configuration files

Performs comprehensive validation of all zzcollab configuration files in
the configuration hierarchy, checking for syntax errors, invalid values,
and structural problems. This helps ensure your configuration is valid
before running zzcollab operations.

## Usage

``` r
validate_config()
```

## Value

Logical value indicating whether all configuration files are valid
(TRUE) or if validation errors were found (FALSE). Returns TRUE if all
configuration files that exist are syntactically correct and contain
valid values. Missing configuration files are not considered errors.

## Details

The validation process checks multiple aspects of configuration files:

**Syntax Validation:**

- YAML syntax correctness in all configuration files

- Proper key-value structure and indentation

- No duplicate keys or invalid characters

**Value Validation:**

- Build mode values are one of: "minimal", "fast", "standard",
  "comprehensive"

- Boolean values are properly formatted as "true" or "false"

- Path values are syntactically valid (though may not exist)

**File Structure:**

- Configuration directory permissions and accessibility

- File permissions for reading and writing

- Backup file integrity (\*.backup files)

This function is particularly useful for:

- **Pre-flight checks**: Validate configuration before important
  operations

- **Troubleshooting**: Identify configuration problems causing failures

- **Setup verification**: Confirm configuration files are properly
  structured

- **CI/CD pipelines**: Automated validation of configuration in
  workflows

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
set_config("profile_name", "publishing")
if (!validate_config()) {
  warning("Configuration may have issues")
}
} # }
```
