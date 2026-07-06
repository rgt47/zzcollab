library(tinytest)

# All tests in this file use local_mocked_bindings, which is a testthat-only
# function. Load it explicitly; exit cleanly if testthat is not available
# (this is the case in R CMD check via test_package()).
if (!requireNamespace("testthat", quietly = TRUE)) {
  exit_file("testthat not available -- all tests use local_mocked_bindings")
}

# init_project validates required parameters
# Ensure no ambient team_name config leaks in and satisfies the requirement
testthat::local_mocked_bindings(
  get_config_default = function(...) NULL,
  .package = "zzcollab"
)

# team_name is required (from parameter or config)
expect_error(
  init_project(project_name = "test"),
  "team_name.*required"
)

# project_name is required
expect_error(
  init_project(team_name = "test"),
  "project_name.*required"
)

# init_project constructs current-model commands
calls <- character(0)
testthat::local_mocked_bindings(
  find_zzcollab_script = function() "zzcollab",
  get_config_default = function(...) NULL,
  safe_system = function(command, ...) {
    calls[[length(calls) + 1]] <<- command
    0L
  },
  .package = "zzcollab"
)

result <- init_project(team_name = "myteam", project_name = "myproj",
                       profile = "analysis")
expect_true(result)

# DockerHub account is set via the config command, not legacy -t/-p flags.
expect_true(any(grepl("config set dockerhub-account", calls, fixed = TRUE) &
                grepl("myteam", calls, fixed = TRUE)))
expect_true(any(grepl("zzcollab analysis", calls, fixed = TRUE)))
expect_false(any(grepl("-t myteam|-p myproj|--use-team-image|--github-account", calls)))

# init_project sets github account when provided
calls <- character(0)
testthat::local_mocked_bindings(
  find_zzcollab_script = function() "zzcollab",
  safe_system = function(command, ...) {
    calls[[length(calls) + 1]] <<- command
    0L
  },
  .package = "zzcollab"
)

init_project(team_name = "myteam", project_name = "myproj",
             github_account = "myuni")
expect_true(any(grepl("config set github-account", calls, fixed = TRUE) &
                grepl("myuni", calls, fixed = TRUE)))

# join_project validates required parameters
testthat::local_mocked_bindings(
  get_config_default = function(...) NULL,
  .package = "zzcollab"
)

expect_error(
  join_project(project_name = "test"),
  "team_name.*required"
)

expect_error(
  join_project(team_name = "test"),
  "project_name.*required"
)

# join_project builds the image via make docker-build
calls <- character(0)
testthat::local_mocked_bindings(
  safe_system = function(command, ...) {
    calls[[length(calls) + 1]] <<- command
    0L
  },
  .package = "zzcollab"
)

tmp <- file.path(tempdir(), "join_with_makefile")
dir.create(tmp, showWarnings = FALSE)
file.create(file.path(tmp, "Makefile"))
old <- setwd(tmp)
on.exit(setwd(old), add = TRUE)

result <- join_project(team_name = "myteam", project_name = "myproj")
expect_true(result)
expect_true(any(grepl("make docker-build", calls, fixed = TRUE)))
expect_false(any(grepl("--use-team-image|-t myteam", calls)))

setwd(old)

# join_project errors without a Makefile
tmp <- file.path(tempdir(), "join_without_makefile")
dir.create(tmp, showWarnings = FALSE)
unlink(file.path(tmp, "Makefile"))
old <- setwd(tmp)
on.exit(setwd(old), add = TRUE)

expect_error(
  join_project(team_name = "myteam", project_name = "myproj"),
  "No Makefile"
)

setwd(old)

# setup_project routes through the docker subcommand
calls <- character(0)
testthat::local_mocked_bindings(
  find_zzcollab_script = function() "zzcollab",
  safe_system = function(command, ...) {
    calls[[length(calls) + 1]] <<- command
    0L
  },
  .package = "zzcollab"
)

expect_true(setup_project())
expect_true(any(grepl("zzcollab docker", calls, fixed = TRUE)))

calls <- character(0)
expect_true(setup_project(base_image = "rocker/rstudio"))
expect_true(any(grepl("zzcollab docker --base-image rocker/rstudio",
                      calls, fixed = TRUE)))

# init_project accepts a profile parameter
expect_true("profile" %in% names(formals(init_project)))

# join_project no longer accepts interface parameter
formals_names <- names(formals(join_project))
expect_false("interface" %in% formals_names)

# team_images parses docker output into a data frame
testthat::local_mocked_bindings(
  safe_system = function(command, ...) {
    c("myteam/proj1\tlatest\t1.2GB\t2026-01-01",
      "myteam/proj2\tv2\t900MB\t2026-02-02")
  },
  .package = "zzcollab"
)

df <- team_images()
expect_true(inherits(df, "data.frame"))
expect_equal(nrow(df), 2)
expect_equal(df$repository, c("myteam/proj1", "myteam/proj2"))
expect_equal(df$tag, c("latest", "v2"))
expect_equal(df$size, c("1.2GB", "900MB"))
expect_equal(df$created, c("2026-01-01", "2026-02-02"))

# team_images returns an empty data frame when no images exist
testthat::local_mocked_bindings(
  safe_system = function(command, ...) character(0),
  .package = "zzcollab"
)

df <- team_images()
expect_true(inherits(df, "data.frame"))
expect_equal(nrow(df), 0)

# team_images tolerates a short (malformed) row without erroring
testthat::local_mocked_bindings(
  safe_system = function(command, ...) "onlyrepo\tlatest",
  .package = "zzcollab"
)

df <- team_images()
expect_true(inherits(df, "data.frame"))
expect_equal(df$repository, "onlyrepo")
expect_true(is.na(df$size))
