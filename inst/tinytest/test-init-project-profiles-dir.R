library(tinytest)

# Regression tests for init_project() defects F2 (scaffolded the session
# working directory, ignored project_name, wrote user config before the
# scaffold) and F3 (profile whitelist disagreed with the CLI and
# templates/bundles.yaml). A stub 'zzcollab' on PATH records each call and
# the directory it ran in, so no real CLI, config, or docker is touched.

if (.Platform$OS.type == 'windows') {
  exit_file('stub CLI is a POSIX shell script')
}

ns <- asNamespace('zzcollab')
profiles <- get0('zzcollab_profiles', envir = ns, inherits = FALSE)
aliases <- get0('zzcollab_profile_aliases', envir = ns, inherits = FALSE)
cache <- get('.zzcollab_cache', envir = ns)

# Profiles the CLI accepts (bundles.yaml plus the 'analysis' alias). Kept
# literal so the behavioral checks do not depend on package internals.
cli_set <- c('minimal', 'tidyverse', 'rstudio', 'publishing', 'analysis')

stub_dir <- tempfile('zzstub')
dir.create(stub_dir)
writeLines(c(
  '#!/bin/sh',
  'printf \'%s|%s\\n\' "$(pwd -P)" "$*" >> "$ZZ_STUB_LOG"',
  'case "$1" in',
  '  config) exit 0 ;;',
  '  *) exit "${ZZ_STUB_FAIL:-0}" ;;',
  'esac'
), file.path(stub_dir, 'zzcollab'))
Sys.chmod(file.path(stub_dir, 'zzcollab'), '0755')

run_init <- function(profile, fail = '0', setup = NULL) {
  work <- normalizePath(tempfile('zzwork'), mustWork = FALSE)
  dir.create(work)
  work <- normalizePath(work)
  log <- file.path(work, 'stub.log')
  if (!is.null(setup)) setup(work)
  old_path <- Sys.getenv('PATH')
  old_wd <- setwd(work)
  on.exit({
    setwd(old_wd)
    Sys.setenv(PATH = old_path)
    Sys.unsetenv(c('ZZ_STUB_LOG', 'ZZ_STUB_FAIL'))
    rm(list = ls(cache), envir = cache)
  })
  rm(list = ls(cache), envir = cache)
  Sys.setenv(PATH = paste(stub_dir, old_path, sep = ':'),
             ZZ_STUB_LOG = log, ZZ_STUB_FAIL = fail)
  value <- tryCatch(
    suppressMessages(suppressWarnings(
      init_project(team_name = 'myteam', project_name = 'demo',
                   profile = profile))),
    error = function(e) e)
  calls <- if (file.exists(log)) readLines(log) else character(0)
  calls <- calls[!grepl('|config list', calls, fixed = TRUE) &
                 !grepl('|config get', calls, fixed = TRUE)]
  list(value = value, calls = calls, work = work,
       demo = file.path(work, 'demo'), wd_after = getwd())
}

call_dirs <- function(calls) sub('\\|.*$', '', calls)
call_args <- function(calls) sub('^[^|]*\\|', '', calls)

# F3: every CLI profile and the deprecated alias is accepted and passed
# through unchanged to 'zzcollab <profile>'.
for (p in cli_set) {
  r <- run_init(p)
  expect_true(isTRUE(r$value),
              info = paste('F3: init_project accepts CLI profile', p))
  expect_true(p %in% call_args(r$calls),
              info = paste('F3: zzcollab', p, 'is invoked'))
}

expect_identical(sort(c(profiles, names(aliases))),
                 sort(cli_set),
                 info = 'F3: R profile set matches the CLI set')
expect_identical(formals(init_project)$profile, 'tidyverse',
                 info = 'F3: default profile is canonical, not the alias')

r <- run_init('bogus')
expect_true(inherits(r$value, 'error') &&
              grepl('Invalid profile', conditionMessage(r$value)),
            info = 'F3: unknown profile is rejected')
expect_equal(length(r$calls), 0,
             info = 'F3: unknown profile reaches no CLI command')

