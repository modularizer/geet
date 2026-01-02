# Developer Guide

This guide explains the internal architecture and developer workflow for geet.

## Table of Contents

- [Script Setup & Entrypoint](#script-setup--entrypoint)
- [Prework & Initialization](#prework--initialization)
- [Logging System](#logging-system)
- [Available Variables & Functions](#available-variables--functions)
- [Writing New Commands](#writing-new-commands)

## Script Setup & Entrypoint

### Entry Point: `bin/geet.sh`

All geet commands flow through `bin/geet.sh`, which serves as the main dispatcher:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Locate the geet library
NODE_BIN="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GEET_LIB="$(cd -- "$NODE_BIN/../lib/node_modules/geet/lib" && pwd)"

# 2. Run the prework (digest-and-locate.sh)
source "$GEET_LIB/digest-and-locate.sh" "$@"

# 3. Dispatch to the appropriate command handler
cmd="${1:-help}"
shift || true

case "$cmd" in
  help|-h|--help)
    source "$GEET_LIB/help.sh"
    help
    ;;
  sync)
    source "$GEET_LIB/sync.sh"
    sync "${GEET_ARGS[@]:1}"
    ;;
  # ... more commands
  *)
    # Default: treat as git subcommand
    source "$GEET_LIB/git.sh"
    call_cmd "${GEET_ARGS[@]}"
    ;;
esac
```

### Command Flow

1. **Entry** → `bin/geet.sh`
2. **Prework** → Sources `lib/digest-and-locate.sh` (sets up environment)
3. **Dispatch** → Routes to appropriate command handler in `lib/*.sh`
4. **Execute** → Command-specific logic runs

## Prework & Initialization

### `digest-and-locate.sh` - The Setup Script

Before any geet command runs, `digest-and-locate.sh` is sourced. This script:

1. **Sources logger.sh** - Sets up the logging system
2. **Parses flags** - Extracts `--geet-dir`, `--verbose`, `--filter`, `--brave`, etc.
3. **Auto-detects template directory** - Finds `.geethier` in parent directories
4. **Loads config** - Reads `config.json` from the template directory
5. **Sets up environment** - Exports all variables and functions needed by commands

### What Gets Set Up

After sourcing `digest-and-locate.sh`, you have access to:

- **Paths**: `$GEET_LIB`, `$GEET_CMD`, `$APP_DIR`, `$TEMPLATE_DIR`, etc.
- **Config values**: `$TEMPLATE_NAME`, `$GEET_ALIAS`, `$TEMPLATE_GH_URL`, etc.
- **Logging functions**: `debug`, `info`, `log`, `warn`, `critical`, `die`
- **Helper functions**: `read_config`, `geet_git`, `brave_guard`, etc.

See the comments at the top of `lib/digest-and-locate.sh` for the complete list.

### Template Detection

`digest-and-locate.sh` automatically finds your template directory by:

1. Starting from `$PWD`
2. Looking for hidden directories containing `.geethier`
3. Choosing the directory with the most lines in `.geethier` (indicates hierarchy depth)
4. Walking up parent directories until finding a candidate or hitting a `.git` directory

You can override auto-detection with `--geet-dir /path/to/template`.

## Logging System

### Overview

The logging system lives in `lib/logger.sh` and provides structured, filterable logging with color support.

### Log Levels

From least to most severe:

- `DEBUG` - Verbose diagnostic information
- `INFO` - General informational messages
- `WARN` - Warning messages
- `ERROR` - Error messages
- `CRITICAL` - Critical errors (used by `die`)
- `NEVER` - Suppresses all output

### Logging Functions

```bash
debug "Checking for template at $dir"      # Only shown with --verbose
info "Syncing template changes..."         # Default level
log "Same as info"                         # Alias
warn "Config file not found, using defaults"
critical "Failed to initialize repository"
die "Fatal error: cannot proceed"          # Logs and exits with code 1
```

### Controlling Log Output

#### By Level

```bash
# Show everything including debug messages
geet sync --verbose

# Show only warnings and errors
geet sync --quiet

# Show only errors
geet sync --min-level ERROR

# Suppress all output
geet sync --silent
```

#### By Filter Pattern

Use `--filter` to show only messages containing a specific string:

```bash
# Only show messages containing "template"
geet sync --filter template

# Only show messages containing "LOCATE"
geet tree --verbose --filter LOCATE
```

#### Inverting Filters with `~`

Prefix your filter with `~` to **exclude** messages matching the pattern:

```bash
# Show all messages EXCEPT those containing "DEBUG"
geet sync --verbose --filter '~DEBUG'

# Show all messages EXCEPT those containing "git"
geet doctor --filter '~git'
```

The `~` acts as a "NOT" operator, inverting the filter logic.

### Filter Implementation

From `lib/logger.sh:125-136`:

```bash
if [[ -n "${LOG_FILTER:-}" ]]; then
  if [[ "$LOG_FILTER" == \~* ]]; then
    # exclude mode: pattern starts with ~
    local pat="${LOG_FILTER:1}"
    [[ "$plain" == *"$pat"* ]] && return 0  # Skip if matches
  else
    # include mode: normal pattern
    [[ "$plain" != *"$LOG_FILTER"* ]] && return 0  # Skip if doesn't match
  fi
fi
```

### Color Configuration

Colors are controlled by environment variables in `digest-and-locate.sh`:

```bash
COLOR_MODE="light"   # Options: light, dark, none
COLOR_SCOPE="line"   # Options: line, level
```

- `COLOR_MODE` - Color scheme for terminal output
  - `light` - Colors optimized for light backgrounds
  - `dark` - Colors optimized for dark backgrounds
  - `none` - No colors
- `COLOR_SCOPE` - What gets colored
  - `line` - Color the entire log line
  - `level` - Color only the level prefix (e.g., `[DEBUG]`)

## Available Variables & Functions

After sourcing `digest-and-locate.sh`, these are available in your command scripts:

### Key Paths

```bash
$GEET_LIB                    # Path to lib/ directory
$GEET_CMD                    # Path to bin/geet.sh
$APP_DIR                     # Your app's root directory (parent of template dir)
$APP_NAME                    # Name of your app
$TEMPLATE_DIR                # The template directory (e.g., .mytemplate)
$DOTGIT                      # The template's git directory (TEMPLATE_DIR/dot-git)
$GEET_GIT                    # Path to geet-git.sh wrapper
$TEMPLATE_JSON               # Path to config.json
```

### Config Values

```bash
$TEMPLATE_NAME               # Template name from config
$TEMPLATE_DESC               # Template description
$GEET_ALIAS                  # Command alias (usually "geet")
$TEMPLATE_GH_USER            # GitHub username
$TEMPLATE_GH_NAME            # GitHub repo name
$TEMPLATE_GH_URL             # GitHub URL
$TEMPLATE_GH_SSH      # SSH remote URL
$TEMPLATE_GH_HTTPS    # HTTPS remote URL
```

### Flags

```bash
$BRAVE                       # Set if --brave flag present
$VERBOSE                     # Set if --verbose flag present
$QUIET                       # Set if --quiet flag present
$SILENT                      # Set if --silent flag present
$MIN_LOG_LEVEL              # Current minimum log level
$LOG_FILTER                 # Active log filter pattern
```

### Helper Functions

```bash
read_config KEY [DEFAULT]              # Read from config.json
geet_git [args...]                     # Run git in template context
detect_template_dir_from_cwd           # Auto-find template directory
brave_guard CMD [REASON]               # Require --brave flag or exit
log_if_brave MESSAGE                   # Log only if --brave is set
```

## Writing New Commands

### Basic Template

Create a new file in `lib/your-command.sh`:

```bash
#!/usr/bin/env bash
# lib/my-command.sh

# This function assumes digest-and-locate.sh has already been sourced
# So you have access to all the variables and functions listed above

my_command() {
  debug "Starting my-command with args: $*"

  # Check if we're in a template directory
  if [[ -z "$TEMPLATE_DIR" ]]; then
    die "Not in a geet template directory. Run this from your app directory."
  fi

  # Use logging functions
  log "Running my command..."

  # Read from config
  local template_name
  template_name="$(read_config name "unknown")"
  info "Template name: $template_name"

  # Run git commands
  geet_git status

  # Guard dangerous operations
  brave_guard "my dangerous operation" "This will modify important files."

  log "Done!"
}
```

### Add to Dispatcher

Edit `bin/geet.sh` to add your command:

```bash
case "$cmd" in
  # ... existing commands ...

  my-command)
    source "$GEET_LIB/my-command.sh"
    my_command "${GEET_ARGS[@]:1}"
    ;;

  # ... rest of commands ...
esac
```

### Testing Your Command

```bash
# Run with verbose logging
geet my-command --verbose

# Run with filtering
geet my-command --verbose --filter "my-command"

# Run with brave mode
geet my-command --brave
```

## Debugging Tips

### Use Verbose Mode

Always develop with `--verbose` to see debug messages:

```bash
geet your-command --verbose
```

### Filter Noise

If there's too much output, filter it:

```bash
# Only show messages from your command
geet your-command --verbose --filter "my-command"

# Exclude git-related messages
geet your-command --verbose --filter '~git'
```

### Check What's Loaded

Add debug messages to see what's set:

```bash
debug "TEMPLATE_DIR=$TEMPLATE_DIR"
debug "TEMPLATE_NAME=$TEMPLATE_NAME"
debug "BRAVE=$BRAVE"
```

### Trace Execution

Enable bash tracing for maximum detail:

```bash
bash -x "$(which geet)" your-command
```

## Common Patterns

### Reading Config

```bash
# With default fallback
timeout="$(read_config timeout 30)"

# Required value (die if missing)
api_key="$(read_config apiKey)"
[[ -z "$api_key" ]] && die "apiKey not set in config.json"
```

### Guarding Destructive Operations

```bash
dangerous_operation() {
  brave_guard "deleting files" "This will permanently remove files."

  # This only runs if --brave was passed
  rm -rf "$SOME_DIR"
}
```

### Conditional Logging

```bash
# Only log if --brave
log_if_brave "About to do something risky..."

# Custom conditions
if [[ "$VERBOSE" ]]; then
  log "Detailed diagnostic info..."
fi
```

### Working with Git

```bash
# Use geet_git wrapper (respects template context)
geet_git fetch origin

# Get git output
current_branch="$(geet_git rev-parse --abbrev-ref HEAD)"
```

## Summary

1. **All commands start** via `bin/geet.sh`
2. **Prework runs first** (`digest-and-locate.sh` sets up environment)
3. **Logging is centralized** (use `debug`, `info`, `warn`, `critical`, `die`)
4. **Filter with `--filter`** (use `~` prefix to invert)
5. **Guard dangerous ops** with `brave_guard`
6. **Everything is documented** in `digest-and-locate.sh` comments

For more examples, browse the existing command files in `lib/`.
