# zzcollab Workspace Structure

This document defines the standard directory and file structure for a
zzcollab research compendium. The `zzc doctor` command uses this
specification to detect missing, outdated, or misplaced files.

## Directory Layout

```
project/
├── .git/                  # Git repository (zzc git)
├── .github/               # GitHub workflows (zzc github)
│   └── workflows/
│       ├── R-CMD-check.yaml
│       └── docker-build.yaml
├── .zzcollab/             # zzcollab metadata
│   └── manifest.json      # Tracks all generated files
├── R/                     # R package functions
│   └── *.R
├── analysis/              # Analysis scripts and reports
│   ├── data/              # Raw data (never modified)
│   ├── derived/           # Processed data
│   └── *.Rmd / *.qmd      # Analysis documents
├── tests/                 # testthat tests
│   ├── testthat/
│   │   └── test-*.R
│   └── testthat.R
├── man/                   # roxygen2 documentation (generated)
├── vignettes/             # Package vignettes
├── docs/                  # Project documentation
└── renv/                  # renv library cache (local)
    └── library/
```

## Core Files

### Package Infrastructure (zzc init)

| File | Required | Version Stamped | Description |
|:-----|:--------:|:---------------:|:------------|
| `DESCRIPTION` | Yes | No | R package metadata |
| `NAMESPACE` | Yes | No | Package namespace (roxygen2) |
| `LICENSE` | No | No | License file |
| `.Rbuildignore` | Yes | No | Files excluded from R CMD build |

### Reproducibility Layer (zzc renv, zzc docker)

| File | Required | Version Stamped | Description |
|:-----|:--------:|:---------------:|:------------|
| `renv.lock` | Yes | No | Package versions lockfile |
| `.Rprofile` | Yes | **v2.2.0** | renv activation, auto-snapshot |
| `Dockerfile` | Yes | **v2.2.0** | Container definition |
| `.dockerignore` | Yes | No | Files excluded from Docker build |
| `Makefile` | Yes | **v2.2.0** | Development targets |

### Editor/IDE Support

| File | Required | Version Stamped | Owner |
|:-----|:--------:|:---------------:|:------|
| `*.Rproj` | No | No | RStudio |
| `.Rprofile.local` | No | **v1.9.0** | zzvim-R |

### Version Control (zzc git, zzc github)

| File | Required | Version Stamped | Description |
|:-----|:--------:|:---------------:|:------------|
| `.gitignore` | Yes | No | Git ignore patterns |
| `.git/` | Yes | No | Git repository |

## Version Stamps

zzcollab embeds version stamps in generated files to detect staleness.
The stamp format is:

```
# zzcollab <filename> v<major>.<minor>.<patch>
```

Example stamps:
```bash
# zzcollab Makefile v2.2.0      # Line 1 of Makefile
# zzcollab .Rprofile v2.2.0     # Line 2 of .Rprofile
# zzcollab Dockerfile v2.2.0   # Line 2 of Dockerfile
```

Third-party tools use a similar format:
```bash
# zzvim-R .Rprofile.local v1.9.0
```

The current template version is defined in `lib/constants.sh`:
```bash
ZZCOLLAB_TEMPLATE_VERSION="2.2.0"
```

## Doctor Checks

`zzc doctor` performs the following checks:

### 1. Required Files

Check that required files exist:

- `DESCRIPTION` - Package metadata
- `renv.lock` - Package lockfile
- `.Rprofile` - R profile
- `Makefile` - Build targets
- `Dockerfile` - Container definition
- `.gitignore` - Git ignore patterns

### 2. Directory Structure

Check that required directories exist:

- `R/` - Package functions
- `analysis/` - Analysis documents

Optional directories (warnings only):

- `tests/testthat/` - Test files
- `man/` - Documentation
- `.zzcollab/` - Metadata directory

### 3. Version Stamp Freshness

For each stamped file, compare embedded version against current
`ZZCOLLAB_TEMPLATE_VERSION`:

| Status | Meaning |
|:-------|:--------|
| `(current)` | Version matches |
| `(outdated)` | Version is older than current |
| `(no stamp)` | File exists but has no version stamp |

### 4. Manifest Integrity (planned)

If `.zzcollab/manifest.json` exists, verify:

- All tracked files still exist
- No orphaned files from partial operations

## File Ownership

Different tools own different files:

| Owner | Files |
|:------|:------|
| zzcollab | Makefile, .Rprofile, Dockerfile, .dockerignore |
| zzcollab (init) | DESCRIPTION, NAMESPACE, .Rbuildignore, .gitignore |
| renv | renv.lock, renv/ |
| zzvim-R | .Rprofile.local |
| roxygen2 | man/, NAMESPACE (regenerated) |
| User | R/, analysis/, tests/, docs/, vignettes/ |

## Migration Notes

### Pre-stamp Workspaces

Workspaces created before version stamping (pre-v2.1.0) will show
`(no stamp)` for all template files. This is expected. Running
`zzc docker` with the update prompt will regenerate files with
current stamps.

### Makefile Customizations

The Makefile does not yet support a `Makefile.local` separation.
User-added targets will be lost if the Makefile is regenerated.
Before updating, review custom targets and re-add them after.

See `docs/versioning-design.md` for the full versioning architecture.
