#!/bin/bash

# Simple script to fetch PR to local branch
# Usage: ./fetch_pr_simple.sh [pr_number]

set -e

# Show usage if help is requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [pr_number]"
    echo ""
    echo "Examples:"
    echo "  $0 10     # Creates branch 'username/pr_10' with PR #10"
    echo "  $0        # Creates branch 'username/pr_10' with PR #10 (default)"
    echo ""
    echo "This script will fetch the specified PR to a local branch."
    exit 0
fi

PR_NUMBER=${1:-10}
CURRENT_USER=$(git config user.name 2>/dev/null || whoami)
BRANCH_NAME="$CURRENT_USER/pr_$PR_NUMBER"

echo "Fetching PR #$PR_NUMBER to branch '$BRANCH_NAME'..."

# Fetch all remote refs first
git fetch --all

# Check if branch already exists
if git show-ref --verify --quiet refs/heads/$BRANCH_NAME; then
    echo "Branch '$BRANCH_NAME' already exists. Deleting it..."
    git branch -D $BRANCH_NAME
fi

# Fetch the specific PR first
echo "Fetching PR #$PR_NUMBER..."
git fetch origin pull/$PR_NUMBER/head:$BRANCH_NAME

# Switch to the new branch
echo "Switching to branch '$BRANCH_NAME'..."
git checkout $BRANCH_NAME

echo "Successfully created branch '$BRANCH_NAME' with PR #$PR_NUMBER"
echo "Current branch: $(git branch --show-current)"
