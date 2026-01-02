# session.sh — run commands in isolated template snapshot
# Usage:
#   source session.sh
#   session run [options] -- <command...>

session() {

# digest-and-locate.sh provides: APP_DIR, TEMPLATE_DIR, TEMPLATE_NAME, GEET_LIB, GEET_ALIAS, die, log

usage() {
  cat <<EOF
$GEET_ALIAS session — run commands in isolated template snapshot

This creates a temporary isolated copy of just the template files,
runs your command there, and optionally copies results back.

Usage:
  $GEET_ALIAS session run [options] -- <command...>

Options:
  --mode tracked|all      split mode (default: tracked)
  --tmp <dir>             use a specific temp dir (default: mktemp)
  --keep                  do not delete temp dir after command
  --copy-back A:B         copy tmp/A back to repo/B after command
                           (repeatable)

Use cases:
  - Build template in isolation (avoid polluting app with artifacts)
  - Test template without app-specific code interfering
  - Generate files that should live only in the template

Examples:
  $GEET_ALIAS session run -- npm run build
  $GEET_ALIAS session run --mode all -- npm test
  $GEET_ALIAS session run --copy-back dist:dist -- npm run build
  $GEET_ALIAS session run --keep -- npm run build
EOF
}

sub="${1:-help}"; shift || true
if [[ "$sub" == "help" || "$sub" == "-h" || "$sub" == "--help" ]]; then
  usage
  return 0
fi
[[ "$sub" == "run" ]] || { usage; return 1; }

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
    -h|--help) usage; return 0 ;;
    *) die "unknown option: $1 (use --help)" ;;
  esac
done

[[ $# -gt 0 ]] || die "missing command (use -- <command...>)"

# Decide temp dir
if [[ -z "$tmp" ]]; then
  tmp="$(mktemp -d -t "${TEMPLATE_NAME}-session-XXXXXX")"
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
# Call split function from split.sh
source "$GEET_LIB/split.sh"
split "$tmp" "$mode"

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
  rm -rf "$APP_DIR/$dst"
  mkdir -p "$(dirname "$APP_DIR/$dst")"
  cp -a "$tmp/$src" "$APP_DIR/$dst"
done

log "done"

}  # end of session()
