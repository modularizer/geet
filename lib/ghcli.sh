# ghcli.sh — GitHub CLI integration for geet
# Usage:
#   source ghcli.sh
#   ghcli <subcommand> [args...]


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

publish_app() {
  GEET_ARGS=("$@")

  log "here in publish app with $APP_DIR and $APP_NAME"
  # Auto-setup if needed
  ensure_gh_ready

  # Get GitHub username
  get_gh_user

  log "publishing app repository to GitHub..."
  log "  source: $APP_NAME"
  log "  name: $APP_NAME"
  log "  owner: $GH_USER"

  local APP_HOMEPAGE=${APP_HOMEPAGE:-};
  local APP_DESC=${APP_DESC:-};
  extract_flag --homepage _HOMEPAGE
  extract_flag --desc _DESC

  local PUB_APP=""
  local PRI_APP=""
  local INT_APP=""

  has_flag --public PUB_APP
  has_flag --private PRI_APP
  has_flag --internal INT_APP

  # Determine publish visibility
  local publish_visibility="public"
  if [[ -n "$PUB_APP" ]]; then
    publish_visibility="public"
  elif [[ -n "$PRI_APP" ]]; then
    publish_visibility="private"
  elif [[ -n "$INT_APP" ]]; then
    publish_visibility="internal"
  fi

  [[ -n "$_DESC" ]] && APP_DESC="$_DESC";
  [[ -n "$_HOMEPAGE" ]] && APP_HOMEPAGE="$_HOMEPAGE";

  # Build args for gh repo create
  local -a gh_args=(
    repo
    create
    "$APP_NAME"
    --source
    .
    --description
    "$APP_DESC"
    "--$publish_visibility"
    --push
  )

  # Add any extra args passed by user
  if [[ $# -gt 0 ]]; then
    gh_args+=("${GEET_ARGS[@]}")
  fi

  if [[ -n "$APP_HOMEPAGE" ]]; then
    gh_args+=("--homepage")
    gh_args+=("$APP_HOMEPAGE")
  fi

  log "calling \`${gh_args[@]}\`"

  # Run gh repo create from APP_DIR
  (
    cd "$APP_DIR"
    gh "${gh_args[@]}"
  )

  log "app repository published successfully"
}

publish_template() {
  GEET_ARGS=("$@")
  # Auto-setup if needed
  ensure_gh_ready

  [[ -z "$TEMPLATE_DIR" ]] && die "TEMPLATE_DIR not set - cannot publish template"

  # Get GitHub username
  get_gh_user

  # Get the repo name - use TEMPLATE_GH_NAME if set, otherwise derive from TEMPLATE_NAME
  local template_repo_name
  if [[ -n "$TEMPLATE_GH_NAME" ]]; then
    template_repo_name="$TEMPLATE_GH_NAME"
  elif [[ -n "$TEMPLATE_NAME" ]]; then
    template_repo_name="$TEMPLATE_NAME"
  else
    template_repo_name="$(basename "$TEMPLATE_DIR")"
  fi

  # Remove leading period if present
  template_repo_name="${template_repo_name#.}"

  log "publishing template repository to GitHub..."
  log "  source: $TEMPLATE_DIR"
  log "  name: $template_repo_name"
  log "  owner: $GH_USER"

  TEMPLATE_HOMEPAGE=${TEMPLATE_HOMEPAGE:-};
  TEMPLATE_DESC=${TEMPLATE_DESC:-};
  TEMPLATE_TOPICS=${TEMPLATE_TOPICS:-"geet,template"};
  extract_flag --topics _TOPICS
  extract_flag --homepage _HOMEPAGE
  extract_flag --desc _DESC

  local PUB_APP=""
  local PRI_APP=""
  local INT_APP=""

  has_flag --public PUB_APP
  has_flag --private PRI_APP
  has_flag --internal INT_APP

  # Determine publish visibility
  local publish_visibility="public"
  if [[ -n "$PUB_APP" ]]; then
    publish_visibility="public"
  elif [[ -n "$PRI_APP" ]]; then
    publish_visibility="private"
  elif [[ -n "$INT_APP" ]]; then
    publish_visibility="internal"
  fi

  [[ -n "$_DESC" ]] && TEMPLATE_DESC="$_DESC";
  [[ -n "$_HOMEPAGE" ]] && TEMPLATE_HOMEPAGE="$_HOMEPAGE";
  [[ -n "$_TOPICS" ]] && TEMPLATE_TOPICS="$_TOPICS";

  # Clean up topics: remove trailing commas, trim whitespace
  TEMPLATE_TOPICS="${TEMPLATE_TOPICS%,}"  # Remove trailing comma
  TEMPLATE_TOPICS="${TEMPLATE_TOPICS#,}"  # Remove leading comma
  TEMPLATE_TOPICS="${TEMPLATE_TOPICS// /}" # Remove spaces

  # Set default if empty
  [[ -z "$TEMPLATE_TOPICS" ]] && TEMPLATE_TOPICS="geet,template"

  # Build args for gh repo create (without --source and --push, we'll handle that manually)
  local -a gh_args=(
    repo
    create
    "$template_repo_name"
    --description
    "$TEMPLATE_DESC"
    "--$publish_visibility"
  )

  # Add any extra args passed by user
  if [[ $# -gt 0 ]]; then
    gh_args+=("$@")
  fi

  if [[ -n "$TEMPLATE_HOMEPAGE" ]]; then
    gh_args+=("--homepage")
    gh_args+=("$TEMPLATE_HOMEPAGE")
  fi

  log "calling \`${gh_args[@]}\`"

  # Create the remote repo
  gh "${gh_args[@]}"

  log "configuring template settings..."
  gh repo edit "$GH_USER/$template_repo_name" --template
  gh repo edit "$GH_USER/$template_repo_name" --add-topic "$TEMPLATE_TOPICS"

  log "adding remote and pushing using geet_git..."

  # Get the remote URL
  local remote_url
  remote_url="$(gh repo view "$GH_USER/$template_repo_name" --json sshUrl -q .sshUrl)"

  log "remote URL: $remote_url"

  # Add remote and push using geet_git (which handles custom git setup)
  geet_git remote add origin "$remote_url" 2>/dev/null || geet_git remote set-url origin "$remote_url"
  geet_git push -u origin HEAD

  log "template repository published successfully"
}

publish_cmd() {
  local subcommand="${1:-}"

  case "$subcommand" in
    app)
      shift
      publish_app "$@"
      ;;
    template)
      shift
      publish_template "$@"
      ;;
    -h|--help|help)
      cat <<EOF
[$TEMPLATE_NAME gh] Publish command

Usage:
  $GEET_ALIAS publish <type> [options...]

Types:
  app        Publish as a regular repository
  template   Publish as a template repository (with --template flag and topics)

Options:
  --public       Create as public repository (default)
  --private      Create as private repository
  --internal     Create as internal repository
  --desc         Repository description
  --homepage     Repository homepage URL
  --topics       Comma-separated topics (template only, default: "geet,template")

Examples:
  $GEET_ALIAS publish app
  $GEET_ALIAS publish template --private --desc "My template"
  $GEET_ALIAS publish app --desc "My app" --homepage "https://example.com"
EOF
      ;;
    "")
      die "publish command requires a type argument: 'app' or 'template'. Use '$GEET_ALIAS publish help' for more info."
      ;;
    *)
      die "unknown publish type: '$subcommand'. Use 'app' or 'template'. Use '$GEET_ALIAS publish help' for more info."
      ;;
  esac
}

usage() {
  cat <<EOF
[$TEMPLATE_NAME gh] GitHub CLI integration

Usage:
  $GEET_ALIAS gh <command> [args...]

Commands:
  setup          Install and authenticate GitHub CLI (runs automatically if needed)
  publish <type> Create and push repo to GitHub (type: 'app' or 'template')
  <any>          Pass through to gh CLI (e.g., 'gh pr list' -> '$GEET_ALIAS gh pr list')
  help           Show this help

Examples:
  $GEET_ALIAS publish app                       # Publish as regular repository
  $GEET_ALIAS publish template                  # Publish as template repository
  $GEET_ALIAS publish app --private --desc "My cool project"
  $GEET_ALIAS gh pr list                        # Auto-setup if needed, then list PRs
  $GEET_ALIAS gh repo view

Note:
  All commands automatically run 'setup' if gh is not installed or authenticated.
  You rarely need to run 'setup' manually.
  Use '$GEET_ALIAS publish help' for detailed publish options.
EOF
}


handle(){
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

    pub|publish)
      publish_cmd "$@"
      ;;

    *)
      # Pass through to gh CLI (auto-setup if needed)
      ensure_gh_ready
      gh "$cmd" "$@"
      ;;
  esac
}