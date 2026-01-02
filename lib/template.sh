#!/usr/bin/env bash
set -euo pipefail
###############################################################################
# HELPERS
###############################################################################
die() { echo "[template] $*" >&2; exit 1; }
log() { echo "[template] $*" >&2; }

###############################################################################
# template.sh — promote the CURRENT APP into a NEW TEMPLATE REPO that the owner can commit files into, and publish
#
# This script creates a NEW hidden layer folder (e.g. .MyApp2 or .sk2)
# and initializes a template git repo for it, WITHOUT disturbing:
#   - the app repo (.git)
#   - any existing layers (e.g. .geet)
#
# Think of this as:
#   “I built something useful, and I think that SOME but not all of my code is re-usable.
#    I want to publish some of my code for other's to use (or to re-use myself)...
#    But I don't want to spend weeks refactoring to split apart the reusable code from the implementation specific code
#    In fact, it may not even be possible”
#
# -----------------------------------------------------------------------------
# What this script does:
#
# 1) Sets up the new layer
# MyApp/
#      .git             <- this is your app's git dir which tracks EVERYTHING, not just template repo code, but including template repo code
#      .mytemplate/  <<<<- THIS is what we are setting up
#        dot-git/       <- this is the .git of the template repo, just in an odd spot with an odd name
#        git.sh         <- base git command for the template's repo
#        geet.sh        <- calls geet but specifies which template we are in
#        .geetinclude   <- to allow adding files to the template's repo
#        .geetexclude    <- this is the .gitignore used by git.sh
#        README.md      <- just helps explain stuff to you and your users
#     ...               <- the rest of your source code for both the app and the template, interleaved
#     .gitignore        <- your app's .gitignore, not to be confused with .mytemplate/.geetexclude, this file mus also exclude **/dot-git/
#     README.md         <- your app's README, not to be confused with the template's readme. this leads to some complication for developers working on both an app and a template... they have to pull a switcheroo....
#
# 2) Initialize a NEW template git repo and commits some files to it
#      .mytemplate/dot-git/
#
# IMPORTANT:
# - This does have to temporarily touch .git (the app's git dir) to move it out of the way, during the init, but it puts it back immediately, unscathed
# - dot-git/ should NEVER be committed to any git repo
#
###############################################################################

###############################################################################
# PATH DISCOVERY
###############################################################################
GEET_DIR="${}"
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

# make empty dirs
mkdir -p "$NEW_LAYER_DIR"

# append the layer name into the hierarchy
cp "$BASE_LAYER_DIR/.geethier" "$NEW_LAYER_DIR/.geethier" 2>/dev/null
echo "$LAYER_NAME\n" >> "$NEW_LAYER_DIR/.geethier"

cat > "$NEW_LAYER_DIR/README.md" <<EOFREADME
# Welcome to the "$NEW_LAYER_DIR" template!

