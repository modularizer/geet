# List tracked files matching a user-supplied glob-ish pattern.
# Uses git pathspec glob when the pattern contains glob chars.
_files_for_pat() {
  local pat="$1"
  if [[ "$pat" == */ ]]; then
    git ls-files -z -- ":(glob)${pat}**"
  elif [[ "$pat" == *[\*\?\[]* ]]; then
    git ls-files -z -- ":(glob)$pat"
  else
    git ls-files -z -- "$pat"
  fi
}

detach() {
  # Usage: geet detach <pattern>
  # Goal: prevent staging/committing AND stop applying pulled changes to working tree.
  local pat="$1"
  [[ -n "$pat" ]] || die "Usage: geet detach <file|pattern>"

  local files
  files="$(_files_for_pat "$pat" | tr '\0' '\n')"

  if [[ -z "$files" ]]; then
    log "Detached: no tracked files match $pat"
    return 0
  fi

  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    git update-index --skip-worktree -- "$f"
  done <<< "$files"

  log "Detached: $pat (skip-worktree set; won't stage/commit and won't update on pulls)"
}

retach() {
  # Usage: geet retach <pattern>
  # Goal: allow staging/committing and applying pulled changes again.
  local pat="$1"
  [[ -n "$pat" ]] || die "Usage: geet retach <file|pattern>"

  local files
  files="$(_files_for_pat "$pat" | tr '\0' '\n')"

  if [[ -z "$files" ]]; then
    log "Reattached: no tracked files match $pat"
    return 0
  fi

  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    git update-index --no-skip-worktree -- "$f"
  done <<< "$files"

  log "Reattached: $pat (skip-worktree cleared; can stage/commit and will update on pulls)"
}


# ---- status ----

detached() {
  # Show files with skip-worktree set
  git ls-files -v | awk '/^S /{print substr($0,3)}'
}
