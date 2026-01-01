#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# doctor.sh — sanity checks for this repo + template layers
#
# Goal:
# - Help humans quickly answer: "Is this repo set up correctly?"
# - Catch the most common foot-guns (especially committing dot-git/)
#
# This script is READ-ONLY:
# - It does not modify files
# - It does not run merges/resets/cleans
#
# It is layer-aware:
# - Run it as .geet/lib/doctor.sh or .sk2/lib/doctor.sh
# - It will check THIS layer and also report other detected layers
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$LAYER_DIR/.." && pwd)"

LAYER_NAME="$(basename "$LAYER_DIR")"
LAYER_NAME="${LAYER_NAME#.}"

APP_GIT="$ROOT/.git"
DOTGIT="$LAYER_DIR/dot-git"
GIT_SH="$SCRIPT_DIR/git.sh"
TREE_SH="$SCRIPT_DIR/tree.sh"
geetinclude="$LAYER_DIR/.geetinclude"
EXCLUDE_FILE="$DOTGIT/info/exclude"

# Pretty printing helpers
ok()   { echo "[$LAYER_NAME doctor] ✅ $*"; }
warn() { echo "[$LAYER_NAME doctor] ⚠️  $*" >&2; }
bad()  { echo "[$LAYER_NAME doctor] ❌ $*" >&2; }
info() { echo "[$LAYER_NAME doctor]    $*"; }

# Track whether we should exit nonzero
HAS_ERRORS=0
fail() { bad "$*"; HAS_ERRORS=1; }

###############################################################################
# Helpers
###############################################################################

# Returns 0 if command exists
have() { command -v "$1" >/dev/null 2>&1; }

# Print a short list of dot-directories that look like layers
# A "layer" is defined as: hidden dir at repo root containing git.sh
detect_layers() {
  # Only look one level deep, and only at hidden dirs.
  # (We intentionally ignore .git and other common dotdirs.)
  find "$ROOT" -maxdepth 1 -mindepth 1 -type d -name ".*" 2>/dev/null \
    | while IFS= read -r d; do
        base="$(basename "$d")"
        case "$base" in
          .|..|.git) continue ;;
        esac
        if [[ -f "$d/lib/git.sh" && -f "$d/lib/init.sh" ]]; then
          echo "$d"
        fi
      done | sort
}

# Check whether a path is tracked by the APP repo (not ignored).
# If it is tracked, that's a big red flag for dot-git.
app_tracks_path() {
  local path="$1"
  git -C "$ROOT" ls-files --error-unmatch -- "$path" >/dev/null 2>&1
}

###############################################################################
# Start
###############################################################################

info "repo root: $ROOT"
info "this layer: .$LAYER_NAME"

echo

###############################################################################
# 1) Basic file presence
###############################################################################

if [[ -d "$APP_GIT" && -f "$APP_GIT/HEAD" ]]; then
  ok "app repo present (.git exists)"
else
  fail "app repo missing or invalid: $APP_GIT"
fi

if [[ -f "$GIT_SH" ]]; then
  ok "layer git wrapper present: $GIT_SH"
else
  fail "missing layer git wrapper: $GIT_SH"
fi

if [[ -f "$SCRIPT_DIR/init.sh" ]]; then
  ok "layer init script present: $SCRIPT_DIR/init.sh"
else
  fail "missing layer init script: $SCRIPT_DIR/init.sh"
fi

# Check for post-init hook
POST_INIT_SH="$LAYER_DIR/post-init.sh"
if [[ -f "$POST_INIT_SH" ]]; then
  if [[ -x "$POST_INIT_SH" ]]; then
    ok "post-init hook present and executable: $POST_INIT_SH"
  else
    warn "post-init hook exists but is NOT executable: $POST_INIT_SH"
    info "fix with: chmod +x $POST_INIT_SH"
  fi
fi

