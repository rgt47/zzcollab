# Reproducibility Best Practices for ZZCOLLAB Projects

This guide provides practical best practices for ensuring complete reproducibility
in research projects created with ZZCOLLAB. Following these practices ensures
that all five pillars of reproducibility are properly maintained.

## The Five Pillars of Reproducibility

Complete reproducibility requires all five components:

1. **Computational Environment** (Dockerfile)
2. **Package Dependencies** (renv.lock)
3. **R Session Configuration** (.Rprofile)
4. **Computational Logic** (Source Code)
5. **Research Data** (Documentation and Files)

## Quick Reference Checklist

### Before Every Commit

```bash
# Validate package environment
Rscript validate_package_environment.R --quiet --fail-on-issues

# Run test suite
Rscript -e "devtools::test()"

# Check for uncommitted changes
git status

# Verify renv.lock is current
git diff renv.lock
```

### Before Sharing or Publication

Use the comprehensive checklist in `getting-started.Rmd` vignette, section
"Reproducibility Verification Checklist".

## Pillar-Specific Best Practices

### Pillar 1: Computational Environment

**Do**:
- ✅ Use zzcollab-generated Dockerfiles (environment variables pre-configured)
- ✅ Specify exact R version in Dockerfile
- ✅ Document system dependencies explicitly
- ✅ Verify environment variables: LANG, LC_ALL, TZ, OMP_NUM_THREADS

**Do Not**:
- ❌ Manually modify environment variables without documenting why
- ❌ Install system packages without adding to Dockerfile
- ❌ Use different base images across team without coordination
- ❌ Assume locale/timezone settings are consistent across systems

**Common Pitfalls**:
- Forgetting to update Dockerfile when adding system dependencies
- Removing environment variables thinking they are unnecessary
- Using platform-specific base images (ARM64 vs AMD64)

### Pillar 2: Package Dependencies

**Do**:
- ✅ Run `renv::snapshot()` after installing new packages
- ✅ Commit renv.lock after every package change
- ✅ Use `validate_package_environment.R` before commits
- ✅ Document package purpose in code comments

**Do Not**:
- ❌ Manually edit renv.lock
- ❌ Use `install.packages()` without running `renv::snapshot()`
- ❌ Commit code that uses packages not in renv.lock
- ❌ Update packages without verifying tests still pass

**Common Pitfalls**:
- Installing packages in global library instead of project-specific renv
- Forgetting to commit renv.lock after adding dependencies
- Using `library()` for packages not in DESCRIPTION

### Pillar 3: R Session Configuration

**Do**:
- ✅ Version control .Rprofile
- ✅ Run `check_rprofile_options.R` in CI/CD
- ✅ Document why specific options are set
- ✅ Use minimal .Rprofile modifications

**Do Not**:
- ❌ Add undocumented options to .Rprofile
- ❌ Set options that vary by user or system
- ❌ Include user-specific paths in .Rprofile
- ❌ Modify stringsAsFactors, digits, or other result-affecting options without
     team discussion

**Common Pitfalls**:
- Setting different options in personal .Rprofile vs project .Rprofile
- Adding interactive-only settings to project .Rprofile
- Not monitoring .Rprofile changes in version control

### Pillar 4: Computational Logic

**Do**:
- ✅ Use explicit `set.seed()` for all stochastic analyses
- ✅ Write comprehensive tests for all functions
- ✅ Document analytical decisions in code comments
- ✅ Use version control for all analysis scripts

**Do Not**:
- ❌ Rely on implicit random number generator state
- ❌ Use undocumented magic numbers or thresholds
- ❌ Commit code without tests
- ❌ Hardcode file paths or user-specific configurations

**Common Pitfalls**:
- Forgetting `set.seed()` in bootstrap, cross-validation, random forest code
- Using absolute paths that only work on one machine
- Not testing edge cases (missing data, zero-length inputs, etc.)

### Pillar 5: Research Data

**Do**:
- ✅ Preserve raw data files (read-only, never modify)
- ✅ Document data provenance (source, DOI, collection dates)
- ✅ Create comprehensive data dictionary
- ✅ Link processing scripts to derived data
- ✅ Commit data/README.md with complete metadata

**Do Not**:
- ❌ Modify raw data files after initial placement
- ❌ Commit large data files without using Git LFS
- ❌ Assume data are self-explanatory
- ❌ Forget to document missing value codes and quality issues

**Common Pitfalls**:
- Overwriting raw data with processed data
- Incomplete data dictionaries (missing units, valid ranges, missing codes)
- No documentation of data quality issues or outliers
- Processing scripts that do not specify input/output file relationships

## Environment Variables: Critical Details

ZZCOLLAB automatically sets these environment variables in all Dockerfiles:

```dockerfile
ENV LANG=en_US.UTF-8        # Locale
ENV LC_ALL=en_US.UTF-8      # Override all locale categories
ENV TZ=UTC                  # Timezone
ENV OMP_NUM_THREADS=1       # Parallel processing
```

### Why Each Variable Matters

**LANG and LC_ALL (Locale)**:

Affects string sorting, number formatting, and factor level ordering.

```r
# Problem: Different locales produce different results
countries <- c("Åland", "Albania", "Algeria")
sort(countries)
# en_US.UTF-8: Åland, Albania, Algeria
# sv_SE.UTF-8: Albania, Algeria, Åland  (Å sorts after Z in Swedish)
```

**TZ (Timezone)**:

Affects date-time arithmetic and temporal aggregations.

```r
# Problem: Different timezones produce different daily aggregates
as.Date(as.POSIXct("2024-03-10 01:00:00"))
# TZ=America/New_York: 2024-03-09 (before midnight local)
# TZ=UTC: 2024-03-10 (after midnight UTC)
```

