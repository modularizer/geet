# init.sh — layer initializer / bootstrapper (IDEMPOTENT)
# Usage:
#   source init.sh
#   init [args...]
#
# Turns a freshly-cloned TEMPLATE REPO into a normal APP REPO,
# while preserving the template repo as a "layer view" in dot-git/

init() {

###############################################################################
# HELP
###############################################################################
if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
$GEET_ALIAS init — initialize a freshly-cloned template repo as your app

This command turns a freshly-cloned TEMPLATE REPO into a normal APP REPO,
while preserving the template repo as a "layer view" in dot-git/

What it does:
  1. Moves .git → .$APP_NAME/dot-git (or whatever the layer is called)
     This "captures" the cloned template repo's git database
  2. Creates a brand new app repo at .git
     Your new app starts with a clean slate
  3. Syncs whitelist rules (.geetinclude → .geetexclude)
  4. Ensures .gitignore excludes **/dot-git/
  5. Optionally runs post-init hook if present

Usage:
  $GEET_ALIAS init [post-init-args...]

  Note: Usually called automatically by '$GEET_ALIAS install'

Arguments:
  post-init-args  Optional arguments passed to the post-init hook
                  (if .geet/post-init.sh exists and is executable)

Key Idea (two repos, one working tree):
  - App repo:       $DD_APP_NAME/.git              (your normal development)
  - Template layer: $DD_APP_NAME/.geet/dot-git     (tracks whitelisted files only)

  Both repos share the same working tree ($DD_APP_NAME/), but have separate gitdirs.

Idempotency:
  - If already initialized, prints status and exits successfully
  - Safe to run multiple times

Environment Variables:
  GEET_RUN_POST_INIT  Set to 0 to skip post-init hook (default: 1)

Examples:
  cd MyNewApp && $GEET_ALIAS init
  cd MyNewApp && $GEET_ALIAS init --app-name "My Cool App"
  GEET_RUN_POST_INIT=0 $GEET_ALIAS init  # Skip post-init hook
EOF
  return 0
fi

source "$GEET_LIB/has-flag.sh" --skip-post SKIP_POST_INIT "$@"

###############################################################################
# SETUP
###############################################################################
# digest-and-locate.sh provides: GEET_LIB, APP_DIR, TEMPLATE_DIR, DOTGIT,
# TEMPLATE_GEET_CMD, die, log, debug

# App repo git directory (normal repo)
APP_GIT="$APP_DIR/.git"

###############################################################################
# PRECONDITIONS
###############################################################################

# Sanity check: git.sh should exist
if [[ ! -f "$GEET_LIB/git.sh" ]]; then
  log "warning: missing $GEET_LIB/git.sh (will skip post-init exclude sync)"
fi

###############################################################################
# IDEMPOTENCY CHECK
###############################################################################

# If the layer dot-git already exists, we've already initialized this layer
# for this working tree. Do not attempt to re-run conversion.
if [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]]; then
  log "already initialized"
  log "layer gitdir: $DOTGIT"
  log "app gitdir:   $APP_GIT"
  return 0
fi

###############################################################################
# MAIN CONVERSION LOGIC
###############################################################################

# The expected "fresh clone" state for THIS layer is:
#   - APP_GIT exists (because you just cloned a template repo)
#   - DOTGIT does not exist yet
#
# Example:
#   - user clones $GEET_ALIAS template to MyApp2
#   - MyApp2/.git exists
#   - MyApp2/.geet/dot-git does not
#
# Another example:
#   - user clones sk2 template to MyApp3
#   - MyApp3/.git exists
#   - MyApp3/.sk2/dot-git does not
#
# If APP_GIT doesn't exist, we do NOT know what to do (maybe user didn't clone).
if [[ ! -d "$APP_GIT" ]]; then
  die "expected $APP_GIT to exist (did you run this in a freshly cloned template repo?)"
fi

# Create layer directory if missing (should exist because this script is inside it)
mkdir -p "$TEMPLATE_DIR"

log "moving $APP_GIT to $DOTGIT"
mv "$APP_GIT" "$DOTGIT"

###############################################################################
# INSTALL DEFAULT WHITELIST (FIRST RUN ONLY)
###############################################################################

GITINCLUDE_SAMPLE="$TEMPLATE_DIR/geetinclude.sample"

