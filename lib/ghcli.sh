# ghcli.sh — GitHub CLI integration for geet
# Usage:
#   source ghcli.sh
#   ghcli <subcommand> [args...]

ghcli() {

# digest-and-locate.sh provides: APP_DIR, TEMPLATE_NAME, TEMPLATE_GH_USER,
# TEMPLATE_GH_NAME, TEMPLATE_GH_URL, GEET_ALIAS, die, log

info() { echo "[$TEMPLATE_NAME gh] $*" >&2; }

###############################################################################
# CHECKS
###############################################################################

# Check if gh is installed
check_gh_installed() {
  command -v gh >/dev/null 2>&1
}

# Check if gh is authenticated
check_gh_authenticated() {
  gh auth status >/dev/null 2>&1
}

# Ensure gh is installed and authenticated (auto-setup if needed)
ensure_gh_ready() {
  local needs_setup=0

  if ! check_gh_installed; then
    needs_setup=1
  elif ! check_gh_authenticated; then
    needs_setup=1
  fi

  if [[ "$needs_setup" -eq 1 ]]; then
    log "gh CLI not ready, running setup..."
    setup_cmd
  fi
}

###############################################################################
# COMMANDS
###############################################################################

setup_cmd() {
  log "checking GitHub CLI setup..."

  # Check if gh is installed
  if ! check_gh_installed; then
    log "gh CLI not found"
    log "installing gh CLI..."

    # Detect package manager
    if command -v apt >/dev/null 2>&1; then
      log "using apt package manager"
      sudo apt update
      sudo apt install -y gh
    elif command -v brew >/dev/null 2>&1; then
      log "using homebrew package manager"
      brew install gh
    elif command -v dnf >/dev/null 2>&1; then
      log "using dnf package manager"
      sudo dnf install -y gh
    elif command -v yum >/dev/null 2>&1; then
      log "using yum package manager"
      sudo yum install -y gh
    else
      die "could not detect package manager (apt, brew, dnf, yum). Please install gh manually: https://cli.github.com/"
    fi

    # Verify installation
    if ! check_gh_installed; then
      die "gh installation failed"
    fi

    log "gh CLI installed successfully"
  else
    log "gh CLI already installed: $(gh --version | head -1)"
  fi

  # Check authentication
  if ! check_gh_authenticated; then
    log "gh CLI not authenticated"
    log "starting authentication flow..."
    gh auth login

    # Verify authentication
    if ! check_gh_authenticated; then
      die "gh authentication failed"
    fi

    log "gh CLI authenticated successfully"
  else
    log "gh CLI already authenticated"
    gh auth status
  fi

  log "GitHub CLI setup complete!"
}

publish_cmd() {
  # Auto-setup if needed
  ensure_gh_ready

  # Get the repo name from the current directory
  local default_repo_name
  default_repo_name="$(basename "$APP_DIR")"

  log "publishing repository to GitHub..."
  log "  source: $APP_DIR"
  log "  default name: $default_repo_name"

  # Build args for gh repo create
  # Default: --source . --push --confirm
  local -a gh_args=(
    repo
    create
    "$default_repo_name"
    --source
    .
    --push
  )

  # Add any extra args passed by user
  if [[ $# -gt 0 ]]; then
    gh_args+=("$@")
  fi

  # Run gh repo create from the ROOT directory
  (
    cd "$APP_DIR"
    gh "${gh_args[@]}"
  )

  log "repository published successfully"
}

usage() {
  cat <<EOF
[$TEMPLATE_NAME gh] GitHub CLI integration

Usage:
  $GEET_ALIAS gh <command> [args...]

Commands:
  setup      Install and authenticate GitHub CLI (runs automatically if needed)
  publish    Create and push repo to GitHub (defaults: name=dirname, --source=., --push)
  <any>      Pass through to gh CLI (e.g., 'gh pr list' -> '$GEET_ALIAS gh pr list')
  help       Show this help

Examples:
  $GEET_ALIAS gh publish                    # Auto-setup if needed, then publish
  $GEET_ALIAS gh publish --public
  $GEET_ALIAS gh publish --private --description "My cool project"
  $GEET_ALIAS gh pr list                    # Auto-setup if needed, then list PRs
  $GEET_ALIAS gh repo view

Note:
  All commands automatically run 'setup' if gh is not installed or authenticated.
  You rarely need to run 'setup' manually.
EOF
}

###############################################################################
# COMMAND DISPATCH
###############################################################################
cmd="${1:-help}"
shift || true

case "$cmd" in
  help|-h|--help)
    usage
    ;;

  setup)
    setup_cmd "$@"
    ;;

  publish)
    publish_cmd "$@"
    ;;

  *)
    # Pass through to gh CLI (auto-setup if needed)
    ensure_gh_ready
    gh "$cmd" "$@"
    ;;
esac

}  # end of ghcli()
