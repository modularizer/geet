#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# HELPERS
###############################################################################
die() { echo "[template] $*" >&2; exit 1; }
log() { echo "[template] $*" >&2; }

###############################################################################
# template.sh — promote the CURRENT APP into a NEW TEMPLATE LAYER
#
# This script creates a NEW hidden layer folder (e.g. .MyApp2 or .sk2)
# and initializes a template git repo for it, WITHOUT disturbing:
#   - the app repo (.git)
#   - any existing layers (e.g. .geet)
#
# Think of this as:
#   “I built something useful on top of existing templates.
#    I now want to publish THIS as a template others can clone.”
#
# -----------------------------------------------------------------------------
# What this script does:
#
# 1) Decide the new layer name
#    - default: app directory name (MyApp -> .MyApp)
#    - optional arg: explicit short name (e.g. sk2 -> .sk2)
#
# 2) Create a new layer directory:
#      .<layer>/
#        git.sh        (copied from current layer)
#        init.sh       (copied from current layer)
#        tree.sh       (if present)
#        .geetinclude   (NEW, initially empty / commented)
#
# 3) Initialize a NEW template git repo:
#      .<layer>/dot-git/
#
# 4) Commit the whitelisted files (as defined by .<layer>/.geetinclude)
#
# IMPORTANT:
# - This does NOT touch .git (the app repo)
# - This does NOT touch existing layers (.geet, etc.)
# - dot-git/ is NOT committed to the app repo
#
###############################################################################

###############################################################################
# PATH DISCOVERY
###############################################################################

# Directory this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine if we're running from a layer or from global installation
# If SCRIPT_DIR is like /usr/lib/node_modules/geet/lib, we're global
# If SCRIPT_DIR is like /path/to/MyApp/.geet/lib, we're in a layer

log "DEBUG: SCRIPT_DIR=$SCRIPT_DIR"

if [[ "$SCRIPT_DIR" == */geet/lib ]]; then
  log "DEBUG: Detected global installation"
  # Global installation - use git to find repo root, or current directory
  if ROOT_TMP="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    ROOT="$ROOT_TMP"
    log "DEBUG: Found git repo root: $ROOT"
  else
    # No git repo, use current directory (will initialize one later)
    ROOT="$(pwd)"
    log "DEBUG: No git repo, using pwd: $ROOT"
  fi
  BASE_LAYER_DIR="$SCRIPT_DIR/.."  # Use global geet as source
  BASE_LAYER_NAME="geet"
else
  log "DEBUG: Detected local layer installation"
  # Local layer installation
  BASE_LAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"  # .geet
  ROOT="$(cd "$BASE_LAYER_DIR/.." && pwd)"  # MyApp/
  BASE_LAYER_NAME="$(basename "$BASE_LAYER_DIR")"
  BASE_LAYER_NAME="${BASE_LAYER_NAME#.}"
  log "DEBUG: ROOT from layer: $ROOT"
fi

# App name = directory name of the project root
APP_NAME="$(basename "$ROOT")"
log "DEBUG: APP_NAME=$APP_NAME, ROOT=$ROOT"

###############################################################################
# ARGUMENT PARSING
###############################################################################

# Optional argument: explicit name for the new template layer
# Example:
#   ./lib/template.sh sk2   -> creates .sk2
#
# Default behavior:
#   ./lib/template.sh       -> creates .<AppName>
#
RAW_NAME="${1:-$APP_NAME}"

# Normalize:
# - ensure no leading dot
# - layer folders are always hidden
LAYER_NAME="${RAW_NAME#.}"
NEW_LAYER_DIR="$ROOT/.${LAYER_NAME}"

###############################################################################
# IMPORTANT PATHS FOR NEW LAYER
###############################################################################

DOTGIT="$NEW_LAYER_DIR/dot-git"
NEW_GIT_SH="$NEW_LAYER_DIR/lib/git.sh"
NEW_geetinclude="$NEW_LAYER_DIR/.geetinclude"



