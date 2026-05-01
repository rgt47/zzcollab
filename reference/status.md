# Check Docker container status for zzcollab projects

This function checks for running Docker containers that have the
'zzcollab' label. It's useful for monitoring your development
environment and seeing which containers are currently active for your
research projects.

## Usage

``` r
status()
```

## Value

Character vector with container status information in table format. Each
element contains: container name, status, and Docker image. Returns
empty character vector if no zzcollab containers are running.

## Details

The function uses Docker's filtering capabilities to find containers
with the 'zzcollab' label. This label is automatically added to
containers created by the zzcollab framework.

## See also

[`rebuild`](https://rgt47.github.io/zzcollab/reference/rebuild.md) for
rebuilding Docker images
[`team_images`](https://rgt47.github.io/zzcollab/reference/team_images.md)
for listing available team images

## Examples

``` r
if (FALSE) { # \dontrun{
# Check if any zzcollab containers are running
container_status <- status()
if (length(container_status) > 0) {
  cat("Running containers:\n")
  print(container_status)
} else {
  cat("No zzcollab containers currently running\n")
}
} # }
```
