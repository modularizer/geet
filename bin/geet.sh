#!/usr/bin/env bash
set -euo pipefail
source digest-and-locate.sh "$@"

cmd="${1:-help}"


shift || true

case "$cmd" in
  help|-h|--help)
    help
    ;;

  sync)
    source "$GEET_LIB/sync.sh"
    sync "$@"
    ;;

  # Explicit non-git commands
  init)
    source "$GEET_LIB/init.sh"
    init "$@"
    ;;

  tree)
    source "$GEET_LIB/tree.sh"
    tree "$@"
    ;;

  split)
    source "$GEET_LIB/tree.sh"
    tree "$@"
    ;;

  session)
    source "$GEET_LIB/session.sh"
    session "$@"
    ;;

  template)
    source "$GEET_LIB/template.sh"
    template "$@"
    ;;

  doctor)
    source "$GEET_LIB/doctor.sh"
    doctor "$@"
    ;;

  gh)
    source "$GEET_LIB/ghcli.sh"
    ghcli "$@"
    ;;

  # Explicit escape hatch
  git)
    exec "$TEMPLATE_GEET_GIT" "$@"
    ;;

  # Default: assume git subcommand
  *)
    exec "$TEMPLATE_GEET_GIT" "$cmd" "$@"
    ;;
esac