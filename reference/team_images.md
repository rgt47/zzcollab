# List available zzcollab team Docker images

Retrieves information about team Docker images that have been created
for zzcollab projects. Team images are base images that contain
pre-installed packages and configurations shared across team members.

## Usage

``` r
team_images()
```

## Value

Data frame with columns:

- `repository`: Docker repository name (e.g., "myteam/projectcore")

- `tag`: Image tag (e.g., "latest", "v1.0.0")

- `size`: Image size (e.g., "2.5GB")

- `created`: Creation timestamp Returns empty data frame if no team
  images are found.

## Details

This function searches for Docker images with the 'zzcollab.team' label,
which is automatically applied to team base images created during
project initialization. Team images are typically named following the
pattern: teamname/projectnamecore-variant:tag

Team images serve as the foundation for individual development
environments, ensuring all team members work with identical package
versions and system configurations.

## See also

[`init_project`](https://rgt47.github.io/zzcollab/reference/init_project.md)
for creating team images
[`status`](https://rgt47.github.io/zzcollab/reference/status.md) for
checking running containers

## Examples

``` r
if (FALSE) { # \dontrun{
# List all available team images
images <- team_images()
if (nrow(images) > 0) {
  print(images)
} else {
  cat("No team images available\n")
}

# Check for specific team's images
images <- team_images()
myteam_images <- images[grepl("myteam", images$repository), ]
print(myteam_images)
} # }
```
