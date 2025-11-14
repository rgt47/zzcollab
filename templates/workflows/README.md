# zzcollab GitHub Actions Workflows

This directory contains CI/CD workflow templates installed by zzcollab into research projects.

## 📋 Default Workflows

These are installed automatically by zzcollab:

### r-package.yml
**Purpose:** Validates R package structure and runs tests
**Triggers:** Push/PR to main branch
**Key Features:**
- Uses `error_on = 'never'` for development flexibility
- Continues even if tests fail (won't block workflow)
- Validates package structure
- **Improvement:** Less strict than previous versions - won't fail on warnings during development

### render-paper.yml
**Purpose:** Renders research manuscripts to PDF
**Triggers:** Changes to analysis/paper, R code, or manual
**Key Features:**
- Auto-detects manuscript file (paper.Rmd, manuscript.Rmd, main.Rmd, or largest .Rmd)
- Renders supplementary documents optionally
- Uploads PDFs as artifacts
- **Improvement:** No longer requires hardcoded filename

### analysis-paradigm.yml
**Purpose:** Runs complete analysis pipeline
**Triggers:** Changes to analysis scripts, R code, data, or manual
**Key Features:**
- Auto-detects numbered scripts (01_*.R, 02_*.R, etc.)
- Runs scripts in order
- Validates outputs at each step
- Uploads analysis artifacts (data, figures, reports)
- **Improvement:** Fully automated script detection and execution

## 🔬 Optional Workflows

Located in `optional/` - copy to `.github/workflows/` to enable:

### optional/matrix-testing.yml
**Purpose:** Test across multiple OS and R versions
**When to use:** If collaborators use different operating systems
**Tests:** Ubuntu, macOS, Windows × R release/devel
**Triggers:** Push/PR, weekly schedule

### optional/code-coverage.yml
**Purpose:** Measure test coverage
**When to use:** Want to track code quality metrics
**Requires:** Codecov account and CODECOV_TOKEN secret
**Triggers:** Push/PR

### optional/data-validation.yml
**Purpose:** Validate data file integrity
**When to use:** Research projects with critical data files
**Checks:** File existence, structure, key variables
**Triggers:** Changes to data directories

## 🚀 Quick Start

### Default Setup
zzcollab installs r-package.yml and render-paper.yml automatically. No action needed!

### Add Analysis Pipeline
If your project has numbered analysis scripts:
```bash
# Analysis pipeline is automatically included in analysis-paradigm.yml
# Just ensure your scripts follow the pattern: analysis/scripts/NN_*.R
```

### Enable Optional Workflows
```bash
cd .github/workflows
cp ~/path/to/zzcollab/templates/workflows/optional/matrix-testing.yml .
cp ~/path/to/zzcollab/templates/workflows/optional/code-coverage.yml .
cp ~/path/to/zzcollab/templates/workflows/optional/data-validation.yml .
```

## 🔧 Customization

### Make r-package.yml Stricter
For production/CRAN submission:
```yaml
# Change line ~42:
error_on = 'warning'  # Fail on any warnings
```

### Change Manuscript Location
The workflow auto-detects, but you can specify:
```yaml
# In render-paper.yml, modify the detection logic at line ~40
```

### Adjust Analysis Script Pattern
```yaml
# In analysis-paradigm.yml, line ~84:
SCRIPTS=$(ls -1 [0-9][0-9]_*.R 2>/dev/null | sort)
# Change pattern to match your naming convention
```

## 📊 What Changed (v2.0)

### Improvements from User Feedback

**r-package.yml:**
- ❌ Was: `error_on = 'warning'` - too strict, failed on development packages
- ✅ Now: `error_on = 'never'` + `continue-on-error: true` for tests
- **Result:** Development-friendly, won't block CI unnecessarily

**render-paper.yml:**
- ❌ Was: Hardcoded `paper.Rmd` - failed if file named differently
- ✅ Now: Auto-detects manuscript (tries common names, then finds largest .Rmd)
- **Result:** Works with any manuscript filename

**analysis-paradigm.yml:**
- ❌ Was: Required manual script specification
- ✅ Now: Auto-detects and runs numbered scripts (01_*.R, 02_*.R, etc.)
- **Result:** Zero configuration for standard research projects

**New Optional Workflows:**
- ✅ matrix-testing.yml - Cross-platform compatibility
- ✅ code-coverage.yml - Test coverage tracking
- ✅ data-validation.yml - Data integrity checks

## 🎯 Workflow Selection Guide

| Project Type | Essential | Recommended | Optional |
|--------------|-----------|-------------|----------|
| **R Package** | r-package.yml | - | matrix-testing, code-coverage |
| **Research Paper** | render-paper.yml | - | - |
| **Data Analysis** | analysis-paradigm.yml | render-paper.yml | data-validation |
| **Research Compendium** | All defaults | All defaults | All optional |

## 💡 Tips

1. **Start Simple:** Use defaults, add optional workflows only when needed
2. **Test Locally:** Run `Rscript` commands locally before pushing
3. **Check Logs:** Workflow summaries appear in GitHub Actions → Summary tab
4. **Artifacts:** Download generated files from Actions → Workflow run → Artifacts
5. **Customize:** All workflows have clear comments - modify as needed

## 🐛 Troubleshooting

**Workflow fails on package check:**
- Check if `error_on = 'never'` in r-package.yml (should be lenient)
- Review logs for specific R CMD check errors

**Manuscript not found:**
- Verify .Rmd file exists in `analysis/paper/`
- Check detection logic in render-paper.yml
- Try manual trigger with workflow_dispatch

**Analysis scripts not running:**
- Ensure scripts match pattern: `NN_*.R` (e.g., 01_prepare.R, 02_analyze.R)
- Scripts must be in `analysis/scripts/`
- Check script permissions (should be readable)

**Artifacts not uploading:**
- Verify output paths match artifact configuration
- Check retention-days setting (default: 30-90 days)
- Ensure files actually generated (check workflow logs)

## 📚 Learn More

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [R Package CI/CD Best Practices](https://r-pkgs.org/ci-cd.html)
- [Research Compendiums](https://the-turing-way.netlify.app/reproducible-research/compendia)

## 🔄 Changelog

**v2.0 (2025-11-14)**
- Fixed r-package.yml strictness (error_on = 'never')
- Added auto-detection to render-paper.yml
- Enhanced analysis-paradigm.yml with auto-detection
- Added optional/ directory with advanced workflows
- Improved inline documentation

**v1.0**
- Initial workflow templates
