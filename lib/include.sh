# include.sh — explicitly add files/paths to template whitelist
# Usage:
#   source include.sh
#   include <path> [...]

include() {

# digest-and-locate.sh provides: APP_DIR, TEMPLATE_GEETINCLUDE, TEMPLATE_NAME,
# DOTGIT, GEET_LIB, GEET_ALIAS, die, log

usage() {
  cat <<EOF
$GEET_ALIAS include — add paths to template whitelist (.geetinclude)

PURPOSE:
  This command exists because 'git add' should NOT mutate whitelist rules.
  We provide an explicit command to make intent clear and reviewable.

What it does:
  1. Checks if each path is already included by the template layer
  2. If not included, appends a clean rule to .geetinclude
  3. Recompiles exclude rules (auto-syncs)
  4. Stages the path for the template repo

Usage:
  $GEET_ALIAS include <path> [...]

Behavior:
  - If a path is already included → nothing happens
  - If a path is ignored → appends to .geetinclude
  - Whitelist is recompiled automatically
  - Paths are staged for the TEMPLATE repo (not app repo)

Notes:
  - Paths are relative to project root
  - Directories are normalized to '<dir>/**'

Examples:
  $GEET_ALIAS include app/foo.tsx
  $GEET_ALIAS include app/shared
  $GEET_ALIAS include package.json
  $GEET_ALIAS include --help
EOF
}

# Handle help
if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  return 0
fi

[[ $# -gt 0 ]] || { usage; return 1; }
[[ -f "$TEMPLATE_GEETINCLUDE" ]] || die "missing .geetinclude"

###############################################################################
# CORE LOGIC
###############################################################################

info() { echo "[$TEMPLATE_NAME include] $*" >&2; }
changed=0

for raw in "$@"; do
  # Normalize path (strip leading ./)
  path="${raw#./}"

  abs="$APP_DIR/$path"
  [[ -e "$abs" ]] || die "path does not exist: $path"

  # Normalize directories → dir/**
  if [[ -d "$abs" ]]; then
    path="${path%/}/**"
  fi

  # Check whether the template repo already includes this path.
  #
  # If git check-ignore says NOTHING, the file is VISIBLE to the template repo,
  # meaning it is already included by existing rules.
  if git --git-dir="$DOTGIT" --work-tree="$APP_DIR" -c "core.excludesFile=$TEMPLATE_GEETEXCLUDE" check-ignore -q "$path" 2>/dev/null; then
    # It is ignored → not included → we should add it
    :
  else
    info "already included: $path"
    continue
  fi

  # Avoid duplicate lines (simple exact-match check)
  if grep -Fxq "$path" "$TEMPLATE_GEETINCLUDE"; then
    info "already present in .geetinclude: $path"
    continue
  fi

  log "including: $path"
  echo "$path" >> "$TEMPLATE_GEETINCLUDE"
  changed=1
done

###############################################################################
# APPLY + STAGE
###############################################################################

if [[ "$changed" -eq 0 ]]; then
  info "no changes needed"
  return 0
fi

# Recompile exclude rules
source "$GEET_LIB/sync.sh"
sync >/dev/null

# Stage whitelist + newly included paths for the TEMPLATE repo
git --git-dir="$DOTGIT" --work-tree="$APP_DIR" -c "core.excludesFile=$TEMPLATE_GEETEXCLUDE" add .geetinclude "$@"

log "done"
log "review .geetinclude, then commit with:"
log "  $GEET_ALIAS commit -m \"Include files in template\""

}  # end of include()
