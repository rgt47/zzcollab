# ZZCOLLAB Practical Guides

This directory contains practical how-to guides for using ZZCOLLAB.

## Available Guides

- **[workflow.md](workflow.md)** - Daily development workflow
  - Host vs container operations
  - Common workflow patterns
  - File persistence
  - Project lifecycle examples
  - Troubleshooting
- **troubleshooting.md** - Common issues and solutions
- **config.md** - Configuration system guide
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

## Contributing

When editing or adding guides:
1. Write the content as plain markdown in this directory
2. Follow the guide format above
3. Validate markdown syntax
4. Update this README to list the new guide

## Dependencies

### Optional (Better Rendering)
- [glow](https://github.com/charmbracelet/glow) - Terminal markdown renderer
- [mdcat](https://github.com/swsnr/mdcat) - Alternative renderer

### Fallback
- `cat` - Basic text display (always available)
