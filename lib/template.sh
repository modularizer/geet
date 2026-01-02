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

# Show help if requested
if [[ "$RAW_NAME" == "help" || "$RAW_NAME" == "-h" || "$RAW_NAME" == "--help" ]]; then
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
  $GEET_ALIAS template <name> [description]

Examples:
  $GEET_ALIAS template mytemplate
  $GEET_ALIAS template mytemplate "A React Native base project"
  $GEET_ALIAS template sk2 "Starter kit v2 with TypeScript"

Requirements:
  - <name> must be non-empty and different from the app name
  - <name> cannot contain spaces

What this creates:
  - $DEMO_DOC_APP_NAME/$DEMO_DOC_TEMPLATE_NAME/         (new layer directory)
  - $DEMO_DOC_APP_NAME/$DEMO_DOC_TEMPLATE_NAME/dot-git/  (template's git repository)
  - $DEMO_DOC_APP_NAME/$DEMO_DOC_TEMPLATE_NAME/geet-git.sh  (git wrapper for template repo)
  - $DEMO_DOC_APP_NAME/$DEMO_DOC_TEMPLATE_NAME/geet.sh      (geet wrapper for template)
  - $DEMO_DOC_APP_NAME/$DEMO_DOC_TEMPLATE_NAME/.geetinclude (whitelist of files to include)
  - $DEMO_DOC_APP_NAME/$DEMO_DOC_TEMPLATE_NAME/.geetexclude (compiled excludes)
  - $DEMO_DOC_APP_NAME/$DEMO_DOC_TEMPLATE_NAME/README.md    (template documentation)
EOF
  return 0
fi

# Validation: must be non-empty
if [[ -z "$RAW_NAME" ]]; then
  die "template requires a name argument (e.g., '$GEET_ALIAS template mytemplate')"
fi

# Normalize: remove leading dot if present
LAYER_NAME="${RAW_NAME#.}"

# Validation: cannot be empty after normalization
if [[ -z "$LAYER_NAME" ]]; then
  die "template name cannot be empty or just a dot"
fi

# Validation: cannot contain spaces
if [[ "$LAYER_NAME" =~ [[:space:]] ]]; then
  die "template name cannot contain spaces: '$LAYER_NAME'"
fi

# Validation: must be different from app name
if [[ "$LAYER_NAME" == "$APP_NAME" ]]; then
  die "template name must be different from app name: '$APP_NAME'"
fi

NEW_LAYER_DIR="$APP_DIR/.${LAYER_NAME}"
TEMPLATE_DIR="$NEW_LAYER_DIR"

# Optional description argument
NEW_TEMPLATE_DESC="${2:-}"




debug "new template layer will be created at: $NEW_LAYER_DIR"



###############################################################################
# SAFETY CHECKS
###############################################################################

# Check if we have a git repo in current directory
if [[ ! -d "$APP_DIR/.git" ]]; then
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


cat > "$NEW_LAYER_DIR/README.md" <<EOFREADME
# Welcome to the "$LAYER_NAME" template!

$(if [[ -n "$NEW_TEMPLATE_DESC" ]]; then echo "$NEW_TEMPLATE_DESC"; echo; fi)This template was created with [geet](https://github.com/modularizer/geet),
a CLI git wrapper which acts as an alternative to git submodules,
allowing publishing a template which controls files which are interspersed in the same working directory as your project.

### Things to know:
1. Typically, template files get double-tracked
   - They get pulled into your working directory and tracked by YOU
   - They ALSO are tracked by the remote template repo
   - If and when you wish, you can pull updates from the template repo into your project and add and commit the files into your repo
   - If you are a developer/contributor of the template repo, you can optionally push code back to the template repo using a different git command
2. \`$GEET_ALIAS\` is the suggested entrypoint for all your pull/push git-like commands. It protects you and adds some features. More on that later.
3. $NEW_LAYER_DIR/git.sh is the base git command controlling this template repo, but **use with caution** or not at all. It runs something _similar_ to
   \`\`\`bash
   git --git-dir=".$LAYER_NAME/dot-git" --work-tree="." -c "core.excludesFile=.$LAYER_NAME/.geetexclude" "\$@"
   \`\`\`
   clean, reset, or checkout commands (amongst others) on the template repo could accidentally destroy files in your actual repo
4. don't worry about \`.geethier\`, just leave it be. all it does is identify and trace the layering of templates
5. You can either operate your template on an include or and exclude basis. You probably know .gitignores are standard, and normally exclude, but in this case since we have all the app code stuff can be a bit different.
   - Let's say your actual full app is 80% of the code and the generic stuff you are turning into a template is only 20% of the code, it might be best to exclude everything to avoid committing implementation-specific code to the template repo, then add some generic files and folders back in, to allow commiting them to the template. This is when you would use .geetinclude for the convenience
   - Alternatively, if your primary goal is to develop a template, and 80% of your code is reusable, but then you just have 20% of "sample" code that you don't want included, maybe just overwrite .geetexclude file entierly, **but leave \*\*/dot-git/ excluded**
   - read the comments in .geetexclude for more info
   - use `$GEET_ALIAS tree` to see what is currently included in the template repo
6. geet supports many layered templating, so if you want to extend a template and publish as a new template it is definitly possible! See .geehier to see how many levels this one has

If you're the owner of this template, feel free to overwrite or add to this README to tell users about what your project does. It's all your's from here.

NOTE: this is an auto-generated README so we're just guessing here, but it is likely you can find more info about this template at [https://github.com/$GH_USER/$LAYER_NAME](https://github.com/$GH_USER/$LAYER_NAME), worth trying?!
EOFREADME
debug "wrote" "$NEW_LAYER_DIR/README.md"

# Create geet-config.json with defaults
cat > "$NEW_LAYER_DIR/geet-config.json" <<EOFCONFIG
{
  "name": "$LAYER_NAME",
  "desc": "$NEW_TEMPLATE_DESC",
  "geetAlias": "$GEET_ALIAS",
  "ghUser": "$GH_USER",
  "ghName": "$LAYER_NAME",
  "ghURL": "https://github.com/$GH_USER/$LAYER_NAME",
  "ghSSH": "git@github.com:$GH_USER/$LAYER_NAME.git",
  "ghHTTPS": "https://github.com/$GH_USER/$LAYER_NAME.git",
  "preventCommit": {
    "filePatterns": [
      ".*\\\\.env.*",
      ".*secret.*",
      ".*\\\\.key$"
    ],
    "contentPatterns": [
      "API_KEY=",
      "SECRET_KEY=",
      "password:\\\\s*[\"'].*[\"']",
      "TODO.*remove.*template"
    ]
  }
}
EOFCONFIG
debug "wrote" "$NEW_LAYER_DIR/geet-config.json"



log "created geet-config.json (edit to set your GitHub info)"

# Create or copy .geetinclude from base template
if [[ -f "$TEMPLATE_DIR/.geetinclude" ]]; then
  log "copying .geetinclude template from $TEMPLATE_DIR/.geetinclude"
  cp "$TEMPLATE_DIR/.geetinclude" "$NEW_LAYER_DIR/.geetinclude"
else
  cat > "$NEW_LAYER_DIR/.geetinclude" <<'EOFGEETINCLUDE'
# Add your include stuff here, you can call '$GEET_ALIAS sync' to sync it to the .geetexclude if you wish, but it will also auto-sync on every geet command
EOFGEETINCLUDE
fi

# Create initial .geetexclude with base rules and markers for compiled includes
cat > "$NEW_LAYER_DIR/.geetexclude" <<EOFGEETEXCLUDE
#-----------------------------------------------------------------------------------------------------------------------
# FAQ SECTION (docs)
#-----------------------------------------------------------------------------------------------------------------------
# Q: Can I fully overwrite this file?
# A: YES BUT: you MUST ensure **/dot-git/ gets ignored/excluded

# Q: How to sync from my .$LAYER_NAME/.geetinclude?
# A: run \`$GEET_ALIAS sync\` or \`.$LAYER_NAME/bin/git-sync.sh\`

#-----------------------------------------------------------------------------------------------------------------------
# DEFAULT INCLUDE SECTION (optional)
#    this section excludes everything, then adds back in some tools
#-----------------------------------------------------------------------------------------------------------------------
*
!*/
!.$LAYER_NAME/geet.sh
!.$LAYER_NAME/.geethier
!.$LAYER_NAME/.geetinclude
!.$LAYER_NAME/.geetexclude
!.$LAYER_NAME/geet-config.json
!.$LAYER_NAME/geet-git.sh
!.$LAYER_NAME/README.md

#-----------------------------------------------------------------------------------------------------------------------
# AUTOGENERATED INCLUDE SECTION (optional)
#    now add back in contents from .geetinclude, just flipped
#-----------------------------------------------------------------------------------------------------------------------
# GEETINCLUDESTART

# Whoops! either .$LAYER_NAME/.geetinclude is empty or .$LAYER_NAME/.geetinclude hasn't been synced

# GEETINCLUDEEND

#-----------------------------------------------------------------------------------------------------------------------
# MANUAL EXCLUDE SECTION
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
GEET_GIT="$NEW_LAYER_DIR/geet-git.sh"
log "created geet.sh wrapper (ensures excludesFile is always applied)"

###############################################################################
# MAKE A GEET WRAPPER
###############################################################################
cat > "$NEW_LAYER_DIR/geet.sh" <<EOFGEET
#!/usr/bin/env bash
# this file behaves like geet, but always specifies our correct template directory, so it can be called from anywhere
THIS_FILE="\${BASH_SOURCE[0]}"
THIS_DIR="\$(cd -- "\$(dirname -- "\$THIS_FILE")" && pwd)"
exec geet --geet-dir "\$THIS_DIR" "\$@"
EOFGEET
chmod +x "$NEW_LAYER_DIR/geet.sh"
log "created geet.sh wrapper (ensures geet sees the correct template dir)"


debug "added files"
###############################################################################
# INITIALIZE TEMPLATE GIT REPO FOR THE NEW LAYER
###############################################################################
NEW_DOTGIT="$NEW_LAYER_DIR/dot-git"
debug "NEW_DOTGIT=$NEW_DOTGIT"

if [ -d "$APP_DIR/.git" ]; then
  log "temporarily moving $APP_DIR/.git to $APP_DIR/not-git"
  mv "$APP_DIR/.git" "$APP_DIR/not-git"
fi

log "initializing template git repo for $LAYER_NAME using 'git init --separate-git-dir=$NEW_DOTGIT $APP_DIR'"
git init --separate-git-dir="$NEW_DOTGIT" "$APP_DIR"

log "removing the pointer file that git leaves behind when --separate-git-dir is specified"
rm "$APP_DIR/.git"

if [ -d "$APP_DIR/not-git" ]; then
  log "restoring our original git dir from $APP_DIR/not-git back to $APP_DIR/.git"
  mv "$APP_DIR/not-git" "$APP_DIR/.git"
fi

# log "don't worry, that file-shuffle was kinda ugly but it was a one-time thing, we don't need to do on every command"
# log "instead, in the future we will use something like 'git --git-dir=<somefolder> --work-tree=<somefolder> -c core.exludesFile=<somefile>'"


###############################################################################
# COMPILE WHITELIST AND CREATE INITIAL COMMIT
###############################################################################

# We run the NEW layer's geet.sh, not the base layer's.
# This ensures:
# - .geetinclude is compiled into .geetexclude
# - commands are scoped correctly to the new layer
#
# First, compile excludes by calling status (idempotent).
source "$GEET_LIB/sync.sh"
sync
geet_git add ".$LAYER_NAME/geet.sh"
geet_git add ".$LAYER_NAME/.geethier"
geet_git add ".$LAYER_NAME/.geetinclude"
geet_git add ".$LAYER_NAME/.geetexclude"
geet_git add ".$LAYER_NAME/geet-config.json"
geet_git add ".$LAYER_NAME/geet-git.sh"

debug "added files"
geet_git commit -m "Initial $LAYER_NAME template"
log "committed initial files"

###############################################################################
# SETUP README PROMOTION
###############################################################################
# Promote .mytemplate/README.md to README.md so it shows on GitHub
# Uses merge=keep-ours to prevent conflicts after README files diverge

log "setting up README.md promotion (see docs/AUTO_PROMOTE.md)"

# Set up keep-ours merge driver (prevents conflicts)
git --git-dir="$NEW_DOTGIT" config merge.keep-ours.name "Always keep working tree version"
git --git-dir="$NEW_DOTGIT" config merge.keep-ours.driver "true"

# Get hash of README.md content
readme_hash=$(git --git-dir="$NEW_DOTGIT" hash-object -w "$NEW_LAYER_DIR/README.md")

# Stage README at promoted location (root)
git --git-dir="$NEW_DOTGIT" update-index --add --cacheinfo 100644 "$readme_hash" "README.md"

# Configure merge strategy for promoted README
mkdir -p "$NEW_DOTGIT/info"
echo "README.md merge=keep-ours" >> "$NEW_DOTGIT/info/attributes"

###############################################################################
# SETUP PRE-COMMIT HOOKS
###############################################################################
# Create pre-commit hook to auto-promote README on future commits

log "creating pre-commit hook for auto-promotion"

mkdir -p "$NEW_DOTGIT/hooks"
cp "$GEET_LIB/pre-commit/hook.sh" "$NEW_DOTGIT/hooks/pre-commit"
chmod +x "$NEW_DOTGIT/hooks/pre-commit"
log "pre-commit hook created:"
log "  • Auto-promotes README.md to root"
log "  • Checks for app-specific patterns (see geet-config.json)"

# Commit the initial promotion
git --git-dir="$NEW_DOTGIT" --work-tree="$APP_DIR" commit -m "Promote README.md to root

This allows the template README to show on GitHub at the root level,
while the working tree can have a different README.md for the app.

Uses merge=keep-ours to prevent conflicts when files diverge.
Auto-promotes on each commit via pre-commit hook.
See docs/AUTO_PROMOTE.md for details." 2>/dev/null || true

log "README.md will appear at root on GitHub"
log "future edits to .$LAYER_NAME/README.md auto-promote to README.md"

geet_git add ".$LAYER_NAME/README.md"
geet_git commit -m "Initial readme"
###############################################################################
# SETUP CUSTOM ALIAS (package.json if present)
###############################################################################

PACKAGE_JSON="$APP_DIR/package.json"
if [[ -f "$PACKAGE_JSON" ]]; then
  # Check if jq is available for safe JSON manipulation
  if command -v jq >/dev/null 2>&1; then
    log "adding '$LAYER_NAME' script to package.json"

    # Add script using jq
    tmp_json=$(mktemp)
    jq --arg name "$LAYER_NAME" --arg path ".$LAYER_NAME/geet.sh" \
      '.scripts[$name] = $path' \
      "$PACKAGE_JSON" > "$tmp_json"
    mv "$tmp_json" "$PACKAGE_JSON"

    log "you can now run: npm run $LAYER_NAME <command>"
  else
    log "tip: install jq to auto-add npm scripts"
    log "or manually add to package.json:"
    log "  \"scripts\": { \"$LAYER_NAME\": \".$LAYER_NAME/geet.sh\" }"
  fi
fi


# update the parents gitignore
debug "checking " "$APP_DIR/.gitignore"
touch "$APP_DIR/.gitignore"
grep -qxF "**/dot-git/" "$APP_DIR/.gitignore" || echo "**/dot-git/" >> "$APP_DIR/.gitignore"


###############################################################################
# FINAL OUTPUT
###############################################################################

log "done"
log "new template layer created:"
log "  layer name: .$LAYER_NAME"
log "  location:   $NEW_LAYER_DIR"
log
log "next steps:"
log "  1) edit: $NEW_LAYER_DIR/.geetinclude"
log "  2) cd $APP_DIR"
log "  3) stage files: $GEET_ALIAS add -A"
log "  4) commit:      $GEET_ALIAS commit -m \"Add the basic template\""
log "  5) publish:     $GEET_ALIAS publish --public"

}  # end of template()
