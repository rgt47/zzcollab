#!/bin/bash
##############################################################################
# FUNCTION SIZE CHECKER
##############################################################################
# 
# PURPOSE: Monitor function sizes to prevent regression to oversized functions
#          Ensures adherence to single responsibility principle
#
# USAGE: ./scripts/check-function-sizes.sh [--max-lines N] [--verbose]
##############################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly MAX_FUNCTION_LINES="${1:-60}"  # Default max lines per function

# Colors for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m' # No Color

# Parse arguments
VERBOSE=false
MAX_LINES=60

while [[ $# -gt 0 ]]; do
    case $1 in
        --max-lines)
            MAX_LINES="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--max-lines N] [--verbose]"
            echo "  --max-lines N    Maximum allowed lines per function (default: 60)"
            echo "  --verbose        Show all functions, not just oversized ones"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "🔍 Checking function sizes (max: $MAX_LINES lines)..."
echo

# Find all bash script files
OVERSIZED_FUNCTIONS=()
TOTAL_FUNCTIONS=0

while IFS= read -r -d '' file; do
    # Skip if not a bash script
    if ! head -1 "$file" | grep -q "^#!/bin/bash"; then
        continue
    fi
    
    echo "📁 $(basename "$file"):"
    
    # Extract functions and their line counts  
    while IFS= read -r line; do
        # Extract function name and start line
        func_name=$(echo "$line" | sed 's/.*:\([a-zA-Z_][a-zA-Z0-9_]*\)().*/\1/')
        start_line=$(echo "$line" | cut -d: -f1)
            
            # Find the end of the function by counting braces
            end_line=$(awk -v start="$start_line" '
                NR >= start {
                    if ($0 ~ /\{/) braces += gsub(/\{/, "", $0)
                    if ($0 ~ /\}/) braces -= gsub(/\}/, "", $0)
                    if (braces == 0 && NR > start) {
                        print NR
                        exit
                    }
                }
            ' "$file")
            
            if [[ -n $end_line ]]; then
                func_lines=$((end_line - start_line + 1))
                TOTAL_FUNCTIONS=$((TOTAL_FUNCTIONS + 1))
                
                if [[ $func_lines -gt $MAX_LINES ]]; then
                    printf "  ${RED}❌ %s${NC}: %d lines (exceeds %d)\n" "$func_name" "$func_lines" "$MAX_LINES"
                    OVERSIZED_FUNCTIONS+=("$(basename "$file"):$func_name:$func_lines")
                elif [[ $VERBOSE == true ]]; then
                    printf "  ${GREEN}✅ %s${NC}: %d lines\n" "$func_name" "$func_lines"
                fi
            fi
        fi
    done < <(grep -n "^[a-zA-Z_][a-zA-Z0-9_]*()[[:space:]]*{[[:space:]]*$" "$file")
    
    echo
done < <(find "$PROJECT_ROOT" -name "*.sh" -type f -print0)

# Summary
echo "📊 SUMMARY:"
echo "  Total functions analyzed: $TOTAL_FUNCTIONS"

if [[ ${#OVERSIZED_FUNCTIONS[@]} -eq 0 ]]; then
    printf "  ${GREEN}✅ No oversized functions found!${NC}\n"
    echo "  All functions adhere to single responsibility principle."
    exit 0
else
    printf "  ${RED}❌ Found ${#OVERSIZED_FUNCTIONS[@]} oversized functions:${NC}\n"
    for func in "${OVERSIZED_FUNCTIONS[@]}"; do
        echo "    - $func"
    done
    echo
    echo "💡 Consider breaking down these functions into smaller, focused functions."
    echo "   Each function should have a single, clear responsibility."
    exit 1
fi