# git.sh — template git operations
# Usage:
#   source git.sh
#   (exposed functions are used via geet.sh command dispatcher)
#
# Provides git wrapper functions for template repo operations

# Helper: git wrapper that uses template's git dir
gitx() {
  git --git-dir="$DOTGIT" --work-tree="$APP_DIR" -c "core.excludesFile=$TEMPLATE_GEETEXCLUDE" "$@"
}

# Helper: sync .geetinclude to .geetexclude
sync_exclude() {
  source "$GEET_LIB/sync.sh"
  sync
}

# Helper: check if template git repo exists
need_dotgit() {
  [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]] || die "missing $DOTGIT (run: $GEET_ALIAS init)"
}

# Helper: block dangerous git commands
block_footguns() {
  case "${1-}" in
    clean|reset|checkout|restore|rm)
      brave_guard "git $1" "git $1 can be destructive and mess with your app's working directory"
    ;;
  esac
}

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

  local recurse=0
  local -a args=()
  local -a post_init_args=()
  local parsing_post_init=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --recurse-submodules|-r)
        recurse=1
        shift
        ;;
      --help|-h)
        cat <<EOF
Usage:
  $GEET_ALIAS install <repo> [dir] [--recurse-submodules] [-- post-init-args...]

Examples:
  $GEET_ALIAS install git@github.com:$GH_USER/template.git MyApp
  $GEET_ALIAS install --recurse-submodules git@github.com:$GH_USER/template.git
  $GEET_ALIAS install git@github.com:$GH_USER/template.git MyApp -- --app-name "My Cool App"

Notes:
  - After cloning, this runs init automatically
  - Arguments after '--' are passed to the post-init hook (if present)
EOF
        return 0
        ;;
      --)
        parsing_post_init=1
        shift
        ;;
      *)
        if [[ "$parsing_post_init" -eq 1 ]]; then
          post_init_args+=("$1")
        else
          args+=("$1")
        fi
        shift
        ;;
    esac
  done

  [[ ${#args[@]} -ge 1 ]] || die "install requires <repo> (and optional [dir])"

  local repo="${args[0]}"
  local dir=""
  if [[ ${#args[@]} -ge 2 ]]; then
    dir="${args[1]}"
  else
    # Derive a directory name from the repo URL (best-effort)
    dir="$(basename "$repo")"
    dir="${dir%.git}"
    [[ -n "$dir" ]] || die "could not infer directory name (pass an explicit [dir])"
  fi

  local -a clone_args=()
  if [[ "$recurse" -eq 1 ]]; then
    clone_args+=(--recurse-submodules)
  fi

  log "cloning template repo:"
  log "  repo: $repo"
  log "  dir:  $dir"
  gitx clone "${clone_args[@]}" "$repo" "$dir"

  log "running init in cloned directory"
  (
    cd "$dir"
    # We intentionally use the init script from INSIDE the clone (not from caller),
    # so this works even when geet is installed globally.
    if [[ -x "./.geet/lib/init.sh" ]]; then
      "./.geet/lib/init.sh" "${post_init_args[@]}"
    elif [[ -x "./$LAYER_DIR/lib/init.sh" ]]; then
      # Fallback: extremely unlikely to hit; keep for completeness.
      "./$LAYER_DIR/lib/init.sh" "${post_init_args[@]}"
    else
      die "could not find init.sh in clone (expected .geet/lib/init.sh)"
    fi
  )

  log "install complete"
}

###############################################################################
# CLONE - Simple git clone without init
###############################################################################
# Just clones a repository without running any post-install logic
clone() {
  git clone "$@"
}
