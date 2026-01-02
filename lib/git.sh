#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# LAYER TEMPLATE GIT WRAPPER (WHITELIST-BASED)
#
# This script gives you a SECOND Git repository ("template repo") over the SAME
# working tree as your normal app repository.
#
# Why?
# - Expo / RN projects are path-sensitive (routing, config, etc.).
# - We want a reusable template WITHOUT moving files, copying files, or codegen.
#
# How?
# - App repo lives at:            ./ .git
# - Template repo git database:   ./ .geet/dot-git   (or any other layer folder)
# - Both use the SAME work tree (project root), but track DIFFERENT files.
#
# The template repo tracks ONLY a whitelist defined by:
#   <layer>/.geetinclude
#
# We compile that whitelist into Git's repo-local ignore mechanism:
#   <layer>/.geetexclude
#
# IMPORTANT:
# - dot-git/ contains Git internals and MUST NOT be committed to the app repo.
# - The app repo should ignore: **/dot-git/
# - This is non-standard Git usage. Read comments carefully.
###############################################################################
source digest-and-locate.sh "$@"

need_dotgit() {
  [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]] || die "missing $DOTGIT (run: $GEET_LIB/init.sh)"
}

###############################################################################
# SAFETY: BLOCK FOOT-GUNS
###############################################################################
block_footguns() {
  case "${1-}" in
    clean|reset|checkout|restore|rm)
      brave_guard "git $1" "git $1 can be descructive and mess with your app's working directory"
    ;;
  esac
}

###############################################################################
# CLONE HELPER
###############################################################################
# This is a convenience command for first-time users:
#
#   geet clone <repo> [dir] [--recurse-submodules]
#
# It:
#  1) runs `git clone`
#  2) cd's into the directory
#  3) runs this layer's init.sh to convert the clone into an app + layer
#
# NOTE:
# - We deliberately keep this VERY thin.
# - We do NOT run post-init hooks here (you said you'll add that in init.sh next).
clone_cmd() {
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
  $LAYER_NAME clone <repo> [dir] [--recurse-submodules] [-- post-init-args...]

Examples:
  $LAYER_NAME clone git@github.com:me/template.git MyApp
  $LAYER_NAME clone --recurse-submodules git@github.com:me/template.git
  $LAYER_NAME clone git@github.com:me/template.git MyApp -- --app-name "My Cool App"

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

  [[ ${#args[@]} -ge 1 ]] || die "clone requires <repo> (and optional [dir])"

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

  log "clone + init complete"
}

###############################################################################
# COMMAND DISPATCH
###############################################################################
cmd="${1:-help}"
shift || true

case "$cmd" in
  help|-h|--help)
    cat <<EOF
Layer template git wrapper (whitelist-based)

This runs git against a SECOND repo ($LAYER_NAME), which is a template repo owning SOME of the working tree:
  - gitdir:   $DOTGIT
  - worktree: $ROOT

Include/Exclude spec:
  - source:   ${SPEC_FILE:-"(none)"}
  - mode:     ${SPEC_MODE:-"(not set)"}
  - compiled: $EXCLUDE_FILE

Usage:
  $LAYER_NAME clone <repo> [dir] [--recurse-submodules] [-- post-init-args...]
  $LAYER_NAME init [remote] [branch]
  $LAYER_NAME pull [remote] [branch]
  $LAYER_NAME status | diff | log
  $LAYER_NAME add -A
  $LAYER_NAME commit -m "msg"
  $LAYER_NAME push [remote] [branch]
  $LAYER_NAME <any git args>

Notes:
- 'clone' runs git clone + init; args after '--' are passed to post-init hook
- After 'pull', commit changes with the APP repo (normal git).
- dot-git/ must be ignored by the app repo (it is git internals).
EOF
    ;;

  clone)
    clone_cmd "$@"
    ;;

  init)
    remote="${1:-}"
    branch="${2:-main}"

    mkdir -p "$DOTGIT"
    if [[ ! -f "$DOTGIT/HEAD" ]]; then
      gitx init "$DOTGIT" >/dev/null
    fi

    sync_exclude

    if [[ -n "$remote" ]]; then
      gitx remote add origin "$remote" 2>/dev/null || gitx remote set-url origin "$remote"
    fi

    gitx show-ref --verify --quiet "refs/heads/$branch" \
      || gitx checkout -b "$branch" >/dev/null 2>&1 || true

    log "initialized template layer (gitdir: $DOTGIT)"
    ;;

  status)
    sync_exclude
    need_dotgit
    gitx status
    ;;

  diff)
    sync_exclude
    need_dotgit
    gitx diff
    ;;

  log)
    sync_exclude
    need_dotgit
    gitx log --oneline --decorate -n 30
    ;;

  add)
    sync_exclude
    need_dotgit
    gitx add "$@"
    ;;

  commit)
    sync_exclude
    need_dotgit
    gitx commit "$@"
    ;;

  pull)
    sync_exclude
    need_dotgit
    gitx pull "$0"
    ;;

  push)
    sync_exclude
    need_dotgit
    gitx push "$0"
esac
