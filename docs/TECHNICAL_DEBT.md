# Technical Debt and Future Improvements

This document tracks known technical debt and planned improvements for ZZCOLLAB.

## Template Selection Logic Duplication (MED-3)

**Status**: Documented, not yet refactored
**Priority**: Medium
**Effort**: 2-3 hours

### Problem

Template selection logic is scattered across multiple modules:

1. `modules/cli.sh::get_template()` (lines 530-547) - General template selection with Dockerfile logic
2. `modules/docker.sh::get_dockerfile_template()` (lines 234-238) - Returns hardcoded "Dockerfile.unified"  
3. Actual selection logic inline in `create_docker_files()` (lines 312-320) - Real logic that's actually used

### Current Behavior

- `docker.sh::get_dockerfile_template()` is called but always returns `"Dockerfile.unified"`
- The real template selection happens inline with conditional logic for team images
- `cli.sh::get_template()` has Dockerfile logic that duplicates part of this

### Desired State

Create a centralized `templates.sh` module with:

```bash
get_dockerfile_template() {
    # Check for team setup
    if [[ -f ".zzcollab_team_setup" ]]; then
        echo "Dockerfile.personal.team"
        return 0
    fi
    
    # Standard unified template for solo developers
    echo "Dockerfile.unified"
}

get_description_template() {
    echo "DESCRIPTION"
}

get_workflow_template() {
    echo "unified/.github/workflows/render-paper.yml"
}
```

### Migration Plan

1. Create `modules/templates_selection.sh` or add to existing `templates.sh`
2. Move all template selection logic there with proper documentation
3. Update `docker.sh::create_docker_files()` to use centralized function
4. Remove duplicate logic from `cli.sh`
5. Add unit tests for template selection logic

### Impact

- **Risk**: Low (changes well-contained to template selection)
- **Benefit**: Single source of truth for template logic
- **Testing**: Affects Docker file creation, needs integration testing

## Other Technical Debt Items

### Variable Naming Consistency

**Status**: Partially addressed in MED-1
**Remaining**: Full codebase audit for UPPERCASE/lowercase consistency

### Error Message Formatting

**Status**: Completed in MED-2
**All error messages now use consistent "❌ Error:" prefix**

### Module Size

**Status**: To be addressed in MED-4
**Target**: Split `help_guides.sh` into smaller, focused modules

