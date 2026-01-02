is_literal_file_pat() {
  local p="$1"
  [[ "$p" != */ ]] || return 1                 # not a directory pattern
  [[ "$p" != *[\*\?\[]* ]] || return 1         # no glob chars *, ?, [
}

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

assert_merge_driver() {
  local pat="$1" expected="$2"
  local fail=0

  while IFS= read -r -d '' path &&
        IFS= read -r -d '' attr &&
        IFS= read -r -d '' val; do

    if [[ "$expected" == "keep-ours" ]]; then
      [[ "$val" == "keep-ours" ]] || {
        echo "FAIL: $path merge=$val (expected keep-ours)" >&2
        fail=1
      }
    else
      [[ "$val" != "keep-ours" ]] || {
        echo "FAIL: $path merge=keep-ours (expected not keep-ours)" >&2
        fail=1
      }
    fi
  done < <(
    _files_for_pat "$pat" \
    | xargs -0 -n 50 git check-attr -z merge --
  )

  return "$fail"
}

add_protected_pat() {
  local pat="$1"
  mkdir -p -- "$(dirname -- "$SOFT_DETACHED_FILE_LIST")"
  touch -- "$SOFT_DETACHED_FILE_LIST"

  # de-dupe exact line
  grep -Fxq -- "$pat" "$SOFT_DETACHED_FILE_LIST" || echo "$pat" >> "$SOFT_DETACHED_FILE_LIST"
}
remove_protected_pat() {
  local pat="$1"
  [[ -f "$SOFT_DETACHED_FILE_LIST" ]] || return 0

  local tmp
  tmp="$(mktemp)"
  grep -Fxv -- "$pat" "$SOFT_DETACHED_FILE_LIST" > "$tmp" && mv -- "$tmp" "$SOFT_DETACHED_FILE_LIST"
}

# ---- attributes-based "keep ours" (your original detach/retach core) ----

soft_detach() {
  # Usage: geet soft_detach <pattern>
  # Goal: receive upstream updates and attempt merges; if conflicts, keep ours.
  # NOTE: does NOT prevent staging/committing. (Use detach() for that.)
  geet_git config merge.keep-ours.driver "true"

  local pat="$1"
  local attrs="$DOTGIT/info/attributes"
  local line_detach="${pat} merge=keep-ours"
  local line_retach="${pat} -merge"

  [[ -n "$pat" ]] || die "Usage: geet soft_detach <file|pattern>"

  mkdir -p -- "$(dirname -- "$attrs")"
  touch -- "$attrs"

  # If exact "-merge" line exists, remove it (so keep-ours can apply again)
  if grep -Fxq -- "$line_retach" "$attrs"; then
    local tmp
    tmp="$(mktemp)"
    grep -Fxv -- "$line_retach" "$attrs" > "$tmp" && mv -- "$tmp" "$attrs"
  fi

  # Only de-dupe literal file patterns; glob/dir patterns may overlap
  if is_literal_file_pat "$pat" && grep -Fxq -- "$line_detach" "$attrs"; then
    add_protected_pat "$pat"
    log "Soft-detached: $pat (already soft-detached)"
    assert_merge_driver "$pat" keep-ours || die "Soft-detach self-test failed for $pat"
    return 0
  fi

  echo "$line_detach" >> "$attrs"

  add_protected_pat "$pat"


  log "Soft-detached: $pat (merge conflicts will keep your version)"
  assert_merge_driver "$pat" keep-ours || die "Soft-detach self-test failed for $pat"
}

soft_sync() {
  # Usage: geet soft_sync <pattern>
  # Goal: apply upstream changes (pull/rebase/merge as your workflow dictates),
  # while keeping keep-ours behavior for conflicts on soft-detached paths.
  #
  # NOTE: If files are "hard detached" (skip-worktree), this temporarily
  # clears skip-worktree for the matched files so they can actually update,
  # then restores it after syncing.
  local pat="$1"
  [[ -n "$pat" ]] || die "Usage: geet soft_sync <file|pattern>"

  local files
  files="$(_files_for_pat "$pat" | tr '\0' '\n')"

  if [[ -z "$files" ]]; then
    log "Soft-sync: no tracked files match $pat"
    return 0
  fi

  # Temporarily allow updates for any hard-detached files
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    git update-index --no-skip-worktree -- "$f" >/dev/null 2>&1 || true
  done <<< "$files"

  # Do your sync operation. Pick ONE that matches your repo norms.
  # If you already have a wrapper, swap this line for it.
  git pull --rebase

  # Restore hard-detach state (only for files we touched)
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    git update-index --skip-worktree -- "$f" >/dev/null 2>&1 || true
  done <<< "$files"

  log "Soft-sync complete for $pat"
}

# ---- hard detach (skip-worktree) ----

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
  # Goal: remove keep-ours merge behavior AND allow staging/committing again.
  geet git config merge.keep-ours.driver "true"

  local pat="$1"
  local attrs="$DOTGIT/info/attributes"
  local line_detach="${pat} merge=keep-ours"
  local line_retach="${pat} -merge"

  [[ -n "$pat" ]] || die "Usage: geet retach <file|pattern>"

  mkdir -p -- "$(dirname -- "$attrs")"
  touch -- "$attrs"

  # Always remove from protected list (so commits can include it again)
  remove_protected_pat "$pat"

  # Case 2: exact "-merge" line already present -> done
  if grep -Fxq -- "$line_retach" "$attrs"; then
    log "Reattached: $pat (already reattached)"
    assert_merge_driver "$pat" unset || die "Retach self-test failed for $pat"
    return 0
  fi

  # Case 1: exact "merge=keep-ours" line present -> remove it
  if grep -Fxq -- "$line_detach" "$attrs"; then
    local tmp
    tmp="$(mktemp)"
    grep -Fxv -- "$line_detach" "$attrs" > "$tmp" && mv -- "$tmp" "$attrs"
    log "Reattached: $pat (removed detach rule)"
    assert_merge_driver "$pat" unset || die "Retach self-test failed for $pat"
    return 0
  fi

  # Case 3: fallback -> append "-merge"
  echo "$line_retach" >> "$attrs"
  log "Reattached: $pat (added -merge override)"
  assert_merge_driver "$pat" unset || die "Retach self-test failed for $pat"
}


# ---- status ----

soft_detached() {
  # Show files whose effective merge driver is keep-ours
  git ls-files -z \
  | xargs -0 -n 1 git check-attr -z merge -- \
  | awk -F': ' '
      $2=="merge" && $3=="keep-ours" { print $1 }
    ' \
  || true
}

detached() {
  # Show files with skip-worktree set
  git ls-files -v | awk '/^S /{print substr($0,3)}'
}
