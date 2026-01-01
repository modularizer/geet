#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# split.sh — export the layer's template-visible files to an external folder
#
# This does NOT change git history. It just copies files.
#
# Why this exists:
# - Sometimes you want a "pure snapshot" of what the template layer includes,
#   as a standalone directory you can inspect, zip, publish, or compare.
#
# Two modes:
#   tracked (default): export only files currently tracked by the template repo
#   all:              export any file in the working tree that the whitelist
#                     includes (even if not yet tracked)
#
# Notes:
# - Requires layer initialization (dot-git exists)
# - Requires compiled exclude (info/exclude). If missing, run git.sh status.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$LAYER_DIR/.." && pwd)"

LAYER_NAME="$(basename "$LAYER_DIR")"
LAYER_NAME="${LAYER_NAME#.}"

GIT_SH="$SCRIPT_DIR/git.sh"
TREE_SH="$SCRIPT_DIR/tree.sh"

DOTGIT="$LAYER_DIR/dot-git"
EXCLUDE_FILE="$DOTGIT/info/exclude"

die() { echo "[$LAYER_NAME split] $*" >&2; exit 1; }
log() { echo "[$LAYER_NAME split] $*" >&2; }

need() {
  [[ -f "$GIT_SH" ]] || die "missing $GIT_SH"
  [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]] || die "layer not initialized (run: $LAYER_NAME init)"
  [[ -f "$EXCLUDE_FILE" ]] || die "missing compiled exclude. Run: $LAYER_NAME status"
}

usage() {
  cat <<EOF
Usage:
  $LAYER_NAME split <dest_dir> [tracked|all]

Examples:
  $LAYER_NAME split /tmp/${LAYER_NAME}-export
  $LAYER_NAME split ../exports/${LAYER_NAME} all

Mode:
  tracked  Export only files tracked by this template repo (default)
  all      Export all files included by whitelist (may include untracked)

Notes:
- Destination directory must NOT already exist (safety).
EOF
}

dest="${1:-}"
mode="${2:-tracked}"

[[ -n "$dest" ]] || { usage; exit 2; }
need

# Safety: refuse to export into an existing directory to avoid accidental overwrites.
if [[ -e "$dest" ]]; then
  die "destination already exists: $dest"
fi

# Build file list
tmp_list="$(mktemp)"
cleanup() { rm -f "$tmp_list"; }
trap cleanup EXIT

case "$mode" in
  tracked)
    # Export what the template repo actually tracks
    "$GIT_SH" ls-files > "$tmp_list"
    ;;
  all)
    # Export anything the whitelist includes (even if untracked)
    [[ -f "$TREE_SH" ]] || die "mode 'all' requires $TREE_SH"
    "$TREE_SH" list all > "$tmp_list"
    ;;
  *)
    die "unknown mode: $mode (use tracked|all)"
    ;;
esac

# Ensure there is something to export
if ! grep -q . "$tmp_list"; then
  die "nothing to export in mode '$mode' (is your whitelist empty?)"
fi

log "exporting layer '$LAYER_NAME' ($mode) to: $dest"
mkdir -p "$dest"

# Copy files preserving paths.
# We use tar because it is:
# - fast
# - preserves directories
# - handles lots of files well
#
# This avoids rsync dependency and avoids writing a bunch of mkdir/cp loops.
(
  cd "$ROOT"
  # Use null delimiters to safely handle weird filenames
  # Convert line-delimited list to null-delimited for tar
  while IFS= read -r line; do
    # Skip empty lines
    [[ -n "$line" ]] && printf '%s\0' "$line"
  done < "$tmp_list" | tar -cpf - --null -T - | (cd "$dest" && tar -xpf -)
)

# Write a small manifest for auditing
{
  echo "layer: $LAYER_NAME"
  echo "mode: $mode"
  echo "source_root: $ROOT"
  echo "exported_at: $(date -Is 2>/dev/null || date)"
  echo
  echo "files:"
  cat "$tmp_list"
} > "$dest/.layer-export-manifest.txt"

log "done"
log "wrote manifest: $dest/.layer-export-manifest.txt"
