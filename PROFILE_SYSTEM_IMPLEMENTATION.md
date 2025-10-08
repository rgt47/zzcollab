# Profile System Implementation Status

## Completed ✅

### 1. CLI Flags Added
- ✅ `--profile-name NAME` - Complete profile shortcut
- ✅ `--libs BUNDLE` - System dependencies bundle
- ✅ `--pkgs BUNDLE` - R packages bundle
- ✅ `--tag TAG` - Docker image tag for variants
- ✅ `--list-profiles` - List available profiles
- ✅ `--list-libs` - List library bundles
- ✅ `--list-pkgs` - List package bundles

### 2. Deprecation Warnings
- ✅ `-I, --interface` → Deprecated (use `--tag`)
- ✅ `-B, --init-base-image` → Deprecated (use `--profile-name` or composition)

### 3. Bundle Definitions
- ✅ Created `templates/bundles.yaml` with:
  - Library bundles: none, minimal, geospatial, bioinfo, modeling, publishing, alpine
  - Package bundles: essential, tidyverse, modeling, bioinfo, geospatial, publishing, shiny
  - Complete profiles: minimal, rstudio, analysis, modeling, bioinformatics, geospatial, publishing, alpine_minimal, alpine_analysis
  - Compatibility rules for validation

### 4. Validation Module
- ✅ Created `modules/profile_validation.sh` with:
  - `expand_profile_name()` - Expands --profile-name to base+libs+pkgs
  - `validate_profile_combination()` - Checks compatibility
  - `suggest_compatible_combination()` - Provides helpful fixes
  - `apply_smart_defaults()` - Auto-detects from base image
  - `validate_team_member_flags()` - Blocks invalid flags for team members

### 5. Dockerfile Updates
- ✅ Added `ARG LIBS_BUNDLE=minimal`
- ✅ Added `ARG PKGS_BUNDLE=""`

## Remaining Work 🚧

### 1. Dockerfile Bundle Installation Logic
Need to add conditional installation based on bundles:

```dockerfile
# Install system dependencies based on LIBS_BUNDLE
RUN if [ "${LIBS_BUNDLE}" = "minimal" ]; then \
        apt-get update && apt-get install -y \
            git curl wget libxml2-dev libcurl4-openssl-dev libssl-dev; \
    elif [ "${LIBS_BUNDLE}" = "geospatial" ]; then \
        apt-get update && apt-get install -y \
            gdal-bin proj-bin libgeos-dev libproj-dev libgdal-dev; \
    # ... etc for all bundles
    fi

# Install R packages based on PKGS_BUNDLE (or fallback to PACKAGE_MODE)
RUN BUNDLE="${PKGS_BUNDLE:-$PACKAGE_MODE}" && \
    if [ "$BUNDLE" = "essential" ]; then \
        Rscript -e "install.packages(c('renv', 'devtools', 'usethis'))"; \
    elif [ "$BUNDLE" = "bioinfo" ]; then \
        Rscript -e "install.packages('BiocManager')" && \
        Rscript -e "BiocManager::install(c('DESeq2', 'edgeR'))"; \
    # ... etc for all bundles
    fi
```

### 2. Team Initialization Updates
In `modules/team_init.sh`, need to:

```bash
# In build_single_team_image():
docker build -f "$dockerfile" \
    --build-arg BASE_IMAGE="$base_image" \
    --build-arg LIBS_BUNDLE="${LIBS_BUNDLE:-minimal}" \
    --build-arg PKGS_BUNDLE="${PKGS_BUNDLE:-}" \
    --build-arg PACKAGE_MODE="$BUILD_MODE" \
    -t "${TEAM_NAME}/${PROJECT_NAME}_core:${IMAGE_TAG:-latest}" \
    "$context"
```

### 3. Discovery Commands Implementation
Need to add in main `zzcollab.sh`:

```bash
if [[ "$LIST_PROFILES" == "true" ]]; then
    echo "Available Profiles:"
    yq eval '.profiles | to_entries | .[] | "  " + .key + " - " + .value.description' \
        "$TEMPLATES_DIR/bundles.yaml"
    exit 0
fi

if [[ "$LIST_LIBS" == "true" ]]; then
    echo "Available Library Bundles:"
    yq eval '.library_bundles | to_entries | .[] | "  " + .key + " - " + .value.description' \
        "$TEMPLATES_DIR/bundles.yaml"
    exit 0
fi

if [[ "$LIST_PKGS" == "true" ]]; then
    echo "Available Package Bundles:"
    yq eval '.package_bundles | to_entries | .[] | "  " + .key + " - " + .value.description' \
        "$TEMPLATES_DIR/bundles.yaml"
    exit 0
fi
```

