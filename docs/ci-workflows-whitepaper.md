# Continuous Integration Workflows for Reproducible Research Frameworks

## A Design Rationale for the ZZCOLLAB CI Pipeline

**Date:** February 2026
**Context:** ZZCOLLAB framework (`github.com/rgt47/zzcollab`)
**Scope:** Six GitHub Actions workflows comprising the framework's
continuous integration strategy

---

## 1. Introduction

Software frameworks that generate computational research environments
carry a dual obligation: the framework itself must be correct, and
the environments it produces must be reproducible. Continuous
integration (CI) is the standard mechanism for enforcing both
guarantees automatically, on every change, without relying on
developer discipline alone.

This document describes the design rationale behind the six CI
workflows in ZZCOLLAB, a Docker-based reproducible research
framework for R. Each workflow targets a distinct failure mode that,
if left undetected, could silently compromise either the framework's
correctness or the reproducibility of downstream research projects.

The workflows are:

1. Shell Tests
2. ShellCheck Static Analysis
3. Security Scanning
4. R Package Check
5. Integration Tests (Docker)
6. Performance Benchmarks

---

## 2. Motivation: Why CI for a Research Framework

### 2.1 The Cost of Silent Failures

Research software failures are uniquely dangerous because they often
produce plausible but incorrect results rather than visible errors
(Hatton, 1997; Soergel, 2015). A subtle bug in a data preparation
pipeline may shift p-values or bias effect estimates without
generating any warning. CI cannot catch every such error, but it
establishes a minimum floor of correctness that holds across all
contributions.

### 2.2 The Dual-Identity Problem

ZZCOLLAB is both a Bash CLI framework (approximately 5,000 lines of
shell across `zzcollab.sh`, `lib/`, and `modules/`) and an R package
(with DESCRIPTION, R/, tests/testthat/). These two components have
different failure modes and require different testing strategies:

- Shell code fails through undefined variables, incorrect quoting,
  non-portable constructs, and logic errors in conditional chains.
- R package code fails through missing imports, namespace
  collisions, and API-breaking changes in dependencies.
- The integration between them---where shell code generates
  Dockerfiles, renv.lock files, and project scaffolding that R code
  then consumes---fails through template drift, variable
  substitution errors, and version mismatches.

No single testing approach covers all three. The six-workflow
architecture ensures that each failure mode has a dedicated detection
mechanism.

### 2.3 Standards and Precedent

The workflow design follows established CI practices for open-source
R packages (Wickham and Bryan, 2023) and shell-based tools (Cooper,
2014), adapted for the specific requirements of a framework that
generates Docker-based research environments:

- **R CMD check** is the canonical validation for R packages,
  enforced by CRAN and recommended by the R Packages book.
- **ShellCheck** is the standard static analyzer for shell scripts,
  analogous to what a linter provides for R or Python.
- **Container image scanning** is a baseline security requirement
  for any project distributing Docker images (NIST SP 800-190).
- **Integration testing** of generated artifacts is necessary
  whenever a tool's output is consumed by other systems, a principle
  well established in compiler and code-generator testing.
- **Performance regression detection** is standard practice for
  build systems whose users are sensitive to iteration speed.

---

## 3. Workflow Architecture

The six workflows are organized into three tiers, reflecting the
progression from fast, inexpensive checks to slow, resource-
intensive validations.

```
Tier 1: Static Analysis (seconds)
  ├── Shell Tests          ~10s   Unit tests for shell functions
  └── ShellCheck           ~15s   Static analysis of all .sh files

Tier 2: Package Validation (minutes)
  ├── R Package Check      ~3m    R CMD check on 4 OS/version combos
  └── Security Scanning    ~2m    Trivy + Hadolint + dependency audit

Tier 3: End-to-End Validation (minutes to tens of minutes)
  ├── Integration Tests    ~30m   Docker builds across 5 profiles
  └── Benchmarks           ~5m    Build time + test time tracking
```

All workflows trigger on pushes to `main` and on pull requests.
Security scanning and integration tests additionally run on weekly
schedules to detect upstream regressions in base images and
dependencies.

---

## 4. Workflow Descriptions

### 4.1 Shell Tests

**File:** `.github/workflows/shell-tests.yml`
**Trigger:** Push to main/develop, pull requests
**Duration:** Approximately 10 seconds
**Runner:** `ubuntu-latest`

#### Purpose

