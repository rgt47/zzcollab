#!/bin/bash
# Test build all 11 static Dockerfiles

set -e

PROFILES=(
    "ubuntu_standard_minimal"
    "ubuntu_standard_analysis"
    "ubuntu_standard_publishing"
    "ubuntu_shiny_minimal"
    "ubuntu_shiny_analysis"
    "ubuntu_x11_minimal"
    "ubuntu_x11_analysis"
    "alpine_standard_minimal"
    "alpine_standard_analysis"
    "alpine_x11_minimal"
    "alpine_x11_analysis"
)

echo "=========================================="
echo "Testing builds for 11 static Dockerfiles"
echo "=========================================="
echo ""

SUCCESS=()
FAILED=()

for profile in "${PROFILES[@]}"; do
    echo "----------------------------------------"
    echo "Testing: $profile"
    echo "----------------------------------------"
    
    if DOCKER_BUILDKIT=1 docker build \
        -f Dockerfile.$profile \
        -t zzcollab-test:$profile \
        --build-arg R_VERSION=latest \
        . > /tmp/build_${profile}.log 2>&1; then
        echo "✓ SUCCESS: $profile"
        SUCCESS+=("$profile")
    else
        echo "✗ FAILED: $profile"
        FAILED+=("$profile")
        echo "  See log: /tmp/build_${profile}.log"
    fi
    echo ""
done

echo "=========================================="
echo "BUILD SUMMARY"
echo "=========================================="
echo "Successful: ${#SUCCESS[@]}/11"
for p in "${SUCCESS[@]}"; do
    echo "  ✓ $p"
done

if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo "Failed: ${#FAILED[@]}/11"
    for p in "${FAILED[@]}"; do
        echo "  ✗ $p"
        echo "    Log: /tmp/build_${p}.log"
    done
    exit 1
else
    echo ""
    echo "All builds successful!"
    exit 0
fi
