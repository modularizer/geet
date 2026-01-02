# doctor.sh — sanity checks for this repo + template layers
# Usage:
#   source doctor.sh
#   doctor
#
# Read-only health checks to catch common setup issues

doctor() {

# Show help if requested
if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
$GEET_ALIAS doctor — run health checks on your geet setup

Goal:
  - Help you quickly answer: "Is this repo set up correctly?"
  - Catch common foot-guns (especially committing dot-git/)

What it checks:
  ✅ App repo exists (.git)
  ✅ Layer scripts present (git.sh, init.sh, etc.)
  ✅ Template git repo exists (dot-git/)
  ✅ Whitelist files exist (.geetinclude, .geetexclude)
  ✅ dot-git/ is NOT tracked by app repo (critical!)
  ✅ Detects other template layers

This is READ-ONLY:
  - Does not modify any files
  - Does not run merges/resets/cleans
  - Safe to run anytime

Usage:
  $GEET_ALIAS doctor

Exit code:
  0 - All checks passed
  1 - One or more issues found

Examples:
  $GEET_ALIAS doctor  # Run all checks
EOF
  return 0
fi

# digest-and-locate.sh provides: APP_DIR, TEMPLATE_DIR, DOTGIT, TEMPLATE_NAME,
# TEMPLATE_GEETINCLUDE, TEMPLATE_GEETEXCLUDE, GEET_LIB, die, log, debug

# Additional paths
APP_GIT="$APP_DIR/.git"

# Pretty printing helpers
ok()   { echo "[$TEMPLATE_NAME doctor] ✅ $*"; }
warn() { echo "[$TEMPLATE_NAME doctor] ⚠️  $*" >&2; }
bad()  { echo "[$TEMPLATE_NAME doctor] ❌ $*" >&2; }
info() { echo "[$TEMPLATE_NAME doctor]    $*"; }

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
  find "$APP_DIR" -maxdepth 1 -mindepth 1 -type d -name ".*" 2>/dev/null \
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
  git -C "$APP_DIR" ls-files --error-unmatch -- "$path" >/dev/null 2>&1
}

###############################################################################
# Start
###############################################################################

info "repo root: $APP_DIR"
info "this layer: $TEMPLATE_NAME"

echo

###############################################################################
# 1) Basic file presence
###############################################################################

if [[ -d "$APP_GIT" && -f "$APP_GIT/HEAD" ]]; then
  ok "app repo present (.git exists)"
else
  fail "app repo missing or invalid: $APP_GIT"
fi

if [[ -f "$GEET_LIB/git.sh" ]]; then
  ok "layer git wrapper present: $GEET_LIB/git.sh"
else
  fail "missing layer git wrapper: $GEET_LIB/git.sh"
fi

if [[ -f "$GEET_LIB/init.sh" ]]; then
  ok "layer init script present"
else
  fail "missing layer init script"
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


echo

###############################################################################
# 2) Layer initialization state
###############################################################################

if [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]]; then
  ok "layer initialized (dot-git exists)"
else
  warn "layer NOT initialized (missing $DOTGIT/HEAD)"
  info "run: $LAYER_NAME init"
fi

# If dot-git exists, make sure compiled exclude exists (after git.sh runs at least once)
if [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]]; then
  if [[ -f "$TEMPLATE_GEETEXCLUDE" ]]; then
    ok "compiled exclude present: $TEMPLATE_GEETEXCLUDE"
  else
    warn "compiled exclude missing: $TEMPLATE_GEETEXCLUDE"
    info "run: $LAYER_NAME status   (this compiles include/exclude rules)"
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
    info "  add to app .geetexclude: **/dot-git/"
  else
    ok "dot-git is not tracked by app repo"
  fi

  # Also check that app ignore rules contain something like dot-git
  # This is a heuristic (gitignore can be split across files), so it's a warning not failure.
  if [[ -f "$ROOT/.geetexclude" ]]; then
    if grep -Eq '(^|\s)(\*\*/dot-git/|\.geet/dot-git/|dot-git/)\s*$' "$ROOT/.geetexclude"; then
      ok "app .geetexclude appears to ignore dot-git/"
    else
      warn "app .geetexclude does not obviously ignore dot-git/ (recommended: **/dot-git/)"
    fi
  else
    warn "app .geetexclude missing (recommended: ignore **/dot-git/)"
  fi
fi

echo

###############################################################################
# 4) Light functional checks (read-only)
###############################################################################
# These checks make sure the layer git wrapper can talk to the layer repo
# WITHOUT modifying anything.

if [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]]; then
  if "$GEET_LIB/git.sh" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ok "layer git wrapper can run git commands"
  else
    fail "layer git wrapper failed to run git (check permissions, env, or dot-git validity)"
  fi

  # Check that HEAD resolves
  if "$GEET_LIB/git.sh" rev-parse HEAD >/dev/null 2>&1; then
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
  return 1
fi

ok "doctor looks good"
return 0

}  # end of doctor()
