# ZZCOLLAB Workflow Type System
*2026-05-31*

## Status: Removed

The multi-workflow-type system described in earlier revisions of this
document was removed during the 2026-05 simplification refactor. It no
longer exists in the codebase, and this note is retained only so that
references to the old system resolve to an explanation rather than a
broken link.

### What was removed

The previous system attempted to select one of several CI/CD workflow
templates automatically, based on a `workflow_type` field declared per
Docker profile. It included:

- An installer script (`scripts/install-workflows.sh`) that read enabled
  profiles and copied a matching workflow into `.github/workflows/`.
- Four workflow templates: `r-package-dev.yml`, `r-package-analysis.yml`,
  `r-package-blog.yml`, and `r-package-shiny.yml`.
- A large profile matrix (`ubuntu_*`, `alpine_*`, and similar) whose
  entries each carried a `workflow_type` mapping.

These mechanisms added configuration surface and maintenance cost without
a corresponding benefit; most projects used a single workflow and edited
it by hand regardless.

### What replaces it

Projects now ship two GitHub Actions templates directly, with no selection
layer:

- `r-package.yml`, which builds the image, restores packages from
  `renv.lock`, validates dependencies, and runs the test suite.
- `render-report.yml`, which renders the manuscript or report.

Environment selection is handled by the Docker profile system rather than
by a workflow-type field. There are four built-in profiles: `minimal`
(rocker/r-ver), `tidyverse` (rocker/tidyverse; formerly named `analysis`,
which is retained as a deprecated alias), `rstudio` (rocker/rstudio), and
`publishing` (rocker/verse; manuscript rendering). Other environments are
obtained with `zzcollab docker --base-image <image>` (for example
rocker/geospatial or bioconductor/bioconductor_docker). Profiles are
defined in `templates/bundles.yaml`.

---

*Part of ZZCOLLAB: Reproducible Research Compendium Framework*
