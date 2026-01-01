#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$LAYER_DIR/.." && pwd)"

LAYER_NAME="$(basename "$LAYER_DIR")"
LAYER_NAME="${LAYER_NAME#.}"

SPLIT="$SCRIPT_DIR/split.sh"

die(){ echo "[$LAYER_NAME session] $*" >&2; exit 1; }
log(){ echo "[$LAYER_NAME session] $*" >&2; }

usage() {
  cat <<EOF
Usage:
  $SCRIPT_DIR/session.sh run [options] -- <command...>

Options:
  --mode tracked|all      split mode (default: tracked)
  --tmp <dir>             use a specific temp dir (default: mktemp)
  --keep                  do not delete temp dir
  --copy-back A:B         copy tmp/A back to repo/B after command
                           (repeatable)

Examples:
  $SCRIPT_DIR/session.sh run -- npm run build
  $SCRIPT_DIR/session.sh run --mode all -- npm test
  $SCRIPT_DIR/session.sh run --copy-back dist:dist -- npm run build
  $SCRIPT_DIR/session.sh run --keep -- npm run build
EOF
}

sub="${1:-help}"; shift || true
[[ "$sub" == "run" ]] || { usage; exit 2; }

mode="tracked"
tmp=""
keep=0
declare -a copy_back=()

# Parse args until "--"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) mode="${2:-}"; shift 2 ;;
    --tmp) tmp="${2:-}"; shift 2 ;;
    --keep) keep=1; shift ;;
    --copy-back) copy_back+=("${2:-}"); shift 2 ;;
    --) shift; break ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (use --help)" ;;
  esac
done

[[ $# -gt 0 ]] || die "missing command (use -- <command...>)"

# Decide temp dir
if [[ -z "$tmp" ]]; then
  tmp="$(mktemp -d -t "${LAYER_NAME}-session-XXXXXX")"
fi

cleanup() {
  if [[ "$keep" -eq 1 ]]; then
    log "keeping temp dir: $tmp"
    return 0
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

log "splitting ($mode) to: $tmp"
"$SPLIT" "$tmp" "$mode"

log "running in temp dir: $*"
(
  cd "$tmp"
  "$@"
)

# Copy-back steps (optional)
for spec in "${copy_back[@]}"; do
  src="${spec%%:*}"
  dst="${spec#*:}"
  [[ -n "$src" && -n "$dst" ]] || die "--copy-back expects A:B, got: $spec"

  if [[ ! -e "$tmp/$src" ]]; then
    log "copy-back skipped (missing in temp): $src"
    continue
  fi

  log "copying back: $src -> $dst"
  rm -rf "$ROOT/$dst"
  mkdir -p "$(dirname "$ROOT/$dst")"
  cp -a "$tmp/$src" "$ROOT/$dst"
done

log "done"
