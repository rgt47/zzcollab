# Trigger Docker image rebuild for zzcollab projects

Rebuilds Docker images for your zzcollab project using the project's
Makefile. This is useful when you've made changes to dependencies,
Dockerfile, or need to incorporate updates from team base images.

## Usage

``` r
rebuild(target = "docker-build")
```

## Arguments

- target:

  Character string specifying the Make target to run. Default is
  "docker-build" which rebuilds the main project image. Other useful
  targets include:

  - "docker-build": Rebuild main Docker image

  - "docker-test": Rebuild and run tests

  - "docker-check": Rebuild and run package checks

  - "docker-clean": Clean up Docker images and containers

## Value

Logical value indicating success (TRUE) or failure (FALSE) of the build.
The function returns TRUE if the make command exits with status 0, FALSE
otherwise.

## Details

This function requires a Makefile to be present in the current working
directory, which is automatically created by zzcollab project
initialization. The function uses the system's make command to execute
the specified target.

Common use cases:

- After adding new R packages to your project

- When team base images have been updated

- After modifying Dockerfile or dependency files

- When containers are behaving unexpectedly

## See also

[`status`](https://rgt47.github.io/zzcollab/reference/status.md) for
checking container status
[`sync_env`](https://rgt47.github.io/zzcollab/reference/sync_env.md) for
syncing R package environment

## Examples

``` r
if (FALSE) { # \dontrun{
# Rebuild the main Docker image
if (rebuild()) {
  message("Docker image rebuilt successfully")
} else {
  message("Docker build failed - check console output")
}

# Rebuild and run tests
rebuild("docker-test")

# Clean up and rebuild
rebuild("docker-clean")
rebuild("docker-build")
} # }
```
