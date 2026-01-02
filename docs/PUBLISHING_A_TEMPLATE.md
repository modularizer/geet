# Publishing a geet template

## Whitelist system

Each template layer defines which files it tracks using a **whitelist** file (`.geetinclude`).

### How it works

The `.geetinclude` file lists patterns for files to include in the template. This whitelist is compiled into `.geetexclude` (gitignore format) automatically.

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

**Why whitelist-only?**
- Makes template boundaries explicit
- Prevents accidentally including sensitive files
- Clear separation between template and app-specific code

**Note:** The `.geetexclude` file is auto-generated - edit `.geetinclude` instead.

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
geet --brave git reset --hard
```

---
