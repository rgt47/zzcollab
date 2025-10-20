# Fix #4: Documentation Migration Plan

## Status: IN PROGRESS

## Objective
Move 3,596 lines of documentation from `modules/help_guides.sh` to markdown files in `docs/guides/`.

## Benefits
- **Easier editing**: Markdown files are easier to edit than shell heredocs
- **Better version control**: Git diffs work better on markdown
- **Reusability**: Documentation can be rendered in multiple formats
- **Reduced shell script size**: help_guides.sh is 32% of total shell codebase
- **Maintainability**: Separate concerns (logic vs documentation)

## Current Structure

### help_guides.sh Content (3,596 lines)
Functions and topics:
- `show_workflow_help()` / `show_workflow_help_content()`
- `show_troubleshooting_help()` / `show_troubleshooting_help_content()`
- `show_config_help()` / `show_config_help_content()`
- `show_dotfiles_help()` / `show_dotfiles_help_content()`
- `show_renv_help()` / `show_renv_help_content()`
- `show_docker_help()` / `show_docker_help_content()`
- `show_cicd_help()` / `show_cicd_help_content()`
- `show_build_modes_help_content()` (deprecated)

## Migration Plan

### Phase 1: Create Directory Structure ✅
```bash
docs/guides/
├── README.md          # Guide index
├── quickstart.md      # Getting started
├── workflow.md        # Daily workflow
├── troubleshooting.md # Common issues
├── config.md          # Configuration
├── dotfiles.md        # Dotfiles setup
├── renv.md            # Package management
├── docker.md          # Docker usage
└── cicd.md            # CI/CD workflows
```

### Phase 2: Extract Content to Markdown
For each guide:
1. Extract heredoc content from `show_*_help_content()` functions
2. Convert to proper markdown (remove EOF markers, fix formatting)
3. Add front matter for metadata
4. Validate markdown syntax
5. Save to appropriate file

Example transformation:
```bash
# Before (in shell script):
show_workflow_help_content() {
    cat << 'EOF'
# Daily Workflow

Content here...
EOF
}

# After (in markdown file):
---
title: Daily Workflow
category: guides
---

# Daily Workflow

Content here...
```

### Phase 3: Update help_guides.sh
Modify functions to read and render markdown files:

```bash
show_workflow_help() {
    local guide_file="$ZZCOLLAB_GUIDES_DIR/workflow.md"

    if [[ -f "$guide_file" ]]; then
        # Render markdown (could use mdcat, glow, or basic cat)
        if command_exists glow; then
            glow "$guide_file"
        elif command_exists mdcat; then
            mdcat "$guide_file"
        else
            cat "$guide_file"
        fi
    else
        log_error "Guide not found: $guide_file"
        return 1
    fi
}
```

### Phase 4: Testing
1. Test each help command:
   ```bash
   zzcollab --help workflow
   zzcollab --help troubleshooting
   zzcollab --help config
   # ... etc
   ```

2. Verify rendered output is readable
3. Test with and without markdown renderers (glow, mdcat)
4. Ensure fallback to plain text works

### Phase 5: Update Documentation
1. Update CLAUDE.md to reflect new structure
2. Update README.md guide references
3. Add docs/guides/README.md index
4. Update ZZCOLLAB_USER_GUIDE.md references

## Dependencies

Optional (for better rendering):
- `glow` - Terminal markdown renderer (recommended)
- `mdcat` - Alternative markdown renderer
- `pandoc` - For advanced rendering

Fallback: Basic `cat` command (always available)

## Implementation Checklist

- [x] Phase 1: Create docs/guides/ directory
- [ ] Phase 2: Extract guides to markdown
  - [ ] quickstart.md
  - [ ] workflow.md
  - [ ] troubleshooting.md
  - [ ] config.md
  - [ ] dotfiles.md
  - [ ] renv.md
  - [ ] docker.md
  - [ ] cicd.md
- [ ] Phase 3: Update help_guides.sh functions
- [ ] Phase 4: Test all help commands
- [ ] Phase 5: Update documentation references
- [ ] Commit and push changes

## Estimated Effort
- Total: 16 hours
- Phase 2: 8 hours (extraction and conversion)
- Phase 3: 4 hours (rewrite functions)
- Phase 4: 2 hours (testing)
- Phase 5: 2 hours (documentation updates)

## Status: READY TO PROCEED
All prerequisites complete. Ready for content extraction phase.

## Notes
- Preserve all existing content (no deletions)
- Maintain backward compatibility during transition
- Test thoroughly before removing old heredoc content
- Consider adding guide validation to CI/CD
