# ZZCOLLAB Practical Guides

This directory contains practical how-to guides for using ZZCOLLAB.

## Available Guides

### ✅ Completed

- **[workflow.md](workflow.md)** - Daily development workflow
  - Host vs container operations
  - Common workflow patterns
  - File persistence
  - Project lifecycle examples
  - Troubleshooting

### 🔄 In Progress

The following guides are being migrated from `modules/help_guides.sh` to markdown:

- **troubleshooting.md** - Common issues and solutions
- **config.md** - Configuration system guide
- **dotfiles.md** - Dotfiles setup and customization
- **renv.md** - Package management with renv
- **docker.md** - Docker essentials
- **cicd.md** - CI/CD workflows and automation

## Usage

### Command Line

Access guides via zzcollab help system:

```bash
zzcollab --help workflow
zzcollab --help troubleshooting
zzcollab --help config
# etc.
```

### Direct Access

Read the markdown files directly:

```bash
# With markdown renderer (recommended)
glow docs/guides/workflow.md
mdcat docs/guides/workflow.md

# Plain text
cat docs/guides/workflow.md
less docs/guides/workflow.md
```

## Guide Format

All guides follow this structure:

```markdown
# Guide Title

## Overview
Brief introduction

## Main Content
Organized sections with:
- Code examples
- Common patterns
- Best practices
- Troubleshooting

## See Also
Links to related guides
```

## Migration Status

**Total Content**: 3,596 lines in `modules/help_guides.sh`

**Progress**:
- ✅ workflow.md - 375 lines (Complete)
- ⏳ 7 remaining guides (~3,200 lines)

**See**: `docs/FIX4_DOCUMENTATION_MIGRATION_PLAN.md` for full migration plan

## Contributing

When migrating guides:
1. Extract content from `show_*_help_content()` functions
2. Convert heredoc to proper markdown
3. Add front matter if needed
4. Validate markdown syntax
5. Update this README
6. Update help_guides.sh to read markdown

## Dependencies

### Optional (Better Rendering)
- [glow](https://github.com/charmbracelet/glow) - Terminal markdown renderer
- [mdcat](https://github.com/swsnr/mdcat) - Alternative renderer

### Fallback
- `cat` - Basic text display (always available)
