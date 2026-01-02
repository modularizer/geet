#!/usr/bin/env bash
set -euo pipefail

GEET_BIN="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GEET_LIB="$(cd -- "$GEET_BIN/../lib" && pwd)"
source digest-and-locate.sh "$@"

cmd="${1:-help}"


shift || true

case "$cmd" in
  help|-h|--help)
    source "$GEET_LIB/help.sh"
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
    source "$GEET_LIB/split.sh"
    split "$@"
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

  publish)
    source "$GEET_LIB/ghcli.sh"
    ghcli publish "$@"
    ;;

  install)
    source "$GEET_LIB/git.sh"
    install "$@"
    ;;

  clone)
    source "$GEET_LIB/git.sh"
    clone "$@"
    ;;

  # Explicit escape hatch
  git)
    exec "$GEET_GIT" "$@"
    ;;

  soft-detach,soft_detach,slide)
    source "$GEET_LIB/detach.sh"
    soft_detach "$@"
    ;;

  detach,hard-detach)
    source "$GEET_LIB/detach.sh"
    detach "$@"
    ;;

  detached)
      source "$GEET_LIB/detach.sh"
      detached "$@"
      ;;

  soft-detached,soft_detached,slid)
        source "$GEET_LIB/detach.sh"
        soft_detached "$@"
        ;;

  retach)
      source "$GEET_LIB/detach.sh"
      retach "$@"
      ;;

  precommit,pc)
    source "$GEET_LIB/pre-commit/hook.sh"
    ;;

  remove,rm,destroy)
    brave_guard
    source "$GEET_LIB/remove.sh"
    retach "$@"
    ;;

  bug,feature,issue,whoops,suggest)
    source "$GEET_LIB/whoops.sh"
    open_issue "$@"
    ;;

  # Default: assume git subcommand
  *)
    exec "$GEET_GIT" "$cmd" "$@"
    ;;
esac