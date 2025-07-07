# ZZCOLLAB Project Context

## Package Name Change
- **Former name**: zzrrtools  
- **Current name**: zzcollab
- **Focus**: Research collaboration framework (not generic tools)
- **Unique value**: Team-based reproducible research with Docker automation

## Recent Updates Completed
- ✅ Complete package rebrand from zzrrtools → zzcollab
- ✅ Updated all documentation, scripts, and configuration files
- ✅ GitHub repository renamed to zzcollab
- ✅ White paper updated in ~/prj/p25/index.qmd
- ✅ Added R options CI monitoring (check_rprofile_options.R)
- ✅ Created zzcollab-init-team automation script
- ✅ Fixed Dockerfile.pluspackages to match workflow.md documentation

## Key Scripts and Tools
- **zzcollab-init-team**: Automated team setup script (replaces 10+ manual steps)
- **check_rprofile_options.R**: Monitors critical R options for changes
- **workflow.md**: Complete team collaboration documentation
- **Dockerfile.pluspackages**: Team-customizable Docker template

## Testing Commands
- `npm run lint` / `npm run typecheck` - Run when available
- Ask user for lint/typecheck commands if not found in package.json

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.