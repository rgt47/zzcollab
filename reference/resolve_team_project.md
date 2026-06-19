# Validate and resolve shared team/project parameters

Shared by
[`init_project()`](https://rgt47.github.io/zzcollab/reference/init_project.md)
and
[`join_project()`](https://rgt47.github.io/zzcollab/reference/join_project.md):
validates `project_name` and `team_name`, fills `team_name` from the
configured default when not supplied, and errors when a required value
is missing.

## Usage

``` r
resolve_team_project(team_name, project_name)
```

## Arguments

- team_name, project_name:

  As passed by the caller; either may be NULL.

## Value

The resolved `team_name`.
