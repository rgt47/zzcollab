#!/bin/bash
# Fix all smart_pager calls in help_guides.sh

file="help_guides.sh"

# Backup
cp "$file" "${file}.pre_pager_fix"

# Replace all smart_pager patterns with proper paging logic
sed -i.tmp '
/show_renv_help_content | smart_pager/ c\
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then\
        show_renv_help_content\
    else\
        show_renv_help_content | "${PAGER:-less}" -R\
    fi

/show_build_modes_help_content | smart_pager/ c\
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then\
        show_build_modes_help_content\
    else\
        show_build_modes_help_content | "${PAGER:-less}" -R\
    fi

/show_docker_help_content | smart_pager/ c\
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then\
        show_docker_help_content\
    else\
        show_docker_help_content | "${PAGER:-less}" -R\
    fi

/show_cicd_help_content | smart_pager/ c\
    if [[ ! -t 1 ]] || [[ -n "${PAGER:-}" && "$PAGER" == "cat" ]]; then\
        show_cicd_help_content\
    else\
        show_cicd_help_content | "${PAGER:-less}" -R\
    fi
' "$file"

rm "${file}.tmp"
echo "Fixed all smart_pager calls"
