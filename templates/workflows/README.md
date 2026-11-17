# zzcollab GitHub Actions workflow templates

CI/CD workflow templates installed by zzcollab into generated research
projects.

## Installed workflows

### r-package.yml

Validates the project's R package structure and runs its tests on push or
pull request to the main branch. Installed by every project.

### render-report.yml

Renders the project's analysis report to PDF when the report or its inputs
change (and on manual dispatch), uploading the PDF as a build artifact.
Installed from the active report-workflow template
(`get_workflow_template`); the copy in this directory is the fallback.

Installed only when the project has a report (`zzc_has_report` in
`lib/core.sh`): an `.Rmd` or `.qmd` file in `analysis/report/`, a
`report.Rmd` anywhere under `analysis/`, or an `.Rmd` in
`analysis/posts/`. A project with nothing to render does not carry it,
and `zzc doctor` reports a copy found without a report as unneeded.

No other workflow templates are installed; earlier per-paradigm variants
(analysis/manuscript/package) were removed when the framework consolidated
on the single research-compendium structure.
