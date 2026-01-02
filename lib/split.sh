# split.sh — export template files to external folder
# Usage:
#   source split.sh
#   split <dest_dir> [tracked|all]

split() {

# digest-and-locate.sh provides: APP_DIR, TEMPLATE_DIR, DOTGIT, TEMPLATE_NAME,
# TEMPLATE_GEETEXCLUDE, GEET_LIB, GEET_ALIAS, die, log

usage() {
  cat <<EOF
$GEET_ALIAS split — export template files to external folder

This creates a clean snapshot of your template files in a separate directory.
Useful for inspecting, zipping, publishing, or comparing what's included.

Usage:
  $GEET_ALIAS split <dest_dir> [tracked|all]

Modes:
  tracked  Export only files tracked by template repo (default)
  all      Export all files included by whitelist (may include untracked)

Examples:
  $GEET_ALIAS split /tmp/${TEMPLATE_NAME}-export
  $GEET_ALIAS split ../exports/${TEMPLATE_NAME} all
  $GEET_ALIAS split --help

Safety:
  - Destination directory must NOT exist (prevents accidental overwrites)
  - This does NOT change git history, only copies files
  - Creates .layer-export-manifest.txt for auditing

Requirements:
  - Layer must be initialized (dot-git exists)
  - Whitelist must be compiled (.geetexclude exists)
EOF
}

# Handle help
if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  return 0
fi

dest="${1:-}"
mode="${2:-tracked}"

[[ -n "$dest" ]] || { usage; return 1; }

# Precondition checks
[[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]] || die "layer not initialized (run: $GEET_ALIAS init)"
[[ -f "$TEMPLATE_GEETEXCLUDE" ]] || die "missing compiled exclude. Run: $GEET_ALIAS sync"

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
    git --git-dir="$DOTGIT" --work-tree="$APP_DIR" ls-files > "$tmp_list"
    ;;
  all)
    # Export anything the whitelist includes (even if untracked)
    source "$GEET_LIB/tree.sh"
    tree list all > "$tmp_list"
    ;;
  *)
    die "unknown mode: $mode (use tracked|all)"
    ;;
esac

# Ensure there is something to export
if ! grep -q . "$tmp_list"; then
  die "nothing to export in mode '$mode' (is your whitelist empty?)"
fi

log "exporting layer '$TEMPLATE_NAME' ($mode) to: $dest"
mkdir -p "$dest"

# Copy files preserving paths.
# We use tar because it is:
# - fast
# - preserves directories
# - handles lots of files well
#
# This avoids rsync dependency and avoids writing a bunch of mkdir/cp loops.
(
  cd "$APP_DIR"
  # Use null delimiters to safely handle weird filenames
  # Convert line-delimited list to null-delimited for tar
  while IFS= read -r line; do
    # Skip empty lines
    [[ -n "$line" ]] && printf '%s\0' "$line"
  done < "$tmp_list" | tar -cpf - --null -T - | (cd "$dest" && tar -xpf -)
)

# Write a small manifest for auditing
{
  echo "layer: $TEMPLATE_NAME"
  echo "mode: $mode"
  echo "source_root: $APP_DIR"
  echo "exported_at: $(date -Is 2>/dev/null || date)"
  echo
  echo "files:"
  cat "$tmp_list"
} > "$dest/.layer-export-manifest.txt"

log "done"
log "wrote manifest: $dest/.layer-export-manifest.txt"

}  # end of split()
