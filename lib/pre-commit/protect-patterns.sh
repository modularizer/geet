
###############################################################################
# PREVENT COMMITTING APP-SPECIFIC CODE
###############################################################################
# Check for patterns that indicate implementation-specific code
protect_patterns(){
  if [[ -f "$CONFIG" ]] && command -v jq >/dev/null 2>&1; then
    # Read pattern lists from config
    file_patterns=$(jq -r '.preventCommit.filePatterns[]? // empty' "$CONFIG" 2>/dev/null || true)
    content_patterns=$(jq -r '.preventCommit.contentPatterns[]? // empty' "$CONFIG" 2>/dev/null || true)

    errors=()

    # Get list of staged files
    staged_files=$(geet_git diff --cached --name-only)

    # Check file patterns
    if [[ -n "$file_patterns" ]]; then
      while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        while IFS= read -r file; do
          [[ -z "$file" ]] && continue
          if echo "$file" | grep -qE "$pattern"; then
            errors+=("FILE: $file matches pattern: $pattern")
          fi
        done <<< "$staged_files"
      done <<< "$file_patterns"
    fi

    # Check content patterns
    if [[ -n "$content_patterns" ]]; then
      while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        while IFS= read -r file; do
          [[ -z "$file" ]] && continue
          # Skip binary files and directories
          [[ ! -f "$file" ]] && continue
          file -b "$file" 2>/dev/null | grep -q text || continue

          # Search for pattern in file
          matches=$(grep -nE "$pattern" "$file" 2>/dev/null || true)
          if [[ -n "$matches" ]]; then
            while IFS= read -r match; do
              errors+=("CONTENT: $file matches pattern: $pattern"$'\n'"  → $match")
            done <<< "$matches"
          fi
        done <<< "$staged_files"
      done <<< "$content_patterns"
    fi

    # If errors found, fail the commit
    if [[ ${#errors[@]} -gt 0 ]]; then
      echo "❌ [pre-commit] Found patterns that may indicate app-specific code:" >&2
      echo >&2
      for error in "${errors[@]}"; do
        echo "  $error" >&2
      done
      echo >&2
      echo "These patterns suggest implementation-specific code that shouldn't be in the template." >&2
      echo >&2
      echo "To bypass this check: $GEET_ALIAS commit --no-verify" >&2
      echo "To fix: Remove the matched patterns or update $CONFIG" >&2
      exit 1
    fi
  fi

}
