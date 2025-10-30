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
echo "Monitoring progress (will exit on first failure)..."
echo ""

# Monitor builds and exit immediately on first failure
LAST_COMPLETED=0
while true; do
    COMPLETED=0
    FAILED_PROFILE=""

    for profile in "${PROFILES[@]}"; do
        # Check if this build has completed
        if [ -f /tmp/result_${profile}.txt ]; then
            ((COMPLETED++))
            result=$(cat /tmp/result_${profile}.txt)

            # If any build failed, exit immediately
            if [[ $result == *"FAILED"* ]]; then
                FAILED_PROFILE=$profile
                break 2
            fi

            # Print success as soon as we see it
            if [[ $result == *"SUCCESS"* ]] && [ $COMPLETED -gt $LAST_COMPLETED ]; then
                echo "  ✓ $profile"
            fi
        fi
    done

    LAST_COMPLETED=$COMPLETED

    # Exit if all completed successfully
    if [ $COMPLETED -eq ${#PROFILES[@]} ]; then
        break
    fi

    sleep 2
done

# If a build failed, print error and exit
if [ -n "$FAILED_PROFILE" ]; then
    echo ""
    echo "=========================================="
    echo "BUILD FAILED: $FAILED_PROFILE"
    echo "=========================================="
    echo ""
    echo "Error log (last 50 lines):"
    tail -50 /tmp/build_${FAILED_PROFILE}.log
    echo ""
    echo "Full log: /tmp/build_${FAILED_PROFILE}.log"

    # Kill remaining builds
    echo ""
    echo "Terminating remaining builds..."
    for profile in "${PROFILES[@]}"; do
        if [ -n "${PIDS[$profile]}" ]; then
            kill ${PIDS[$profile]} 2>/dev/null
        fi
    done

    # Cleanup
    rm -f /tmp/result_*.txt /tmp/build_*.log
    exit 1
fi

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