### 4. Main Workflow Integration
In main `zzcollab.sh`, after CLI parsing:

```bash
# Load profile validation module
source "${MODULES_DIR}/profile_validation.sh"

# Expand profile if specified
if [[ -n "$PROFILE_NAME" ]]; then
    expand_profile_name "$PROFILE_NAME"
fi

# Apply smart defaults if needed
if [[ -n "$BASE_IMAGE" ]]; then
    apply_smart_defaults "$BASE_IMAGE"
fi

# Validate combination
validate_profile_combination "$BASE_IMAGE" "$LIBS_BUNDLE" "$PKGS_BUNDLE"

# Validate team member restrictions
if [[ -n "$TEAM_NAME" ]] && [[ "$INIT_MODE" != "true" ]]; then
    validate_team_member_flags "true"
fi
```

### 5. Help Documentation Updates
Need to update `modules/help.sh`:
- Add `--profile-name`, `--libs`, `--pkgs`, `--tag` to main help
- Update examples to show new flags
- Add `--help-profiles` section explaining profile system
- Document discovery commands (`--list-*`)

### 6. Configuration System Integration
Add to config.yaml defaults:
```yaml
defaults:
  profile_name: ""          # Default profile to use
  libs_bundle: "minimal"    # Default library bundle
  pkgs_bundle: "essential"  # Default package bundle
  image_tag: "latest"       # Default image tag
```

### 7. Personal Dockerfile Generation
For team members adding packages, generate:
```dockerfile
FROM ${TEAM_NAME}/${PROJECT_NAME}_core:${IMAGE_TAG}

# Install additional R packages from PKGS_BUNDLE
RUN if [ "${PKGS_BUNDLE}" = "modeling" ]; then \
        Rscript -e "install.packages(c('tidymodels', 'xgboost'))"; \
    fi

# Personal dotfiles
COPY dotfiles/ /home/analyst/
```

## Usage Examples (When Complete)

### Solo Developer
```bash
# Using profile
zzcollab --profile-name bioinformatics -G

# Using composition
zzcollab -b bioconductor/bioconductor_docker --libs bioinfo --pkgs bioinfo -G

# Discovery
zzcollab --list-profiles
zzcollab --list-libs
zzcollab --list-pkgs
```

### Team Lead
```bash
# Create primary team image
zzcollab -i -t genomicslab -p study --profile-name bioinformatics -G

# Create additional variant
zzcollab -i -t genomicslab -p study --profile-name rstudio --tag rstudio
```

### Team Member
```bash
# Use default
zzcollab -t genomicslab -p study

# Use variant
zzcollab -t genomicslab -p study --tag rstudio

# Add packages
zzcollab -t genomicslab -p study --pkgs modeling
```

## Testing Checklist

- [ ] Test --profile-name expansion
- [ ] Test compatibility validation (alpine + bioinfo should fail)
- [ ] Test smart defaults (alpine base auto-sets alpine libs)
- [ ] Test team member flag blocking
- [ ] Test discovery commands
- [ ] Test tag-based image selection
- [ ] Test deprecated flag warnings
- [ ] Test solo workflow
- [ ] Test team lead workflow
- [ ] Test team member workflow

## Files Modified

1. ✅ `modules/cli.sh` - Added flags, deprecated old ones
2. ✅ `templates/bundles.yaml` - Created bundle definitions
3. ✅ `modules/profile_validation.sh` - Created validation module
4. 🚧 `templates/Dockerfile.unified` - Partial (added ARGs, need installation logic)
5. ⏳ `modules/team_init.sh` - Need to add bundle support to build
6. ⏳ `zzcollab.sh` - Need to integrate validation and discovery
7. ⏳ `modules/help.sh` - Need to update documentation
8. ⏳ `modules/config.sh` - Need to add config defaults

## Next Steps

Priority order:
1. Complete Dockerfile.unified bundle installation logic
2. Update team_init.sh to pass bundle args
3. Integrate validation in main zzcollab.sh
4. Add discovery commands
5. Update help documentation
6. Add config system integration
7. Test all workflows