Unit tests for the shell function libraries that comprise the core
of the framework. These tests verify argument parsing, configuration
loading, validation logic, and module interactions without requiring
Docker, network access, or interactive input.

#### What It Checks

The workflow executes three test suites corresponding to the
framework's module structure:

| Test File | Count | Scope |
|-----------|-------|-------|
| `test-core.sh` | 16 | Foundation libraries: logging, path |
|  |  | resolution, R version validation, |
|  |  | module loading |
| `test-cli.sh` | 22 | CLI argument parsing, flag handling, |
|  |  | subcommand routing, configuration |
|  |  | variable propagation |
| `test-validation.sh` | 14 | Input validation for package names, |
|  |  | R versions, profile names, YAML |
|  |  | config files, renv.lock integrity |

Total: 52 assertions executed in under 10 seconds.

#### Design Rationale

Shell unit tests are the first line of defense against regressions
in argument parsing and configuration logic. Because the framework
accepts user input through CLI flags, YAML configuration files, and
interactive prompts, incorrect parsing can cause downstream failures
that are difficult to diagnose (e.g., a malformed R version string
producing an invalid Dockerfile). Fast execution time means these
tests impose no friction on the development cycle.

The tests use a lightweight assertion framework
(`tests/shell/test_helpers.sh`) rather than a third-party tool like
BATS, minimizing external dependencies for the test infrastructure
itself.

---

### 4.2 ShellCheck Static Analysis

**File:** `.github/workflows/shellcheck.yml`
**Trigger:** Push to main/develop, pull requests
**Duration:** Approximately 15 seconds
**Runner:** `ubuntu-latest`

#### Purpose

Static analysis of every shell script in the repository using
ShellCheck (Kowalczyk, 2012), the standard linter for Bash and POSIX
shell. This workflow catches bugs that unit tests may miss because
they occur only under specific runtime conditions (e.g., unquoted
variable expansions that fail only when values contain spaces).

#### What It Checks

The workflow scans scripts in four scopes at `--severity=warning`:

1. **Main script** (`zzcollab.sh`): The 1,800-line entry point
   containing subcommand dispatch, module loading, and orchestration
   logic.

2. **Modules** (`modules/*.sh`): Six modules covering CLI parsing,
   configuration management, Docker image generation, GitHub
   integration, profile management, and validation.

3. **Utility scripts** (`install.sh`): The framework installer that
   configures PATH, creates symlinks, and validates prerequisites.

4. **Template scripts** (`templates/*.sh`): Shell scripts that are
   copied into generated research projects, including container
   entry points and navigation helpers.

Additionally, the workflow enforces a **reproducibility guard**: it
scans critical template files (Dockerfile templates, Makefile) for
`:latest` Docker tag defaults. The use of `:latest` in generated
Dockerfiles violates the reproducibility contract because the tag
resolves to different images over time.

On pull requests, a **diff-only analysis** job runs ShellCheck
exclusively on changed files, providing targeted feedback.

#### Design Rationale

Shell scripts are notoriously susceptible to classes of bugs that
are invisible during normal execution but catastrophic under edge
conditions. ShellCheck detects over 200 categories of issues,
including:

- **SC2086** (unquoted variables): A variable containing spaces will
  split into multiple arguments, potentially executing unintended
  commands or corrupting file paths.
- **SC2155** (declare and assign separately): Masking return codes
  from command substitutions, hiding failures.
- **SC2120/SC2119** (function argument mismatches): Functions that
  accept arguments but are never called with them, or vice versa.

The `:latest` guard deserves special emphasis. Docker's `:latest`
tag is mutable: `rocker/r-ver:latest` pointed to R 4.3.x in 2024,
R 4.4.x in 2025, and R 4.5.x in 2026. A Dockerfile template
containing `FROM rocker/r-ver:latest` would produce different
computational environments depending on when it was built, directly
undermining the framework's reproducibility guarantee. This check
ensures that such regressions are caught before they reach users.

---

### 4.3 Security Scanning

**File:** `.github/workflows/security-scan.yml`
**Trigger:** Push to main/develop, pull requests, weekly schedule
**Duration:** Approximately 2 minutes
**Runner:** `ubuntu-latest`

#### Purpose

Vulnerability detection across three attack surfaces: the Docker
base image, the Dockerfile configuration, and R package
dependencies. Research environments that process sensitive data
(clinical trials, patient records, proprietary datasets) must meet
minimum security standards even when running behind institutional
firewalls.

#### What It Checks

