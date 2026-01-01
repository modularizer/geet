#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# cli.sh — command router for this layer
#
# Behavior:
# - Explicit tool commands route to their scripts
# - Any unknown command is assumed to be a git subcommand
#   and forwarded to git.sh
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$LAYER_DIR/.." && pwd)"
LIB="$(cd "$LAYER_DIR/lib" && pwd)}"

LAYER_NAME="$(basename "$LAYER_DIR")"
LAYER_NAME="${LAYER_NAME#.}"

die() { echo "[$LAYER_NAME] $*" >&2; exit 1; }

script() {
  local name="$1"
  local path="$SCRIPT_DIR/$name"
  [[ -f "$path" ]] || die "missing $path"
  echo "$path"
}

geetcmd="${geetcmd:-geet}"
geetname="${geetname:-LAYER_NAME}"
geetexplanation=""

if [[ "$geetname" != "$LAYER_NAME" ]]; then
  geetexplanation="($geetname)"
fi
cmd="${1:-help}"
help() {
  cat <<EOF
$geetcmd — template layer tooling for "$LAYER_NAME" $geetexplanation

Usage:
  $geetcmd <command> [args...]

Git commands (forwarded automatically):
  status | diff | add | commit | pull | push | checkout | log | ...

Explicit commands:
  init       Convert a freshly cloned template repo into an app repo + layer view
  tree       Inspect which files are included by this layer
  split      Export the layer-visible files into an external folder
  session    split -> run -> optional copy-back workflow
  template   Promote the current app into a new template layer
  doctor     Sanity checks for this repo + layers
  gh         GitHub CLI integration (setup, etc.)
  help       Show this help

Examples:
  $geetcmd status
  $geetcmd add app/foo.tsx
  $geetcmd commit -m "Update template"
  $geetcmd pull

Notes:
- using geet command:       $geetcmd
- full geet command:        $0
- This script:              $CLI
- Layer Name:               $LAYER_NAME
- App repo (normal):        $ROOT/.git
- This layer template repo: $LAYER_DIR/dot-git
- Whitelist spec:           $LAYER_DIR/.geetinclude
EOF
}

shift || true

case "$cmd" in
  help|-h|--help)
    help
    ;;

  # Explicit non-git commands
  init)
    exec "$(script init.sh)" "$@"
    ;;

  tree)
    exec "$(script tree.sh)" "$@"
    ;;

  split)
    exec "$(script split.sh)" "$@"
    ;;

  session)
    exec "$(script session.sh)" "$@"
    ;;

  template)
    exec "$(script template.sh)" "$@"
    ;;

  doctor)
    exec "$(script doctor.sh)" "$@"
    ;;

  gh)
    exec "$(script gh.sh)" "$@"
    ;;

  # Explicit escape hatch
  git)
    exec "$(script git.sh)" "$@"
    ;;

  # Default: assume git subcommand
  *)
    exec "$(script git.sh)" "$cmd" "$@"
    ;;
esac
