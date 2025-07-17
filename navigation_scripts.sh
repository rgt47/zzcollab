#!/bin/bash
# Navigation Scripts Generator
# Creates one-letter shell scripts for quick directory navigation
# Usage: ./navigation_scripts.sh

echo "Creating navigation scripts..."

# Remove existing navigation scripts
rm -f a n f t s m e o c p

# Create navigation scripts for existing directories
if [[ -d "./data" ]]; then
    cat > a << 'SCRIPT'
#!/bin/bash
cd ./data
exec "$SHELL"
SCRIPT
    chmod +x a
    echo "Created: a → ./data"
fi

if [[ -d "./analysis" ]]; then
    cat > n << 'SCRIPT'
#!/bin/bash
cd ./analysis
exec "$SHELL"
SCRIPT
    chmod +x n
    echo "Created: n → ./analysis"
fi

if [[ -d "./analysis/figures" ]]; then
    cat > f << 'SCRIPT'
#!/bin/bash
cd ./analysis/figures
exec "$SHELL"
SCRIPT
    chmod +x f
    echo "Created: f → ./analysis/figures"
fi

if [[ -d "./analysis/tables" ]]; then
    cat > t << 'SCRIPT'
#!/bin/bash
cd ./analysis/tables
exec "$SHELL"
SCRIPT
    chmod +x t
    echo "Created: t → ./analysis/tables"
fi

if [[ -d "./scripts" ]]; then
    cat > s << 'SCRIPT'
#!/bin/bash
cd ./scripts
exec "$SHELL"
SCRIPT
    chmod +x s
    echo "Created: s → ./scripts"
fi

if [[ -d "./man" ]]; then
    cat > m << 'SCRIPT'
#!/bin/bash
cd ./man
exec "$SHELL"
SCRIPT
    chmod +x m
    echo "Created: m → ./man"
fi

if [[ -d "./tests" ]]; then
    cat > e << 'SCRIPT'
#!/bin/bash
cd ./tests
exec "$SHELL"
SCRIPT
    chmod +x e
    echo "Created: e → ./tests"
fi

if [[ -d "./docs" ]]; then
    cat > o << 'SCRIPT'
#!/bin/bash
cd ./docs
exec "$SHELL"
SCRIPT
    chmod +x o
    echo "Created: o → ./docs"
fi

if [[ -d "./archive" ]]; then
    cat > c << 'SCRIPT'
#!/bin/bash
cd ./archive
exec "$SHELL"
SCRIPT
    chmod +x c
    echo "Created: c → ./archive"
fi

if [[ -d "./analysis/report" ]]; then
    cat > p << 'SCRIPT'
#!/bin/bash
cd ./analysis/report
exec "$SHELL"
SCRIPT
    chmod +x p
    echo "Created: p → ./analysis/report"
fi

echo "Navigation scripts created successfully!"
echo "Usage: ./a (data), ./n (analysis), ./p (report), etc."