###############################################################################
# SAFETY CHECKS
###############################################################################

# Check if we have a git repo in current directory
if [[ ! -d "$ROOT/.git" ]]; then
  log "no git repo found at $ROOT/.git"
  log "initializing new git repo..."
  git -C "$ROOT" init >/dev/null
fi

# Do not overwrite an existing layer
if [[ -e "$NEW_LAYER_DIR" ]]; then
  die "layer already exists: $NEW_LAYER_DIR"
fi

# We expect git.sh and init.sh to exist in the base layer
if [[ ! -f "$BASE_LAYER_DIR/lib/git.sh" || ! -f "$BASE_LAYER_DIR/lib/init.sh" ]]; then
  die "source files missing (expected at $BASE_LAYER_DIR/lib/)"
fi

###############################################################################
# CREATE NEW LAYER STRUCTURE
###############################################################################

log "creating new template layer: .$LAYER_NAME"

mkdir -p "$NEW_LAYER_DIR"

# Copy core tooling from the base layer.
# This keeps all layers structurally identical and self-contained.
mkdir -p "$NEW_LAYER_DIR/lib"
mkdir -p "$NEW_LAYER_DIR/bin"

cp "$BASE_LAYER_DIR/README.md" "$NEW_LAYER_DIR/README.md" 2>/dev/null
cp "$BASE_LAYER_DIR/.geethier" "$NEW_LAYER_DIR/.geethier" 2>/dev/null
echo "$LAYER_NAME\n" >> "$NEW_LAYER_DIR/.geethier"

# Copy all shell scripts from lib/
cp "$BASE_LAYER_DIR/lib"/*.sh "$NEW_LAYER_DIR/lib/" 2>/dev/null

# Copy bin files if they exist
if [[ -d "$BASE_LAYER_DIR/bin" ]]; then
  cp "$BASE_LAYER_DIR/bin"/*.sh "$NEW_LAYER_DIR/bin/" 2>/dev/null
fi

# Copy sample files
if [[ -f "$BASE_LAYER_DIR/geetinclude.sample" ]]; then
  cp "$BASE_LAYER_DIR/geetinclude.sample" "$NEW_LAYER_DIR/geetinclude.sample"
  cp "$BASE_LAYER_DIR/geetinclude.sample" "$NEW_LAYER_DIR/.geetinclude"
fi


###############################################################################
# INITIALIZE TEMPLATE GIT REPO FOR THE NEW LAYER
###############################################################################

log "initializing template git repo for .$LAYER_NAME"
mv "$ROOT/.git" "$ROOT/not-git"
git init --separate-git-dir="$DOTGIT" "$ROOT"
rm "$ROOT/.git"
mv "$ROOT/not-git" "$ROOT/.git"

###############################################################################
# COMPILE WHITELIST AND CREATE INITIAL COMMIT
###############################################################################

# We run the NEW layer's git.sh, not the base layer's.
# This ensures:
# - .geetinclude is compiled into .gitignore
# - commands are scoped correctly to the new layer
#
# First, compile excludes by calling status (idempotent).
"$NEW_GIT_SH" status >/dev/null

# TODO: right here, complet/autogen the .gitignore and do a git add of it

# Stage only the initial folder
set +e
"$NEW_GIT_SH" add ".$LAYER_NAME" ":!.$LAYER_NAME/dot-git/"
ADD_RC=$?
set -e
"$NEW_GIT_SH" commit -m "Initial $LAYER_NAME template" 2>/dev/null || true

###############################################################################
# FINAL OUTPUT
###############################################################################

log "done"
log "new template layer created:"
log "  layer name: .$LAYER_NAME"
log "  location:   $NEW_LAYER_DIR"
log
log "next steps:"
log "  1) edit: $NEW_geetinclude"
log "  2) cd $NEW_LAYER_DIR"
log "  3) stage files: $LAYER_NAME add -A"
log "  4) commit:      $LAYER_NAME commit -m \"Initial $LAYER_NAME template\""
log "  5) publish:     push this repo to create a reusable template"
