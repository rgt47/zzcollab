# zzcollab Examples and Tutorials

This directory contains instructional materials, complete example projects, and reusable code patterns for reproducible research with zzcollab.

## Purpose

**These materials teach reproducible research best practices.** They are NOT installed with every project - they live here in the zzcollab repository as learning resources you can reference when needed.

## Directory Structure

### 📚 tutorials/
Step-by-step tutorial scripts demonstrating best practices for common research tasks.

**Available Tutorials:**
- `01_eda_tutorial.R` - Systematic exploratory data analysis (252 lines)
- `02_modeling_tutorial.R` - Statistical modeling with tidymodels
- `03_validation_tutorial.R` - Cross-validation and model assessment
- `04_dashboard_tutorial.Rmd` - Interactive Shiny dashboards
- `05_reporting_tutorial.Rmd` - Parameterized reporting

All tutorials use the Palmer Penguins dataset for consistency and clarity.

### 🔬 complete_projects/
Full example research compendia demonstrating end-to-end workflows.

**Available Projects:**
- `penguins_analysis/` - Simple data analysis project
- `covid_manuscript/` - Academic manuscript with supplementary materials (coming soon)
- `churn_prediction/` - Machine learning project (coming soon)

Each complete project includes:
- Full directory structure
- Working analysis code
- Rendered manuscript
- GitHub Actions workflows
- Documentation

### 🧩 patterns/
Reusable code patterns for common reproducible research tasks.

**Available Patterns:**
- `data_validation.R` - Input validation and quality checks
- `model_evaluation.R` - Standardized model assessment
- `reproducible_plots.R` - Publication-ready ggplot2 themes (coming soon)

## How to Use These Examples

### Learning the Framework
1. **Start with tutorials**: Read through tutorial scripts to understand best practices
2. **Explore complete projects**: See how all pieces fit together in real projects
3. **Reference patterns**: Copy/adapt reusable patterns to your own work

### Creating Your Own Project
```bash
# Create new project with zzcollab
zzcollab init my-project

# Your project will have clean structure, NOT these tutorial files
# Reference these examples as needed from:
# https://github.com/rgt47/zzcollab/tree/main/examples
```

### Running Tutorial Examples Locally
```bash
# Clone zzcollab repository
git clone https://github.com/rgt47/zzcollab.git
cd zzcollab/examples/tutorials

# Run a tutorial (requires R and packages)
Rscript 01_eda_tutorial.R
```

## Tutorial Philosophy

**These are EXAMPLES, not templates.**

- **Marwick/rrtools approach**: Provide minimal structure, let researchers write their own code
- **zzcollab examples**: Show what good code looks like, let researchers adapt patterns

Your research project structure remains clean and minimal. These examples teach you patterns to apply in your own scripts.

## Contributing Examples

Have a great example research compendium or reusable pattern? Contributions welcome!

1. Fork zzcollab repository
2. Add your example to appropriate directory
3. Update this README
4. Submit pull request

Examples should:
- Use openly available data (Palmer Penguins, built-in R datasets, etc.)
- Include comprehensive comments explaining the "why" not just "what"
- Follow zzcollab best practices (Docker, renv, testing)
- Be self-contained and reproducible

## Learn More

- [Unified Paradigm Guide](../docs/UNIFIED_PARADIGM_GUIDE.md) - Complete framework documentation
- [Marwick Comparison Analysis](../docs/MARWICK_COMPARISON_ANALYSIS.md) - How zzcollab relates to research compendium literature
- [CI/CD Guide](../docs/CICD_GUIDE.md) - GitHub Actions for reproducible research

---

**Questions?** Open an issue at https://github.com/rgt47/zzcollab/issues
