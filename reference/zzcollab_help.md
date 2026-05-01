# Get zzcollab help

Displays help documentation for zzcollab. Can show general help or
specialized help pages covering specific topics like configuration,
workflows, Docker, and more.

## Usage

``` r
zzcollab_help(topic = NULL)
```

## Arguments

- topic:

  Character string specifying which help page to display. Options
  include:

  - NULL or "general": Main help with all command-line options (default)

  - "init": Team initialization help

  - "quickstart": Individual researcher quick start guide

  - "workflow": Daily development workflow

  - "troubleshooting": Top 10 common issues and solutions

  - "config": Configuration system guide

  - "renv": Package management with renv

  - "docker": Docker essentials for researchers

  - "cicd": CI/CD and GitHub Actions

  - "github": GitHub integration and automation

  - "next-steps": Development workflow guidance

## Value

Character vector with help text, or invisible NULL if displayed via
pager. The help text is formatted with ANSI colors for terminal display.

## Details

This function provides access to zzcollab's comprehensive help system
directly from R. Each help page is designed to be accessible to
researchers without extensive DevOps knowledge, focusing on practical
workflows and examples.

The help pages are displayed using your system's pager (usually 'less')
when running interactively, allowing easy navigation of longer help
content.

## See also

[`zzcollab_next_steps`](https://rgt47.github.io/zzcollab/reference/zzcollab_next_steps.md)
for development workflow guidance
[`list_config`](https://rgt47.github.io/zzcollab/reference/list_config.md)
for viewing current configuration

## Examples

``` r
if (FALSE) { # \dontrun{
# Display main help
zzcollab_help()

# Get quick start guide for individual researchers
zzcollab_help("quickstart")

# Learn about configuration system
zzcollab_help("config")

# Troubleshooting common issues
zzcollab_help("troubleshooting")

# Docker basics for researchers
zzcollab_help("docker")
} # }
```
