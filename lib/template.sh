# template.sh — sourceable template creation function
# Usage:
#   source template.sh
#   template [layer-name]
#
# Creates a new template layer in the current app.

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

template() {
debug "creating new template layer, APP_NAME=$APP_NAME"

###############################################################################
# ARGUMENT PARSING & VALIDATION
###############################################################################

# Required argument: explicit name for the new template layer
# Example:
#   $GEET_ALIAS template sk2   -> creates .sk2
#
RAW_NAME="${1:-}"
#
NEW_TEMPLATE_DESC="${2:-}"

# usage, both raw_name and new_template desc are required to be non-empty, and neither can startwith a dash, and neither can equal "help"

# Show help if requested
if [[ -z "$RAW_NAME" || -z "$NEW_TEMPLATE_DESC" \
   || "$RAW_NAME" == -* || "$NEW_TEMPLATE_DESC" == -* \
   || "$RAW_NAME" == "help" || "$NEW_TEMPLATE_DESC" == "help" \
   || ! "$RAW_NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
  cat <<EOF
$GEET_ALIAS template — promote the CURRENT APP into a NEW TEMPLATE REPO

This script creates a NEW hidden layer folder (e.g., .MyApp2 or .sk2)
and initializes a template git repo for it, WITHOUT disturbing:
  - the app repo (.git)
  - any existing layers (e.g., .geet)

Think of this as:
  "I built something useful, and I think that SOME but not all of my code is re-usable.
   I want to publish some of my code for others to use (or to re-use myself)...
   But I don't want to spend weeks refactoring to split apart the reusable code from
   the implementation specific code. In fact, it may not even be possible"

Usage:
  $GEET_ALIAS template <name> <description> [--public|--private|--internal]

Examples:
  $GEET_ALIAS template mytemplate "A React Native base project"
  $GEET_ALIAS template sk2 "Starter kit v2 with TypeScript"

Requirements:
  - <name> must be non-empty and different from the app name
  - <name> cannot contain spaces

What this creates:
  - $DD_APP_NAME/$DD_TEMPLATE_NAME/         (new layer directory)
  - $DD_APP_NAME/$DD_TEMPLATE_NAME/dot-git/  (template's git repository)
  - $DD_APP_NAME/$DD_TEMPLATE_NAME/geet-git.sh  (git wrapper for template repo)
  - $DD_APP_NAME/$DD_TEMPLATE_NAME/geet.sh      (geet wrapper for template)
  - $DD_APP_NAME/$DD_TEMPLATE_NAME/.geetinclude (whitelist of files to include)
  - $DD_APP_NAME/$DD_TEMPLATE_NAME/.geetexclude (compiled excludes)
  - $DD_APP_NAME/$DD_TEMPLATE_NAME/README.md    (template documentation)
EOF
  return 0
fi


GEET_ALIAS='geet'
# Detect GH_USER lazily (only when needed for template creation)
if [[ "$GH_USER" == "$DEFAULT_GH_USER" ]] || [[ -z "$GH_USER" ]]; then
  get_gh_user
fi
TEMPLATE_GH_USER=GH_USER
debug "GH_USER=$GH_USER"
TEMPLATE_FILE_SUFFIX=".template"

# Normalize: remove leading dot if present
LAYER_NAME="${RAW_NAME#.}"


# Validation: must be different from app name
if [[ "$LAYER_NAME" == "$APP_NAME" ]]; then
  die "template name must be different from app name: '$APP_NAME'"
fi

has_flag "--allow-exists" ALLOW_EXISTS;
if [[ -e "$LAYER_NAME" ]] && ! [[ -n "${ALLOW_EXISTS:-}" ]]; then
  warn "Hmm... it looks like .$LAYER_NAME exists, which is odd..."
  warn "Please review our docs to make sure you understand what we are doing here. "
  warn "If you are able to put all of your template code into one folder like $LAYER_NAME, geet may not be the right tool to be using"
  warn "It seems likely that git submodules may work better for your use case"
  die "If you wish to proceed, try again with --allow-exists"
fi


NEW_LAYER_DIR="$APP_DIR/.${LAYER_NAME}"
TEMPLATE_DIR="$NEW_LAYER_DIR"

debug "new template layer will be created at: $NEW_LAYER_DIR"

###############################################################################
# SAFETY CHECKS
###############################################################################

# Check if we have a git repo in current directory
if [[ ! -e "$APP_DIR/.git" ]]; then
  log "no git repo found at $APP_DIR/.git"
  log "initializing new git repo..."
  git -C "$APP_DIR" init >/dev/null
fi

# Idempotency check - if layer already exists, exit cleanly
if [[ -e "$NEW_LAYER_DIR" ]]; then
  log "layer already exists: $NEW_LAYER_DIR"
  log "leaving existing layer undisturbed"
  return 0
fi

# We expect the base layer (TEMPLATE_DIR) to have the required files
if [[ ! -f "$GEET_LIB/git.sh" || ! -f "$GEET_LIB/init.sh" ]]; then
  die "source files missing (expected at $GEET_LIB/)"
fi

###############################################################################
# CREATE NEW LAYER STRUCTURE
###############################################################################

log "creating new template layer: .$LAYER_NAME"

# make empty dirs
mkdir -p "$NEW_LAYER_DIR"

# append the layer name into the hierarchy
# Copy from the base template's .geethier if it exists
if [[ -f "$TEMPLATE_DIR/.geethier" ]]; then
  cp "$TEMPLATE_DIR/.geethier" "$NEW_LAYER_DIR/.geethier"
else
  touch "$NEW_LAYER_DIR/.geethier"
fi
echo "$LAYER_NAME" >> "$NEW_LAYER_DIR/.geethier"
debug "made" "$NEW_LAYER_DIR/.geethier"


cp "$GEET_LIB/../layer/README.md" "$NEW_LAYER_DIR/README.md"
sed -i "s|\\\$LAYER_NAME|$LAYER_NAME|g" "$NEW_LAYER_DIR/README.md"
sed -i "s|\\\$GH_USER|$GH_USER|g" "$NEW_LAYER_DIR/README.md"
sed -i "s|\\\$NEW_TEMPLATE_DESC|$NEW_TEMPLATE_DESC|g" "$NEW_LAYER_DIR/README.md"
sed -i "s|\\\$DD_APP_NAME|$DD_APP_NAME|g" "$NEW_LAYER_DIR/README.md"
sed -i "s|\\\$TEMPLATE_FILE_SUFFIX|$TEMPLATE_FILE_SUFFIX|g" "$NEW_LAYER_DIR/README.md"
debug "wrote" "$NEW_LAYER_DIR/README.md" .g


cp "$GEET_LIB/../layer/parent.gitignore" "$NEW_LAYER_DIR/parent.gitignore"
sed -i "s|\\\$LAYER_NAME|$LAYER_NAME|g" "$NEW_LAYER_DIR/parent.gitignore"
sed -i "s|\\\$TEMPLATE_FILE_SUFFIX|$TEMPLATE_FILE_SUFFIX|g" "$NEW_LAYER_DIR/parent.gitignore"
debug "wrote" "$NEW_LAYER_DIR/parent.gitignore"


extract_flag --topics TEMPLATE_TOPICS
extract_flag --homepage TEMPLATE_HOMEPAGE
write_geet_template_env() {
  local target="$NEW_LAYER_DIR/template-config.env"
  cp "$GEET_LIB/../layer/template-config.env" "$NEW_LAYER_DIR/template-config.env"
  sed -i "s|\\\$LAYER_NAME|$LAYER_NAME|g" "$NEW_LAYER_DIR/template-config.env"
  sed -i "s|\\\$NEW_TEMPLATE_DESC|$NEW_TEMPLATE_DESC|g" "$NEW_LAYER_DIR/template-config.env"
  sed -i "s|\\\$TEMPLATE_TOPICS|$TEMPLATE_TOPICS|g" "$NEW_LAYER_DIR/template-config.env"
  sed -i "s|\\\$TEMPLATE_HOMEPAGE|$TEMPLATE_HOMEPAGE|g" "$NEW_LAYER_DIR/template-config.env"
  sed -i "s|\\\$GH_USER|$GH_USER|g" "$NEW_LAYER_DIR/template-config.env"
  sed -i "s|\\\$GEET_ALIAS|$GEET_ALIAS|g" "$NEW_LAYER_DIR/template-config.env"
  sed -i "s|\\\$TEMPLATE_FILE_SUFFIX|$TEMPLATE_FILE_SUFFIX|g" "$NEW_LAYER_DIR/template-config.env"
  debug "wrote $target"
}

# Create template .env configuration files
write_geet_template_env
cp "$GEET_LIB/../layer/semitracked-template-config.env" "$NEW_LAYER_DIR/semitracked-template-config.env"
log "created template .env configuration files"

# Create or copy .geetinclude from base template
if [[ -f "$TEMPLATE_DIR/.geetinclude" ]]; then
  log "copying .geetinclude template from $TEMPLATE_DIR/.geetinclude"
  cp "$TEMPLATE_DIR/.geetinclude" "$NEW_LAYER_DIR/.geetinclude"
else
  cp "$GEET_LIB/../layer/.geetinclude" "$NEW_LAYER_DIR/.geetinclude"
  sed -i "s|\\\$GEET_ALIAS|$GEET_ALIAS|g" "$NEW_LAYER_DIR/.geetinclude"
fi

# Create initial .geetexclude with base rules and markers for compiled includes
cp "$GEET_LIB/../layer/.geetexclude" "$NEW_LAYER_DIR/.geetexclude"
sed -i "s|\\\$LAYER_NAME|$LAYER_NAME|g" "$NEW_LAYER_DIR/.geetexclude"


###############################################################################
# MAKE A GIT WRAPPER
###############################################################################
cp "$GEET_LIB/../layer/geet-git.sh" "$NEW_LAYER_DIR/geet-git.sh"
sed -i "s|\\\$LAYER_NAME|$LAYER_NAME|g" "$NEW_LAYER_DIR/geet-git.sh"
sed -i "s|\\\$APP_NAME|$APP_NAME|g" "$NEW_LAYER_DIR/geet-git.sh"
sed -i "s|\\\$PATH_TO|$PATH_TO|g" "$NEW_LAYER_DIR/geet-git.sh"
chmod +x "$NEW_LAYER_DIR/geet-git.sh"
GEET_GIT="$NEW_LAYER_DIR/geet-git.sh"
log "created geet.sh wrapper (ensures excludesFile is always applied)"

###############################################################################
# MAKE A GEET WRAPPER
###############################################################################
cp "$GEET_LIB/../layer/geet.sh" "$NEW_LAYER_DIR/geet.sh"
sed -i "s|\\\$LAYER_NAME|$LAYER_NAME|g" "$NEW_LAYER_DIR/geet.sh"
chmod +x "$NEW_LAYER_DIR/geet.sh"
log "created geet.sh wrapper (ensures geet sees the correct template dir)"

mkdir -p "$NEW_LAYER_DIR/pre-commit"
cp "$GEET_LIB/../layer/pre-commit/README.md" "$NEW_LAYER_DIR/pre-commit/README.md"
sed -i "s|\\\$LAYER_NAME|$LAYER_NAME|g" "$NEW_LAYER_DIR/pre-commit/README.md"
chmod +x "$NEW_LAYER_DIR/pre-commit/README.md"

debug "added files"
###############################################################################
# INITIALIZE TEMPLATE GIT REPO FOR THE NEW LAYER
###############################################################################
NEW_DOTGIT="$NEW_LAYER_DIR/dot-git"
debug "NEW_DOTGIT=$NEW_DOTGIT"

if [ -e "$APP_DIR/.git" ]; then
  log "temporarily moving $APP_DIR/.git to $APP_DIR/not-git"
  mv "$APP_DIR/.git" "$APP_DIR/not-git"
fi

log "initializing template git repo for $LAYER_NAME using 'git init --separate-git-dir=$NEW_DOTGIT $APP_DIR'"
git init --separate-git-dir="$NEW_DOTGIT" "$APP_DIR"

log "removing the pointer file that git leaves behind when --separate-git-dir is specified"
rm "$APP_DIR/.git"

if [ -e "$APP_DIR/not-git" ]; then
  log "restoring our original git dir from $APP_DIR/not-git back to $APP_DIR/.git"
  mv "$APP_DIR/not-git" "$APP_DIR/.git"
fi

###############################################################################
# COMPILE WHITELIST AND CREATE INITIAL COMMIT
###############################################################################

# We run the NEW layer's geet.sh, not the base layer's.
# This ensures:
# - .geetinclude is compiled into .geetexclude
# - commands are scoped correctly to the new layer
#
# First, compile excludes by calling status (idempotent).
debug "sourcing sync"
source "$GEET_LIB/sync.sh"
debug "syncing"
sync
debug "synced"

# update the parents gitignore
debug "checking " "$APP_DIR/.gitignore"
touch "$APP_DIR/.gitignore"
grep -qxF "!.$LAYER_NAME/" "$APP_DIR/.gitignore" || echo "!.$LAYER_NAME/" >> "$APP_DIR/.gitignore"
grep -qxF "!.$LAYER_NAME/*" "$APP_DIR/.gitignore" || echo "!.$LAYER_NAME/*" >> "$APP_DIR/.gitignore"
grep -qxF ".$LAYER_NAME/dot-git" "$APP_DIR/.gitignore" || echo ".$LAYER_NAME/dot-git" >> "$APP_DIR/.gitignore"
grep -qxF "**/dot-git/" "$APP_DIR/.gitignore" || echo "**/dot-git/" >> "$APP_DIR/.gitignore"
grep -qxF "**/untracked-template-config.env" "$APP_DIR/.gitignore" || echo "**/untracked-template-config.env" >> "$APP_DIR/.gitignore"
grep -qxF "*$TEMPLATE_FILE_SUFFIX.*" "$APP_DIR/.gitignore" || echo "*$TEMPLATE_FILE_SUFFIX.*" >> "$APP_DIR/.gitignore"

geet_git add ".$LAYER_NAME/geet.sh"
geet_git add ".$LAYER_NAME/.geethier"
geet_git add ".$LAYER_NAME/.geetinclude"
geet_git add ".$LAYER_NAME/.geetexclude"
geet_git add ".$LAYER_NAME/template-config.env"
geet_git add ".$LAYER_NAME/geet-git.sh"
geet_git add ".$LAYER_NAME/pre-commit/README.md"


###############################################################################
# MANUALLY PERFORM INITIAL AUTO-PROMOTION
###############################################################################
geet_git add ".$LAYER_NAME/README.md"
log "setting up README.md promotion (see docs/AUTO_PROMOTE.md)"
readme_hash=$(git --git-dir="$NEW_DOTGIT" hash-object -w "$NEW_LAYER_DIR/README.md")
git --git-dir="$NEW_DOTGIT" update-index --add --cacheinfo 100644 "$readme_hash" "README.md"

geet_git add ".$LAYER_NAME/parent.gitignore"
log "setting up parent.gitignore promotion (see docs/AUTO_PROMOTE.md)"
pgi_hash=$(git --git-dir="$NEW_DOTGIT" hash-object -w "$NEW_LAYER_DIR/parent.gitignore")
git --git-dir="$NEW_DOTGIT" update-index --add --cacheinfo 100644 "$pgi_hash" ".gitignore"


###############################################################################
# SETUP MERGE DRIVERS
###############################################################################
git config merge.geetSuffixDriver.name "geet suffix merge driver"
git config merge.geetSuffixDriver.driver "$GEET_LIB/merge-drivers/suffix-merge.sh %O %A %B %P $TEMPLATE_FILE_SUFFIX"
git --git-dir="$NEW_DOTGIT" config merge.keep-ours.name "Always keep working tree version"
git --git-dir="$NEW_DOTGIT" config merge.keep-ours.driver "true"
mkdir -p "$NEW_DOTGIT/info"
cat >> "$NEW_DOTGIT/info/attributes" <<'EOF'
* merge=geetSuffixDriver
README.md merge=keep-ours
.gitignore merge=keep-ours
EOF


debug "added files and merge drivers"
###############################################################################
# SETUP PRE-COMMIT HOOKS
###############################################################################
# Create pre-commit hook to auto-promote README on future commits

log "creating pre-commit hook for auto-promotion"

mkdir -p "$NEW_DOTGIT/hooks"
cp "$GEET_LIB/pre-commit/hook.sh" "$NEW_DOTGIT/hooks/pre-commit"
chmod +x "$NEW_DOTGIT/hooks/pre-commit"
log "pre-commit hook created:"
log "  • Auto-promotes README.md and parent.gitignore to root"
log "  • Checks for app-specific patterns (configure in template-config.env)"

geet_git commit -m "Initial commit" || true


###############################################################################
# FINAL OUTPUT
###############################################################################
log "NICE! we think it worked!"
log "a template repo was created which uses $APP_DIR as its working directory, but its .git lives at $NEW_DOTGIT"
log "\`$GEET_ALIAS\` commands will call \`git\` for the template repo, while \`git\` will continue to mean your working repo"
log "you can modify the template's .gitignore using $NEW_LAYER_DIR/.geetinclude or $NEW_LAYER_DIR/.geetexclude"
log "you can modify some tracked settings at $NEW_LAYER_DIR/.templateconfig.env or untracked ones at $NEW_LAYER_DIR/untracked-template-config.env"
log "you can customize your template's README at $NEW_LAYER_DIR/README.md and we will sync it to the right location to show up in project root on GitHub and clones"

local PUB_APP=""
local PRI_APP=""
local INT_APP=""

has_flag --public PUB_APP
has_flag --private PRI_APP
has_flag --internal INT_APP

# Determine publish visibility
local publish_visibility="none"
if [[ -n "$PUB_APP" ]]; then
  publish_visibility="public"
elif [[ -n "$PRI_APP" ]]; then
  publish_visibility="private"
elif [[ -n "$INT_APP" ]]; then
  publish_visibility="internal"
fi

if [[ "$publish_visibility" != "none" ]];then
  source "$GEET_LIB/ghcli.sh"
  publish_template "--$publish_visibility"
  exit 0
fi



log
log "next steps:"
log "  1) stage files:           \`$GEET_ALIAS include \"app/index.tsx\" \"app/_layout.tsx\"\`  # we use include instead of add because it will modify the .geetinclude to allow the file in"
log "  2) commit:                \`$GEET_ALIAS commit -m \"Add the basic template\""\`
log "  5) publish to github:     \`$GEET_ALIAS publish template\`  # (or $GEET_ALIAS publish template --private)"

}  # end of template()