The workflow comprises four jobs:

**1. Trivy Vulnerability Scan**

Builds a minimal Docker image from `rocker/r-ver:4.4.0` and scans
it with Aqua Security's Trivy scanner for known CVEs at CRITICAL
and HIGH severity. Results are uploaded in SARIF format to the
GitHub Security tab, enabling integration with GitHub's security
alerting and Dependabot workflows.

This scan detects vulnerabilities in:

- Base OS packages (Debian/Ubuntu libraries)
- System libraries installed via `apt-get`
- Known vulnerable versions of curl, openssl, zlib, and other
  foundational libraries

**2. Dependency Vulnerability Check**

Inspects the Dockerfile and renv.lock for security anti-patterns:

- Use of `:latest` base image tags (unpinned, mutable references)
- Use of `sudo` in build steps (unnecessary privilege escalation)
- Auto-accepting package manager prompts without version pinning
- Validates that renv.lock exists and is syntactically valid

**3. Hadolint Dockerfile Linting**

Runs Hadolint, the standard Dockerfile linter, checking against
Docker security best practices:

- Presence of a non-root `USER` directive
- Presence of a `HEALTHCHECK` directive
- Package pinning in `apt-get install` commands
- Appropriate use of multi-stage builds

Certain rules (DL3008, DL3009, DL3007) are suppressed because the
framework intentionally uses unpinned system packages within a
version-pinned base image, a deliberate tradeoff documented in the
framework's architecture decisions.

**4. Security Summary**

Aggregates results from all three scans into a GitHub Step Summary
for quick review.

#### Design Rationale

Container image scanning is a baseline expectation for any project
distributing Docker images. NIST SP 800-190 (Application Container
Security Guide) recommends scanning images for known
vulnerabilities before deployment. While research containers
typically run in isolated environments rather than production
servers, they often process sensitive data subject to institutional
review board (IRB) requirements and data use agreements that mandate
minimum security hygiene.

The weekly schedule ensures that newly disclosed CVEs in base images
are detected even when the framework code is not actively changing.
A vulnerability disclosed in libcurl on a Tuesday will be flagged by
the following Sunday's scan without requiring any code change to
trigger it.

---

### 4.4 R Package Check

**File:** `.github/workflows/r-package.yml`
**Trigger:** Push to main, pull requests
**Duration:** Approximately 3 minutes per matrix cell
**Runner:** Matrix across `ubuntu-latest`, `macos-latest`,
`windows-latest`

#### Purpose

Full R CMD check validation of the framework's R package component
across multiple operating systems and R versions. R CMD check is the
canonical validation tool for R packages, required for CRAN
submission and recommended as a CI standard by the R Packages book
(Wickham and Bryan, 2023).

#### What It Checks

The workflow tests a four-cell matrix:

| OS | R Version | Purpose |
|----|-----------|---------|
| Ubuntu | 4.4 | Primary validation platform |
| Ubuntu | 4.3 | Backward compatibility |
| macOS | 4.4 | Cross-platform (developer machines) |
| Windows | 4.4 | Cross-platform (collaborator access) |

R CMD check performs over 50 individual checks, including:

- **DESCRIPTION validity**: Package metadata, licensing, authorship
- **Namespace consistency**: Exports match documented functions,
  imports are declared
- **Documentation**: Roxygen-generated man pages parse correctly,
  examples run without error
- **Test execution**: `testthat` test suite passes
- **No global variable pollution**: Functions do not modify the
  global environment
- **Vignette building**: Long-form documentation compiles

On the Ubuntu/R 4.4 cell, the workflow additionally computes test
coverage using `covr` and enforces a **minimum coverage threshold of
35%**. Coverage results are uploaded to Codecov for historical
tracking. The threshold is set at the current coverage level and is
intended to be ratcheted upward as more tests are added, preventing
coverage regression.

#### Design Rationale

Cross-platform testing is particularly important for ZZCOLLAB
because the framework is used by research teams whose members may
run macOS (common in academic settings), Ubuntu (common on servers
and in Docker), or Windows (common among clinical collaborators).
A function that works on one platform but fails on another due to
path separator differences, locale handling, or system library
availability would silently break the reproducibility guarantee for
a subset of users.

The coverage threshold serves as a regression guard rather than a
target. New code that reduces overall coverage below the threshold
will fail CI, creating a natural incentive to include tests with
each contribution. This follows the "ratchet" pattern recommended
by Feathers (2004) for legacy codebases where comprehensive
coverage cannot be achieved immediately.

