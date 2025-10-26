# WPHA n8n

Custom n8n build for the Western Sector Public Health Authority (WPHA) platform with white-labeling and task runner customizations.

## About

This repository builds **two synchronized Docker images**:
- **`ghcr.io/dralshehri/wpha-n8n:latest`** - Main n8n with WPHA branding
- **`ghcr.io/dralshehri/wpha-n8n-runners:latest`** - Task runners with custom npm/Python packages

Both images are built from official n8n releases with WPHA-specific customizations applied automatically via GitHub Actions.

## Quick Start

```bash
# Pull both images
docker pull ghcr.io/dralshehri/wpha-n8n:latest
docker pull ghcr.io/dralshehri/wpha-n8n-runners:latest

# Start n8n with task runners
docker run -d \
  --name wpha-n8n \
  -p 5678:5678 \
  -e N8N_RUNNERS_ENABLED=true \
  -e N8N_RUNNERS_MODE=external \
  -e N8N_RUNNERS_AUTH_TOKEN=your-secret-token-change-me \
  -v ~/.n8n:/home/node/.n8n \
  ghcr.io/dralshehri/wpha-n8n:latest

# Start task runners
docker run -d \
  --name wpha-runners \
  -e N8N_RUNNERS_AUTH_TOKEN=your-secret-token-change-me \
  -e N8N_RUNNERS_TASK_BROKER_URI=http://wpha-n8n:5679 \
  --link wpha-n8n \
  ghcr.io/dralshehri/wpha-n8n-runners:latest
```

Access n8n at http://localhost:5678

## What's Included

### Task Runners (Essential)

Task runners execute user code from Code nodes in isolated containers, providing:

- **Security**: Sandboxed execution away from main n8n process
- **Stability**: Code errors don't crash main app
- **Resource limits**: Control memory/CPU per execution
- **Custom packages**: Pre-installed npm and Python packages for Code nodes

> 📖 See the [official n8n task runners documentation](https://docs.n8n.io/hosting/configuration/task-runners/) for more details.

### WPHA Branding

Custom white-labeling following n8n's [white-labeling guidelines](https://docs.n8n.io/embed/white-labelling/):

- Custom theme colors (light/dark mode)
- WPHA logos and favicons
- Brand name and text localization
- Custom window titles

## Customization

### Adding Packages to Code Node

Edit files in the `runners/` directory and commit to trigger automatic rebuild:

#### 1) Add JavaScript packages

Edit `runners/package.json`:
```json
{
  "dependencies": {
    "axios": "^1.6.0",
    "uuid": "^9.0.0",
    "dayjs": "^1.11.10"
  }
}
```
Pin versions for reproducibility (e.g., `^1.6.0` or `1.6.0`).

#### 2) Add Python packages

Edit `runners/extras.txt`:
```txt
requests==2.31.0
pandas==2.2.0
numpy==1.26.3
```
Pin exact versions with `==` for deterministic builds.

#### 3) Allowlist packages for Code node

Edit `runners/n8n-task-runners.json`:

⚠️ **Important**: For security, packages must be **explicitly allowlisted**:

```json
{
  "task-runners": [
    {
      "runner-type": "javascript",
      "env-overrides": {
        "NODE_FUNCTION_ALLOW_BUILTIN": "crypto,fs,path",
        "NODE_FUNCTION_ALLOW_EXTERNAL": "axios,uuid,dayjs,lodash,zod,moment"
      }
    },
    {
      "runner-type": "python",
      "env-overrides": {
        "N8N_RUNNERS_STDLIB_ALLOW": "json,datetime,math,random",
        "N8N_RUNNERS_EXTERNAL_ALLOW": "requests,pandas,numpy,dateutil"
      }
    }
  ]
}
```

**Configuration fields:**
- `NODE_FUNCTION_ALLOW_BUILTIN`: Node.js built-in modules (e.g., `crypto`, `path`)
- `NODE_FUNCTION_ALLOW_EXTERNAL`: npm packages (must match `package.json`)
- `N8N_RUNNERS_STDLIB_ALLOW`: Python standard library modules
- `N8N_RUNNERS_EXTERNAL_ALLOW`: Python packages (must match `extras.txt`)

After editing, commit and push to trigger automatic rebuild of both images.

### Modifying Branding

The `overrides/` directory contains WPHA-specific customizations that are applied during the Docker build.

**How it works:**

1. **Edit** in upstream n8n repo (`../n8n` on `custom` branch)
2. **Extract** - `./scripts/extract-overrides.sh` copies changed files to `overrides/`
3. **Apply** - During Docker build, `scripts/apply-overrides.sh` overlays these files onto n8n source before compilation

This two-step process ensures:
- Customizations are tracked in version control
- Changes can be rebased onto new n8n versions
- Build process remains clean and reproducible

⚠️ **Important**: Never edit files in `overrides/` directly - they get overwritten by the extract script. Always make changes in the upstream n8n repo's `custom` branch, then extract. See [Development Workflow](#development-workflow) below.

## Repository Structure

```
wpha-n8n/                       (Self-contained repository)
├── runners/                    # Task runner customizations
│   ├── package.json            # Extra npm packages for Code node
│   ├── extras.txt              # Extra Python packages for Code node
│   └── n8n-task-runners.json   # Runner configuration & allowed modules
├── overrides/                  # Custom files to override in n8n
├── scripts/
│   ├── apply-overrides.sh     # Applies overrides during Docker build
│   └── extract-overrides.sh   # Development tool for maintainers
├── BASE_VERSION               # n8n version this is based on
├── Dockerfile                 # Builds custom n8n image from base + overrides
├── Dockerfile.runners         # Extends official runners with custom packages
└── .github/workflows/build.yml # Automated build and publish (both images)
```

## Development Workflow

### For Maintainers Only

#### Initial Setup (One-time)

```bash
# Clone upstream n8n repository
cd ..
git clone git@github.com:n8n-io/n8n.git
cd n8n
VERSION=$(cat ../wpha-n8n/BASE_VERSION)
git checkout n8n@$VERSION
git checkout -b custom
```

#### Making Branding Changes

**1) Switch to upstream for development:**