# F2: the scaffold runs inside a new ./<project_name> directory, the session
# working directory is restored, and config is written after the scaffold.
r <- run_init('minimal')
scaffold_idx <- which(call_args(r$calls) == 'minimal')
config_idx <- grep('^config set', call_args(r$calls))
expect_true(dir.exists(r$demo),
            info = 'F2: project_name directory is created')
expect_identical(call_dirs(r$calls)[scaffold_idx],
                 normalizePath(r$demo, mustWork = FALSE),
                 info = 'F2: scaffold runs inside project_name directory')
expect_identical(r$wd_after, r$work,
                 info = 'F2: session working directory is unchanged')
expect_equal(length(config_idx), 2,
             info = 'F2: dockerhub and github accounts are recorded')
expect_true(length(scaffold_idx) == 1 && all(config_idx > scaffold_idx),
            info = 'F2: config is written only after the scaffold')

# F2: a failed scaffold leaves user config untouched and removes the empty
# directory this call created.
r <- run_init('minimal', fail = '1')
expect_false(isTRUE(r$value),
             info = 'F2: failed scaffold returns FALSE')
expect_equal(length(grep('^config set', call_args(r$calls))), 0,
             info = 'F2: failed scaffold writes no config')
expect_false(dir.exists(r$demo),
             info = 'F2: empty directory created by a failed call is removed')

# F2: an existing non-empty directory is refused before any CLI call.
r <- run_init('minimal', setup = function(work) {
  dir.create(file.path(work, 'demo'))
  writeLines('keep', file.path(work, 'demo', 'existing.txt'))
})
expect_true(inherits(r$value, 'error') &&
              grepl('not empty', conditionMessage(r$value)),
            info = 'F2: non-empty project_name directory is refused')
expect_equal(length(r$calls), 0,
             info = 'F2: refused call issues no scaffold or config command')
expect_true(file.exists(file.path(r$demo, 'existing.txt')),
            info = 'F2: existing directory contents are left intact')

# F2: an existing empty directory is used.
r <- run_init('minimal', setup = function(work) {
  dir.create(file.path(work, 'demo'))
})
expect_true(isTRUE(r$value),
            info = 'F2: existing empty project_name directory is accepted')
expect_identical(call_dirs(r$calls)[call_args(r$calls) == 'minimal'],
                 normalizePath(r$demo, mustWork = FALSE),
                 info = 'F2: scaffold runs inside the existing empty directory')

# F3 drift guard: the R profile set must match templates/bundles.yaml and
# the CLI dispatcher. templates/ is excluded from the built package, so this
# runs only from a source checkout (not under R CMD check).
src_root <- normalizePath(file.path('..', '..'), mustWork = FALSE)
bundles <- file.path(src_root, 'templates', 'bundles.yaml')
cli <- file.path(src_root, 'zzcollab.sh')
if (file.exists(bundles) && file.exists(cli)) {
  lines <- readLines(bundles)
  block <- lines[(grep('^profiles:', lines) + 1):length(lines)]
  top_level <- grep('^[^[:space:]#]', block)
  if (length(top_level) > 0) {
    block <- block[seq_len(top_level[1] - 1)]
  }
  yaml_profiles <- sub('^  ([A-Za-z0-9_-]+):.*$', '\\1',
                       grep('^  [A-Za-z0-9_-]+:', block, value = TRUE))
  expect_identical(sort(profiles), sort(yaml_profiles),
                   info = 'F3: zzcollab_profiles matches bundles.yaml')

  cli_lines <- readLines(cli)
  anchor <- grep('Profile names as standalone commands', cli_lines)
  dispatch <- grep('^[[:space:]]+[a-z|]+\\)[[:space:]]*$', cli_lines,
                   value = TRUE)
  dispatch <- dispatch[grep('^[[:space:]]+[a-z|]+\\)[[:space:]]*$',
                            cli_lines) > anchor[1]][1]
  cli_profiles <- strsplit(gsub('[[:space:])]', '', dispatch), '|',
                           fixed = TRUE)[[1]]
  expect_identical(sort(c(profiles, names(aliases))), sort(cli_profiles),
                   info = 'F3: R profiles match the CLI profile dispatcher')
}