---

### 4.5 Integration Tests (Docker)

**File:** `.github/workflows/integration-tests.yml`
**Trigger:** Push to main/develop, pull requests, weekly schedule
**Duration:** Up to 60 minutes (timeout), typically 15-30 minutes
**Runner:** `ubuntu-latest`

#### Purpose

End-to-end validation that the framework produces working Docker
images across all supported profiles. This is the most
comprehensive test tier, exercising the full pipeline from
`zzcollab <profile>` invocation through Dockerfile generation,
Docker image building, container startup, and in-container R
package installation.

#### What It Checks

The workflow contains two jobs:

**1. Docker Integration Matrix (5 profiles x 1 R version)**

For each of the five core profiles (minimal, analysis, publishing,
rstudio, shiny), the workflow:

1. Creates a test project directory with DESCRIPTION, renv.lock,
   and .Rprofile
2. Installs the framework via `install.sh`
3. Runs `zzcollab <profile> -Y --no-build` to generate project
   scaffolding
4. Builds the Docker image using `docker/build-push-action` with
   GitHub Actions cache
5. Starts a container and verifies:
   - Container starts and remains running
   - R is installed and the version matches the specification
   - Project directory structure exists at the expected path
   - Working directory is set correctly
   - The R package installs from source inside the container
   - The non-root user (`analyst`) has write permissions to the
     project directory and R library

**2. End-to-End Workflow Test**

Exercises the complete user workflow without Docker building:

1. Installs zzcollab via `install.sh`
2. Initializes configuration (`zzcollab config init`)
3. Creates a project (`zzcollab minimal -Y --no-build`)
4. Verifies that Dockerfile, DESCRIPTION, and Makefile were
   generated with expected content

#### Design Rationale

Integration tests are necessary because unit tests and static
analysis cannot detect failures that emerge from the interaction
between components. A Dockerfile template may be syntactically
valid (passes ShellCheck and unit tests) but produce an image where
R cannot find installed packages because of a PATH ordering error.
A profile definition may correctly specify a base image but fail
to include system libraries required by the profile's R packages.

The weekly schedule addresses a class of failures unique to
Docker-based projects: **upstream image drift**. The `rocker`
project periodically updates its base images, and these updates
can introduce breaking changes (new system library requirements,
changed default configurations, removed packages). Weekly
integration tests detect such changes promptly, before they affect
active development.

The 60-minute timeout accommodates the reality that Docker builds
with R package installation can be slow, particularly for profiles
like `publishing` that include LaTeX distributions.

---

### 4.6 Performance Benchmarks

**File:** `.github/workflows/benchmarks.yml`
**Trigger:** Push to main, pull requests
**Duration:** Approximately 5 minutes
**Runner:** `ubuntu-latest`

#### Purpose

Track performance metrics across three dimensions: Docker image
build time, R package installation overhead, and test suite
execution time. These benchmarks do not enforce pass/fail
thresholds; they serve as observational instruments for detecting
performance regressions over time.

#### What It Checks

**1. Docker Build Performance**

Measures two builds of the project's Dockerfile:

- **Cold build** (no cache): Establishes the baseline build time
  for a fresh environment, relevant to new contributors and CI
  cold starts.
- **Cached build**: Measures incremental build time, relevant to
  the iterative development cycle.
- **Image size**: Reports the final image size, which affects
  download time and storage costs.
- **Cache speedup**: Computes the percentage improvement from
  caching, validating that the Dockerfile's layer ordering is
  optimized.

**2. R Package Installation**

Counts the packages declared in renv.lock and benchmarks renv
initialization time. As the framework's default renv.lock grows,
this metric provides early warning of installation time increases
that could affect user experience.

**3. Test Suite Execution**

Times each shell test file individually, providing per-module
execution metrics. This detects test suite bloat (a common problem
as test counts grow) and identifies specific test files that have
become disproportionately slow.

All benchmark results are uploaded as artifacts with a 90-day
retention period, enabling longitudinal analysis.

#### Design Rationale

Build time is a first-order concern for Docker-based development
workflows. A research compendium that takes 45 minutes to build
from scratch will deter collaborators and slow iteration cycles.
Tracking build times on every commit enables the team to detect
and address regressions (e.g., an added system dependency that
invalidates Docker cache layers) before they accumulate.

