# Tests for project initialization and management functions

test_that("init_project validates required parameters", {
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
})

test_that("init_project constructs current-model commands", {
  calls <- character(0)
  local_mocked_bindings(
    find_zzcollab_script = function() "zzcollab",
    safe_system = function(command, ...) {
      calls[[length(calls) + 1]] <<- command
      0L
    },
    .package = "zzcollab"
  )

  result <- init_project(team_name = "myteam", project_name = "myproj",
                         profile = "analysis")
  expect_true(result)

  # DockerHub account is set via the config command, not legacy -t/-p flags
  expect_true(any(grepl("config set dockerhub-account myteam", calls)))
  # Compendium is scaffolded via the profile quickstart
  expect_true(any(grepl("zzcollab analysis", calls, fixed = TRUE)))
  # Removed flags must not reappear
  expect_false(any(grepl("-t myteam|-p myproj|--use-team-image|--github-account", calls)))
})

test_that("init_project sets github account when provided", {
  calls <- character(0)
  local_mocked_bindings(
    find_zzcollab_script = function() "zzcollab",
    safe_system = function(command, ...) {
      calls[[length(calls) + 1]] <<- command
      0L
    },
    .package = "zzcollab"
  )

  init_project(team_name = "myteam", project_name = "myproj",
               github_account = "myuni")
  expect_true(any(grepl("config set github-account myuni", calls)))
})

test_that("join_project validates required parameters", {
  # team_name is required
  expect_error(
    join_project(project_name = "test"),
    "team_name.*required"
  )

  # project_name is required
  expect_error(
    join_project(team_name = "test"),
    "project_name.*required"
  )
})

test_that("join_project builds the image via make docker-build", {
  calls <- character(0)
  local_mocked_bindings(
    safe_system = function(command, ...) {
      calls[[length(calls) + 1]] <<- command
      0L
    },
    .package = "zzcollab"
  )

  # join_project requires a Makefile in the working directory
  tmp <- file.path(tempdir(), "join_with_makefile")
  dir.create(tmp, showWarnings = FALSE)
  file.create(file.path(tmp, "Makefile"))
  old <- setwd(tmp)
  on.exit(setwd(old), add = TRUE)

  result <- join_project(team_name = "myteam", project_name = "myproj")
  expect_true(result)
  expect_true(any(grepl("make docker-build", calls, fixed = TRUE)))
  # Removed flags must not reappear
  expect_false(any(grepl("--use-team-image|-t myteam", calls)))
})

test_that("join_project errors without a Makefile", {
  tmp <- file.path(tempdir(), "join_without_makefile")
  dir.create(tmp, showWarnings = FALSE)
  unlink(file.path(tmp, "Makefile"))
  old <- setwd(tmp)
  on.exit(setwd(old), add = TRUE)

  expect_error(
    join_project(team_name = "myteam", project_name = "myproj"),
    "No Makefile"
  )
})

test_that("setup_project handles optional parameters", {
  # Should work with no parameters (uses defaults)
  result <- tryCatch({
    setup_project()
  }, error = function(e) {
    expect_true(grepl("zzcollab.*script", e$message, ignore.case = TRUE))
    FALSE
  })

  expect_type(result, "logical")

  # Should accept base_image parameter
  result <- tryCatch({
    setup_project(base_image = "rocker/rstudio")
  }, error = function(e) {
    expect_true(grepl("zzcollab.*script", e$message, ignore.case = TRUE))
    FALSE
  })

  expect_type(result, "logical")
})

test_that("init_project accepts a profile parameter", {
  expect_true("profile" %in% names(formals(init_project)))
})

test_that("join_project no longer accepts interface parameter", {
  # Verify interface parameter was removed (breaking change)
  formals_names <- names(formals(join_project))
  expect_false("interface" %in% formals_names)
})
