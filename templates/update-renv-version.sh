#!/usr/bin/env bash
#==============================================================================
# update-renv-version.sh
# Update renv.lock to use r2u renv version from Docker base image
#
# Usage: ./update-renv-version.sh BASE_IMAGE R_VERSION
# Example: ./update-renv-version.sh rocker/tidyverse 4.5.1
#==============================================================================

set -euo pipefail

BASE_IMAGE="${1:-}"
R_VERSION="${2:-latest}"

if [[ -z "$BASE_IMAGE" ]]; then
    echo "Usage: $0 BASE_IMAGE R_VERSION" >&2
    echo "Example: $0 rocker/tidyverse 4.5.1" >&2
    exit 1
fi

RENV_LOCK="renv.lock"
FULL_IMAGE="${BASE_IMAGE}:${R_VERSION}"

# Check if renv.lock exists
if [[ ! -f "$RENV_LOCK" ]]; then
    echo "ℹ️  renv.lock not found, skipping renv version update"
    exit 0
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "⚠️  jq not found, skipping renv version update"
    echo "   Install jq for automatic renv version detection: brew install jq"
    exit 0
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker not found, skipping renv version update"
    exit 0
fi

echo "🔍 Querying r2u renv version from $FULL_IMAGE..."

# Query renv version from Docker image
RENV_VERSION=$(docker run --rm "$FULL_IMAGE" R --slave -e "cat(as.character(packageVersion('renv')))" 2>/dev/null || true)

if [[ -z "$RENV_VERSION" ]]; then
    echo "⚠️  Could not detect renv version from Docker image, skipping update"
    exit 0
fi

echo "✓ Detected r2u renv version: $RENV_VERSION"

# Check if renv.lock already has this version
CURRENT_VERSION=$(jq -r '.Packages.renv.Version // empty' "$RENV_LOCK" 2>/dev/null || true)

if [[ "$CURRENT_VERSION" == "$RENV_VERSION" ]]; then
    echo "✓ renv.lock already uses version $RENV_VERSION"
    exit 0
fi

# Update renv.lock using jq
TEMP_LOCK=$(mktemp)

jq --arg ver "$RENV_VERSION" \
   '.Packages.renv.Version = $ver | .Packages.renv.Source = "Repository" | .Packages.renv.Repository = "CRAN"' \
   "$RENV_LOCK" > "$TEMP_LOCK"

if [[ $? -eq 0 ]]; then
    mv "$TEMP_LOCK" "$RENV_LOCK"
    echo "✅ Updated renv.lock: $CURRENT_VERSION → $RENV_VERSION"
    echo "   Performance: ~60x faster (binary install vs source compile)"
else
    rm -f "$TEMP_LOCK"
    echo "❌ Failed to update renv.lock"
    exit 1
fi
