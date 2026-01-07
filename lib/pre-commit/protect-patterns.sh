
###############################################################################
# PREVENT COMMITTING APP-SPECIFIC CODE
###############################################################################
# Check for patterns that indicate implementation-specific code
# Configure by adding PREVENT_COMMIT_FILE_PATTERNS and PREVENT_COMMIT_CONTENT_PATTERNS to .geet-template.env
protect_patterns(){
  # Read patterns from env vars (pipe-delimited)
  file_patterns="${PREVENT_COMMIT_FILE_PATTERNS_1:-}|${PREVENT_COMMIT_FILE_PATTERNS_2:-}"
  file_patterns="${file_patterns#|}"
  file_patterns="${file_patterns%|}"
  file_patterns="${PREVENT_COMMIT_FILE_PATTERNS:-"$file_patterns"}"

  content_patterns="${PREVENT_COMMIT_CONTENT_PATTERNS_1:-}|${PREVENT_COMMIT_CONTENT_PATTERNS_2:-}"
  content_patterns="${content_patterns#|}"
  content_patterns="${content_patterns%|}"
  content_patterns="${PREVENT_COMMIT_CONTENT_PATTERNS:-"$content_patterns"}"

  if [[ -n "$file_patterns" ]] || [[ -n "$content_patterns" ]]; then

    errors=()

    # Get list of staged files
    staged_files=$("$geet_git" diff --cached --name-only)

    # Check file patterns (pipe-delimited)
    if [[ -n "$file_patterns" ]]; then
      IFS='|' read -ra patterns <<< "$file_patterns"
      for pattern in "${patterns[@]}"; do
        [[ -z "$pattern" ]] && continue
        while IFS= read -r file; do
          [[ -z "$file" ]] && continue
#          echo "checking $file against pattern $pattern"
          if echo "$file" | grep -qiE "$pattern"; then
            errors+=("FILE: $file matches pattern: $pattern")
          fi
        done <<< "$staged_files"
      done
    fi

    # Check content patterns (pipe-delimited)
    if [[ -n "$content_patterns" ]]; then
      IFS='|' read -ra patterns <<< "$content_patterns"
      for pattern in "${patterns[@]}"; do
        [[ -z "$pattern" ]] && continue
        while IFS= read -r file; do
          [[ -z "$file" ]] && continue

          # Skip if file doesn't exist in the index (deleted files)
          "$geet_git" ls-files --error-unmatch "$file" &>/dev/null || continue

          # Skip binary files by checking the staged content
          if "$geet_git" diff --cached --numstat "$file" | grep -q '^-[[:space:]]*-'; then
            continue
          fi

#          echo "checking content of $file for $pattern"

          [[ "$file" == *template-config.env ]] && continue

          # Search for pattern in staged content
          matches=$("$geet_git" show ":$file" 2>/dev/null | grep -niE "$pattern" || true)
          if [[ -n "$matches" ]]; then
            while IFS= read -r match; do
              errors+=("CONTENT: $file matches pattern: $pattern"$'\n'"  → $match")
            done <<< "$matches"
          fi
        done <<< "$staged_files"
      done
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
      echo "To bypass this check: geet commit --no-verify" >&2
      echo "To fix: Remove the matched patterns or update .geet-template.env" >&2
      exit 1
    fi
  fi

}