**OMP_NUM_THREADS (Parallel Processing)**:

Affects reproducibility of parallel computations.

```r
# Problem: Multi-threaded execution produces different results
sum(rnorm(1e6))
# OMP_NUM_THREADS=1: Always identical
# OMP_NUM_THREADS=4: Varies due to floating-point operation order
```

## Team Collaboration Patterns

### Pattern 1: Union-Based Package Management

Team members add packages independently. Final renv.lock contains union of
all packages.

```bash
# Alice adds geospatial packages
make docker-zsh
# Inside container:
renv::install("sf")
renv::snapshot()

# CRITICAL: Validate before committing
Rscript validate_package_environment.R --fix --fail-on-issues
devtools::test()
exit

git add renv.lock DESCRIPTION
git commit -m "Add geospatial packages"
git push

# Bob adds machine learning packages
git pull  # Gets Alice's changes
make docker-zsh
# Inside container:
renv::install("tidymodels")
renv::snapshot()  # renv.lock now has sf + tidymodels

# CRITICAL: Validate before committing
Rscript validate_package_environment.R --fix --fail-on-issues
devtools::test()
exit

git add renv.lock DESCRIPTION
git commit -m "Add ML packages"
git push
```

**Key principles**:
- renv::snapshot() scans ALL code files, generating union of dependencies
- validate_package_environment.R MUST run before every commit
- Tests MUST pass before committing package changes

### Pattern 2: Pre-commit Validation

**This is non-negotiable.** All team members MUST run validation before every
commit that changes renv.lock or code dependencies.

```bash
# Inside container (after making code/package changes):

# 1. VALIDATE dependencies
Rscript validate_package_environment.R --fix --fail-on-issues

# 2. RUN tests
devtools::test()

# 3. EXIT container
exit

# 4. COMMIT only if validation passed and tests passed
git add renv.lock DESCRIPTION <other-files>
git commit -m "Add analysis"
git push
```

**Why this matters**: validate_package_environment.R prevents:
- Code using packages not in renv.lock
- Packages in renv.lock not in DESCRIPTION
- Invalid package sources
- Missing dependencies

**CI/CD will reject** commits that fail validation, but catching it locally
saves time and prevents broken builds.

### Pattern 3: Continuous Integration Safety Net

GitHub Actions validates every pull request:

```yaml
# .github/workflows/r-package.yml
- name: Validate dependencies
  run: Rscript validate_package_environment.R --quiet --fail-on-issues

- name: Run tests
  run: Rscript -e "devtools::test()"
```

## Troubleshooting Common Issues

### Issue: "Works on my machine" problem

**Symptoms**: Analysis runs locally but fails for colleagues.

**Diagnosis**:
```bash
# Check environment variables
docker run --rm <image> env | grep -E "LANG|TZ|OMP"

# Check package versions
docker run --rm <image> R -e "packageVersion('dplyr')"

# Check R options
docker run --rm <image> R -e "getOption('stringsAsFactors')"
```

**Solution**: Verify all five pillars are version controlled and Docker image
builds successfully.

### Issue: Different results across team members

**Symptoms**: Identical code produces different numerical results.

**Common Causes**:
1. Missing `set.seed()` in stochastic code
2. Different locale settings (string sorting affects factor ordering)
3. Different timezone settings (date aggregation differs)
4. Multi-threaded execution without thread control

**Solution**:
```r
# Add explicit seed
set.seed(47)

# Verify environment variables in Dockerfile
# LANG=en_US.UTF-8
# TZ=UTC
# OMP_NUM_THREADS=1
```

### Issue: Tests pass locally but fail in CI/CD

**Symptoms**: `devtools::test()` passes locally, fails in GitHub Actions.

**Common Causes**:
1. Packages in local library not in renv.lock
2. Data files not committed to repository
3. Hardcoded file paths specific to local machine
4. .Rprofile settings not version controlled

**Solution**:
```bash
# Validate package environment
Rscript validate_package_environment.R --fail-on-issues

# Check for uncommitted files
git status

# Test in clean Docker environment
make docker-test
```

## Additional Resources

- **Comprehensive reproducibility model**: `docs/COLLABORATIVE_REPRODUCIBILITY.md`
- **Five pillars explanation**: `vignettes/quickstart.Rmd`
- **Testing guide**: `docs/TESTING_GUIDE.md`
- **Configuration system**: `docs/CONFIGURATION.md`
- **Data workflow**: `data/DATA_WORKFLOW_GUIDE.md` (auto-generated in projects)

## Quick Decision Tree

**Question: Should I commit this change?**

```
1. Does validate_package_environment.R pass?
   NO → Fix dependencies, run renv::snapshot()
   YES → Continue to 2

2. Do all tests pass (devtools::test())?
   NO → Fix code or update tests
   YES → Continue to 3

3. Is renv.lock current (git status)?
   NO → Run renv::snapshot(), commit renv.lock
   YES → Continue to 4

4. Are data files documented (data/README.md)?
   NO → Update data dictionary and provenance
   YES → Continue to 5

5. Is .Rprofile version controlled?
   NO → Commit .Rprofile
   YES → Safe to commit!
```

## Summary

Reproducible research with ZZCOLLAB requires:

1. **Use automated tools**: validate_package_environment.R, check_rprofile_options.R
2. **Follow the five pillars**: Dockerfile, renv.lock, .Rprofile, Source Code, Data
3. **Verify before committing**: Run validation, tests, check git status
4. **Document everything**: Data provenance, analytical decisions, package purposes
5. **Trust but verify**: CI/CD provides safety net, but local validation prevents issues

The goal is to make reproducibility automatic and effortless, not burdensome.
ZZCOLLAB provides the infrastructure; these best practices ensure it is used
effectively.
