```markdown
# CLAUDE.md Regeneration Git Hooks Setup Guide

## Overview
This guide merges instructions for creating a pre-commit Git hook to automatically regenerate `CLAUDE.md` files in R projects (or any codebase) using Claude Code CLI. The hook scans project files, optionally merges global/shared `CLAUDE.md` context, and updates the local file before each commit. Includes repo-level, user-level (global), and global-shared memory integration.

## 1. Repo-Level Pre-Commit Hook
Place this script in `.git/hooks/pre-commit` to regenerate `CLAUDE.md` on every commit in a single repo.

```
#!/bin/bash
set -e

# Path to Claude CLI (adjust if needed)
CLAUDE_CLI="claude"

# Project files/directories to scan (customize for your R package)
SCAN_PATHS="DESCRIPTION R/ vignettes/ tests/ README.md"

# Global/shared CLAUDE.md (optional - uncomment and adjust path)
GLOBAL_CLAUDE_MD="$HOME/prj/d07/zzcollab/CLAUDE.md"
GLOBAL_CONTENT=""
if [ -f "$GLOBAL_CLAUDE_MD" ]; then
  GLOBAL_CONTENT=$(cat "$GLOBAL_CLAUDE_MD")
fi

# Temporary output file
NEW_CLAUDE_MD="CLAUDE.new.md"

# Prompt for Claude to generate updated CLAUDE.md
PROMPT="Scan the following project files and update CLAUDE.md accordingly. Preserve manual notes and sections tagged 'Manual Notes'.

Project files/dirs: $SCAN_PATHS"

if [ -n "$GLOBAL_CONTENT" ]; then
  PROMPT="$PROMPT

Global shared memory (from $GLOBAL_CLAUDE_MD):
$GLOBAL_CONTENT"
fi

PROMPT="$PROMPT

Generate complete refreshed CLAUDE.md content."

# Run Claude CLI headless, capture output
$CLAUDE_CLI -p "$PROMPT" > "$NEW_CLAUDE_MD"

# Replace CLAUDE.md if generation succeeded
if [ -s "$NEW_CLAUDE_MD" ]; then
  mv "$NEW_CLAUDE_MD" "CLAUDE.md"
  git add CLAUDE.md
  echo "✓ Updated CLAUDE.md from project files"
else
  echo "⚠ Generated CLAUDE.md empty, keeping existing"
  rm -f "$NEW_CLAUDE_MD"
fi

exit 0
```

**Setup**: `chmod +x .git/hooks/pre-commit`

## 2. User-Level (Global) Setup
Apply the hook across **all your repositories** using Git's template directory (recommended) or global hooks path.

### Option A: Git Template Directory (New Repos + Manual Install)
```
# Create global template
mkdir -p ~/.git-templates/hooks
cp .git/hooks/pre-commit ~/.git-templates/hooks/pre-commit  # Copy from any repo
chmod +x ~/.git-templates/hooks/pre-commit

# Enable globally
git config --global init.templateDir ~/.git-templates

# Install in existing repos
find ~/path/to/repos -name .git -type d -execdir git init \;
```

### Option B: Global Hooks Path (All Repos Instantly)
```
mkdir -p ~/.githooks
cp your-pre-commit-script ~/.githooks/pre-commit
chmod +x ~/.githooks/pre-commit
git config --global core.hooksPath ~/.githooks
```
⚠️ Overrides all local `.git/hooks/` - use cautiously.

## 3. Global/Shared CLAUDE.md Integration
The hook above automatically reads `~/prj/d07/zzcollab/CLAUDE.md` (or any path you set in `$GLOBAL_CLAUDE_MD`) and feeds its content to Claude as context when regenerating local `CLAUDE.md` files. This ensures:

- Shared workspace conventions (e.g., R dev workflows, reproducible research patterns)
- Personal preferences (renv, devtools, usethis patterns)
- Cross-project consistency

Claude merges global + local project context into each repo's `CLAUDE.md`.

## 4. Verification & Workflow
- **Test**: `git commit -m "test"` in any repo → see "✓ Updated CLAUDE.md"
- **Config check**: `git config --global --list | grep -E '(hooksPath|templateDir)'`
- **Customization**:
  - Adjust `$SCAN_PATHS` for your project structure
  - Modify `$PROMPT` for specific instructions
  - Add conditions to skip non-Claude projects (e.g., `! grep -q "R/" .git/HEAD`)

## Benefits for R Reproducible Research Packages
- Keeps `CLAUDE.md` always current with `R/`, `vignettes/`, `DESCRIPTION`
- Claude Code sessions instantly understand your workspace without re-explaining
- Global memory ensures consistent dev practices across projects
- Commits stay clean - no manual `CLAUDE.md` maintenance

**Save as `claude-md-git-hooks.md`** [web:54][web:56][web:59][web:73]
```

Copy the content above and save it as `claude-md-git-hooks.md` in your project or `~/prj/d07/zzcollab/` for reference.[1]

[1](https://stackoverflow.com/questions/427207/can-git-hook-scripts-be-managed-along-with-the-repository)
[2](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
[3](https://interrupt.memfault.com/blog/pre-commit)
[4](https://pre-commit.com)
[5](https://github.com/gabyx/Githooks-Docs)
[6](https://www.hatica.io/blog/pre-commit-git-hooks/)
[7](https://github.com/CompSciLauren/awesome-git-hooks)
[8](https://marmelab.com/blog/2024/02/27/git-hooks.html)
[9](https://git-scm.com/docs/githooks)
[10](https://www.reddit.com/r/javascript/comments/99wpuy/git_precommit_hook_to_ensure_code_documentation/)
