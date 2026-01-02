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
  geet_git clone "${clone_args[@]}" "$repo" "$dir"

  log "running init in cloned directory"
  (
    cd "$dir"
    "$GEET_CMD" init "${post_init_args[@]}"
  )

  log "install complete"
}
