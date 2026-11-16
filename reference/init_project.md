# Initialize a new zzcollab team project

Creates a research compendium in a new directory `project_name` under
the current working directory and, once the compendium has been created,
records the team's DockerHub and GitHub accounts in the user-level
zzcollab configuration so that the `dockerhub` and `github` commands can
publish under them. Intended for team leads setting up a new
collaborative research project.

## Usage

``` r
init_project(
  team_name = NULL,
  project_name = NULL,
  github_account = NULL,
  profile = "tidyverse"
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
  created in the directory `file.path(getwd(), project_name)`, which is
  created if absent and must be empty if it already exists; the CLI
  names the compendium after that directory. Must be a valid Docker
  repository name (lowercase, no spaces).

- github_account:

  Character string specifying GitHub account for repository creation. If
  NULL, uses config default or falls back to `team_name`. Used with
  GitHub CLI to create private repositories.

- profile:

  Character string naming the Docker profile / quickstart bundle to
  scaffold, matching the CLI's profiles in `templates/bundles.yaml`:
  "minimal" (rocker/r-ver), "tidyverse" (rocker/tidyverse), "rstudio"
  (rocker/rstudio), or "publishing" (rocker/verse). "analysis" is
  accepted as a deprecated alias for "tidyverse". Defaults to
  "tidyverse".

## Value

Logical value indicating success (TRUE) or failure (FALSE) of the
scaffolding step.

## Details

This function performs three steps using the current zzcollab CLI:

1.  **Directory**: Creates `project_name` under the current working
    directory, or uses it if it exists and is empty. A non-empty
    directory is an error. The R session's working directory is not
    changed.

2.  **Scaffolding**: Runs the profile quickstart (`zzcollab <profile>`)
    inside that directory, which creates the R package structure,
    renv.lock, and Dockerfile. If it fails, a directory created by this
    call is removed when it is still empty, and step 3 is skipped.

3.  **Configuration**: Records the DockerHub account (and GitHub
    account, if given) via `zzcollab config set` in the user-level
    zzcollab configuration, so that later `dockerhub` and `github`
    commands publish under the correct accounts.

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
