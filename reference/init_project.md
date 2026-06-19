# Initialize a new zzcollab team project

Creates a research compendium in the current working directory and
records the team's DockerHub and GitHub accounts in the zzcollab
configuration so that the `dockerhub` and `github` commands can publish
under them. Intended for team leads setting up a new collaborative
research project.

## Usage

``` r
init_project(
  team_name = NULL,
  project_name = NULL,
  github_account = NULL,
  profile = "analysis"
)
```

## Arguments

- team_name:

  Character string specifying the Docker Hub team/organization name.
  This becomes part of the Docker image names (e.g.,
  "myteam/projectcore"). If NULL, uses value from configuration file via
  `get_config("team_name")`.

- project_name:

  Character string specifying the project name. The compendium is
  created in the current working directory (which should be named
  accordingly); the value is validated and used in status messages. Must
  be a valid Docker repository name (lowercase, no spaces).

- github_account:

  Character string specifying GitHub account for repository creation. If
  NULL, uses config default or falls back to `team_name`. Used with
  GitHub CLI to create private repositories.

- profile:

  Character string naming the Docker profile / quickstart bundle to
  scaffold (e.g. "analysis", "minimal", "rstudio"). Defaults to
  "analysis".

## Value

Logical value indicating success (TRUE) or failure (FALSE) of the
scaffolding step.

## Details

This function performs two steps using the current zzcollab CLI:

1.  **Configuration**: Records the DockerHub account (and GitHub
    account, if given) via `zzcollab config set` so that later
    `dockerhub` and `github` commands publish under the correct
    accounts.

2.  **Scaffolding**: Runs the profile quickstart (`zzcollab <profile>`),
    which creates the R package structure, renv.lock, and Dockerfile.

To publish the team image and repository afterwards, run
`zzcollab dockerhub` and `zzcollab github` in the project directory.

**Prerequisites:**

- Docker installed and running

- Docker Hub account for image hosting

- GitHub CLI authenticated (for repository creation)

- zzcollab installed in PATH or source directory

**Team Workflow:**

- Team Lead: Runs `init_project()` once per project

- Team Members: Use
  [`join_project()`](https://rgt47.github.io/zzcollab/reference/join_project.md)
  to join existing projects

## See also

[`join_project`](https://rgt47.github.io/zzcollab/reference/join_project.md)
for team members joining existing projects
[`set_config`](https://rgt47.github.io/zzcollab/reference/set_config.md)
for setting up configuration defaults
[`team_images`](https://rgt47.github.io/zzcollab/reference/team_images.md)
for listing created team images

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic team project initialization
success <- init_project(
  team_name = "mylab",
  project_name = "covid-study"
)

# Full specification with all parameters
success <- init_project(
  team_name = "datascience",
  project_name = "market-analysis",
  github_account = "myuniversity"
)

# Using configuration defaults (recommended workflow)
# First, set up your defaults
set_config("team_name", "mylab")

# Then initialize projects easily
init_project(project_name = "new-study")
} # }
```
