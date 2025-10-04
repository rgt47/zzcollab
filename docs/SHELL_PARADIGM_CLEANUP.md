# Shell Script Paradigm Cleanup Tasks

Remaining paradigm references in shell modules that need to be fixed.

## modules/cli.sh

**Line 480**: Remove PARADIGM from export
```bash
# OLD:
export TEAM_NAME PROJECT_NAME INTERFACE GITHUB_ACCOUNT DOCKERFILE_PATH PARADIGM

# NEW:
export TEAM_NAME PROJECT_NAME INTERFACE GITHUB_ACCOUNT DOCKERFILE_PATH
```

**Line 545**: Remove PARADIGM from debug output
```bash
# OLD:
echo "  PARADIGM: $PARADIGM"

# REMOVE THIS LINE
```

## modules/config.sh

**Line 443**: Remove PARADIGM fallback
```bash
# OLD:
[[ -z "$PARADIGM" && -n "$CONFIG_PARADIGM" ]] && PARADIGM="$CONFIG_PARADIGM"

# REMOVE THIS LINE
```

## modules/docker.sh

**Line 331**: Remove PARADIGM_GUIDE.md installation
```bash
# OLD:
if ! install_template "PARADIGM_GUIDE.md" "PARADIGM_GUIDE.md" "paradigm selection guide" "Created paradigm selection guide"; then

# This template no longer exists - remove the whole if block
```

**Lines 410-420**: Remove paradigm build args
```bash
# OLD:
# --build-arg PARADIGM: Pass research paradigm for paradigm-specific packages
#   - Optional: Adapts package installation to paradigm (analysis, manuscript, package)
#   - Defaults to empty if not specified
#   - Example: --build-arg PARADIGM="manuscript"
if [[ -n "$PARADIGM" ]]; then
    package_mode="paradigm:$PARADIGM"
    log_info "Using paradigm-specific packages: $PARADIGM"
fi

local docker_cmd="... --build-arg PARADIGM=\"${PARADIGM:-}\" ..."

# NEW:
# Remove paradigm build args entirely
# package_mode already set based on BUILD_MODE only

local docker_cmd="... --build-arg PACKAGE_MODE=\"$package_mode\" ..."
```

## modules/help.sh

**Lines 276-277**: Remove paradigm guidance section
```bash
# OLD:
📋 PARADIGM GUIDANCE:
After project creation, see PARADIGM_GUIDE.md for detailed information about:

# NEW:
📋 RESEARCH COMPENDIUM GUIDE:
After project creation, see README.md for detailed information about:
- Unified research compendium structure (Marwick et al. 2018)
- Tutorial examples: https://github.com/rgt47/zzcollab/tree/main/examples
```

## modules/templates.sh

**Line 179**: Update section header
```bash
# OLD:
# PARADIGM-SPECIFIC TEMPLATE FUNCTIONS

# NEW:
# UNIFIED PARADIGM TEMPLATE FUNCTIONS
```

Also search for any paradigm-specific template functions in this file and consolidate them.

## Summary of Changes

1. **cicd.sh**: Fixed workflow template selection (completed)
2. ⏳ **cli.sh**: Remove PARADIGM from exports and debug
3. ⏳ **config.sh**: Remove PARADIGM fallback
4. ⏳ **docker.sh**: Remove PARADIGM_GUIDE and paradigm build args
5. ⏳ **help.sh**: Update paradigm guidance section
6. ⏳ **templates.sh**: Update section headers and consolidate functions

## Testing After Changes

```bash
# Verify no PARADIGM references remain (except in comments explaining removal)
grep -rn "PARADIGM" modules/*.sh | grep -v "# OLD:" | grep -v "Unified paradigm"

# Should find zero results (or only explanatory comments)
```
