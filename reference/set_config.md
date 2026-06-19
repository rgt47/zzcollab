# Set configuration value in zzcollab configuration system

Sets or updates configuration values in the zzcollab user-level
configuration file. This function writes to ~/.zzcollab/config.yaml,
creating the directory and file if they don't exist. Configuration
values set here become defaults for future zzcollab operations.

## Usage

``` r
set_config(key, value)
```

## Arguments

- key:

  Character string specifying the configuration key to set. Recommended
  keys include:

  - "team_name": Your Docker Hub team/organization name

  - "profile_name": Docker profile ("minimal", "analysis", "rstudio")

  - "github_account": Your GitHub account for repository creation

- value:

  Character string specifying the configuration value to set. The value
  will be stored as a string in the YAML configuration file. Boolean
  values should be passed as "true" or "false" strings.

## Value

Logical value indicating success (TRUE) or failure (FALSE) of the
configuration operation. Returns FALSE if the zzcollab script cannot be
found or if the configuration write operation fails.

## Details

This function provides a convenient R interface to the zzcollab
configuration system. It's particularly useful for setting up your
personal defaults once, then using them across multiple projects without
repeatedly specifying the same parameters.

The function creates the ~/.zzcollab directory if it doesn't exist and
initializes a default config.yaml file. Values are stored in YAML format
for easy editing and cross-platform compatibility.

**Configuration Strategy:**

- Set personal defaults once using this function

- Use project-specific settings in ./zzcollab.yaml for project overrides

- Let the hierarchy system handle precedence automatically

## See also

[`get_config`](https://rgt47.github.io/zzcollab/reference/get_config.md)
for retrieving configuration values
[`list_config`](https://rgt47.github.io/zzcollab/reference/list_config.md)
for viewing all current configuration
[`init_config`](https://rgt47.github.io/zzcollab/reference/init_config.md)
for initializing default configuration

## Examples

``` r
if (FALSE) { # \dontrun{
# Set up your personal defaults (run once)
set_config("team_name", "mylab")
set_config("profile_name", "analysis")
set_config("github_account", "myuniversity")

# Check if configuration was successful
if (set_config("team_name", "newteam")) {
  cat("Team name updated successfully\n")
} else {
  cat("Failed to update configuration\n")
}
} # }
```
