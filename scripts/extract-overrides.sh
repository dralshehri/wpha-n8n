#!/bin/bash
# Extract changed files from upstream n8n to overrides directory
set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

VERSION=$(cat "$REPO_DIR/BASE_VERSION")
N8N_DIR="$REPO_DIR/../n8n"

echo "Base version: $VERSION"

if [ ! -d "$N8N_DIR" ]; then
    echo "Error: Upstream n8n directory not found at $N8N_DIR"
    echo "Clone and setup: cd $(dirname "$REPO_DIR") && git clone git@github.com:n8n-io/n8n.git"
    echo "Then: cd n8n && git checkout n8n@$VERSION && git checkout -b custom"
    exit 1
fi

cd "$N8N_DIR" || exit 1

# Ensure we're on the custom branch
if [ "$(git branch --show-current)" != "custom" ]; then
    echo "Error: Not on 'custom' branch"
    echo "Run: cd $N8N_DIR && git checkout custom"
    exit 1
fi

# Check for uncommitted changes in upstream
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Warning: Uncommitted changes detected in custom branch"
    echo "Please commit your changes to include them in overrides"
fi

# Verify custom branch is based on the expected version
if ! git merge-base --is-ancestor "n8n@$VERSION" HEAD 2>/dev/null; then
    echo "Error: Custom branch is not based on n8n@$VERSION"
    echo "Please ensure your custom branch started from n8n@$VERSION"
    exit 1
fi

cd "$REPO_DIR" || exit 1
rm -rf overrides
mkdir -p overrides

cd "$N8N_DIR" || exit 1

# Get all changes: modified files + new files, excluding deleted files
CHANGED_FILES=$(git diff --name-only --diff-filter=AM "n8n@$VERSION" HEAD)

if [ -z "$CHANGED_FILES" ]; then
    echo "No committed changes detected between n8n@$VERSION and current custom branch"
    exit 0
fi

echo "Extracting changed files from upstream..."
extracted_count=0
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        echo "  $file"
        target_dir="$REPO_DIR/overrides/$(dirname "$file")"
        mkdir -p "$target_dir"
        cp "$file" "$REPO_DIR/overrides/$file"
        ((extracted_count++))
    fi
done

cd "$REPO_DIR" || exit 1
echo "Extracted $extracted_count files to overrides/"
