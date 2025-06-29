#!/bin/bash
##############################################################################
# ZZRRTOOLS ANALYSIS MODULE
##############################################################################
# 
# PURPOSE: Research analysis framework and academic paper templates
#          - Research paper template (R Markdown)
#          - Bibliography and citation management
#          - Analysis templates and examples
#          - Academic workflow support
#
# DEPENDENCIES: core.sh (logging), templates.sh (file creation)
#
# TRACKING: All created analysis files are tracked for uninstall capability
##############################################################################

# Validate required modules are loaded
if [[ "${ZZRRTOOLS_CORE_LOADED:-}" != "true" ]]; then
    echo "❌ Error: analysis.sh requires core.sh to be loaded first" >&2
    exit 1
fi

if [[ "${ZZRRTOOLS_TEMPLATES_LOADED:-}" != "true" ]]; then
    echo "❌ Error: analysis.sh requires templates.sh to be loaded first" >&2
    exit 1
fi

#=============================================================================
# ANALYSIS FILES CREATION (extracted from lines 525-536)
#=============================================================================

# Function: create_analysis_files
# Purpose: Creates research paper templates and analysis framework
# Creates:
#   - analysis/paper/paper.Rmd (main research paper template)
#   - analysis/paper/references.bib (bibliography file)
#   - Citation style files for academic publishing
#
# Template Features:
#   - Complete R Markdown paper structure
#   - Author and institution placeholders
#   - Bibliography integration with references.bib
#   - Standard academic sections (Introduction, Methods, Results, Discussion)
#   - Knitr chunk options for reproducible figures
#   - Package loading and setup configurations
#
# Academic Standards:
#   - Follows academic paper conventions
#   - Supports multiple citation styles
#   - Integrated with R package workflow
#   - Reproducible research practices
#
# Tracking: All created files are tracked in manifest for uninstall
create_analysis_files() {
    log_info "Creating analysis and paper files..."
    
    # Create research paper template from R Markdown template
    # Template includes: YAML header, author info, bibliography setup, standard sections
    if copy_template_file "paper.Rmd" "analysis/paper/paper.Rmd" "Research paper template"; then
        track_template_file "paper.Rmd" "analysis/paper/paper.Rmd"
        log_info "Created research paper template with academic structure"
    else
        log_error "Failed to create research paper template"
        return 1
    fi
    
    # Create bibliography file for citations and references
    # BibTeX format for academic reference management
    if copy_template_file "references.bib" "analysis/paper/references.bib" "references.bib file"; then
        track_template_file "references.bib" "analysis/paper/references.bib"
        log_info "Created bibliography file for citation management"
    else
        log_error "Failed to create bibliography file"
        return 1
    fi
    
    # Create citation style file for academic journals
    # CSL (Citation Style Language) file for formatting citations
    if copy_template_file "statistics-in-medicine.csl" "analysis/paper/statistics-in-medicine.csl" "citation style file"; then
        track_template_file "statistics-in-medicine.csl" "analysis/paper/statistics-in-medicine.csl"
        log_info "Created citation style file for academic formatting"
    else
        log_warn "Citation style file not found - citations will use default format"
    fi
    
    log_success "Analysis files created successfully"
}

#=============================================================================
# ANALYSIS FRAMEWORK UTILITIES
#=============================================================================