if [[ -f "$geetinclude" ]]; then
  ok "whitelist spec present: $geetinclude"
else
  warn "whitelist spec missing: $geetinclude (template view may include nothing or behave unexpectedly)"
fi

echo

###############################################################################
# 2) Layer initialization state
###############################################################################

if [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]]; then
  ok "layer initialized (dot-git exists)"
else
  warn "layer NOT initialized (missing $DOTGIT/HEAD)"
  info "run: $SCRIPT_DIR/init.sh"
fi

# If dot-git exists, make sure compiled exclude exists (after git.sh runs at least once)
if [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]]; then
  if [[ -f "$EXCLUDE_FILE" ]]; then
    ok "compiled exclude present: $EXCLUDE_FILE"
  else
    warn "compiled exclude missing: $EXCLUDE_FILE"
    info "run: $GIT_SH status   (this should compile .geetinclude -> info/exclude)"
  fi
fi

echo

###############################################################################
# 3) Critical safety: dot-git must NOT be tracked by app repo
###############################################################################

# dot-git is a git database; committing it is disastrous.
# We warn hard if it's tracked or if ignore rules look missing.
if [[ -d "$DOTGIT" ]]; then
  # If ANY files under dot-git are tracked, that's a serious problem.
  # Check the exact path relative to root
  rel_dotgit="${DOTGIT#"$ROOT/"}"

  if app_tracks_path "$rel_dotgit" || git -C "$ROOT" ls-files -- "$rel_dotgit" | grep -q .; then
    fail "SECURITY: app repo is tracking $rel_dotgit (must be ignored; remove from git history)"
    info "fix (careful):"
    info "  git rm -r --cached -- \"$rel_dotgit\""
    info "  add to app .gitignore: **/dot-git/"
  else
    ok "dot-git is not tracked by app repo"
  fi

  # Also check that app ignore rules contain something like dot-git
  # This is a heuristic (gitignore can be split across files), so it's a warning not failure.
  if [[ -f "$ROOT/.gitignore" ]]; then
    if grep -Eq '(^|\s)(\*\*/dot-git/|\.geet/dot-git/|dot-git/)\s*$' "$ROOT/.gitignore"; then
      ok "app .gitignore appears to ignore dot-git/"
    else
      warn "app .gitignore does not obviously ignore dot-git/ (recommended: **/dot-git/)"
    fi
  else
    warn "app .gitignore missing (recommended: ignore **/dot-git/)"
  fi
fi

echo

###############################################################################
# 4) Light functional checks (read-only)
###############################################################################
# These checks make sure the layer git wrapper can talk to the layer repo
# WITHOUT modifying anything.

if [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]]; then
  if "$GIT_SH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ok "layer git wrapper can run git commands"
  else
    fail "layer git wrapper failed to run git (check permissions, env, or dot-git validity)"
  fi

  # Check that HEAD resolves
  if "$GIT_SH" rev-parse HEAD >/dev/null 2>&1; then
    ok "layer HEAD resolves"
  else
    warn "layer HEAD does not resolve yet (maybe no commits in layer repo)"
    info "after defining whitelist and committing, this will become OK"
  fi
fi

echo

###############################################################################
# 5) Report other detected layers (informational)
###############################################################################
info "detected layers at repo root:"
layers="$(detect_layers || true)"
if [[ -z "$layers" ]]; then
  info "  (none found)"
else
  while IFS= read -r d; do
    base="$(basename "$d")"
    name="${base#.}"
    dotgit="$d/dot-git"
    if [[ -f "$dotgit/HEAD" ]]; then
      info "  .$name  (initialized)"
    else
      info "  .$name  (not initialized)"
    fi
  done <<< "$layers"
fi

echo

###############################################################################
# Exit status
###############################################################################
if [[ "$HAS_ERRORS" -eq 1 ]]; then
  bad "doctor found errors"
  exit 2
fi

ok "doctor looks good"
exit 0
