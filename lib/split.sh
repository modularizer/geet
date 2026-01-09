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
  $GEET_ALIAS split <dest_dir> [mode]

Modes:
  live     Symlink worktree files using .geetinclude src => dst mapping
  tracked  Copy tracked files using .geetinclude src => dst mapping
  staged   Copy files from git staged area (default)
  HEAD     Copy files from git HEAD
  <ref>    Copy files from specified git ref (e.g., main, develop)

Examples:
  $GEET_ALIAS split /tmp/${TEMPLATE_NAME}-export
  $GEET_ALIAS split /tmp/${TEMPLATE_NAME}-live live
  $GEET_ALIAS split /tmp/${TEMPLATE_NAME}-tracked tracked
  $GEET_ALIAS split /tmp/${TEMPLATE_NAME}-head HEAD
  $GEET_ALIAS split /tmp/${TEMPLATE_NAME}-main main
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
mode="${2:-staged}"

[[ -n "$dest" ]] || { usage; return 1; }

# Precondition checks
[[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]] || die "layer not initialized (run: $GEET_ALIAS init)"
[[ -f "$TEMPLATE_DIR/.geetexclude" ]] || die "missing compiled exclude. Run: $GEET_ALIAS sync"

# Safety: refuse to export into an existing directory to avoid accidental overwrites.
has_flag "--overwrite" SPDE
if [[ -e "$dest"  && -n "$SPDE" ]]; then
  die "destination already exists: $dest"
fi

# Build file list
tmp_list="$(mktemp)"
cleanup() { rm -f "$tmp_list"; }
trap cleanup EXIT

# Determine if mode is a git ref (not a special mode keyword)
is_git_ref=false
case "$mode" in
  live|tracked|staged|HEAD)
    # Special mode keywords
    ;;
  *)
    # Check if it's a valid git ref
    if git --git-dir="$DOTGIT" rev-parse --verify "$mode" >/dev/null 2>&1; then
      is_git_ref=true
    else
      die "unknown mode: $mode (use live|tracked|staged|HEAD or a valid git ref)"
    fi
    ;;
esac

case "$mode" in
  live)
    # Symlink worktree files using .geetinclude mapping
    source "$GEET_LIB/mapping.sh"
    export_from_index=false
    export_mode="live"

    # Build list of local files from mappings
    declare -A local_to_remote
    declare -A dummy_remote_to_local
    load_mappings local_to_remote dummy_remote_to_local
    for local_path in "${!local_to_remote[@]}"; do
      echo "$local_path"
    done > "$tmp_list"
    ;;
  tracked)
    # Copy tracked files using .geetinclude mapping
    source "$GEET_LIB/mapping.sh"
    export_from_index=false
    export_mode="tracked"

    # Build list of local files from mappings (only if tracked)
    declare -A local_to_remote
    declare -A dummy_remote_to_local
    load_mappings local_to_remote dummy_remote_to_local
    for local_path in "${!local_to_remote[@]}"; do
      # Only include if file is tracked by git
      if git --git-dir="$DOTGIT" --work-tree="$APP_DIR" ls-files --error-unmatch "$local_path" >/dev/null 2>&1; then
        echo "$local_path"
      fi
    done > "$tmp_list"
    ;;
  staged)
    # Export files from git staged area
    git --git-dir="$DOTGIT" --work-tree="$APP_DIR" ls-files > "$tmp_list"
    export_from_index=true
    export_mode="staged"
    ;;
  HEAD)
    # Export files from HEAD
    git --git-dir="$DOTGIT" --work-tree="$APP_DIR" ls-tree -r --name-only HEAD > "$tmp_list"
    export_from_index=false
    export_mode="HEAD"
    export_ref="HEAD"
    ;;
  *)
    if [[ "$is_git_ref" == "true" ]]; then
      # Export from specified git ref
      git --git-dir="$DOTGIT" --work-tree="$APP_DIR" ls-tree -r --name-only "$mode" > "$tmp_list"
      export_from_index=false
      export_mode="ref"
      export_ref="$mode"
    fi
    ;;