if [[ ! -f "$TEMPLATE_DIR/.geetinclude" ]]; then
  if [[ -f "$GITINCLUDE_SAMPLE" ]]; then
    log "installing default whitelist:"
    log "  $GITINCLUDE_SAMPLE -> $TEMPLATE_DIR/.geetinclude"
    cp "$GITINCLUDE_SAMPLE" "$TEMPLATE_DIR/.geetinclude"
  else
    log "no .geetinclude or geetinclude.sample found (whitelist left empty)"
  fi
else
  log "whitelist already exists: .geetinclude"
fi

###############################################################################
# CREATE NEW APP REPO
###############################################################################

# After the move:
# - APP_DIR/.git no longer exists
# - DOTGIT contains the template git database
#
# Now we create a fresh app repo at APP_DIR/.git
log "initializing new app repo at $APP_GIT"
git -C "$APP_DIR" init >/dev/null

###############################################################################
# POST-INIT: COMPILE WHITELIST / EXCLUDES
###############################################################################

# Sync whitelist rules (.geetinclude -> .geetexclude)
if [[ -f "$GEET_LIB/sync.sh" ]]; then
  log "syncing whitelist rules (.geetinclude -> .geetexclude)"
  source "$GEET_LIB/sync.sh"
  sync >/dev/null || true
fi

###############################################################################
# ENSURE APP .geetexclude IGNORES dot-git/
###############################################################################

# Critical safety: dot-git/ contains git internals and must NEVER be committed
# to the app repo. Ensure it's in .gitignore.
APP_GITIGNORE="$APP_DIR/.gitignore"
DOTGIT_PATTERN="**/dot-git/"

if [[ -f "$APP_GITIGNORE" ]]; then
  # Check if any form of dot-git ignore already exists
  if ! grep -Eq '(^|[[:space:]])((\*\*/)?dot-git/|\.geet/dot-git/)([[:space:]]|$)' "$APP_GITIGNORE"; then
    log "adding $DOTGIT_PATTERN to app .gitignore"
    echo "$DOTGIT_PATTERN" >> "$APP_GITIGNORE"
  else
    log "app .gitignore already ignores dot-git/"
  fi
else
  log "creating app .gitignore with $DOTGIT_PATTERN"
  echo "$DOTGIT_PATTERN" > "$APP_GITIGNORE"
fi

###############################################################################
# FINAL OUTPUT
###############################################################################
log "done"
log "layer initialized:"
log "  layer:  $TEMPLATE_NAME"
log "  worktree: $APP_DIR"
log "  layer gitdir: $DOTGIT"
log "  app gitdir:   $APP_GIT"
log
log "next steps:"
log "  - develop normally with: git ..."
log "  - update this layer with: $GEET_ALIAS pull"
log "  - see included files with: $GEET_ALIAS tree"


if  ! [[ "$SKIP_POST_INIT" ]]; then
  ###############################################################################
  # OPTIONAL POST-INIT HOOK
  ###############################################################################
  # Some templates want to do a one-time setup step after init, e.g.:
  # - create .env from .env.sample
  # - rename package name / bundle id
  # - install dependencies
  # - print “next steps” instructions
  #
  # geet itself should not become a framework-specific scaffold tool, so we keep
  # this mechanism very small and template-owned:
  #
  #   - If <layer>/post-init.sh exists AND is executable, we run it.
  #   - Otherwise, we do nothing.
  #
  # Security note:
  # - This is code from the template you just cloned.
  # - Running it is equivalent to "running a script from the internet".
  # - Keep it simple and obvious, and consider requiring an env var gate later.
  POST_INIT_SH="$TEMPLATE_DIR/post-init.sh"

  if [[ -f "$POST_INIT_SH" ]]; then
    if [[ ! -x "$POST_INIT_SH" ]]; then
      die "found post-init hook but it is not executable: $POST_INIT_SH (run: chmod +x $POST_INIT_SH)"
    fi

    log "running post-init hook:"
    log "  $POST_INIT_SH"

    # Provide some context to the hook.
    # The hook can use these to make decisions without re-discovering paths.
    export GEET_LAYER_DIR="$TEMPLATE_DIR"
    export GEET_LAYER_NAME="$TEMPLATE_NAME"
    export GEET_ROOT="$APP_DIR"
    export GEET_DOTGIT="$DOTGIT"

    # Run from the project root so relative paths behave naturally.
    # Pass through any arguments that were provided to init.sh (from install command).
    (
      cd "$APP_DIR"
      "$POST_INIT_SH" "$@"
    )

    log "post-init hook complete"
    log "enjoy developing!"
  fi

fi

}  # end of init()
