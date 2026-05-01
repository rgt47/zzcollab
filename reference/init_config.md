# Initialize default zzcollab configuration file

Creates a default zzcollab configuration file in the user's home
directory (~/.zzcollab/config.yaml) with template values and helpful
comments. This function sets up the foundation for personalized zzcollab
configuration.

## Usage

``` r
init_config()
```

## Value

Logical value indicating success (TRUE) or failure (FALSE) of the
initialization process. Returns TRUE if the configuration directory and
file were created successfully, FALSE if there were permission issues or
other errors during creation.

## Details

This function creates the complete zzcollab user configuration
infrastructure:

**Directory Creation:**

- Creates ~/.zzcollab directory if it doesn't exist

- Sets appropriate permissions for security

- Creates any necessary parent directories

**Configuration File:**

- Creates ~/.zzcollab/config.yaml with template structure

- Includes helpful comments explaining each configuration option

- Sets reasonable default values where appropriate

- Uses YAML format for human readability and easy editing

**Template Content Includes:**

- team_name: (empty, to be filled by user)

- profile_name: "analysis" (balanced default)

- github_account: (empty, for repository creation)

This function is typically run once per system to establish your
personal zzcollab configuration. After initialization, use
[`set_config()`](https://rgt47.github.io/zzcollab/reference/set_config.md)
to set your specific values.

## See also

[`set_config`](https://rgt47.github.io/zzcollab/reference/set_config.md)
for setting configuration values after initialization
[`list_config`](https://rgt47.github.io/zzcollab/reference/list_config.md)
for viewing the initialized configuration
[`validate_config`](https://rgt47.github.io/zzcollab/reference/validate_config.md)
for validating the configuration file

## Examples

``` r
if (FALSE) { # \dontrun{
# Initialize configuration (typically run once)
if (init_config()) {
  cat("Configuration initialized successfully\n")
  cat("Edit ~/.zzcollab/config.yaml to set your preferences\n")
} else {
  cat("Failed to initialize configuration\n")
}

# Complete setup workflow
init_config()  # Create template
set_config("team_name", "mylab")  # Set your values
validate_config()  # Verify everything is correct

# Check if initialization is needed
if (is.null(get_config("team_name"))) {
  cat("Consider running init_config() to set up defaults\n")
}
} # }
```