This template was created with [geet](https://github.com/modularizer/geet),
a CLI git wrapper which acts as an alternative to git submodules,
allowing publishing a template which controls files which are interspersed in the same working directory as your project.

### Things to know:
1. Typically, template files get double-tracked
  - They get pulled into your working directory and tracked by YOU
  - They ALSO are tracked by the remote template repo
  - If and when you wish, you can pull updates from the template repo into your project and add and commit the files into your repo
  - If you are a developer/contributor of the template repo, you can optionally push code back to the template repo using a different git command
2. `$NEW_LAYER_DIR/geet.sh` or just `geet` is the suggested entrypoint for all your pull/push git-like commands. It protects you and adds some features. More on that later.
3. $NEW_LAYER_DIR/git.sh is the base git command controlling this template repo. It runs
    exec git --git-dir="$DOTGIT" --work-tree="$ROOT" -c "core.excludesFile=$EXCLUDE_FILE" "\$@"
   but use with caution, and prefer to use the suggested entrypoint, because stuff like clean, reset, checkout commands on the template repo could accidentally destroy files in your actual repo
4. don't worry about .geethier, just leave it be. all it does is identify and trace the layering of templates
5. You can either operate your template on an include or and exclude basis. You probably know .gitignores are standard, and normally exclude, but in this case since we have all the app code stuff can be a bit different.
   - Let's say your actual full app is 80% of the code and the generic stuff you are turning into a template is only 20% of the code, it might be best to exclude everything to avoid committing implementation-specific code to the template repo, then add some generic files and folders back in, to allow commiting them to the template. This is when you would use .geetinclude for the convenience
   - Alternatively, if your primary goal is to develop a template, and 80% of your code is reusable, but then you just have 20% of "sample" code that you don't want included, maybe just overwrite .geetexclude file entierly, **but leave \*\*/dot-git/ excluded**
   - read the comments in .geetexclude for more info
   - use `geet tree` to see what is currently included in the template repo
6. geet supports many layered templating, so if you want to extend a template and publish as a new template it is definitly possible! See .geehier to see how many levels this one has

If you're the owner of this template, feel free to overwrite or add to this README to tell users about what your project does. It's all your's from here.
EOFREADME

cat > "$NEW_LAYER_DIR/.geetexclude" <<EOFGEETINCLUDE
# Add your include stuff here, you can call 'geet sync' to sync it to the .geetexclude if you wish, but it will also auto-sync on every geet command
EOFGEETINCLUDE

# Create initial .geetexclude with base rules and markers for compiled includes
cat > "$NEW_LAYER_DIR/.geetexclude" <<EOFGEETEXCLUDE
#-----------------------------------------------------------------------------------------------------------------------
# FAQ SECTION (docs)
#-----------------------------------------------------------------------------------------------------------------------
# Q: Can I fully overwrite this file?
# A: YES BUT: you MUST ensure **/dot-git/ gets ignored/excluded

# Q: How to sync from my .$LAYER_NAME/.geetinclude?
# A: run `geet sync` or `.$LAYER_NAME/bin/git-sync.sh`

#-----------------------------------------------------------------------------------------------------------------------
# DEFAULT INCLUDE SECTION (optional)
#    this section excludes everything, then adds back in some tools
#-----------------------------------------------------------------------------------------------------------------------
*
!*/
!.$LAYER_NAME/**
.$LAYER_NAME/dot-git/

#-----------------------------------------------------------------------------------------------------------------------
# AUTOGENERATED INCLUDE SECTION (optional)
#    now add back in contents from .geetinclude, just flipped
#-----------------------------------------------------------------------------------------------------------------------
# GEETINCLUDESTART

# Whoops! either .$LAYER_NAME/.geetinclude is empty or .$LAYER_NAME/.geetinclude hasn't been synced

# GEETINCLUDEEND

#-----------------------------------------------------------------------------------------------------------------------
# MANUAL EXLUDE SECTION
#    treat this part as your standard .gitignore, if you want to operate on an exclude basis vs an include basis
#    typically either add to this section OR use .geetinclude, not both
#    technically you could use both this section and your .geetinclude, but why?
#-----------------------------------------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------------------------------------
# MANDATORY EXCLUDE SECTION (required)
#    we must never ever commit dot-git folder or its contents
#-----------------------------------------------------------------------------------------------------------------------
**/dot-git/
EOFGEETEXCLUDE

###############################################################################
# INITIALIZE TEMPLATE GIT REPO FOR THE NEW LAYER
###############################################################################
DOTGIT="$NEW_LAYER_DIR/dot-git"

if [ ! -d "$ROOT/.git" ]; then
  log "temporarily moving $ROOT/.git to $ROOT/not-git"
  mv "$ROOT/.git" "$ROOT/not-git"
fi

log "initializing template git repo for $LAYER_NAME using 'git init --separate-git-dir=$DOTGIT $ROOT'"
git init --separate-git-dir="$DOTGIT" "$ROOT"

log "removing the pointer file that git leaves behind when --separate-git-dir is specified"
rm "$ROOT/.git"

if [ -d "$ROOT/not-git" ]; then
  log "restoring our original git dir from $ROOT/not-git back to $ROOT/.git"
  mv "$ROOT/not-git" "$ROOT/.git"
fi

log "don't worry, that file-shuffle was kinda ugly but it was a one-time thing, we don't need to do on every command"
log "instead, in the future we will use something like 'git --git-dir=<somefolder> --work-tree=<somefolder> -c core.exludesFile=<somefile>'"

###############################################################################
# MAKE A GIT WRAPPER
###############################################################################
cat > "$NEW_LAYER_DIR/geet-git.sh" <<EOFGIT
#!/usr/bin/env bash

THIS_FILE="\${BASH_SOURCE[0]}"
THIS_DIR="\$(cd -- "\$(dirname -- "\$THIS_FILE")" && pwd)"
PARENT_DIR="\$(dirname "\$THIS_DIR")"

# this file behaves like git, but always specifies our correct git directory, working tree, and gitignore
exec git --git-dir="\$THIS_DIR/dot-git" --work-tree="\$PARENT_DIR" -c "core.excludesFile=\$THIS_DIR/.geetexclude" "\$@"
EOFGIT
chmod +x "$NEW_LAYER_DIR/geet-git.sh"
log "created geet.sh wrapper (ensures excludesFile is always applied)"

###############################################################################
# MAKE A GEET WRAPPER
###############################################################################
cat > "$NEW_LAYER_DIR/geet.sh" <<EOFGEET
#!/usr/bin/env bash
# this file behaves like geet, but always specifies our correct template directory, so it can be called from anywhere

# first, check if geet is installed, else tell then how to installation
command -v geet >/dev/null 2>\&1 || {
  echo "geet not installed. Install it first." >\&2
  exit 127
}

THIS_FILE="\${BASH_SOURCE[0]}"
THIS_DIR="\$(cd -- "\$(dirname -- "\$THIS_FILE")" && pwd)"

# now, call geet
exec geet --geet-dir "\$THIS_DIR" "\$@"
EOFGEET
chmod +x "$NEW_LAYER_DIR/geet.sh"
log "created geet.sh wrapper (ensures geet sees the correct template dir)"

###############################################################################
# COMPILE WHITELIST AND CREATE INITIAL COMMIT
###############################################################################

# We run the NEW layer's geet.sh, not the base layer's.
# This ensures:
# - .geetinclude is compiled into .geetexclude
# - commands are scoped correctly to the new layer
#
# First, compile excludes by calling status (idempotent).
"$NEW_LAYER_DIR/geet.sh" sync >/dev/null
"$NEW_LAYER_DIR/git.sh" add ".$LAYER_NAME" ":!.$LAYER_NAME/dot-git/"
"$NEW_LAYER_DIR/git.sh" commit -m "Initial $LAYER_NAME template" 2>/dev/null || true

###############################################################################
# FINAL OUTPUT
###############################################################################

log "done"
log "new template layer created:"
log "  layer name: .$LAYER_NAME"
log "  location:   $NEW_LAYER_DIR"
log
log "next steps:"
log "  1) edit: "
log "  2) cd $NEW_LAYER_DIR"
log "  3) stage files: $LAYER_NAME add -A"
log "  4) commit:      $LAYER_NAME commit -m \"Initial $LAYER_NAME template\""
log "  5) publish:     push this repo to create a reusable template"
