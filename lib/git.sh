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
  #   1) Map remote path to local path using .geetinclude mapping
  #   2) copy local file -> local file.bak
  #   3) git restore remote path (reset to HEAD) so merge/pull can proceed
  #   4) rerun operation
  #   5) copy post-op remote file -> local path (mapped from remote)
  #   6) restore .bak back to local path
  #
  # Notes:
  # - No commits, no stashes.
  # - Only works for *tracked* files (the ones that trigger the overwrite error).
  # - Uses .geetinclude mappings (local => remote) to determine file locations
  set -euo pipefail

  if ! geet_git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Not a git repo." >&2
    return 2
  fi

  # Load mapping library
  source "$GEET_LIB/mapping.sh"

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

  log "resolving merge conflicts using .geetinclude mappings"
  # 3) parse file list (robust across "error:" prefix + different endings)
  # These are REMOTE paths (what's tracked in the template repo)
  mapfile -t remote_files < <(
    awk '
      index($0, "Your local changes to the following files would be overwritten by merge:") {parsing=1; next}
      parsing && ($0 ~ /^Please commit your changes/ || $0 ~ /^Aborting/ || $0 ~ /^Merge with strategy/ || $0 ~ /^error:/) {exit}
      parsing && $0 ~ /^[[:space:]]+/ {
        sub(/^[[:space:]]+/, "", $0)
        if (length($0)) print $0
      }
    ' "$tmp_err"
  )


  if [[ ${#remote_files[@]} -eq 0 ]]; then
    critical "Matched overwrite error but couldn't parse file list." >&2
    return "$rc"
  fi

  # Track backups: "local_path|remote_path|bak_path"
  local -a backups=()
  cleanup_restore() {
    local i local_path bak_path
    for ((i=${#backups[@]}-1; i>=0; i--)); do
      local_path="${backups[$i]%%|*}"
      bak_path="${backups[$i]##*|}"
      if [[ -f "$bak_path" ]]; then
        debug "restoring $bak_path back to $local_path"
        mkdir -p "$(dirname "$local_path")"
        mv -f -- "$bak_path" "$local_path"
      fi
    done
  }
  trap 'cleanup_restore' ERR INT TERM

  # 4) For each blocking file: map remote to local, back it up, then reset remote to HEAD
  for remote_path in "${remote_files[@]}"; do
    # Map remote path to local path
    local local_path
    get_local_from_remote "$remote_path" local_path

    debug "mapping: remote=$remote_path => local=$local_path"

    # Check if local file exists
    if [[ ! -f "$local_path" ]]; then
      # Local file doesn't exist, check if remote file exists
      if [[ ! -f "$remote_path" ]]; then
        debug "Neither local ($local_path) nor remote ($remote_path) file exists, skipping" >&2
        continue
      else
        # Only remote exists, back it up
        local bak="$remote_path.bak"
        debug "backing up remote file $remote_path to $bak"
        mkdir -p "$(dirname "$bak")"
        cp -p -- "$remote_path" "$bak"
        backups+=("$remote_path|$remote_path|$bak")
      fi
    else
      # Local file exists, back it up
      local bak="$local_path.bak"
      debug "backing up local file $local_path to $bak"
      mkdir -p "$(dirname "$bak")"
      cp -p -- "$local_path" "$bak"
      backups+=("$local_path|$remote_path|$bak")
    fi

    # reset remote file to HEAD so the op can proceed
    debug "resetting git state of $remote_path"
    geet_git restore --source=HEAD --worktree -- "$remote_path" 2>/dev/null || true
  done

  # 5) retry the operation (should proceed now)
  debug "running command"
  geet_git "$@" --no-edit

  # 6) After op: copy remote changes to local path, then restore local backup
  for entry in "${backups[@]}"; do
    local local_path="${entry%%|*}"
    local rest="${entry#*|}"
    local remote_path="${rest%%|*}"
    local bak="${rest##*|}"

    # save the post-pull remote version to local path
    if [[ -f "$remote_path" ]]; then
      debug "copying remote changes from $remote_path to $local_path"
      mkdir -p "$(dirname "$local_path")"
      cp -p -- "$remote_path" "$local_path"
    else
      warn "Post-op remote file missing: $remote_path" >&2
    fi

    # restore original local file content from backup
    if [[ -f "$bak" ]]; then
      debug "restoring original content from $bak to $local_path"
      mv -f -- "$bak" "$local_path"
    fi
  done

  # success: disable restore-on-error trap
  trap - ERR INT TERM
  log "Pulled/merged while preserving local files. New remote changes saved to local paths:"
  for entry in "${backups[@]}"; do
    local local_path="${entry%%|*}"
    log "    $local_path"
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

  local git_rc=0
  if [[ $NORMAL ]]; then
    geet_git "${GEET_ARGS[@]}"
    git_rc=$?
  else
    git_retry_with_local_ours "${GEET_ARGS[@]}"
    git_rc=$?
  fi

  # Update git ref tracking after commands that might change the ref
  if [[ $git_rc -eq 0 ]]; then
    case "${1:-}" in
      checkout|switch|pull|fetch|merge|rebase|reset|commit|cherry-pick)
        source "$GEET_LIB/git-ref.sh"
        update_git_ref
        ;;
    esac
  fi

  return $git_rc
#  if [[ "$1" == "status" ]]; then
#    log "Don't Panic! it is expected to see README.md and .gitignore show up as deleted, don't worry. read docs/AUTO_PROMOTE.md to understand why"
#  fi
}
