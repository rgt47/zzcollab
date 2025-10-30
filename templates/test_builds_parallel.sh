#!/bin/bash
# Test build all 11 static Dockerfiles IN PARALLEL

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
echo "RUNNING IN PARALLEL"
echo "=========================================="
echo ""

# Array to store background PIDs
declare -A PIDS

# Start all builds in parallel
for profile in "${PROFILES[@]}"; do
    echo "Starting: $profile"
    (
        if DOCKER_BUILDKIT=1 docker build \
            -f Dockerfile.$profile \
            -t zzcollab-test:$profile \
            --build-arg R_VERSION=latest \
            . > /tmp/build_${profile}.log 2>&1; then
            echo "✓ SUCCESS: $profile" > /tmp/result_${profile}.txt
        else
            echo "✗ FAILED: $profile" > /tmp/result_${profile}.txt
        fi
    ) &
    PIDS[$profile]=$!
done

echo ""
echo "All 11 builds started in parallel!"
echo "Monitoring progress..."
echo ""

# Wait for all builds to complete
for profile in "${PROFILES[@]}"; do
    wait ${PIDS[$profile]}
done

echo ""
echo "=========================================="
echo "All builds completed!"
echo "=========================================="
echo ""

# Collect results
SUCCESS=()
FAILED=()

for profile in "${PROFILES[@]}"; do
    result=$(cat /tmp/result_${profile}.txt 2>/dev/null)
    if [[ $result == *"SUCCESS"* ]]; then
        SUCCESS+=("$profile")
        echo "$result"
    else
        FAILED+=("$profile")
        echo "$result (log: /tmp/build_${profile}.log)"
    fi
    rm -f /tmp/result_${profile}.txt
done

echo ""
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
