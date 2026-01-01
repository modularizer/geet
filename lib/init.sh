#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# init.sh — layer initializer / bootstrapper (IDEMPOTENT)
#
# This script turns a freshly-cloned TEMPLATE REPO into a normal APP REPO,
# while preserving the template repo as a "layer view" living in:
#
#   <layer>/dot-git
#
# It is designed to be copied into any layer folder:
#   MyApp/.geet/lib/init.sh
#   MyApp/.sk2/lib/init.sh
#   MyApp/.mytemplate/lib/init.sh
#
# The same script works for both the base template layer (.geet) and any
# additional template layer folders created by template.sh.
#
# -----------------------------------------------------------------------------
# Key idea (two repos, one working tree):
#
#   - App repo:       MyApp/.git            (normal development)
#   - Layer template: MyApp/.<layer>/dot-git (tracks only whitelisted files)
#
# Both repos share the same working tree (MyApp/), but have separate gitdirs.
#
# -----------------------------------------------------------------------------
# What init.sh does (the common case):
#
#   Starting state after cloning a template repo:
#     MyApp/.git exists                 (belongs to the template you cloned)
#     MyApp/.<layer>/dot-git does NOT   (not yet created)
#
#   init.sh performs:
#     1) Move MyApp/.git -> MyApp/.<layer>/dot-git
#        (this "captures" the cloned template repo git database)
#     2) Create a brand new app repo: git init (creates new MyApp/.git)
#     3) Ensure layer whitelist rules are in effect by compiling .geetinclude
#        (delegated to git.sh; this script calls git.sh status to trigger it)
#
# -----------------------------------------------------------------------------
# Idempotency / safety:
#
# - If <layer>/dot-git already exists, we do NOT run again.
#   We print a friendly message and exit successfully.
#
# - If the repo state looks unexpected, we fail rather than guess.
#
###############################################################################

###############################################################################
# PATH DISCOVERY
###############################################################################

# Directory this script lives in (.geet/lib)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Layer directory (e.g. /path/to/MyApp/.geet or /path/to/MyApp/.sk2)
LAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Layer name used for log prefixes:
#   .geet -> geet
#   .sk2 -> sk2
LAYER_NAME="$(basename "$LAYER_DIR")"
LAYER_NAME="${LAYER_NAME#.}"

# Project root is the parent directory of the layer folder.
ROOT="$(cd "$LAYER_DIR/.." && pwd)"

###############################################################################
# IMPORTANT PATHS
###############################################################################

# Where the layer template repo git database will live (this is the "captured" .git)
DOTGIT="$LAYER_DIR/dot-git"

# App repo git directory (normal repo). This exists AFTER init (and before, if we cloned).
APP_GIT="$ROOT/.git"

# Layer git wrapper (used to run git in the template view and to compile whitelist rules)
GIT_SH="$SCRIPT_DIR/git.sh"

###############################################################################
# HELPERS
###############################################################################
die() { echo "[$LAYER_NAME init] $*" >&2; exit 1; }
log() { echo "[$LAYER_NAME init] $*" >&2; }

###############################################################################
# PRECONDITIONS
###############################################################################

# Sanity: this file is expected to live next to git.sh in the layer dir.
# We don't strictly require it, but it is very useful for post-init sync/exclude.
if [[ ! -f "$GIT_SH" ]]; then
  log "warning: missing $GIT_SH (will skip post-init exclude sync)"
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
  exit 0
fi

###############################################################################
# MAIN CONVERSION LOGIC
###############################################################################

# The expected "fresh clone" state for THIS layer is:
#   - APP_GIT exists (because you just cloned a template repo)
#   - DOTGIT does not exist yet
#
# Example:
#   - user clones geet template to MyApp2
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
mkdir -p "$LAYER_DIR"

# Create DOTGIT parent dir (LAYER_DIR exists, but be explicit)
mkdir -p "$DOTGIT"

# If DOTGIT exists but doesn't look like a git dir, that's suspicious.
# We refuse to overwrite it.
if [[ -e "$DOTGIT" && ! -f "$DOTGIT/HEAD" ]]; then
  die "$DOTGIT exists but is not a git directory (missing HEAD). Refusing to proceed."
fi

log "capturing cloned template repo:"
log "  moving $APP_GIT -> $DOTGIT"
mv "$APP_GIT" "$DOTGIT"

###############################################################################
# INSTALL DEFAULT WHITELIST (FIRST RUN ONLY)
###############################################################################

GITINCLUDE="$LAYER_DIR/.geetinclude"
GITINCLUDE_SAMPLE="$LAYER_DIR/geetinclude.sample"

if [[ ! -f "$GITINCLUDE" ]]; then
  if [[ -f "$GITINCLUDE_SAMPLE" ]]; then
    log "installing default whitelist:"
    log "  $GITINCLUDE_SAMPLE -> $GITINCLUDE"
    cp "$GITINCLUDE_SAMPLE" "$GITINCLUDE"
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
# - ROOT/.git no longer exists
# - DOTGIT contains the template git database
#
# Now we create a fresh app repo at ROOT/.git
log "initializing new app repo at $APP_GIT"
git -C "$ROOT" init >/dev/null

###############################################################################
# POST-INIT: COMPILE WHITELIST / EXCLUDES
###############################################################################

# The whitelist compilation lives in git.sh (single responsibility).
#
# We trigger it by calling "status" in the layer view, which should:
# - compile .geetinclude -> dot-git/info/exclude
# - show template status (optional)
if [[ -f "$GIT_SH" ]]; then
  log "syncing whitelist rules (.geetinclude -> dot-git/info/exclude)"
  # We do not care about the status output, only that it runs without error.
  "$GIT_SH" status >/dev/null || true
fi


if [[ "${GEET_RUN_POST_INIT:-1}" == "1" ]]; then
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
  # - Running it is equivalent to “running a script from the internet”.
  # - Keep it simple and obvious, and consider requiring an env var gate later.
  POST_INIT_SH="$LAYER_DIR/post-init.sh"

  if [[ -f "$POST_INIT_SH" ]]; then
    if [[ ! -x "$POST_INIT_SH" ]]; then
      die "found post-init hook but it is not executable: $POST_INIT_SH (run: chmod +x $POST_INIT_SH)"
    fi

    log "running post-init hook:"
    log "  $POST_INIT_SH"

    # Provide some context to the hook.
    # The hook can use these to make decisions without re-discovering paths.
    export GEET_LAYER_DIR="$LAYER_DIR"
    export GEET_LAYER_NAME="$LAYER_NAME"
    export GEET_ROOT="$ROOT"
    export GEET_DOTGIT="$DOTGIT"

    # Run from the project root so relative paths behave naturally.
    # Pass through any arguments that were provided to init.sh (from clone command).
    (
      cd "$ROOT"
      "$POST_INIT_SH" "$@"
    )

    log "post-init hook complete"
  fi

fi


###############################################################################
# FINAL OUTPUT
###############################################################################
log "done"
log "layer initialized:"
log "  layer:  $LAYER_NAME"
log "  worktree: $ROOT"
log "  layer gitdir: $DOTGIT"
log "  app gitdir:   $APP_GIT"
log
log "next steps:"
log "  - develop normally with: git ..."
log "  - update this layer with: $SCRIPT_DIR/git.sh pull"
log "  - see included files with: $SCRIPT_DIR/tree.sh tree  (if present)"
