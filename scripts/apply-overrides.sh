#!/bin/bash
# Apply overrides to n8n source code during build
set -e

if [ ! -d "/tmp/overrides" ]; then
    echo "Error: /tmp/overrides directory not found"
    exit 1
fi

cd /tmp/overrides || exit 1

echo "Applying WPHA n8n overrides..."
count=0

# Apply each override file to its target location in source
while IFS= read -r file; do
    # Skip if not a file
    [ ! -f "$file" ] && continue

    # Default target is in the n8n source directory
    target="/n8n/$file"

    # Create target directory and copy file
    mkdir -p "$(dirname "$target")"
    cp -f "$file" "$target"
    echo "  Applied: $file"
    count=$((count + 1))
done < <(find . -type f | sed 's|^\./||')

echo "Successfully applied $count override files"
