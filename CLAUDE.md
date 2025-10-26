# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository builds **two synchronized Docker images** for WPHA (Western Sector Public Health Authority):

1. **Main n8n image** - WPHA-branded n8n with white-labeling customizations
2. **Task runners image** - Code execution environment with custom npm and Python packages

Both images are built together and published to GitHub Container Registry.

## Architecture

### Two-Repository System

1. **This Repository (`wpha-n8n`)**: Self-contained repository with build infrastructure and extracted customizations
2. **Upstream Repository (`../n8n`)**: Local clone of n8n-io/n8n with a `custom` branch for WPHA modifications

### Build Processes

#### Main n8n Image (Dockerfile)

Two-stage build process:
1. **Builder Stage** (`n8nio/base:22`):
   - Clones n8n source at version from `BASE_VERSION`
   - Applies overrides from `overrides/` directory
   - Runs `pnpm build` and `build-n8n.mjs` to create production `compiled` directory
2. **Final Stage** (`n8nio/n8n:${BASE_VERSION}`):
   - Extends official image
   - Replaces `/usr/local/lib/node_modules/n8n` with custom build
   - Rebuilds native modules (sqlite3, canvas)
   - Inherits EXPOSE, ENTRYPOINT, CMD from base image

#### Task Runners Image (Dockerfile.runners)

Single-stage extension:
1. **Base** (`n8nio/runners:${BASE_VERSION}`):
   - Node.js 22.18.0, Python 3.13.9
   - Extends official runners image
2. **Customization**:
   - Adds extra npm packages to `/opt/runners/task-runner-javascript`
   - Adds extra Python packages to `/opt/runners/task-runner-python/.venv`
   - Replaces runner config with `runners/n8n-task-runners.json`
   - Inherits EXPOSE, ENTRYPOINT, CMD from base image

## Key Commands

### Workflow for Branding Customizations

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
git add . && git commit -m "WPHA: Update branding"

cd ../wpha-n8n
./scripts/extract-overrides.sh  # Extracts committed changes to overrides/
git add overrides/
git commit -m "Update: describe changes"
git push  # Triggers automatic build of both images
```

### Workflow for Task Runner Customizations

```bash
# Add JavaScript packages
# 1. Edit runners/package.json - add dependencies
# 2. Edit runners/n8n-task-runners.json - add to NODE_FUNCTION_ALLOW_EXTERNAL
git add runners/
git commit -m "Add: axios package to JavaScript runner"
git push  # Triggers automatic build of both images

# Add Python packages
# 1. Edit runners/extras.txt - add package==version
# 2. Edit runners/n8n-task-runners.json - add to N8N_RUNNERS_EXTERNAL_ALLOW
git add runners/
git commit -m "Add: pandas package to Python runner"
git push  # Triggers automatic build of both images
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

### runners/

Contains customizations for task runners that execute Code node scripts:

**runners/package.json**
- Extra npm packages available in JavaScript Code nodes
- Follows upstream pattern: backup original → install extras → restore original → extras saved as `extras.json`
- Packages installed into existing `node_modules` in `/opt/runners/task-runner-javascript`

**runners/extras.txt**
- Extra Python packages available in Python Code nodes
- Installed via `uv pip install` into existing venv at `/opt/runners/task-runner-python/.venv`
- Auto-detected by `uv` when working in that directory

**runners/n8n-task-runners.json**
- Runner configuration with security allowlists
- **CRITICAL**: Packages must be explicitly allowlisted to be usable in Code nodes
- Environment variables:
  - `NODE_FUNCTION_ALLOW_BUILTIN`: Node.js built-in modules (e.g., crypto, fs, path)
  - `NODE_FUNCTION_ALLOW_EXTERNAL`: npm packages (must match package.json)
  - `N8N_RUNNERS_STDLIB_ALLOW`: Python standard library modules
  - `N8N_RUNNERS_EXTERNAL_ALLOW`: Python packages (must match extras.txt)

### Dockerfile

Main n8n image build:
- Uses `n8nio/base:22` for building (has git pre-installed)
- Requires `python3 make g++ bash` for n8n build dependencies
- Uses `pnpm@10.16.1` matching n8n's requirements
- Final stage extends `n8nio/n8n:${BASE_VERSION}` replacing only the n8n module
- Does NOT specify EXPOSE/ENTRYPOINT/CMD (inherited from base image)

### Dockerfile.runners

Task runners image build:
- Extends `n8nio/runners:${BASE_VERSION}` (Node.js 22.18.0, Python 3.13.9)
- Switches to `USER root` for package installation, then back to `USER runner`
- Does NOT specify EXPOSE/ENTRYPOINT/CMD (inherited from base image)
- Does NOT create new venv for Python (uses existing `.venv` auto-detected by `uv`)

## GitHub Actions

The workflow in `.github/workflows/build.yml`:
- Triggers on push to main branch (ignoring *.md files)
- Builds and pushes **both images** to `ghcr.io/${{ github.repository }}`
  - `ghcr.io/dralshehri/wpha-n8n` (main n8n)
  - `ghcr.io/dralshehri/wpha-n8n-runners` (task runners)
- Tags with both SHA and `latest`
- Uses `BASE_VERSION` for the base image version
- Both images are built in parallel and synchronized

## Important Notes for Claude Code

### When customizing task runner packages:
1. **Always update both files**: Add package to `package.json`/`extras.txt` AND allowlist in `n8n-task-runners.json`
2. **Pin versions**: Use exact versions in `package.json` (e.g., `"1.6.0"`) and `extras.txt` (e.g., `requests==2.31.0`)
3. **Security first**: Packages won't work in Code nodes unless explicitly allowlisted - this is intentional

### When working with Dockerfiles:
- **DO NOT** add EXPOSE/ENTRYPOINT/CMD directives - they're inherited from base images
- **DO NOT** edit `overrides/` directly - always use the extract script workflow
- **DO NOT** create Python venv in Dockerfile.runners - it exists and is auto-detected

### When updating base version:
- Prefix all custom commits with "WPHA:" for easy identification during rebase
- Use interactive rebase (`git rebase -i`) to cleanly separate WPHA changes from upstream

## Common Issues and Solutions

### Uncommitted changes warning
The extract script will warn if there are uncommitted changes in the upstream custom branch. Commit changes first to include them in overrides.

### Build failures after base version update
The custom branch may have conflicts with the new base version. Carefully rebase and resolve conflicts in the upstream repository before extracting.

### Package installed but not usable in Code node
Check that the package is allowlisted in `runners/n8n-task-runners.json` under the appropriate environment variable.

### Finding what can be customized
Refer to n8n's white-labeling documentation: https://docs.n8n.io/embed/white-labelling/
Main customization points:
- Theme colors: `_tokens.scss` and `_tokens.dark.scss`
- Logos: `public/` directory files in editor-ui
- Text: `en.json` localization file
- Window title: `index.html` and `useDocumentTitle.ts`

For task runners: https://docs.n8n.io/hosting/configuration/task-runners/
