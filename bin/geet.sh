#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERR at ${BASH_SOURCE[0]}:${LINENO}: $BASH_COMMAND" >&2' ERR

NODE_BIN="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GEET_LIB="$(cd -- "$NODE_BIN/../lib/node_modules/geet/lib" && pwd)"
GEET_ARGS=("$@")
source "$GEET_LIB/digest-and-locate.sh" "$@"
debug "GEET_ARGS=${GEET_ARGS[@]}"
cmd="${1:-help}"


shift || true

case "$cmd" in
  help|-h|--help)
    source "$GEET_LIB/help.sh"
    help
    ;;

  sync)
    source "$GEET_LIB/sync.sh"
    sync "${GEET_ARGS[@]:1}"
    ;;

  # Explicit non-git commands
  init)
    source "$GEET_LIB/init.sh"
    init "${GEET_ARGS[@]:1}"
    ;;

  tree)
    source "$GEET_LIB/tree.sh"
    tree "${GEET_ARGS[@]:1}"
    ;;

  split)
    source "$GEET_LIB/split.sh"
    split "${GEET_ARGS[@]:1}"
    ;;

  session)
    source "$GEET_LIB/session.sh"
    session "${GEET_ARGS[@]:1}"
    ;;

  template)
    source "$GEET_LIB/template.sh"
    template "${GEET_ARGS[@]:1}"
    ;;

  doctor)
    source "$GEET_LIB/doctor.sh"
    doctor "${GEET_ARGS[@]:1}"
    ;;

  prework)
    source "$GEET_LIB/prework.sh"
    prework "${GEET_ARGS[@]:1}"
    ;;

  gh)
    source "$GEET_LIB/ghcli.sh"
    ghcli "${GEET_ARGS[@]:1}"
    ;;

  publish)
    source "$GEET_LIB/ghcli.sh"
    ghcli publish "${GEET_ARGS[@]:1}"
    ;;

  install)
    source "$GEET_LIB/git.sh"
    install "${GEET_ARGS[@]:1}"
    ;;

  soft-detach|soft_detach|slide)
    source "$GEET_LIB/detach.sh"
    soft_detach "${GEET_ARGS[@]:1}"
    ;;

  detach|hard-detach)
    source "$GEET_LIB/detach.sh"
    detach "${GEET_ARGS[@]:1}"
    ;;

  detached)
      source "$GEET_LIB/detach.sh"
      detached "${GEET_ARGS[@]:1}"
      ;;

  soft-detached|soft_detached|slid)
        source "$GEET_LIB/detach.sh"
        soft_detached "${GEET_ARGS[@]:1}"
        ;;

  retach)
      source "$GEET_LIB/detach.sh"
      retach "${GEET_ARGS[@]:1}"
      ;;

  precommit|pc)
    source "$GEET_LIB/pre-commit/hook.sh"
    ;;

  remove|rm)
    brave_guard "removing the template tracking" "Are you sure you want to call \`rm -rf \"$TEMPLATE_DIR\"\`?"
    log "You asked for it! Deleting $TEMPLATE_DIR"
    rm -rf "$TEMPLATE_DIR"
    log "You have FULLY detached from the template and removed the git tracking of the template repo"
    log "geet commands will now only work in the generic sense to create or init new projects, but will have no reference of the template repo"
    ;;

  destroy)
    log "You asked for it! Deleting $TEMPLATE_DIR"
    rm -rf "$TEMPLATE_DIR"
    log "You have FULLY detached from the template and removed the git tracking of the template repo"
    log "geet commands will now only work in the generic sense to create or init new projects, but will have no reference of the template repo"
      ;;

  bug|feature|issue|whoops|suggest)
    source "$GEET_LIB/whoops.sh"
    open_issue "${GEET_ARGS[@]:1}"
    ;;

  # Explicit escape hatch
  git)
    source "$GEET_LIB/git.sh"
    call_cmd "${GEET_ARGS[@]:1}"
    ;;

  # Default: assume git subcommand
  *)
    source "$GEET_LIB/git.sh"
    call_cmd "${GEET_ARGS[@]}"
    ;;
esac