# Function: validate_analysis_structure
# Purpose: Verify that all required analysis files were created successfully
# Checks: paper.Rmd, references.bib, analysis directories
# Returns: 0 if all files exist, 1 if any are missing
validate_analysis_structure() {
    log_info "Validating analysis structure..."
    
    local -r required_files=(
        "analysis/paper/paper.Rmd"
        "analysis/paper/references.bib"
    )
    
    local -r required_dirs=(
        "analysis/paper"
        "analysis/figures"
        "analysis/tables"
        "analysis/templates"
    )
    
    local missing_items=()
    
    # Check required files
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_items+=("file: $file")
        fi
    done
    
    # Check required directories
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            missing_items+=("directory: $dir")
        fi
    done
    
    if [[ ${#missing_items[@]} -eq 0 ]]; then
        log_success "All required analysis files and directories exist"
        return 0
    else
        log_error "Missing analysis items: ${missing_items[*]}"
        return 1
    fi
}

# Function: show_analysis_summary
# Purpose: Display analysis framework summary and usage instructions
show_analysis_summary() {
    log_info "Analysis framework summary:"
    cat << 'EOF'
📝 ANALYSIS FRAMEWORK CREATED:

├── analysis/
│   ├── paper/
│   │   ├── paper.Rmd            # Main research paper template
│   │   ├── references.bib       # Bibliography for citations
│   │   └── *.csl               # Citation style files (optional)
│   ├── figures/                # Generated plots and visualizations
│   ├── tables/                 # Generated statistical tables
│   └── templates/              # Analysis templates and snippets

📊 RESEARCH WORKFLOW:
1. Edit analysis/paper/paper.Rmd for your research paper
2. Add references to analysis/paper/references.bib
3. Generate figures and save to analysis/figures/
4. Create tables and save to analysis/tables/
5. Use knitr to render paper.Rmd to PDF

📚 KEY FEATURES:
- R Markdown integration with package functions
- Automatic bibliography generation
- Reproducible figure and table creation
- Standard academic paper structure
- Citation management with BibTeX

🔧 RENDERING COMMANDS:
- rmarkdown::render("analysis/paper/paper.Rmd")     # Render to PDF
- make docker-render                                 # Render in container
- knitr::knit("analysis/paper/paper.Rmd")           # Process R chunks

📝 EDITING WORKFLOW:
1. Write analysis code in R chunks within paper.Rmd
2. Reference package functions with PKG_NAME::function_name
3. Include figures with knitr chunk options
4. Cite references with [@citation_key] syntax
5. Use cross-references for figures and tables

🎯 ACADEMIC STANDARDS:
- Follows reproducible research practices
- Integrates with R package development
- Supports multiple citation styles
- Version controlled with git
- Container-ready for collaboration
EOF
}

# Function: create_analysis_examples
# Purpose: Create example analysis scripts and templates
# Optional: Provides examples for common analysis patterns
create_analysis_examples() {
    log_info "Creating analysis examples and templates..."
    
    # Create example data analysis script
    local example_analysis='# Example Data Analysis Script
# This script demonstrates common analysis patterns

# Load required packages
library(here)
library(dplyr)
library(ggplot2)
library(knitr)

# Load package functions
# Replace PKG_NAME with your actual package name
# library(PKG_NAME)

# Example: Load and explore data
# data <- read.csv(here("data", "raw_data", "your_data.csv"))
# summary(data)

# Example: Create a figure
# p <- ggplot(data, aes(x = variable1, y = variable2)) +
#   geom_point() +
#   theme_minimal() +
#   labs(title = "Example Plot",
#        x = "Variable 1",
#        y = "Variable 2")
# 
# ggsave(here("analysis", "figures", "example_plot.png"), p)

# Example: Create a table
# result_table <- data %>%
#   group_by(group_variable) %>%
#   summarise(
#     mean_value = mean(numeric_variable, na.rm = TRUE),
#     sd_value = sd(numeric_variable, na.rm = TRUE),
#     n = n()
#   )
# 
# write.csv(result_table, 
#           here("analysis", "tables", "summary_table.csv"),
#           row.names = FALSE)

cat("Analysis example template created\\n")
cat("Edit this file to implement your specific analysis\\n")'
    
    if create_file_if_missing "analysis/templates/example_analysis.R" "$example_analysis" "example analysis script"; then
        track_file "analysis/templates/example_analysis.R"
        log_info "Created example analysis script"
    else
        log_warn "Failed to create example analysis script"
    fi
    
    # Create figure template script
    local figure_template='# Figure Creation Template
# Template for creating publication-ready figures

library(ggplot2)
library(here)

# Function to create publication-ready theme
pub_theme <- function() {
  theme_minimal() +
  theme(
    text = element_text(size = 12),
    plot.title = element_text(size = 14, face = "bold"),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 10),
    legend.title = element_text(size = 12),
    legend.text = element_text(size = 10),
    panel.grid.minor = element_blank()
  )
}

# Example figure creation function
create_example_figure <- function(data) {
  p <- ggplot(data, aes(x = x_var, y = y_var)) +
    geom_point(alpha = 0.7) +
    geom_smooth(method = "lm", se = TRUE) +
    pub_theme() +
    labs(
      title = "Example Figure Title",
      subtitle = "Descriptive subtitle",
      x = "X Variable Label",
      y = "Y Variable Label",
      caption = "Source: Your data source"
    )
  
  return(p)
}

# Save figure with consistent settings
save_figure <- function(plot, filename, width = 8, height = 6, dpi = 300) {
  ggsave(
    filename = here("analysis", "figures", filename),
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    device = "png"
  )
}

cat("Figure template functions loaded\\n")
cat("Use create_example_figure() and save_figure() in your analysis\\n")'
    
    if create_file_if_missing "analysis/templates/figure_template.R" "$figure_template" "figure creation template"; then
        track_file "analysis/templates/figure_template.R"
        log_info "Created figure creation template"
    else
        log_warn "Failed to create figure template"
    fi
    
    log_success "Analysis examples and templates created"
}

#=============================================================================
# ANALYSIS MODULE VALIDATION
#=============================================================================

# Validate that required directories exist for analysis files
# These should be created by the structure module
if [[ ! -d "analysis/paper" ]]; then
    log_warn "analysis/paper directory not found - may need to run structure module first"
fi

if [[ ! -d "analysis/figures" ]]; then
    log_warn "analysis/figures directory not found - may need to run structure module first"
fi

# Set analysis module loaded flag
readonly ZZRRTOOLS_ANALYSIS_LOADED=true

log_info "Analysis module loaded successfully"