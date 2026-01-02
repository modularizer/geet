is_literal_file_pat() {
  local p="$1"
  [[ "$p" != */ ]] || return 1                 # not a directory pattern
  [[ "$p" != *[\*\?\[]* ]] || return 1         # no glob chars *, ?, [
  return 0
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



detach() {
  # Usage: geet detach <pattern>
  geet git config merge.keep-ours.driver "true"

  local pat="$1"
  local attrs="$DOTGIT/info/attributes"
  local line_detach="${pat} merge=keep-ours"
  local line_retach="${pat} -merge"

  [[ -n "$pat" ]] || die "Usage: geet detach <file|pattern>"

  mkdir -p -- "$(dirname -- "$attrs")"
  touch -- "$attrs"

  # If exact "-merge" line exists, remove it
  if grep -Fxq -- "$line_retach" "$attrs"; then
    local tmp
    tmp="$(mktemp)"
    grep -Fxv -- "$line_retach" "$attrs" > "$tmp" && mv -- "$tmp" "$attrs"
  fi

  # in detach(), before echo:
  # NOTE: only de-dupe literal file patterns; glob/dir patterns may overlap
    # Only short-circuit for literal file paths (safe against overlap)
    if is_literal_file_pat "$pat" && grep -Fxq -- "$line_detach" "$attrs"; then
      log "Detached: $pat (already detached)"
      assert_merge_driver "$pat" keep-ours || die "Detach self-test failed for $pat"
      return 0
    fi


  # Append detach rule (even if already present; mirrors current behavior)
  echo "$line_detach" >> "$attrs"

  log "Detached: $pat (will keep your version on future pulls)"
  assert_merge_driver "$pat" keep-ours || die "Detach self-test failed for $pat"
}

retach() {
  # Usage: geet retach <pattern>
  geet git config merge.keep-ours.driver "true"

  local pat="$1"
  local attrs="$DOTGIT/info/attributes"
  local line_detach="${pat} merge=keep-ours"
  local line_retach="${pat} -merge"

  [[ -n "$pat" ]] || die "Usage: geet retach <file|pattern>"

  mkdir -p -- "$(dirname -- "$attrs")"
  touch -- "$attrs"

  # Case 2: exact "-merge" line already present -> do nothing
  if grep -Fxq -- "$line_retach" "$attrs"; then
    log "Reattached: $pat (already reattached)"
    assert_merge_driver "$pat" unset || die "Detach self-test failed for $pat"

    return 0
  fi

  # Case 1: exact "merge=keep-ours" line present -> remove it
  if grep -Fxq -- "$line_detach" "$attrs"; then
    local tmp
    tmp="$(mktemp)"
    grep -Fxv -- "$line_detach" "$attrs" > "$tmp" && mv -- "$tmp" "$attrs"
    log "Reattached: $pat (removed detach rule)"
    assert_merge_driver "$pat" unset || die "Detach self-test failed for $pat"
    return 0
  fi

  # Case 3: fallback -> append "-merge"
  echo "$line_retach" >> "$attrs"
  log "Reattached: $pat (added -merge override)"
  assert_merge_driver "$pat" unset || die "Detach self-test failed for $pat"
}


detached() {
  # Show files whose effective merge driver is keep-ours
  git ls-files -z \
  | xargs -0 -n 1 git check-attr -z merge -- \
  | awk -F': ' '
      $2=="merge" && $3=="keep-ours" { print $1 }
    ' \
  || true
}


