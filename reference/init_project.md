# Initialize a new zzcollab team project

Creates a complete team research collaboration infrastructure including
Docker base images, GitHub repository, and project structure. This
function is the R interface to the `zzcollab --init` command and should
be used by team leads to set up new collaborative research projects.

## Usage

``` r
init_project(team_name = NULL, project_name = NULL, github_account = NULL)
```

## Arguments

- team_name:

  Character string specifying the Docker Hub team/organization name.
  This becomes part of the Docker image names (e.g.,
  "myteam/projectcore"). If NULL, uses value from configuration file via
  `get_config("team_name")`.

- project_name:

  Character string specifying the project name. Used for Docker image
  names, GitHub repository, and directory names. Must be a valid Docker
  repository name (lowercase, no spaces).

- github_account:

  Character string specifying GitHub account for repository creation. If
  NULL, uses config default or falls back to `team_name`. Used with
  GitHub CLI to create private repositories.

## Value

Logical value indicating success (TRUE) or failure (FALSE) of the
initialization process. The function creates multiple components, so
partial failures may occur.

## Details

This function orchestrates the complete team project setup process:

1.  **Team Docker Images**: Creates and pushes base images to Docker Hub

2.  **Project Structure**: Generates R package structure with analysis
    templates

3.  **GitHub Repository**: Creates private repository with CI/CD
    workflows

4.  **Configuration Files**: Sets up Dockerfile, Makefile, and config
    files

5.  **Documentation**: Generates user guides and README files

The function integrates with the zzcollab configuration system, allowing
team leads to set default values once and reuse them across projects.

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
