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


---

## Large Module Size - help_guides.sh (MED-4)

**Status**: Documented, not yet refactored
**Priority**: Medium  
**Effort**: 3-4 hours
**File Size**: 3597 lines (exceeds recommended 500-line limit)

### Problem

`modules/help_guides.sh` is extremely large (3597 lines), making it difficult to:
- Navigate and maintain
- Test individual components
- Load efficiently
- Follow single responsibility principle

### Current Structure

The module contains three main help content functions:
1. `show_workflow_help()` - Daily development workflow guidance
2. `show_troubleshooting_help()` - Common issues and solutions
3. `show_config_help()` - Configuration system documentation

Each function includes extensive documentation content (hundreds of lines of HERE documents).

### Proposed Split

Create focused modules:

```
modules/help/
├── workflow.sh         (~1200 lines) - Daily workflow guidance
├── troubleshooting.sh  (~1200 lines) - Troubleshooting guides
└── configuration.sh    (~1200 lines) - Configuration documentation
```

### Migration Plan

1. Create `modules/help/` directory
2. Split content:
   - Move `show_workflow_help*` to `workflow.sh`
   - Move `show_troubleshooting_help*` to `troubleshooting.sh`
   - Move `show_config_help*` to `configuration.sh`
3. Create `modules/help.sh` as orchestrator that loads submodules
4. Update `zzcollab.sh` to load help system properly
5. Add module dependency checks
6. Test all help commands work correctly

### Alternative Approach

Instead of shell modules, convert help content to Markdown files:

```
docs/help/
├── workflow.md
├── troubleshooting.md  
└── configuration.md
```

Then create simple shell functions that display these files using `less` or `cat`.

**Benefits**:
- Easier to edit (Markdown vs HERE documents)
- Better for version control (smaller diffs)
- Can be viewed outside zzcollab
- Reduces shell code size significantly

### Impact

- **Risk**: Medium (affects help system, user-facing)
- **Benefit**: Much easier maintenance, better code organization
- **Testing**: Verify all help commands display correctly

### Recommendation

Use the Markdown approach:
1. Convert HERE document content to Markdown files
2. Create simple display functions
3. Reduces `help_guides.sh` from 3597 to ~200 lines
4. Makes documentation more accessible

