#!/usr/bin/env bash
## tools/render.sh
##
## Render a document to a PDF stamped with a provenance footer:
## the source file and the time of rendering, laid out by
## tools/stamp.tex. The script dispatches by file extension so
## that one command serves all three toolchains:
##
##   .Rmd   rmarkdown, by way of tools/stamp-render.R
##   .qmd   quarto, with the stamp passed through a metadata file
##   .md    pandoc, with the stamp passed through include-in-header
##
## For a multi-document Quarto project the cleaner wiring is a
## pre-render script in _quarto.yml; see tools/README.md. This
## script is the single-file convenience.
##
## Usage:
##   bash tools/render.sh <document.Rmd|.qmd|.md>
##
## Vendored by zzcollab; this file is not project-specific.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <document.Rmd|.qmd|.md>" >&2
  exit 1
fi

input="$1"
if [[ ! -f "$input" ]]; then
  echo "error: file not found: $input" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp_tex="$script_dir/stamp.tex"
values_tex="$script_dir/.stamp-values.tex"
input_dir="$(cd "$(dirname "$input")" && pwd)"
abs_input="$input_dir/$(basename "$input")"

## Display the source path with a leading tilde for the home
## directory. The tilde is placed inside a double-quoted string so
## that it is not re-expanded back to an absolute path.
case "$abs_input" in
  "$HOME"/*) display_src="~${abs_input#"$HOME"}" ;;
  *)         display_src="$abs_input" ;;
esac
render_time="$(date '+%Y-%m-%d %H:%M %Z')"

## Write the generated values file consumed by stamp.tex. The
## source path is wrapped in \detokenize so that underscores and
## other LaTeX-special characters in the path typeset literally.
write_values() {
  {
    printf '\\renewcommand{\\stampsource}{\\detokenize{%s}}\n' \
      "$display_src"
    printf '\\renewcommand{\\stamptime}{%s}\n' "$render_time"
  } > "$values_tex"
}

case "$input" in
  *.Rmd|*.rmd)
    ## stamp-render.R computes the values itself and appends the
    ## header files through rmarkdown.
    Rscript -e \
      "source('$script_dir/stamp-render.R')\$value('$abs_input')"
    ;;
  *.qmd)
    write_values
    meta_yml="$script_dir/.stamp-meta.yml"
    trap 'rm -f "$values_tex" "$meta_yml"' EXIT
    {
      echo 'include-in-header:'
      echo "  - $stamp_tex"
      echo "  - $values_tex"
    } > "$meta_yml"
    quarto render "$abs_input" --to pdf --metadata-file "$meta_yml"
    ;;
  *.md)
    write_values
    trap 'rm -f "$values_tex"' EXIT
    pandoc "$abs_input" -o "${abs_input%.*}.pdf" \
      --pdf-engine=xelatex \
      --include-in-header="$stamp_tex" \
      --include-in-header="$values_tex"
    ;;
  *)
    echo "error: unsupported extension (need .Rmd, .qmd, .md): $input" >&2
    exit 3
    ;;
esac

echo "stamped PDF rendered: $display_src" >&2
