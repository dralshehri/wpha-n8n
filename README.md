# WPHA n8n

Custom n8n build for the Western Sector Public Health Authority (WPHA) platform with white-labeling support.

## About

This repository builds a custom Docker image of [n8n](https://github.com/n8n-io/n8n) by applying WPHA-specific overrides and rebuilding from source. The build process creates a production-ready `compiled` directory with customizations, then replaces the official n8n module while maintaining all runtime dependencies.

## How It Works

1. **Build Stage**: Clones n8n source, applies overrides, builds production version
2. **Final Stage**: Extends official n8n image with our custom-built module
3. **GitHub Actions**: Automatically builds and publishes to GitHub Container Registry
4. **Deployment**: Pull and run the pre-built custom image

## Quick Start

```bash
# Pull the custom WPHA n8n image
docker pull ghcr.io/dralshehri/wpha-n8n:latest

# Run the container
docker run -d \
  --name wpha-n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  ghcr.io/dralshehri/wpha-n8n:latest
```

## Customizations

The `overrides/` directory contains WPHA-specific customizations following n8n's [white-labeling guidelines](https://docs.n8n.io/embed/white-labelling/):

### Theme Colors
- `packages/frontend/@n8n/design-system/src/css/_tokens.scss` - Light theme colors
- `packages/frontend/@n8n/design-system/src/css/_tokens.dark.scss` - Dark theme colors

### Logos and Assets
- `packages/frontend/editor-ui/public/favicon-16x16.png`
- `packages/frontend/editor-ui/public/favicon-32x32.png`
- `packages/frontend/editor-ui/public/favicon.ico`
- `packages/frontend/editor-ui/public/n8n-logo.svg`
- `packages/frontend/editor-ui/public/n8n-logo-collapsed.svg`
- `packages/frontend/editor-ui/public/n8n-logo-expanded.svg`

### Text Localization
- `packages/frontend/@n8n/i18n/src/locales/en.json` - Brand name and text replacements

### Window Title
- `packages/frontend/editor-ui/index.html`
- `packages/frontend/editor-ui/src/composables/useDocumentTitle.ts`

**⚠️ Important:** Never edit files in `overrides/` directly. These files are automatically extracted from the upstream n8n repository. All modifications should be made in the upstream repo's custom branch, then extracted using `./scripts/extract-overrides.sh`.

## Repository Structure

```
wpha-n8n/                       (Self-contained repository)
├── overrides/                  # Custom files to override in n8n
│   └── packages/
│       ├── frontend/           # Frontend customizations
│       │   ├── @n8n/
│       │   │   ├── design-system/  # Theme colors
│       │   │   └── i18n/           # Text localization
│       │   └── editor-ui/          # UI assets and components
│       └── cli/                    # Backend modifications (if any)
├── scripts/
│   ├── apply-overrides.sh     # Applies overrides during Docker build
│   └── extract-overrides.sh   # Development tool for maintainers
├── BASE_VERSION               # n8n version this is based on
├── Dockerfile                 # Builds custom image from base + overrides
└── .github/workflows/build.yml # Automated build and publish
```

## Development

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

#### Daily Workflow

1. **Switch to upstream for development**:

```bash
cd ../n8n
git checkout custom
# Make your white-labeling changes following n8n docs:
# - Edit packages/frontend/@n8n/design-system/src/css/_tokens.scss for colors
# - Replace logos in packages/frontend/editor-ui/public/
# - Edit packages/frontend/@n8n/i18n/src/locales/en.json for text
```

2. **Commit changes in upstream**:

```bash
git add .
git commit -m "Add: specific WPHA branding/customization"
```

3. **Extract and deploy customizations**:

```bash
cd ../wpha-n8n
./scripts/extract-overrides.sh  # Extracts changed files to overrides/
git add overrides/
git commit -m "Update: describe what was customized"
git push  # Triggers automatic Docker build
```

#### Updating Base Version

When upgrading to a new n8n version (best done in your IDE for easy conflict resolution):

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

# Alternative: Auto rebase (may include upstream commits causing conflicts)
# git rebase n8n@1.116.2
# If conflicts occur, resolve in IDE and continue rebase

# 3. Update BASE_VERSION and extract overrides
cd ../wpha-n8n
echo "1.116.2" > BASE_VERSION
./scripts/extract-overrides.sh
git add BASE_VERSION overrides/
git commit -m "Update to n8n 1.116.2"
git push
```

## Docker Build Process

The efficient two-stage build:

1. **Builder Stage** (`n8nio/base:22`):
   - Uses n8n's official build environment
   - Clones n8n source at specific version
   - Applies overrides from `overrides/` directory
   - Runs `pnpm build` and `build-n8n.mjs` to create production `compiled` directory

2. **Final Stage** (`n8nio/n8n:${BASE_VERSION}`):
   - Extends the official n8n image
   - Replaces `/usr/local/lib/node_modules/n8n` with our custom build
   - Rebuilds native modules (sqlite3, canvas)
   - Maintains all runtime dependencies and configuration

## Base Version

Current base: **n8n [BASE_VERSION](./BASE_VERSION)**

This determines which official n8n image is used as the foundation for our customizations.

## License

Western Sector Public Health Authority
