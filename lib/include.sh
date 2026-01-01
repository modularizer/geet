#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# include.sh — explicitly add files/paths to the layer whitelist (.geetinclude)
#
# PURPOSE
# -------
# This script exists because:
# - `git add` should NOT mutate ignore / whitelist rules.
# - Automatically editing `.geetinclude` during `git add` would be surprising.
#
# So we provide an EXPLICIT command:
#
#   geet include <path> [...]
#
# What it does:
# 1) Checks whether each path is already INCLUDED by the template layer
#    (using Git’s ignore engine in template view).
# 2) If not included, appends a clean rule to `.geetinclude`.
# 3) Recompiles exclude rules (via git.sh).
# 4) Optionally stages the file for the template repo.
#
# This keeps intent obvious and reviewable.
###############################################################################

###############################################################################
# PATH DISCOVERY
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$LAYER_DIR/.." && pwd)"

LAYER_NAME="$(basename "$LAYER_DIR")"
LAYER_NAME="${LAYER_NAME#.}"

GIT_SH="$SCRIPT_DIR/git.sh"
WHITELIST="$LAYER_DIR/.geetinclude"

###############################################################################
# HELPERS
###############################################################################

die()  { echo "[$LAYER_NAME include] $*" >&2; exit 1; }
log()  { echo "[$LAYER_NAME include] $*" >&2; }
info() { echo "[$LAYER_NAME include] $*" >&2; }

need_files() {
  [[ -f "$GIT_SH" ]] || die "missing git.sh"
  [[ -f "$WHITELIST" ]] || die "missing .geetinclude"
}

usage() {
  cat <<EOF
Usage:
  $LAYER_NAME include <path> [...]

Description:
  Explicitly adds paths to the template whitelist (.geetinclude).

Behavior:
  - If a path is already included, nothing happens.
  - If a path is ignored by the template view, it is appended to .geetinclude.
  - The whitelist is recompiled automatically.
  - The path is then staged for the TEMPLATE repo.

Notes:
  - Paths are relative to the project root.
  - Directories are normalized to '<dir>/**'.

Examples:
  $LAYER_NAME include app/foo.tsx
  $LAYER_NAME include app/shared
  $LAYER_NAME include package.json
EOF
}

###############################################################################
# ARG PARSING
###############################################################################

[[ $# -gt 0 ]] || { usage; exit 2; }
need_files

###############################################################################
# CORE LOGIC
###############################################################################

changed=0

for raw in "$@"; do
  # Normalize path (strip leading ./)
  path="${raw#./}"

  abs="$ROOT/$path"
  [[ -e "$abs" ]] || die "path does not exist: $path"

  # Normalize directories → dir/**
  if [[ -d "$abs" ]]; then
    path="${path%/}/**"
  fi

  # Check whether the template repo already includes this path.
  #
  # If git check-ignore says NOTHING, the file is VISIBLE to the template repo,
  # meaning it is already included by existing rules.
  if "$GIT_SH" check-ignore -q "$path" 2>/dev/null; then
    # It is ignored → not included → we should add it
    :
  else
    info "already included: $path"
    continue
  fi

  # Avoid duplicate lines (simple exact-match check)
  if grep -Fxq "$path" "$WHITELIST"; then
    info "already present in .geetinclude: $path"
    continue
  fi

  log "including: $path"
  echo "$path" >> "$WHITELIST"
  changed=1
done

###############################################################################
# APPLY + STAGE
###############################################################################

if [[ "$changed" -eq 0 ]]; then
  info "no changes needed"
  exit 0
fi

# Recompile exclude rules by forcing a cheap git command
"$GIT_SH" status >/dev/null

# Stage whitelist + newly included paths for the TEMPLATE repo
"$GIT_SH" add .geetinclude "$@"

log "done"
log "review .geetinclude, then commit with:"
log "  $LAYER_NAME commit -m \"Include files in template\""