The benchmarks deliberately avoid enforcing thresholds because
performance requirements are context-dependent. A 5-minute build
time is acceptable for a complex publishing environment but
excessive for a minimal analysis container. The data is collected
for human review rather than automated gating.

---

## 5. Trigger Strategy

The workflows use a deliberate trigger strategy that balances
coverage against resource consumption:

| Workflow | Push | PR | Schedule | Dispatch |
|----------|------|----|----------|----------|
| Shell Tests | main, develop | main, develop | -- | manual |
| ShellCheck | main, develop | main, develop | -- | manual |
| Security Scan | main, develop | main, develop | Weekly Mon | -- |
| R Package | main | main | -- | -- |
| Integration | main, develop | main, develop | Weekly Sun | manual |
| Benchmarks | main | main | -- | manual |

Scheduled runs serve different purposes:

- **Security scanning (Monday)**: Detects newly disclosed CVEs in
  base images at the start of the work week, when developers are
  available to respond.
- **Integration tests (Sunday)**: Detects upstream Docker image
  changes before the work week begins, providing lead time for
  investigation.

Manual dispatch (`workflow_dispatch`) is enabled on workflows where
ad-hoc execution is useful for debugging or validation after
infrastructure changes.

---

## 6. Artifact and Reporting Strategy

Each workflow generates structured artifacts:

| Workflow | Artifact | Retention | Format |
|----------|----------|-----------|--------|
| Shell Tests | Test report | 30 days | Markdown |
| ShellCheck | Analysis report | 30 days | Markdown |
| Security Scan | Trivy SARIF | Persistent | SARIF |
| R Package | Check snapshots | 30 days | R CMD check |
| Benchmarks | Three reports | 90 days | Plain text |

Security scan results receive special treatment: SARIF output is
uploaded to the GitHub Security tab, integrating with GitHub's
native vulnerability tracking and alerting infrastructure. This
ensures that critical vulnerabilities surface in the repository's
security dashboard rather than being buried in workflow logs.

Benchmark artifacts use a longer retention period (90 days) to
support longitudinal performance analysis across release cycles.

---

## 7. Known Limitations and Future Directions

### 7.1 Current Limitations

- **No ARM/Apple Silicon testing**: The integration tests run
  exclusively on x86_64 Ubuntu runners. Docker images built for
  `linux/amd64` may exhibit different behavior on ARM-based
  machines (Apple M-series, Graviton).

- **Single R version in integration matrix**: The Docker
  integration tests currently test only R 4.4.0. Expanding to
  multiple R versions would increase confidence but also increase
  CI resource consumption and execution time.

- **Coverage threshold is low**: The 35% coverage floor reflects
  the current state of the R package tests. As the test suite
  matures, this threshold should be raised incrementally.

- **No mutation testing**: The shell test suite verifies expected
  behavior but does not use mutation testing to assess the quality
  of the assertions themselves.

### 7.2 Potential Improvements

- **Matrix expansion**: Add R 4.5.x to the integration test matrix
  as rocker images stabilize for that version.

- **Benchmark regression alerts**: Implement threshold-based
  alerting for Docker build time increases beyond a configurable
  percentage, converting benchmarks from observational to
  prescriptive.

- **Dependency license scanning**: Add a workflow to audit R
  package licenses in renv.lock for compatibility with GPL-3,
  relevant for institutions with strict open-source policies.

- **SBOM generation**: Produce a Software Bill of Materials for
  generated Docker images, increasingly required by institutional
  security policies and federal mandates (Executive Order 14028).

---

## References

Cooper, M. (2014). Advanced Bash-Scripting Guide. The Linux
Documentation Project.

Feathers, M. (2004). Working Effectively with Legacy Code.
Prentice Hall.

Hatton, L. (1997). The T experiments: Errors in scientific
software. IEEE Computational Science and Engineering, 4(2), 27-38.

Kowalczyk, V. (2012). ShellCheck: A static analysis tool for shell
scripts. https://www.shellcheck.net

NIST (2017). SP 800-190: Application Container Security Guide.
National Institute of Standards and Technology.

Soergel, D. A. W. (2015). Rampant software errors may undermine
scientific results. F1000Research, 3, 303.

Wickham, H. and Bryan, J. (2023). R Packages (2nd ed.). O'Reilly
Media. https://r-pkgs.org

---
*Generated on 2026-02-16.*
*Source: /Users/zenn/prj/sfw/07-zzcollab/zzcollab/docs/ci-workflows-whitepaper.md*
