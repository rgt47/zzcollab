# zzcollab Extended TODO

*2026-06-02 16:48 PDT*

This document records deferred work following the June 2026 system-review
remediation. P0 through P2 are complete; items below are ordered by priority
within each tier. The source audit is `docs/zzcollab-system-review.pdf`.

---

## P2 remainder — contemporaneity

### 1. `targets` pipeline integration

**What:** Add a `_targets.R` stub and two Makefile targets to the scaffold template.

```makefile
targets:
	docker run --rm -v $(pwd):/home/analyst/project -w /home/analyst/project \
	  $(PACKAGE_NAME) Rscript -e "targets::tar_make()"

targets-vis:
	docker run --rm -v $(pwd):/home/analyst/project -w /home/analyst/project \
	  $(PACKAGE_NAME) Rscript -e "targets::tar_visnetwork()"
```

The `_targets.R` stub should declare `tar_option_set(packages = character(0))`
and a minimal `list()` so the project is targets-ready without imposing a
workflow. Add `targets` to the suggested packages section of the scaffold
DESCRIPTION. The `targets` package must be in `renv.lock` for the Makefile
targets to work inside the container.

**Why:** Dependency-aware skip-the-unchanged execution is the 2024 standard for
non-trivial pipelines. zzcollab projects currently have no hook for it; users
must add it manually.

**Files:** `templates/Makefile`, new `templates/_targets.R`, `modules/project.sh`
(wire `install_template`).

---

### 2. SBOM / attestation

**What:** Add `--sbom=true --provenance=mode=max` to the `docker-push-team`
target in `templates/Makefile`.

```makefile
docker-push-team:
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--sbom=true \
		--provenance=mode=max \
		--tag $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG) \
		--push \
		.
```

This produces a machine-readable SPDX SBOM attached to the image manifest on
Docker Hub. No separate storage is required; `docker buildx imagetools inspect`
can retrieve it.

**Why:** The review (Section 12) notes the absence of SBOM/attestation as a
contemporaneity gap. For journal-submission reproducibility the SBOM provides a
machine-verifiable record of every package in the image.

**Files:** `templates/Makefile` (one block change).

---

### 3. DOI / Zenodo deposition

**What:** A GitHub Actions workflow that deposits a tagged release to Zenodo and
writes the resulting DOI back into `CITATION.cff`.

Skeleton:

```yaml
# .github/workflows/zenodo.yml
on:
  release:
    types: [published]

jobs:
  deposit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>
      - name: Deposit to Zenodo
        env:
          ZENODO_TOKEN: ${{ secrets.ZENODO_TOKEN }}
        run: |
          # Use zenodo_get or the Zenodo REST API to create a deposition,
          # upload the release tarball, and publish.
          # Write the resulting DOI to CITATION.cff.
```

The workflow requires a `ZENODO_TOKEN` repository secret. Document the one-time
setup in the user guide and add a `make zenodo-deposit` target that triggers the
workflow via `gh workflow run`.

**Why:** Without a DOI, zzcollab-scaffolded compendiums cannot be cited as
persistent artifacts. The ORCID field already present in `CITATION.cff` signals
intent; the deposition workflow delivers it.

**Files:** `templates/workflows/zenodo.yml` (new), `templates/Makefile` (new
target), `ZZCOLLAB_USER_GUIDE.md` (setup section).

---

### 4. `rang`-style long-term recovery documentation

**What:** A short guide (`docs/long-term-recovery.md`) explaining how to
reconstruct a zzcollab environment years after publication using only the
committed artifacts, without relying on Docker Hub image availability.

The guide should cover:

- Reading `tooling.lock` to identify the zzrenvcheck tag and PPM snapshot date.
- Using `renv::restore()` against the PPM snapshot URL in `renv.lock` to
  reconstruct the R package library on a host R installation.
- Pulling the base image by digest (from `tooling.lock`) if the Docker tag has
  been overwritten.
- The `rang` package as an alternative for generating a replayable R environment
  specification from `renv.lock`.
- Nix/rix as a content-addressed fallback (see item 5).

**Why:** The review (Section 13) flags the absence of a long-term recovery path.
All the pinning infrastructure is now in place; the documentation is the missing
piece.

**Files:** New `docs/long-term-recovery.md`, reference from README and user guide.

---

### 5. Optional Nix/rix tier (low priority)

**What:** A `flake.nix` or `rix`-generated `default.nix` that provides a
content-addressed R environment as an alternative to the Docker-based workflow.

```r
# In a new zzc command: zzc nix
library(rix)
rix(
  r_ver = "4.4.2",
  r_pkgs = c("tidyverse", "renv"),
  system_pkgs = NULL,
  git_pkgs = NULL,
  ide = "none",
  project_path = "."
)
```

This is genuinely optional — the Docker path covers the overwhelming majority of
use cases. Only pursue if journal submission or HPC workflows require it.

**Why:** Content-addressed environments (Nix store hashes) are the only path to
bit-for-bit reproducibility without a running Docker daemon. The review notes
this as a gap against the 2026 state of the art.

