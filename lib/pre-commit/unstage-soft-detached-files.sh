# helper: append NUL-separated
append_nul() { to_unstage+="${1}"$'\0'; }

unstage_soft_detached(){
  [[ -f "$SOFT_DETACHED" ]] || return 0

  # staged files (NUL-separated)
  staged="$(geet_git diff --cached --name-only -z || true)"
  [[ -n "$staged" ]] || return 0

  # Build list of staged files to unstage (NUL-separated)
  to_unstage=""


  # check each staged file against each protected pattern
  while IFS= read -r -d '' f; do
    [[ -n "$f" ]] || continue

    while IFS= read -r pat; do
      # strip comments/blank lines
      pat="${pat%%#*}"
      pat="${pat%"${pat##*[![:space:]]}"}"
      pat="${pat#"${pat%%[![:space:]]*}"}"
      [[ -n "$pat" ]] || continue

      if [[ "$pat" == */ ]]; then
        # directory prefix rule
        [[ "$f" == "$pat"* ]] && { append_nul "$f"; break; }
      else
        # exact match OR prefix (treat "dir" same as "dir/")
        [[ "$f" == "$pat" || "$f" == "$pat/"* ]] && { append_nul "$f"; break; }
      fi
    done < "$SOFT_DETACHED"
  done < <(printf '%s' "$staged")

  # If any protected files were staged, unstage them and continue.
  if [[ -n "$to_unstage" ]]; then
    # Show a friendly note (optional; remove if you want totally silent)
    echo "geet: unstaging protected files:" >&2
    while IFS= read -r -d '' f; do
      [[ -n "$f" ]] || continue
      echo "  - $f" >&2
    done < <(printf '%s' "$to_unstage")

    # Unstage (keep working tree edits)
    printf '%s' "$to_unstage" | xargs -0 git restore --staged --
  fi
}