# Publishing a geet template

## Include/Exclude modes

Each template layer defines which files it tracks using **either** a whitelist or blacklist.

**Choose one (never both):**
- `.geetinclude` — **Whitelist mode** (only listed files are tracked)
- `.geetexclude`

### Whitelist mode (`.geetinclude`)

Use when only specific files should be in the template.

**Rules:**
```text
path        # include
!path       # exclude (override earlier include)
!!path      # escape (literal leading "!")
```

**Example:**
```text
app/**
!app/custom/**
app/custom/shared/**
package.json
```

**Best for:** Component libraries, shared utilities, minimal templates

### Blacklist mode (`.geetexclude`)

Use when most files should be in the template.

**Rules:**
```text
path        # exclude this path
```

**Example:**
```text
node_modules/**
.env
.env.local
app/custom/**
```

**Best for:** Full app templates where only a few paths are app-specific

**Note:** Both files are compiled into Git's repo-local ignore system (`.geetexclude`) automatically.

## Creating a post-init hook

Create `<layer>/post-init.sh` in your template:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Available environment variables:
# - GEET_LAYER_DIR   (e.g., /path/to/MyApp/.geet)
# - GEET_LAYER_NAME  (e.g., geet)
# - GEET_ROOT        (e.g., /path/to/MyApp)
# - GEET_DOTGIT      (e.g., /path/to/MyApp/.geet/dot-git)

echo "Running post-init setup..."

# Example: copy .env.sample to .env
[[ -f .env.sample && ! -f .env ]] && cp .env.sample .env

# Example: parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name)
      APP_NAME="$2"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

echo "Setup complete!"
```

Make it executable:
```bash
chmod +x .geet/post-init.sh
```

## Publishing to GitHub

### Setup GitHub CLI (one-time)

```bash
geet gh setup
```

This installs and authenticates GitHub CLI if needed.

### Publish repository

```bash
geet gh publish                # Creates repo named after directory
geet gh publish --public       # Make it public
geet gh publish --private --description "My template"
```

This:
- Creates GitHub repository
- Sets up remote
- Pushes code

### Export clean snapshot

Export just the template files (useful for debugging):

```bash
geet split /tmp/geet-export
geet split /tmp/geet-export all    # include untracked whitelisted files
```

Use cases:
* publish a clean snapshot
* debug what's actually included
* run builds in isolation

## Advanced: Session workflows

For templates that need isolated builds:

```bash
geet session run -- npm run build
geet session run --copy-back dist:dist -- npm run build
geet session run --keep -- npm test
```

This:
1. Splits to temp directory
2. Runs command
3. Optionally copies results back
4. Cleans up

No config. No state. Just a convenience wrapper.

## Safety features

Template repos **do not own the filesystem**.

Destructive Git commands are blocked by default:

* `clean`
* `reset`
* `checkout`
* `restore`
* `rm`

Override only if you know what you're doing:

```bash
geetGIT_DANGEROUS=1 geet git reset --hard
```

---
