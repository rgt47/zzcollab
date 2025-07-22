#!/bin/bash

# Script to set up GitHub repository for png1

echo "Setting up GitHub repository..."

# Initialize git if not already done
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
fi

# Add all files
echo "Adding files..."
git add .

# Commit with message (only if there are changes to commit)
if ! git diff --cached --quiet; then
    echo "Creating commit..."
    git commit -m "Initial commit"
else
    echo "No changes to commit."
fi

# Create GitHub repo and push (only if repo doesn't exist)
if ! gh repo view png1 &>/dev/null; then
    echo "Creating GitHub repository..."
    gh repo create png1 --private --source=. --remote=origin --push
else
    echo "Repository already exists on GitHub."
fi

# Interactive collaborator invitation
while true; do
    read -p "Enter GitHub username to invite as collaborator (or press Enter to skip): " username
    
    if [ -z "$username" ]; then
        echo "Skipping collaborator invitation."
        break
    fi
    
    echo "Inviting $username as collaborator..."
    if gh api repos/rgt47/png1/collaborators/$username -X PUT -f permission=push &>/dev/null; then
        echo "Successfully invited $username!"
    else
        echo "Failed to invite $username. User may not exist or invitation failed."
    fi
    
    read -p "Add another collaborator? (y/n): " add_more
    if [[ ! "$add_more" =~ ^[Yy]$ ]]; then
        break
    fi
done

echo "GitHub setup complete!"
echo "Repository URL: https://github.com/rgt47/png1"