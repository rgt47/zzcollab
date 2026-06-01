#!/bin/bash
##############################################################################
# render-architecture-pdf.sh
#
# PURPOSE: Reproducibly render docs/architecture-diagrams.Rmd to
#          docs/architecture-diagrams.pdf with the Mermaid diagrams
#          rasterized as on-page images.
#
# WHY THIS IS NOT A PLAIN `quarto render`:
#   - The .Rmd uses plain ```mermaid fenced blocks so it renders natively on
#     GitHub. Quarto only rasterizes its executable ```{mermaid} cells, so we
#     transform the fences to cells in a scratch copy before rendering.
#   - Quarto emits explicit \includegraphics[width=..in,height=..in] sized from
#     each PNG's native pixels; the widest C4 / data-flow diagrams reach ~22in
#     and overflow the page. We rewrite those to width=\linewidth,keepaspectratio
#     in the generated LaTeX, then recompile so every diagram fits the margins.
#
# REQUIREMENTS: quarto (>=1.9), a TeX install with lualatex, and a headless
#   browser registered with Quarto: `quarto install chrome-headless-shell`.
#
# USAGE: bash docs/render-architecture-pdf.sh
##############################################################################
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="${script_dir}/architecture-diagrams.Rmd"
out="${script_dir}/architecture-diagrams.pdf"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

cat > "${work}/header.yaml" <<'YAML'
---
title: "zzcollab Architecture Diagrams"
format:
  pdf:
    toc: true
    toc-depth: 2
    geometry:
      - margin=0.75in
    fig-pos: 'H'
    include-in-header:
      text: |
        \usepackage[export]{adjustbox}
---
YAML

# Body: drop the .Rmd's own 7-line YAML header, convert ```mermaid fences to
# Quarto executable ```{mermaid} cells.
sed '1,7d' "${src}" | sed 's/^```mermaid$/```{mermaid}/' > "${work}/body.md"
cat "${work}/header.yaml" "${work}/body.md" > "${work}/diagrams.qmd"

cd "${work}"
quarto render diagrams.qmd --to pdf --no-clean -M keep-tex:true

# Clamp every oversized diagram include to the text width, preserving aspect.
sed -E 's/\\includegraphics\[width=[0-9.]+in,height=[0-9.]+in\]/\\includegraphics[width=\\linewidth,height=0.8\\textheight,keepaspectratio]/g' \
  diagrams.tex > diagrams_fit.tex

lualatex -interaction=nonstopmode diagrams_fit.tex >/dev/null 2>&1 || true
lualatex -interaction=nonstopmode diagrams_fit.tex >/dev/null 2>&1 || true

cp diagrams_fit.pdf "${out}"
echo "Wrote ${out}"
