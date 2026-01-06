# git.sh — template git operations
# Usage:
#   source git.sh
#   (exposed functions are used via geet.sh command dispatcher)
#
# Provides git wrapper functions for template repo operations



# Helper: sync .geetinclude to .geetexclude
sync_exclude() {
  source "$GEET_LIB/sync.sh"
  sync
}

# Helper: check if template git repo exists
need_dotgit() {
  [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]] || die "missing $DOTGIT (run: $GEET_ALIAS init)"
}

# Helper: block dangerous git commands
block_footguns() {
  case "${1-}" in
    add)
      brave_guard "git add" "we recommend using our include script (\`geet include\`) instead of directly using \`git add\` as it has tools to keep you on track"
    ;;
    clean|reset|checkout|restore|rm)
      brave_guard "git $1" "git $1 can be destructive and mess with your app's working directory"
    ;;
  esac
}


git_retry_with_local_ours() {
  # Usage:
  #   git_retry_with_local_ours pull
  #   git_retry_with_local_ours merge origin/main
  #
  # Behavior (for files that block the op with "would be overwritten by merge"):
  #   1) copy file -> file.bak
  #   2) git restore file (reset to HEAD) so merge/pull can proceed
  #   3) rerun operation
  #   4) copy post-op file -> <name><TEMPLATE_SUFFIX>.<ext>
  #   5) restore .bak back to original path
  #
  # Notes:
  # - No commits, no stashes.
  # - Only works for *tracked* files (the ones that trigger the overwrite error).
  # - TEMPLATE_FILE_SUFFIX can be overridden via env var, default ".template"
  set -euo pipefail

  if ! geet_git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Not a git repo." >&2
    return 2
  fi

  local tmp_err="" rc=0
  tmp_err="$(mktemp)"

  trap '[[ -n "${tmp_err:-}" ]] && rm -f "$tmp_err"' RETURN

  # 1) attempt the operation normally
  set +e
  geet_git "$@" 2> >(tee "$tmp_err" >&2)
  rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    return 0
  fi

  # 2) detect the specific error
  if ! grep -q "Your local changes to the following files would be overwritten by merge:" "$tmp_err"; then
    return "$rc"
  fi

  log "resolving this error by pulling changes into $TEMPLATE_FILE_SUFFIX versions of the files"
  # 3) parse file list (robust across "error:" prefix + different endings)
  mapfile -t files < <(
    awk '
      index($0, "Your local changes to the following files would be overwritten by merge:") {parsing=1; next}
      parsing && ($0 ~ /^Please commit your changes/ || $0 ~ /^Aborting/ || $0 ~ /^Merge with strategy/ || $0 ~ /^error:/) {exit}
      parsing && $0 ~ /^[[:space:]]+/ {
        sub(/^[[:space:]]+/, "", $0)
        if (length($0)) print $0
      }
    ' "$tmp_err"
  )


  if [[ ${#files[@]} -eq 0 ]]; then
    critical "Matched overwrite error but couldn't parse file list." >&2
    return "$rc"
  fi

  local template_suffix="${TEMPLATE_FILE_SUFFIX:-.template}"

  # Track backups so we can always restore on error.
  local -a backups=()
  cleanup_restore() {
    local i orig bak
    for ((i=${#backups[@]}-1; i>=0; i--)); do
      orig="${backups[$i]%%|*}"
      bak="${backups[$i]##*|}"
      if [[ -f "$bak" ]]; then
        debug "moving $bak back to $orig"
        mkdir -p "$(dirname "$orig")"
        mv -f -- "$bak" "$orig"
      fi
    done
  }
  trap 'cleanup_restore' ERR INT TERM

  # 4) For each blocking file: back it up, then reset it to HEAD
  for f in "${files[@]}"; do
#    if ! geet_git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
#      debug "Skipping untracked path (unexpected for this error): $f" >&2
#      continue
#    fi
    if [[ ! -f "$f" ]]; then
      debug "File missing in working tree, skipping backup: $f" >&2
      continue
    fi

    local bak="$f.bak"
    debug "temporarily moving $f to $bak"
    mkdir -p "$(dirname "$bak")"
    cp -p -- "$f" "$bak"
    backups+=("$f|$bak")

    # reset just this file so the op can proceed
    debug "temporarily resetting git state of $f"
    geet_git restore --source=HEAD --worktree -- "$f"
  done

  # 5) retry the operation (should proceed now)
  debug "running command"
  geet_git "$@" --no-edit

  # 6) After op: for each path, copy the new version to the template path, then restore bak
  for entry in "${backups[@]}"; do
    local orig="${entry%%|*}"
    local bak="${entry##*|}"

    # compute suffix path: dir/name + template_suffix + .ext
    local dir base name ext suffix_path
    dir="$(dirname "$orig")"
    base="$(basename "$orig")"
    name="${base%.*}"
    ext="${base##*.}"
    if [[ "$base" == "$ext" ]]; then
      # no extension
      suffix_path="$dir/${name}${template_suffix}"
    else
      suffix_path="$dir/${name}${template_suffix}.${ext}"
    fi

    mkdir -p "$(dirname "$suffix_path")"

    # save the post-pull version as template/sample
    if [[ -f "$orig" ]]; then
      debug "moving $orig (the version from the remote) to $suffix_path"
      cp -p -- "$orig" "$suffix_path"
    else
      warn "Post-op file missing, not writing template: $orig" >&2
    fi

    # restore original local file content
    debug "restoring $bak back to $orig"
    mv -f -- "$bak" "$orig"
  done

  # success: disable restore-on-error trap and remove any leftover .bak (should be none)
  trap - ERR INT TERM
  log "Pulled/merged while preserving local files. See new remote changes at:"
  for entry in "${backups[@]}"; do
    local orig="${entry%%|*}"
    local dir base name ext suffix_path
    dir="$(dirname "$orig")"
    base="$(basename "$orig")"
    name="${base%.*}"
    ext="${base##*.}"
    if [[ "$base" == "$ext" ]]; then
      # no extension
      suffix_path="$dir/${name}${template_suffix}"
    else
      suffix_path="$dir/${name}${template_suffix}.${ext}"
    fi
    log "    $suffix_path"
  done
}


###############################################################################
# CLONE - Simple git clone without init
###############################################################################
# Just clones a repository without running any post-install logic
call_cmd() {
  if [[ -z "$TEMPLATE_DIR" ]]; then
    critical "We could not find your template repo anywhere in this project!"
    warn "Are you sure you are somewhere inside a project which has a template repo?"
    warn "The template repo is a hidden folder at the root of your working directory which contains a .geethier file inside it"
    warn "To debug our search, run \`$GEET_ALIAS status --verbose --filter LOCATE\`"
    warn "If you think we made a mistake, review the code at $GEET_LIB/digest-and-locate.sh detect_template_dir_from_cwd"
    exit 1
  fi
  need_dotgit
  sync_exclude
  block_footguns "$@"
  if [[ "$1" == "push" ]] && ! [[ "$(geet_git remote -v)" ]]; then
      log "It looks like you have no remote setup yet. Would you like to publish on github?"
      log "Just run \`$GEET_ALIAS pub\` to publish as a public repo or \`$GEET_ALIAS publish --private\`"
      exit 1
  fi
  has_flag "--normal" "NORMAL"
  if [[ $NORMAL ]]; then
    geet_git "${GEET_ARGS[@]}"
  else
    git_retry_with_local_ours "${GEET_ARGS[@]}"
  fi
#  if [[ "$1" == "status" ]]; then
#    log "Don't Panic! it is expected to see README.md and .gitignore show up as deleted, don't worry. read docs/AUTO_PROMOTE.md to understand why"
#  fi
}
