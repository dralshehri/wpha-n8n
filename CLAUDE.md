# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository creates a custom Docker image of n8n with WPHA (Western Sector Public Health Authority) specific customizations using white-labeling. It maintains a clean separation between the upstream n8n code and WPHA customizations through an override system.

## Architecture

### Two-Repository System

1. **This Repository (`wpha-n8n`)**: Contains only the build infrastructure and extracted customizations
2. **Upstream Repository (`../n8n`)**: GitHub's n8n repository with a `custom` branch containing WPHA modifications

### Build Process

The Docker build uses a two-stage process:
1. **Builder Stage** (`n8nio/base:22`): Clones n8n source, applies overrides, runs `pnpm build` and `build-n8n.mjs` to create production `compiled` directory
2. **Final Stage** (`n8nio/n8n:${BASE_VERSION}`): Extends official image, replaces `/usr/local/lib/node_modules/n8n` with custom build

## Key Commands

### Workflow for Customizations

```bash
# Initial setup (one-time)
cd ..
git clone git@github.com:n8n-io/n8n.git
cd n8n
VERSION=$(cat ../wpha-n8n/BASE_VERSION)
git checkout n8n@$VERSION
git checkout -b custom

# Daily workflow
cd ../n8n
git checkout custom
# Make white-labeling changes to:
# - packages/frontend/@n8n/design-system/src/css/_tokens.scss (colors)
# - packages/frontend/editor-ui/public/*.png/*.svg (logos)
# - packages/frontend/@n8n/i18n/src/locales/en.json (text)
git add . && git commit -m "Add: specific customization"

cd ../wpha-n8n
./scripts/extract-overrides.sh  # Extracts committed changes to overrides/
git add overrides/
git commit -m "Update: describe changes"
git push  # Triggers automatic Docker build
```

### Building

```bash
# Build Docker image
docker build --build-arg BASE_VERSION=1.115.3 -t wpha-n8n:local .
```

### Updating Base Version

```bash
# In upstream repo, rebase custom branch (do this in your IDE for easy conflict resolution)
cd ../n8n
git fetch origin --tags
git checkout custom

# Option 1: Interactive rebase (recommended - lets you drop non-WPHA commits)
git rebase -i n8n@1.116.2
# In the editor that opens:
#   - DELETE all lines NOT starting with "WPHA:"
#   - KEEP all lines starting with "WPHA:"
#   - Save and close
# If conflicts occur, your IDE will show them - resolve and continue rebase in IDE

# Option 2: Auto rebase (may have conflicts from non-WPHA commits)
git rebase n8n@1.116.2
# If conflicts occur, resolve in IDE and continue rebase

# Update and extract
cd ../wpha-n8n
echo "1.116.2" > BASE_VERSION
./scripts/extract-overrides.sh
git add BASE_VERSION overrides/
git commit -m "Update to n8n 1.116.2"
git push
```

## Critical Files and Their Purposes

### BASE_VERSION
Contains the n8n version (e.g., `1.115.3`) this custom build is based on. Changing this requires rebasing the upstream custom branch.

### overrides/
**CRITICAL: Never edit directly!** These files are automatically extracted from the upstream repository. Directory structure mirrors n8n's source structure under `packages/`.

### scripts/extract-overrides.sh
Extracts committed changes from the upstream `custom` branch comparing against `n8n@${BASE_VERSION}` tag. Will warn about uncommitted changes.

### scripts/apply-overrides.sh
Used during Docker build to copy override files to `/n8n/$file` locations. Runs inside the builder container.

### Dockerfile
- Uses `n8nio/base:22` for building (has git pre-installed)
- Requires `python3 make g++ bash` for n8n build dependencies
- Uses `pnpm@10.16.1` matching n8n's requirements
- Final stage extends `n8nio/n8n:${BASE_VERSION}` replacing only the n8n module

## GitHub Actions

The workflow in `.github/workflows/build.yml`:
- Triggers on push to main branch (ignoring *.md files)
- Builds and pushes to `ghcr.io/${{ github.repository }}`
- Tags with both SHA and `latest`
- Uses `BASE_VERSION` for the base image version

## Common Issues and Solutions

### Uncommitted changes warning
The extract script will warn if there are uncommitted changes in the upstream custom branch. Commit changes first to include them in overrides.

### Build failures after base version update
The custom branch may have conflicts with the new base version. Carefully rebase and resolve conflicts in the upstream repository before extracting.

### Finding what can be customized
Refer to n8n's white-labeling documentation: https://docs.n8n.io/embed/white-labelling/
Main customization points:
- Theme colors: `_tokens.scss` and `_tokens.dark.scss`
- Logos: `public/` directory files in editor-ui
- Text: `en.json` localization file
- Window title: `index.html` and `useDocumentTitle.ts`
