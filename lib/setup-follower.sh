#!/usr/bin/env bash
# setup-follower.sh - Enable follower mode for automatic template repo syncing

# Check if follower mode is enabled (exit 0 if enabled, 1 if disabled)
following() {
  if [[ "${1:-}" == "help" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<EOF
    $GEET_ALIAS following - Check if follower mode is enabled

    Returns exit code 0 if follower mode is enabled, 1 if disabled.
    Used in git hooks to conditionally execute template sync commands.

    Usage:
      $GEET_ALIAS following              # Check status (silent)
      $GEET_ALIAS following --verbose    # Show status message

    Examples:
      geet following && echo "Following enabled"
      geet following && geet include src/
EOF
    return 0
  fi

  local VERBOSE=""
  has_flag --verbose VERBOSE
  has_flag -v VERBOSE_SHORT
  [[ -n "$VERBOSE_SHORT" ]] && VERBOSE="true"

  if [[ -z "$TEMPLATE_DIR" ]]; then
    [[ -n "$VERBOSE" ]] && echo "Not in a geet project"
    return 1
  fi

  local FOLLOW_FILE="$TEMPLATE_DIR/.geet-follow"

  if [[ -f "$FOLLOW_FILE" ]]; then
    [[ -n "$VERBOSE" ]] && log "Follower mode: enabled"
    return 0
  else
    [[ -n "$VERBOSE" ]] && log "Follower mode: disabled"
    return 1
  fi
}

# Enable follower mode
follow() {
  if [[ "${1:-}" == "help" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<EOF
    $GEET_ALIAS follow - Enable automatic template repo syncing

    This command sets up "follower mode" where your template repo automatically
    mirrors your parent repo's git operations:

    - pre-commit: Auto-include modified files
    - commit-msg: Auto-commit to template repo with same message
    - pre-push: Auto-push template repo
    - post-checkout: Auto-switch template repo branches

    Requirements:
      - fishook npm package (https://www.npmjs.com/package/fishook)

    Usage:
      $GEET_ALIAS follow                 # Enable follower mode

    Examples:
      cd my-app
      npm install --save-dev fishook
      $GEET_ALIAS follow
      npx fishook install
      # Now git operations automatically sync to template repo

    To disable:
      $GEET_ALIAS unfollow

    To check status:
      $GEET_ALIAS following
EOF
    return 0
  fi

  if [[ -z "$TEMPLATE_DIR" ]]; then
    die "Not in a geet project (no template directory found)"
  fi

  local APP_DIR="${APP_DIR:-.}"
  local FISHOOK_FILE="$APP_DIR/${TEMPLATE_NAME}-fishook-follower.json"
  local FOLLOW_FILE="$TEMPLATE_DIR/.geet-follow"

  # Check if fishook is installed
  if ! command -v fishook >/dev/null 2>&1 && ! npx fishook --version >/dev/null 2>&1; then
    warn "fishook is not installed"
    log ""
    log "To enable follower mode, install fishook first:"
    log "  npm install --save-dev fishook"
    log "  # or"
    log "  npm install fishook"
    log ""
    log "Then run: $GEET_ALIAS follow"
    return 1
  fi

  # Create or update fishook.json
  cat > "$FISHOOK_FILE" <<'EOF'
{
  "pre-commit": {"onFileEvent": "geet following && echo \"calling includeif for $FISHOOK_PATH\" && geet includeif $FISHOOK_PATH"},
  "commit-msg": "geet following && geet commit -m \"$(cat $1)\" && echo \"Committed changes to template repo\" || echo \"Did not commit changes to template repo\"",
  "pre-push": "geet following && geet push && echo \"Pushed changes\" || echo \"Did not push changes to template repo\"",
  "post-checkout": "geet following && geet checkout -B $(git branch --show-current) && echo \"Switched template repo to $(git branch --show-current)\" || echo \"Did not checkout branch in template repo\""
}
EOF

  # Enable follower mode by creating flag file
  touch "$FOLLOW_FILE"

  log "Follower mode enabled!"
  log ""
  log "Created: ${TEMPLATE_NAME}-fishook-follower.json"
  log ""
  log "Your template repo will now automatically:"
  log "  ✓ Include modified files on commit"
  log "  ✓ Commit changes with the same message"
  log "  ✓ Push when you push"
  log "  ✓ Switch branches to match your app"
  log ""

  if [[ ! -f "$APP_DIR/.git/hooks/pre-commit" ]]; then
    log "Next steps:"
    log "  1. Install hooks: npx fishook install"
    log ""
  else
    log "Hooks already installed"
    log ""
  fi

  log "To disable follower mode:"
  log "  $GEET_ALIAS unfollow"
}

# Disable follower mode
unfollow() {
  if [[ "${1:-}" == "help" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<EOF
    $GEET_ALIAS unfollow - Disable automatic template repo syncing

    Disables follower mode. Git hooks remain installed but will not
    execute template sync commands.

    Usage:
      $GEET_ALIAS unfollow               # Disable follower mode

    Examples:
      $GEET_ALIAS unfollow
      # Git operations will no longer sync to template repo

    To re-enable:
      $GEET_ALIAS follow
EOF
    return 0
  fi

  if [[ -z "$TEMPLATE_DIR" ]]; then
    die "Not in a geet project (no template directory found)"
  fi

  local FOLLOW_FILE="$TEMPLATE_DIR/.geet-follow"

  if [[ -f "$FOLLOW_FILE" ]]; then
    rm "$FOLLOW_FILE"
    log "Follower mode disabled"
    log ""
    log "Git hooks will remain installed but will not execute template sync commands."
    log ""
    log "To re-enable follower mode:"
    log "  $GEET_ALIAS follow"
  else
    log "Follower mode was already disabled"
  fi
}
