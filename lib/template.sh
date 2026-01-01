#!/usr/bin/env bash
set -euo pipefail

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

# Directory this script lives in (the "current" layer, usually .geet)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # .geet/lib
BASE_LAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"  # .geet
ROOT="$(cd "$BASE_LAYER_DIR/.." && pwd)"  # MyApp/

# Name of the base layer (for logging only)
BASE_LAYER_NAME="$(basename "$BASE_LAYER_DIR")"
BASE_LAYER_NAME="${BASE_LAYER_NAME#.}"

# App name = directory name of the project root
APP_NAME="$(basename "$ROOT")"

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
# HELPERS
###############################################################################
die() { echo "[template] $*" >&2; exit 1; }
log() { echo "[template] $*" >&2; }

###############################################################################
# SAFETY CHECKS
###############################################################################

# Must be run from inside an app repo
if [[ ! -d "$ROOT/.git" ]]; then
  die "no app repo found at $ROOT/.git (run from inside an app repo)"
fi

# Do not overwrite an existing layer
if [[ -e "$NEW_LAYER_DIR" ]]; then
  die "layer already exists: $NEW_LAYER_DIR"
fi

# We expect git.sh and init.sh to exist in the base layer
if [[ ! -f "$BASE_LAYER_DIR/lib/git.sh" || ! -f "$BASE_LAYER_DIR/lib/init.sh" ]]; then
  die "base layer missing lib/git.sh or lib/init.sh (cannot promote)"
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
cp "$BASE_LAYER_DIR/lib/*.sh" "$NEW_LAYER_DIR/lib/"
cp "$BASE_LAYER_DIR/bin/*.sh" "$NEW_LAYER_DIR/bin/"
cp "$BASE_LAYER_DIR/README.md" "$NEW_LAYER_DIR/README.md"
cp "$BASE_LAYER_DIR/package.json" "$NEW_LAYER_DIR/package.json"
cp "$BASE_LAYER_DIR/geetinclude.sample" "$NEW_LAYER_DIR/geetinclude.sample"
cp "$BASE_LAYER_DIR/geetinclude.sample" "$NEW_LAYER_DIR/.geetinclude"

###############################################################################
# INITIALIZE TEMPLATE GIT REPO FOR THE NEW LAYER
###############################################################################

log "initializing template git repo for .$LAYER_NAME"

mkdir -p "$DOTGIT"
git init "$DOTGIT" >/dev/null

###############################################################################
# COMPILE WHITELIST AND CREATE INITIAL COMMIT
###############################################################################

# We run the NEW layer's git.sh, not the base layer's.
# This ensures:
# - .geetinclude is compiled into dot-git/info/exclude
# - commands are scoped correctly to the new layer
#
# First, compile excludes by calling status (idempotent).
"$NEW_GIT_SH" status >/dev/null || true

# Stage files according to the whitelist.
# At this point, the whitelist is probably empty, so this may stage nothing.
#
# That is OK — we handle it explicitly.
set +e
"$NEW_GIT_SH" add -A
ADD_RC=$?
set -e

# Check if anything was staged
if git -C "$ROOT" --git-dir="$DOTGIT" diff --cached --quiet; then
  log "no files staged for .$LAYER_NAME yet"
  log "edit $NEW_geetinclude to define the template contents"
  log "then run:"
  log "  $NEW_LAYER_DIR/lib/git.sh add -A"
  log "  $NEW_LAYER_DIR/lib/git.sh commit -m \"Initial $LAYER_NAME template\""
else
  "$NEW_GIT_SH" commit -m "Initial $LAYER_NAME template"
fi

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
log "  2) stage files: $NEW_LAYER_DIR/lib/git.sh add -A"
log "  3) commit:      $NEW_LAYER_DIR/lib/git.sh commit -m \"Initial $LAYER_NAME template\""
log "  4) publish:     push this repo to create a reusable template"
