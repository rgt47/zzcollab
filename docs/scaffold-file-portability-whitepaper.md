# Scaffold File Portability: Static versus Repo-Specific

*2026-07-05 09:31 PDT*

## Abstract

This paper classifies every file produced by `zzc init` (the zzcollab scaffold)
according to whether it is static across repositories or carries repository-
specific information. The classification is derived empirically: two projects
were scaffolded with the publishing profile under identical configuration, and
every generated file was compared byte for byte. The result identifies the
substitution axes that actually vary a scaffold, which in turn tells a fleet
migration which files can be copied verbatim and which require per-repository
attention.

## Method

Two projects, named `alpharepo` and `betarepo`, were scaffolded with
`zzc init --archetype analysis` followed by
`zzc docker --profile publishing`, under a single user configuration
(`~/.zzcollab/config.yaml`) and a fixed Posit Package Manager snapshot
(2026-06-29). Each generated file was compared between the two projects. A file
that is identical is static with respect to the project name; a file that
differs isolates exactly which token varies. Configuration-driven fields (author,
licence holder) are constant within one author's fleet by construction, so they
appear identical here and are classified separately as author-constant rather
than static.

## Classification

### 1. Static: byte-identical across any repository

These files carry no per-repository information. Where they reference the
project at all, they do so through runtime derivation rather than a hardcoded
value. They may be copied verbatim within a profile and template-version cohort.

| File | Basis for staticness |
| --- | --- |
| `.github/workflows/r-package.yml` | Derives the package name at runtime |
| `.github/workflows/render-report.yml` | Discovers `report.Rmd` dynamically |
| `Makefile` | `PACKAGE_NAME := $(shell basename $(CURDIR))` |
| `.Rprofile` | Environment-resolved repositories; no substitution |
| `.gitignore`, `.Rbuildignore` | Fixed ignore lists |
| `.zzcollab` | Marker file |
| `docs/ZZCOLLAB_USER_GUIDE.md` | Shipped documentation |
| `analysis/templates/statistics-in-medicine.csl` | Citation style |
| `inst/tinytest/test-basic.R` | Boilerplate placeholder (`expect_true(TRUE)`) |
| `NAMESPACE` | Empty roxygen stub |

### 2. Static by seed: empty template now, repository-specific once populated

These are identical as shipped because they are empty or seed forms. They become
repository-specific as the researcher adds content.

| File | Seed to real content |
| --- | --- |
| `renv.lock` | Seed lock to the project's pinned dependency closure |
| `analysis/report/references.bib` | Empty to bibliography |
| `analysis/data/README.md` | Template to data documentation |

### 3. Author-constant: identical within one author's fleet

These are driven by the resolved configuration. They are constant across all of
one author's repositories and differ only across authors.

| File | Driver |
| --- | --- |
| `LICENSE` | Copyright holder (configuration author) |

A note on `zzcollab.yaml`. An earlier draft placed `zzcollab.yaml` here, on the
strength of the two-scaffold comparison, in which the file was identical. That
comparison used `ZZCOLLAB_ACCEPT_DEFAULTS`, which never sets a `team_name`, and
so masked a repository-specific field. A real project's `zzcollab.yaml` carries
`defaults.team_name` derived from the project name (for example
`peng1_team`) and a `defaults.archetype` that can legitimately differ per
repository. The file is therefore mixed rather than author-constant: only
`docker.default_profile` is worth propagating across a fleet, and it should be
set with a targeted `zzc config set-local docker.default_profile <profile>`
rather than by copying the file, which would overwrite the per-repository
`team_name` and `archetype`. This is a caution about the method: a
defaults-only scaffold understates the per-repository fields that interactive
initialisation fills in.

### 4. Repository-specific: package name substituted at scaffold time

The package name is the single substitution axis that varies these files at
creation.

| File | Substituted token |
| --- | --- |
| `DESCRIPTION` | `Package:`, `Title:`, `Authors@R` |
| `CITATION.cff` | `title:`, authors |
| `analysis/report/report.Rmd` | `library(<pkg>)` |
| `tests/tinytest.R` | `test_package("<pkg>")` |
| `.devcontainer/devcontainer.json` | `name`, `image` |

A caution on `DESCRIPTION` and `report.Rmd`. The substitution axis is not the
whole story for these two. In a mature repository they also accumulate genuine
research content: `DESCRIPTION` carries the real `Title` and the one-paragraph
`Description` abstract, and the actual `Imports`/`Suggests` dependency set with
its role split; `report.Rmd` carries the manuscript body. The scaffold ships
them as generic seeds, but a migration must treat them like the static-by-seed
files (`renv.lock`, `references.bib`): edit surgically and preserve the content,
never overwrite from the template. Regenerating `DESCRIPTION` from the template
would replace a real methodological title and abstract with
`<pkg> Data Analysis` and wipe every dependency declaration; the correct action
is a targeted edit (fix roles, drop a stale `renv` import) that leaves the title,
abstract, and real dependencies intact.

### 5. Generated metadata: per-build variation

These vary by build timestamp, content-addressed digest, or resolved closure
rather than by project name. In the controlled comparison the three files below
differed only by a one-second `generated` or `created` timestamp; their other
variation appears across real projects, not across two same-day scaffolds.

| File | Varies by |
| --- | --- |
| `Dockerfile` | Base-image digest, PPM snapshot date, derived system dependencies, `created` timestamp. The package name is not baked in. |
| `.zzcollab-state` | R version, environment fields, `generated` timestamp |
| `tooling.lock` | Tool versions, `generated` timestamp |

## Discussion

Two axes account for essentially all scaffold variation. The package name
substitutes into five files at creation time, and the configuration author
substitutes into the licence, the configuration snapshot, and the author fields
of `DESCRIPTION` and `CITATION.cff`. Every remaining file is either static or
resolved at runtime.

Three consequences follow for a fleet migration.

- The infrastructure layer is static. The `Makefile`, the `.Rprofile`, and both
  GitHub Actions workflows are byte-identical across repositories because they
  derive the package name at runtime rather than embedding it. Regenerating them
  from the current template is correct but equivalent to a verbatim copy;
  `doctor --force` performs the regeneration, and a plain copy would produce the
  same bytes.
- The only genuinely generated per-repository file is the `Dockerfile`, and it
  does not carry the package name. Its variation is confined to the base-image
  digest, the PPM snapshot date, and the derived system dependencies. This is
  why the reconciled generator can produce a Dockerfile that is identical across
  repositories that share a profile, base image, and snapshot.
- Two files that this classification labels static nonetheless require per-
  repository work during migration: `inst/tinytest/test-basic.R`, a placeholder
  test that should be replaced with real tests, and `renv.lock`, a seed that must
  be regrown to the project's actual closure. These are exactly the two manual
  steps observed when migrating a representative compendium.

## Conclusion

For a single author migrating a fleet of compendia, the scaffold reduces to a
small, well-bounded set of variables: the package name in five files, the author
in four, a seed lock and a seed bibliography to populate, and a single generated
`Dockerfile` whose only per-repository inputs are the base digest, the snapshot
date, and the derived system dependencies. Everything else can be treated as
static within a profile and template-version cohort.

---

*Source: ~/prj/sfw/07-zzcollab/zzcollab/docs/scaffold-file-portability-whitepaper.md*