```bash
cd ../n8n
git checkout custom
# Make your white-labeling changes following n8n docs:
# - Edit packages/frontend/@n8n/design-system/src/css/_tokens.scss for colors
# - Replace logos in packages/frontend/editor-ui/public/
# - Edit packages/frontend/@n8n/i18n/src/locales/en.json for text
```

**2) Commit changes in upstream:**

```bash
git add .
git commit -m "WPHA: Update branding/customization"
```

**3) Extract and deploy customizations:**

```bash
cd ../wpha-n8n
./scripts/extract-overrides.sh  # Extracts changed files to overrides/
git add overrides/
git commit -m "Update: describe what was customized"
git push  # Triggers automatic Docker build
```

#### Updating Base Version

When upgrading to a new n8n version:

```bash
# 1. In upstream repo, rebase custom branch onto new version
cd ../n8n
git fetch origin --tags
git tag --sort=-version:refname | grep "^n8n@" | head -10  # Check latest version
git checkout custom

# 2. Interactive rebase (RECOMMENDED - lets you drop non-WPHA commits)
git rebase -i n8n@1.116.2
# In the editor that opens:
#   - DELETE all lines NOT starting with "WPHA:"
#   - KEEP all lines starting with "WPHA:"
#   - Save and close
# If conflicts occur, your IDE will highlight them - resolve and continue rebase in IDE

# 3. Update BASE_VERSION and extract overrides
cd ../wpha-n8n
echo "1.116.2" > BASE_VERSION
./scripts/extract-overrides.sh
git add BASE_VERSION overrides/
git commit -m "Update to n8n 1.116.2"
git push
```

## How It Works

### n8n Image Build Process

1. **Builder Stage** (`n8nio/base:22`):
   - Uses n8n's official build environment
   - Clones n8n source at version specified in `BASE_VERSION`
   - Applies overrides from `overrides/` directory
   - Runs `pnpm build` and `build-n8n.mjs` to create production `compiled` directory

2. **Final Stage** (`n8nio/n8n:${BASE_VERSION}`):
   - Extends the official n8n image
   - Replaces `/usr/local/lib/node_modules/n8n` with custom build
   - Rebuilds native modules (sqlite3, canvas)
   - Maintains all runtime dependencies and configuration

### Runners Image Build Process

1. **Base** (`n8nio/runners:${BASE_VERSION}`):
   - Extends the official runners image

2. **Customization**:
   - Installs extra npm packages from `runners/package.json`
   - Installs extra Python packages from `runners/extras.txt`
   - Replaces runner config with `runners/n8n-task-runners.json`

### GitHub Actions

Both images are built together automatically:
- **Trigger**: Push to `main` branch
- **Output**: Two synchronized images with matching versions
- **Tags**: `latest` and `sha-<commit>`
- **Registry**: GitHub Container Registry (ghcr.io)

## Base Version

Current base: **n8n 1.116.2** ([BASE_VERSION](./BASE_VERSION))

This determines which official n8n image is used as the foundation.

## License

Western Sector Public Health Authority