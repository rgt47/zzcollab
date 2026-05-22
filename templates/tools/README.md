# tools/

This directory holds the render-stamp helpers that zzcollab
vendors into every document-rendering compendium. Their single
purpose is to ensure that any PDF produced from this project
carries, in a discreet page footer, a record of the document it
was rendered from and the time it was rendered. We have found
that an unlabelled PDF circulating among collaborators is a
recurring source of confusion, and a footer that names its own
source is the simplest remedy.

## What is here

- `stamp.tex` defines the footer. It is a small LaTeX preamble,
  included at render time, that prints two macros, `\stampsource`
  and `\stamptime`. It carries `\providecommand` defaults so that
  a document still compiles when the values have not been
  supplied.
- `stamp-render.R` is the wrapper for R Markdown. It computes the
  source path and the render time, writes a short generated file
  that fills in the two macros, and renders the document with
  both files appended to the pandoc invocation.
- `render.sh` is the command-line entry point. It dispatches on
  the file extension so that one command stamps `.Rmd`, `.qmd`,
  and `.md` documents alike.

## Why a wrapper

The three toolchains, rmarkdown, Quarto, and a bare pandoc call,
share a common back end: each passes through pandoc and then
LaTeX. We therefore stamp at the layer they have in common, the
LaTeX preamble, rather than solving the problem once per engine.
The source path must be injected at render time because LaTeX
sees only the intermediate `.tex` file and not the original
document.

## Usage

For a one-off render of any supported document:

```
bash tools/render.sh analysis/report/report.Rmd
```

For R Markdown, the more convenient arrangement is to let the
document stamp itself on every render, including from RStudio's
Knit button. Add the following to the YAML header:

```
knit: (function(input, ...) source(file.path(
  rprojroot::find_root(rprojroot::has_file('DESCRIPTION')),
  'tools', 'stamp-render.R'))$value(input))
```

For a multi-document Quarto project, declare a `pre-render`
script in `_quarto.yml` that writes the generated values file,
and add `stamp.tex` together with that file to the PDF format's
`include-in-header`. The `render.sh` route remains available for
single-file Quarto renders.

## Provenance

These files are vendored from the zzcollab templates so that the
compendium builds standalone, without reaching outside the
repository. They are not project-specific; the canonical copies
live in zzcollab, and `zzc tools` will reinstall them. Project-
specific scripts should live alongside them here but are written
per project and are not managed by zzcollab.
