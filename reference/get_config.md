# Get configuration value from zzcollab configuration system

Retrieves configuration values from the zzcollab configuration
hierarchy. The system uses a three-tier configuration system with
priority order: project-level (./zzcollab.yaml) \> user-level
(~/.zzcollab/config.yaml) \> system-level (/etc/zzcollab/config.yaml).

## Usage

``` r
get_config(key)
```

## Arguments

- key:

  Character string specifying the configuration key to retrieve. Common
  keys include:

  - "team_name": Docker Hub team/organization name

  - "profile_name": Docker profile ("minimal", "analysis",
    "bioinformatics", "geospatial", etc.)

  - "github_account": GitHub account for repository creation

## Value

Character string with the configuration value, or NULL if the key is not
set in any configuration file. Returns the highest priority value if the
key exists in multiple configuration files.

## Details

The function interfaces with the zzcollab shell script's configuration
system, which manages YAML configuration files across project, user, and
system levels. This provides consistent configuration management between
R and shell interfaces.

Configuration precedence (highest to lowest):

1.  Project-level: ./zzcollab.yaml (project-specific overrides)

2.  User-level: ~/.zzcollab/config.yaml (personal defaults)

3.  System-level: /etc/zzcollab/config.yaml (system-wide defaults)

## See also

[`set_config`](https://rgt47.github.io/zzcollab/reference/set_config.md)
for setting configuration values
[`list_config`](https://rgt47.github.io/zzcollab/reference/list_config.md)
for viewing all configuration
[`get_config_default`](https://rgt47.github.io/zzcollab/reference/get_config_default.md)
for configuration with defaults

## Examples

``` r
if (FALSE) { # \dontrun{
# Get current team name
team <- get_config("team_name")
if (!is.null(team)) {
  cat("Current team:", team, "\n")
} else {
  cat("No team name configured\n")
}

# Check Docker profile setting
profile <- get_config("profile_name")
cat("Docker profile:", profile %||% "minimal", "\n")

# Get GitHub account with fallback
github <- get_config("github_account") %||% get_config("team_name")
} # }
```
