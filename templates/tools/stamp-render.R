## tools/stamp-render.R
##
## Render an R Markdown document to a PDF stamped with a
## provenance footer: the source file and the time of rendering.
## The footer layout is defined in tools/stamp.tex; this script
## fills in the two values and appends both files to the pandoc
## invocation, leaving the document's own YAML untouched.
##
## Wire it into a document by adding to the YAML header:
##
##   knit: (function(input, ...) source(file.path(
##     rprojroot::find_root(rprojroot::has_file('DESCRIPTION')),
##     'tools', 'stamp-render.R'))$value(input))
##
## RStudio's Knit button, rmarkdown::render(), and a Makefile
## target all honour the knit: field, so each route yields a
## stamped PDF. tools/render.sh calls this script for .Rmd input.
##
## Vendored by zzcollab; this file is not project-specific.

stamp_render <- function(input, encoding = 'UTF-8', ...) {
  input <- normalizePath(input, mustWork = TRUE)

  ## Locate the vendored tools/ directory by walking up from the
  ## document until tools/stamp.tex is found. This keeps the
  ## script free of any dependency on here:: or rprojroot.
  tools_dir <- local({
    d <- dirname(input)
    repeat {
      if (file.exists(file.path(d, 'tools', 'stamp.tex'))) {
        return(file.path(d, 'tools'))
      }
      parent <- dirname(d)
      if (identical(parent, d)) {
        stop('stamp_render(): tools/stamp.tex not found above ',
             input, call. = FALSE)
      }
      d <- parent
    }
  })

  ## Provenance values. The source path is shown with a leading
  ## tilde for the home directory; the time is local.
  home <- normalizePath('~', mustWork = FALSE)
  src  <- if (startsWith(input, home)) {
    paste0('~', substring(input, nchar(home) + 1L))
  } else {
    input
  }
  stamp_time <- format(Sys.time(), '%Y-%m-%d %H:%M %Z')

  ## Write the generated values file. The source path is wrapped
  ## in \detokenize so that underscores and other LaTeX-special
  ## characters in the path typeset literally.
  values_tex <- file.path(tools_dir, '.stamp-values.tex')
  writeLines(c(
    sprintf('\\renewcommand{\\stampsource}{\\detokenize{%s}}', src),
    sprintf('\\renewcommand{\\stamptime}{%s}', stamp_time)),
    values_tex)
  on.exit(unlink(values_tex), add = TRUE)

  ## Render, appending both header files so the document's own
  ## YAML includes are preserved rather than overridden.
  rmarkdown::render(
    input, encoding = encoding, envir = new.env(), ...,
    output_options = list(pandoc_args = c(
      '--include-in-header', file.path(tools_dir, 'stamp.tex'),
      '--include-in-header', values_tex)))
}

## Sourcing this file returns the function, so a YAML knit: hook
## may call source(...)$value(input).
stamp_render
