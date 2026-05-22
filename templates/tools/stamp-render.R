## tools/stamp-render.R
##
## Render a document (.Rmd, .qmd, or .md) to a PDF, stamp a
## provenance footer onto it, and deposit a date-time-version
## stamped copy in the project's share/ directory.
##
## The footer (laid out by tools/stamp.tex) and the staged
## filename are derived from one provenance triple: the source
## document, the render time, and the git version
## (`git describe --tags --always --dirty`). The footer names the
## source document; the staged copy names the artefact.
##
## Wire it into an R Markdown document by adding to the YAML
## header (the hook walks up to find this file, so it needs no
## package):
##
##   knit: (function(input, ...) { d <- dirname(input); while
##     (!file.exists(file.path(d, 'tools', 'stamp-render.R')) &&
##     d != dirname(d)) d <- dirname(d); source(file.path(d,
##     'tools', 'stamp-render.R'))$value(input) })
##
## tools/render.sh calls this script for documents of any of the
## three supported kinds.
##
## Vendored by zzcollab; this file is not project-specific.

## --- helpers -----------------------------------------------------

## Locate the vendored tools/ directory by walking up from `start`
## until tools/stamp.tex is found.
.stamp_find_tools <- function(start) {
  d <- start
  repeat {
    if (file.exists(file.path(d, 'tools', 'stamp.tex'))) {
      return(normalizePath(file.path(d, 'tools')))
    }
    parent <- dirname(d)
    if (identical(parent, d)) {
      stop('stamp-render: tools/stamp.tex not found above ',
           start, call. = FALSE)
    }
    d <- parent
  }
}

## The git version, or 'nogit' when the tree is not a repository.
.stamp_git_version <- function(root) {
  out <- tryCatch(
    system2('git', c('-C', root, 'describe', '--tags',
                     '--always', '--dirty'),
            stdout = TRUE, stderr = FALSE),
    error   = function(e) character(0),
    warning = function(w) character(0))
  if (length(out) == 0L || !nzchar(out[[1]])) 'nogit' else out[[1]]
}

## A path shown with a leading tilde for the home directory.
.stamp_display <- function(path) {
  home <- normalizePath('~', mustWork = FALSE)
  if (startsWith(path, home)) {
    paste0('~', substring(path, nchar(home) + 1L))
  } else {
    path
  }
}

## --- main --------------------------------------------------------

stamp_render <- function(input, encoding = 'UTF-8', ...) {
  input     <- normalizePath(input, mustWork = TRUE)
  ext       <- tolower(tools::file_ext(input))
  tools_dir <- .stamp_find_tools(dirname(input))
  root      <- dirname(tools_dir)
  stamp_tex <- file.path(tools_dir, 'stamp.tex')

  ## Provenance triple: source, time, version.
  now         <- Sys.time()
  src_display <- .stamp_display(input)
  stamp_time  <- format(now, '%Y-%m-%d %H:%M %Z')
  version     <- .stamp_git_version(root)

  ## Generated header redefining the three stamp macros. Written
  ## to a temp file so the repository's tools/ stays clean. The
  ## source and version are wrapped in \detokenize so that LaTeX-
  ## special characters in either typeset literally.
  values_tex <- tempfile(fileext = '.tex')
  on.exit(unlink(values_tex), add = TRUE)
  writeLines(c(
    sprintf('\\renewcommand{\\stampsource}{\\detokenize{%s}}',
            src_display),
    sprintf('\\renewcommand{\\stamptime}{%s}', stamp_time),
    sprintf('\\renewcommand{\\stampversion}{\\detokenize{%s}}',
            version)), values_tex)
  headers <- c(stamp_tex, values_tex)

  ## Render, by engine. Each route appends both header files so
  ## the document's own configuration is preserved.
  pdf <- switch(
    ext,
    rmd = rmarkdown::render(
      input, encoding = encoding, envir = new.env(), ...,
      output_options = list(pandoc_args = c(
        rbind('--include-in-header', headers)))),
    qmd = {
      meta <- tempfile(fileext = '.yml')
      on.exit(unlink(meta), add = TRUE)
      writeLines(c('include-in-header:',
                   paste0('  - ', headers)), meta)
      out <- sub('\\.qmd$', '.pdf', input, ignore.case = TRUE)
      st  <- system2('quarto', c('render', input, '--to', 'pdf',
                                 '--metadata-file', meta))
      if (!isTRUE(st == 0) || !file.exists(out)) {
        stop('stamp-render: quarto render failed for ', input,
             call. = FALSE)
      }
      out
    },
    md = {
      out <- sub('\\.md$', '.pdf', input, ignore.case = TRUE)
      st  <- system2('pandoc', c(
        input, '-o', out, '--pdf-engine=xelatex',
        rbind('--include-in-header', headers)))
      if (!isTRUE(st == 0) || !file.exists(out)) {
        stop('stamp-render: pandoc failed for ', input,
             call. = FALSE)
      }
      out
    },
    stop('stamp-render: unsupported extension .', ext,
         ' (need Rmd, qmd, or md)', call. = FALSE))
  pdf <- normalizePath(pdf)

  ## Stage a stamped copy. The share directory is analysis/report/
  ## share/ when an analysis/report/ tree exists, and a repo-root
  ## share/ otherwise.
  rep_dir <- file.path(root, 'analysis', 'report')
  share   <- if (dir.exists(rep_dir)) {
    file.path(rep_dir, 'share')
  } else {
    file.path(root, 'share')
  }
  dir.create(share, showWarnings = FALSE, recursive = TRUE)

  ## Filename prefix: the document basename, falling back to the
  ## parent directory name when the basename is a generic stub
  ## (so that several report.Rmd files do not collide).
  base    <- tools::file_path_sans_ext(basename(input))
  generic <- c('report', 'index', 'paper', 'manuscript', 'main')
  prefix  <- if (tolower(base) %in% generic) {
    basename(dirname(input))
  } else {
    base
  }
  vsafe       <- gsub('[^A-Za-z0-9._-]', '_', version)
  staged      <- sprintf('%s-%s-%s-%s.pdf', prefix,
                         format(now, '%Y-%m-%d'),
                         format(now, '%H%M'), vsafe)
  staged_path <- file.path(share, staged)
  file.copy(pdf, staged_path, overwrite = TRUE)

  ## Append a manifest row.
  manifest <- file.path(share, 'MANIFEST.md')
  if (!file.exists(manifest)) {
    writeLines(c(
      '# Staged renders', '',
      paste('*Auto-generated by tools/stamp-render.R.',
            'One row per render.*'), '',
      '| Staged PDF | Source | Version | Rendered |',
      '|---|---|---|---|'), manifest)
  }
  cat(sprintf('| `%s` | `%s` | `%s` | %s |\n',
              staged, src_display, version, stamp_time),
      file = manifest, append = TRUE)

  message('stamp-render: staged ', file.path(basename(share),
          staged))
  invisible(pdf)
}

## Sourcing this file returns stamp_render, so a YAML knit: hook
## may call source(...)$value(input).
stamp_render
