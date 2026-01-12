#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERR at ${BASH_SOURCE[0]}:${LINENO}: $BASH_COMMAND" >&2' ERR

NODE_BIN="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -e "$NODE_BIN/../lib/digest-and-locate.sh" ]]; then
  GEET_LIB="$(cd -- "$NODE_BIN/../lib" && pwd)"
else
  if [[ -e "$NODE_BIN/../lib/node_modules/geet-geet/lib/digest-and-locate.sh" ]]; then
    GEET_LIB="$(cd -- "$NODE_BIN/../lib/node_modules/geet-geet/lib" && pwd)"
  else
    echo "could not find geet's lib/ folder"
    exit 1
  fi
fi
GEET_ARGS=("$@")
source "$GEET_LIB/digest-and-locate.sh" "$@"
debug "GEET_ARGS=${GEET_ARGS[@]}"
cmd="${1:-overview}"


shift || true

case "$cmd" in
  overview)
    source "$GEET_LIB/help.sh"
    help "${GEET_ARGS[@]:1}"
    ;;

  explain)
      source "$GEET_LIB/explain.sh"
      explain
      ;;

  learn|context)
    source "$GEET_LIB/explain.sh"
    learn
    ;;

  open)
    open "https://github.com/modularizer/geet"
    ;;

  tutorial)
    open "https://www.youtube.com/watch?v=bEacWh8Kdug"
    ;;

  help|-h|--help)
    source "$GEET_LIB/help.sh"
    help "${GEET_ARGS[@]:1}" --all
    ;;

  version|-v|--version)
    source "$GEET_LIB/version.sh"
    version
    ;;

  why)
    source "$GEET_LIB/why.sh"
    why
    ;;

  whynot)
    source "$GEET_LIB/why.sh"
    whynot
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

  livesplit)
    source "$GEET_LIB/split.sh"
    # Extract destination from args, add 'live' mode
    dest_arg="${GEET_ARGS[1]:-}"
    split "$dest_arg" live "${GEET_ARGS[@]:2}"
    ;;

  session)
    source "$GEET_LIB/session.sh"
    session "${GEET_ARGS[@]:1}"
    ;;

  livesession)
    source "$GEET_LIB/session.sh"
    # Add --mode live to the arguments
    session --mode live "${GEET_ARGS[@]:1}"
    ;;

  template)
    source "$GEET_LIB/template.sh"
    template "${GEET_ARGS[@]:1}"
    ;;

  doctor)
    source "$GEET_LIB/doctor.sh"
    doctor "${GEET_ARGS[@]:1}"
    ;;

  prework|valueof)
    source "$GEET_LIB/prework.sh"
    prework "${GEET_ARGS[@]:1}"
    ;;

  read)
    source "$GEET_LIB/resolve-path.sh"
    file="${GEET_ARGS[1]:-help}"
    GEET_ARGS=("${GEET_ARGS[@]:1}")
    srccat "$file"
    ;;

  doc|docs)
    source "$GEET_LIB/resolve-path.sh"
    name="${GEET_ARGS[1]%.md}"
    name="${name^^}.md"
    GEET_ARGS=("${GEET_ARGS[@]:1}")
    srcresolve "/docs/$name"
    ;;

  readme|readme.md|README|README.md)
    source "$GEET_LIB/resolve-path.sh"
    GEET_ARGS=("${GEET_ARGS[@]:1}")
    srccat "README.md"
    ;;

  gh)
    source "$GEET_LIB/ghcli.sh"
    handle "${GEET_ARGS[@]:1}"
    ;;

  pub|publish)
    GEET_ARGS=("${GEET_ARGS[@]:1}")
    source "$GEET_LIB/ghcli.sh"
    publish_cmd "${GEET_ARGS[@]}"
    ;;

  install)
    source "$GEET_LIB/git.sh"
    source "$GEET_LIB/install.sh"
    GEET_ARGS=("${GEET_ARGS[@]:1}")
    install "${GEET_ARGS[@]}"
    ;;

  refresh|checkout)
      source "$GEET_LIB/refresh.sh"
      GEET_ARGS=("${GEET_ARGS[@]:1}")
      refresh "${GEET_ARGS[@]}"
      ;;

  detach)
    source "$GEET_LIB/detach.sh"
    detach "${GEET_ARGS[@]:1}"
    ;;

  detached)
      source "$GEET_LIB/detach.sh"
      detached "${GEET_ARGS[@]:1}"
      ;;

  retach)
      source "$GEET_LIB/detach.sh"
      retach "${GEET_ARGS[@]:1}"
      ;;

  precommit|pc)
    source "$GEET_LIB/pre-commit/hook.sh"
    ;;

  destroy)
    log "You asked for it! Deleting $TEMPLATE_DIR"
    rm -rf "$TEMPLATE_DIR"
    log "You have FULLY detached from the template and removed the git tracking of the template repo"
    log "geet commands will now only work in the generic sense to create or init new projects, but will have no reference of the template repo"
      ;;

  report|bug|feature|issue|whoops|suggest)
    source "$GEET_LIB/whoops.sh"
    open_issue "${GEET_ARGS[@]:1}"
    ;;

  accept)
      source "$GEET_LIB/accept.sh"
      accept "${GEET_ARGS[@]:1}"
      ;;

  # Explicit escape hatch
  git)
    source "$GEET_LIB/git.sh"
    call_cmd "${GEET_ARGS[@]:1}"
    ;;

  include)
    source "$GEET_LIB/include.sh"
    GEET_ARGS=("${GEET_ARGS[@]:1}")
    include "${GEET_ARGS[@]}"
    ;;

  includeif)
    source "$GEET_LIB/include.sh"
    GEET_ARGS=("${GEET_ARGS[@]:1}")
    includeif "${GEET_ARGS[@]}"
    ;;

  inspect)
    source "$GEET_LIB/inspect.sh"
    inspect "${GEET_ARGS[@]:1}"
    ;;

  # Default: assume git subcommand
  *)
    source "$GEET_LIB/git.sh"
    call_cmd "${GEET_ARGS[@]}"
    ;;
esac