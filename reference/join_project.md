# Join an existing zzcollab team project

Allows team members (Developers 2+) to join an existing zzcollab project
by setting up their local development environment using the team's
shared Docker images and project structure. This function is the R
interface to team collaboration workflows.

## Usage

``` r
join_project(team_name = NULL, project_name = NULL)
```

## Arguments

- team_name:

  Character string specifying the Docker Hub team/organization name.
  This should match the team name used when the project was initialized.
  If NULL, uses value from configuration file via
  `get_config("team_name")`.

- project_name:

  Character string specifying the project name. Must match the project
  name used during initialization. Used to identify the correct team
  Docker images and repository.

## Value

Logical value indicating success (TRUE) or failure (FALSE). The function
validates team images exist before proceeding with setup.

## Details

This function is designed for team members joining existing projects.
The team lead should have already run
[`init_project()`](https://rgt47.github.io/zzcollab/reference/init_project.md)
to create the necessary team infrastructure.

**Setup Process:**

1.  **Validation**: Checks that team Docker images exist and are
    accessible

2.  **Project Setup**: Creates local project structure and configuration

3.  **Environment**: Configures to use team's Docker image via
    –use-team-image

**Prerequisites:**

- Team lead has run
  [`init_project()`](https://rgt47.github.io/zzcollab/reference/init_project.md)
  and shared repository access

- Docker installed and running locally

- Access to team's Docker images (usually public on Docker Hub)

- Git repository cloned locally (typically done before calling this
  function)

**Development Workflow:** After joining, start development with `make r`
(shell) or `make docker-rstudio` (RStudio Server at
http://localhost:8787).

## See also

[`init_project`](https://rgt47.github.io/zzcollab/reference/init_project.md)
for team leads initializing projects
[`set_config`](https://rgt47.github.io/zzcollab/reference/set_config.md)
for setting up configuration defaults
[`team_images`](https://rgt47.github.io/zzcollab/reference/team_images.md)
for checking available team images

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic team project joining
success <- join_project(
  team_name = "mylab",
  project_name = "covid-study"
)

# Using configuration defaults (recommended)
set_config("team_name", "mylab")

# Then join projects easily
join_project(project_name = "new-study")

# Complete workflow for team member
# 1. Clone repository (outside R)
# system("git clone https://github.com/mylab/study.git")
# setwd("study")

# 2. Join project
join_project(team_name = "mylab", project_name = "study")

# 3. Start development (outside R)
# system("make r")  # or make docker-rstudio
} # }
```
