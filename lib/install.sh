# install.sh — clone and init
# Usage:
#   source install.sh
#   (exposed functions are used via geet.sh command dispatcher)


###############################################################################
# INSTALL - Clone a template repo and run init
###############################################################################
# This is a convenience command for first-time users:
#
#   $GEET_ALIAS install <repo> [dir] [--recurse-submodules]
#
# It:
#  1) runs `git clone`
#  2) cd's into the directory
#  3) runs this layer's init.sh to convert the clone into an app + layer
#
install() {
  local INIT_SH="$GEET_LIB/init.sh"
  [[ -f "$INIT_SH" ]] || die "missing init script: $INIT_SH"

  # Check for help first
  if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage:
  $GEET_ALIAS install <repo> <dir> [options] [-- post-init-args...]

Options:
  --recurse-submodules, -r   Clone with submodules
  --pub, --public            Publish app as public GitHub repo after install
  --pri, --private           Publish app as private GitHub repo after install
  --int, --internal          Publish app as internal GitHub repo after install

Examples:
  $GEET_ALIAS install git@github.com:$GH_USER/template.git MyApp
  $GEET_ALIAS install mytemplate MyApp --pub
  $GEET_ALIAS install modularizer/geet MyGeetApp --private
  $GEET_ALIAS install --recurse-submodules git@github.com:$GH_USER/template.git MyApp -- --app-name "My Cool App"

Notes:
  - <dir> is required and must be different from the template repo name
  - After cloning, this runs init automatically
  - Arguments after '--' are passed to the post-init hook (if present)
  - Publish flags create a NEW GitHub repo for the app (not the template)
EOF
    return 0
  fi

  # Extract flags using has_flag
  local RECURSE=""
  local PUB_APP=""
  local PRI_APP=""
  local INT_APP=""

  has_flag --recurse-submodules RECURSE
  has_flag --pub PUB_APP
  has_flag --pri PRI_APP
  has_flag --int INT_APP

  # Determine publish visibility
  local publish_visibility=""
  if [[ -n "$PUB_APP" ]]; then
    publish_visibility="public"
  elif [[ -n "$PRI_APP" ]]; then
    publish_visibility="private"
  elif [[ -n "$INT_APP" ]]; then
    publish_visibility="internal"
  fi

  # Separate positional args from post-init args
  local -a args=()
  local -a post_init_args=()
  local parsing_post_init=0

  for arg in "${GEET_ARGS[@]}"; do
    if [[ "$arg" == "--" ]]; then
      parsing_post_init=1
      continue
    fi

    if [[ "$parsing_post_init" -eq 1 ]]; then
      post_init_args+=("$arg")
    else
      args+=("$arg")
    fi
  done

  [[ ${#args[@]} -ge 2 ]] || die "install requires both <repo> and <dir> arguments"

  local repo="${args[0]}"
  local dir="${args[1]}"

  # repo supports 5 possibilities
  # OPTION 1: resolves to a path on your own computer which already exists
  # OPTION 2: startswith http, treat as a git remote. add ".git" to the end if it isn't there already
  # OPTION 3: startswith git@, treat as a git ssh remote. add ".git" to the end if it isn't there already
  # OPTION 4: in format or username/name, e.g. "modularizer/geet" or "modularizer/geet/", convert to "https://github.com/modularizer/geet.git"
  # OPTION 5: just a repo name, e.g. "mytemplate", use get_gh_user then convert to "$GH_USER/mytemplate"

  if [[ -e "$repo" ]]; then
    # OPTION 1: local path exists, use as-is
    :
  elif [[ "$repo" == http* ]]; then
    # OPTION 2: HTTP URL
    if [[ "$repo" != *.git ]]; then
      repo="${repo}.git"
    fi
  elif [[ "$repo" == git@* ]]; then
    # OPTION 3: SSH URL
    if [[ "$repo" != *.git ]]; then
      repo="${repo}.git"
    fi
  elif [[ "$repo" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+/?$ ]]; then
    # OPTION 4: username/repo format
    repo="${repo%/}"  # remove trailing slash if present
    repo="https://github.com/${repo}.git"
  elif [[ "$repo" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    # OPTION 5: just a repo name
    get_gh_user
    repo="https://github.com/${GH_USER}/${repo}.git"
  fi

  # Extract repo name for validation
  local repo_name="$(basename "$repo")"
  repo_name="${repo_name%.git}"

  # Ensure dir is different from repo name to avoid confusion
  # (template repo vs new app directory)
  if [[ "$dir" == "$repo_name" ]]; then
    die "dir must be different from repo name ('$repo_name'). The dir is your NEW app, not the template."
  fi

  local -a clone_args=()
  if [[ -n "$RECURSE" ]]; then
    clone_args+=(--recurse-submodules)
  fi

  log "cloning template repo:"
  log "  repo: $repo"
  log "  dir:  $dir"
  geet_git clone "${clone_args[@]}" "$repo" "$dir"

  log "running init in cloned directory"
  (
    cd "$dir"
    "$GEET_CMD" init "${post_init_args[@]}"
  )

  # Publish the app as a GitHub repo if requested
  if [[ -n "$publish_visibility" ]]; then
    log "publishing app as GitHub repo (--${publish_visibility})"
    (
      cd "$dir"
      gh repo create --source=. --${publish_visibility} --push
    )
    log "app published to GitHub"
  fi

  log "install complete"
}