**Files:** New `templates/flake.nix` or rix-based generator in
`modules/docker.sh`, gated behind a `--nix` flag on `zzc analysis`.

---

## P3 — maturity

### 6. Decompose `config.sh`

`modules/config.sh` is 1,400 lines bundling seven responsibilities:

- YAML I/O (`yaml_get`, `yaml_set`, `_load_file`)
- Config loading and precedence (`load_config`)
- Input validation helpers (`validate_email`, `validate_orcid`, etc.)
- Interactive prompts (`prompt_input`, `prompt_validated`, `prompt_select`)
- Init wizard sections (`_setup_basic`, `_setup_advanced`, etc.)
- `config_set` / `config_get` / `config_list` commands
- Identity gate (`config_identity_gate`)

The interactive UI layer (wizard sections + prompt helpers) is the clearest
extraction target — roughly 40% of the file, with no tests. Extract to
`modules/config-interactive.sh`, sourced unconditionally at startup alongside
the other modules.

**Why:** The file is too large to audit, test, or modify safely. The review
(Section 6) flags it explicitly; the P1 config fixes (C-1 through C-5) worked
around the size by making targeted edits.

**Files:** New `modules/config-interactive.sh`, reduced `modules/config.sh`,
update `zzcollab.sh` source block.

---

### 7. Shell coverage measurement

The repository badge claims ~35% coverage but instruments only the R wrapper
(`r-package.yml`). The ~6,500 lines of bash that constitute the actual product
have zero coverage measurement.

**What:**

- Add `kcov` to the CI Docker image used in `shell-tests.yml`.
- Wrap `run_all_tests.sh` with `kcov --include-path=. coverage/ bash ...`.
- Upload the coverage report as a workflow artifact.
- Update the README badge to either display shell coverage separately or remove
  the misleading combined figure.

**Why:** The review (T-7) flags that the 35% badge covers only the R skin.
Without shell coverage, the test suite provides false assurance about the
codebase that matters most.

**Files:** `.github/workflows/shell-tests.yml`, `README.md`.

---

### 8. CRAN decision

The package carries a CRAN submission badge. Two blockers remain from the review:

- **Non-hermetic tests (P-2):** Several tests in `tests/testthat/` shell out to
  live `docker`/`git`/`gh` processes. These must be mocked or gated with
  `skip_if_not(nzchar(Sys.which("docker")))` before `R CMD check` will pass
  consistently in the CRAN environment.
- **Stale-install masking (P-1):** `devtools::test()` runs against whatever is
  installed; a stale install masked 16 failures that the source-under-`load_all`
  did not. The fix (always reinstall before testing, drop `zzcollab::`-qualified
  self-calls in tests) is documented but not implemented.

**Decision required:** Either fix both blockers and submit, or drop the CRAN
badge from README and DESCRIPTION and pursue a different distribution path (e.g.,
r-universe, direct GitHub install).

**Files:** `tests/testthat/` (mock non-hermetic calls), `README.md`,
`DESCRIPTION` (remove `BugReports` / CRAN URL if dropping).

---

### 9. End-to-end scaffold + build + run test

**What:** A single test (bash or R) that:

1. Scaffolds a project in a temp directory (`zzc analysis --no-build`).
2. Builds the Docker image from the generated Dockerfile.
3. Runs a known R script inside the container.
4. Asserts the output matches a known value.

This is the missing integration test called for by the review (Section 14,
item 14). It would have caught the `renv::init`-before-`renv::restore` bug
before it reached users.

**Placement:** `tests/integration/test-scaffold-build-run.sh` (bats or plain
bash). Gate on Docker availability with `skip_on_cran()` / `SKIP_DOCKER_TESTS`.

**Files:** New `tests/integration/test-scaffold-build-run.sh`, update
`.github/workflows/integration-tests.yml`.

---

## Housekeeping

### 10. `install.sh` version number

`install.sh` has `readonly VERSION="2.0.0"` hardcoded at line 19. This is the
installer version, not the framework version, but the mismatch (2.0.0 vs
`ZZCOLLAB_TEMPLATE_VERSION="2.4.0"`) is confusing. Either keep them in sync or
remove the installer version and derive it from `lib/constants.sh` at install
time.

### 11. `zzcollab.sh` decomposition

At ~2,000 lines, `zzcollab.sh` is a monolith. `cmd_github` (lines 1023-1120)
and `cmd_dockerhub` (lines 1122-1270) are the most self-contained extraction
candidates — each is a distinct workflow with its own prompts and git operations.

### 12. Emoji removal from shell output

Several `log_*` calls and `.Rprofile` messages use emoji (✅, 📸, 🔧, etc.).
The global CLAUDE.md style guide prohibits emoji. These are user-visible strings,
not code comments, so the constraint is advisory rather than strict — but
consistency with the no-emoji policy applied elsewhere would clean up the output.

### 13. `docker-compose.yml` is stale

The review (Section 9) notes `docker-compose.yml` is stale relative to the
Makefile (wrong workdir/user, obsolete `version:` key). The file is a divergent
second entry point. Options: regenerate it from the same templating as the
Makefile, or remove it and document that `make r` is the canonical entry point.
