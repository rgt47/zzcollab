#!/bin/bash
# Navigation Links Generator
# Creates one-letter symbolic links for quick directory navigation
# Usage: ./navigation_scripts.sh [--clean | -c]
#   --clean | -c : Remove all navigation links

# Function to clean up navigation links
cleanup_links() {
    echo "Removing navigation links..."
    rm -f a n f t s m e o p
    echo "All navigation links removed."
    exit 0
}

# Check for cleanup flag
if [[ "$1" == "--clean" || "$1" == "-c" ]]; then
    cleanup_links
fi

echo "Creating navigation symbolic links (rrtools structure)..."

# Remove existing navigation links first
rm -f a n f t s m e o p

# Create symbolic links for existing directories
if [[ -d "./analysis/data" ]]; then
    ln -sf "./analysis/data" a
    echo "Created: a → ./analysis/data"
fi

if [[ -d "./analysis" ]]; then
    ln -sf "./analysis" n
    echo "Created: n → ./analysis"
fi

if [[ -d "./analysis/figures" ]]; then
    ln -sf "./analysis/figures" f
    echo "Created: f → ./analysis/figures"
fi

if [[ -d "./analysis/tables" ]]; then
    ln -sf "./analysis/tables" t
    echo "Created: t → ./analysis/tables"
fi

if [[ -d "./analysis/scripts" ]]; then
    ln -sf "./analysis/scripts" s
    echo "Created: s → ./analysis/scripts"
fi

if [[ -d "./man" ]]; then
    ln -sf "./man" m
    echo "Created: m → ./man"
fi

if [[ -d "./tests" ]]; then
    ln -sf "./tests" e
    echo "Created: e → ./tests"
fi

if [[ -d "./docs" ]]; then
    ln -sf "./docs" o
    echo "Created: o → ./docs"
fi

if [[ -d "./analysis/paper" ]]; then
    ln -sf "./analysis/paper" p
    echo "Created: p → ./analysis/paper"
fi

echo "Navigation symbolic links created successfully!"
echo "Usage: cd a (data), cd n (analysis), cd p (paper), etc."
echo "To remove all links: ./navigation_scripts.sh --clean"