esac

# Ensure there is something to export
if ! grep -q . "$tmp_list"; then
  die "nothing to export in mode '$mode' (is your whitelist empty?)"
fi

log "exporting layer '$TEMPLATE_NAME' ($mode) to: $dest"
mkdir -p "$dest"

# Link or copy the git directory based on mode
if [[ "$export_mode" == "live" ]]; then
  # Live mode: symlink the git directory
  cp -al "$DOTGIT" "$dest/.git"
else
  # Other modes: copy the git directory
  cp -r "$DOTGIT" "$dest/.git"
fi

# Copy or symlink files based on mode
if [[ "$export_mode" == "live" ]]; then
  # Live mode: create symlinks using .geetinclude mapping
  source "$GEET_LIB/mapping.sh"
  declare -A local_to_remote
  declare -A dummy_remote_to_local
  load_mappings local_to_remote dummy_remote_to_local

  for local_path in "${!local_to_remote[@]}"; do
    remote_path="${local_to_remote[$local_path]}"
    src_file="$APP_DIR/$local_path"
    dest_file="$dest/$remote_path"
    dest_dir="$(dirname "$dest_file")"

    [[ -e "$src_file" ]] || continue

    mkdir -p "$dest_dir"
    ln "$src_file" "$dest_file"
  done

elif [[ "$export_mode" == "tracked" ]]; then
  # Tracked mode: copy tracked files using .geetinclude mapping
  source "$GEET_LIB/mapping.sh"
  declare -A local_to_remote
  declare -A dummy_remote_to_local
  load_mappings local_to_remote dummy_remote_to_local

  while IFS= read -r local_path; do
    [[ -n "$local_path" ]] || continue
    remote_path="${local_to_remote[$local_path]}"
    src_file="$APP_DIR/$local_path"
    dest_file="$dest/$remote_path"
    dest_dir="$(dirname "$dest_file")"

    [[ -e "$src_file" ]] || continue

    mkdir -p "$dest_dir"
    cp -a "$src_file" "$dest_file"
  done < "$tmp_list"

elif [[ "$export_from_index" == "true" ]]; then
  # Export staged content from git index using :path syntax
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    dest_file="$dest/$file"
    dest_dir="$(dirname "$dest_file")"
    mkdir -p "$dest_dir"
    git --git-dir="$DOTGIT" --work-tree="$APP_DIR" show ":$file" > "$dest_file"
  done < "$tmp_list"

elif [[ -n "${export_ref:-}" ]]; then
  # Export from specific git ref (HEAD or other ref)
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    dest_file="$dest/$file"
    dest_dir="$(dirname "$dest_file")"
    mkdir -p "$dest_dir"
    git --git-dir="$DOTGIT" --work-tree="$APP_DIR" show "$export_ref:$file" > "$dest_file" 2>/dev/null || true
  done < "$tmp_list"

else
  # Fallback: Export from working tree using tar
  # This should not be reached with current modes, but kept as fallback
  (
    cd "$APP_DIR" || exit
    # Use null delimiters to safely handle weird filenames
    # Convert line-delimited list to null-delimited for tar
    while IFS= read -r line; do
      # Skip empty lines
      [[ -n "$line" ]] && printf '%s\0' "$line"
    done < "$tmp_list" | tar -cpf - --null -T - | (cd "$dest" || exit && tar -xpf -)
  )
fi

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

# Track live folders for hot-reload support
if [[ "$export_mode" == "live" ]]; then
  local live_folders_file="$TEMPLATE_DIR/live-folders"
  local dest_abs="$(cd "$dest" && pwd)"

  # Add to tracking file if not already present
  if [[ -f "$live_folders_file" ]]; then
    if ! grep -qxF "$dest_abs" "$live_folders_file"; then
      echo "$dest_abs" >> "$live_folders_file"
    fi
  else
    echo "$dest_abs" > "$live_folders_file"
  fi

  log "tracked live folder: $dest_abs"
fi

log "done"
log "wrote manifest: $dest/.layer-export-manifest.txt"

}  # end of split()
