

# Helper: sync .geetinclude to .geetexclude
sync_exclude() {
  source "$GEET_LIB/sync.sh"
  sync
}

# Helper: check if template git repo exists
need_dotgit() {
  [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]] || die "missing $DOTGIT (run: $GEET_ALIAS init)"
}

rel_path() {
  local p="$1"

  # turn absolute into repo-relative
  if [[ "$p" == /* ]]; then
    [[ "$p" == "$root/"* ]] || die "path outside project: $p"
    p="${p#"$root"/}"
  fi

  p="${p#./}"

  while [[ "$p" == *"//"* ]]; do
    p="${p//\/\//\/}"
  done

  echo "$p"
}

abs_path() {
  local p="$1"

  # if already absolute, keep it
  if [[ "$p" == /* ]]; then
    [[ "$p" == "$root/"* ]] || die "path outside project: $p"
    echo "$p"
    return
  fi

  p="$(rel_path "$p")"
  echo "$root/$p"
}

# Resolve src and dst paths for a file
# Returns: src_rel (actual file), src_abs (absolute path), dst_rel (clean name for git)
# Invariants: dst = dir/stem+ext, src = first existing: dir/stem+suffix+ext
resolve_paths() {
  local path_rel="$1"
  local -n _src_rel="$2"
  local -n _src_abs="$3"
  local -n _dst_rel="$4"

  # Parse path components
  local path_base=$(basename -- "$path_rel")
  local path_dir=$(dirname -- "$path_rel")

  # Extract extension
  local ext=""
  if [[ "$path_base" == *.* ]]; then
    ext=".${path_base##*.}"
  fi

  # Extract stem and suffix
  local name_without_ext="${path_base%.*}"
  local stem suffix
  if [[ "$name_without_ext" == *"$TEMPLATE_FILE_SUFFIX" ]]; then
    stem="${name_without_ext%"$TEMPLATE_FILE_SUFFIX"}"
    suffix="$TEMPLATE_FILE_SUFFIX"
  elif [[ "$name_without_ext" == *"$TEMPLATE_FILE_SUFFIX_2" ]]; then
    stem="${name_without_ext%"$TEMPLATE_FILE_SUFFIX_2"}"
    suffix="$TEMPLATE_FILE_SUFFIX_2"
  else
    stem="$name_without_ext"
    suffix=""
  fi

  # dst is always clean name
  _dst_rel="$path_dir/${stem}${ext}"

  # Check for conflict: both template variants exist
  local template1="$path_dir/${stem}${TEMPLATE_FILE_SUFFIX}${ext}"
  local template2="$path_dir/${stem}${TEMPLATE_FILE_SUFFIX_2}${ext}"
  if [[ -e "$template1" && -e "$template2" ]]; then
    die "conflicting templates exist: $template1 and $template2"
  fi

  # src is first existing file in priority order
  local src_base
  if [[ -n "$suffix" ]]; then
    src_base="${stem}${suffix}${ext}"
  elif [[ -e "$template1" ]]; then
    src_base="${stem}${TEMPLATE_FILE_SUFFIX}${ext}"
  elif [[ -e "$template2" ]]; then
    src_base="${stem}${TEMPLATE_FILE_SUFFIX_2}${ext}"
  else
    src_base="${stem}${ext}"
  fi

  _src_rel="$path_dir/$src_base"
  _src_abs="$(abs_path "$_src_rel")"
}

# Merge pattern variables with fallback
merge_patterns() {
  local pattern1="${1:-}"
  local pattern2="${2:-}"
  local default="${3:-}"

  local merged="${pattern1}|${pattern2}"
  merged="${merged#|}"
  merged="${merged%|}"
  echo "${default:-"$merged"}"
}

# Find files matching an argument (glob, directory, file, or -u flag)
find_matches() {
  local arg="$1"
  local root="$2"
  local -n _matches="$3"

  _matches=()

  if [[ "$arg" == "-u" ]]; then
    # Read from .geetinclude file
    local include_file="$TEMPLATE_DIR/.geetinclude"
    while IFS= read -r line; do
      line="${line%%#*}"          # strip comments
      line="$(echo "$line" | xargs)"  # trim whitespace
      if [[ -n "$line" && -e "$line" ]]; then
        _matches+=("$line")
        debug "match $line"
      fi
    done < "$include_file"
  elif [[ "$arg" != *[\*\?\[]* && -d "$arg" ]]; then
    # Directory: recurse all files
    while IFS= read -r -d '' m; do
      _matches+=("$m")
    done < <(find "$arg" -type f -print0)
  elif [[ "$arg" == *[\*\?\[]* ]]; then
    # Glob pattern: use find -path (supports * matching across /)
    while IFS= read -r -d '' m; do
      _matches+=("$m")
    done < <(find "$root" -path "$root/$arg" -type f -print0)
  else
    # Literal file
    [[ -f "$arg" ]] || die "no files matched: $arg"
    _matches+=("$arg")
  fi

  (( ${#_matches[@]} > 0 )) || die "no files matched: $arg"
}

# Check if file path matches any of the given patterns
check_file_patterns() {
  local file_patterns="$1"
  local src_rel="$2"
  local path_rel="$3"
  local -n _errors="$4"

  [[ -n "$file_patterns" ]] || return 0

  IFS='|' read -ra patterns <<< "$file_patterns"
  for pattern in "${patterns[@]}"; do
    [[ -z "$pattern" ]] && continue
    if echo "$src_rel" | grep -qiE "$pattern"; then
      _errors+=("FILE: $path_rel matches pattern: $pattern")
    fi
  done
}

# Check if file content matches any of the given patterns
check_content_patterns() {
  local content_patterns="$1"
  local src_rel="$2"
  local path_rel="$3"
  local -n _errors="$4"

  [[ -n "$content_patterns" ]] || return 0

  IFS='|' read -ra patterns <<< "$content_patterns"
  for pattern in "${patterns[@]}"; do
    [[ -z "$pattern" ]] && continue

    # Skip if file doesn't exist
    [[ -f "$src_rel" ]] || continue

    # Skip binary files
    if file --mime "$src_rel" 2>/dev/null | grep -q 'charset=binary'; then
      continue
    fi

    # Skip template config
    [[ "$path_rel" == *template-config.env ]] && continue

    # Search for pattern in file content
    matches_content=$(grep -niE "$pattern" "$src_rel" 2>/dev/null || true)
    if [[ -n "$matches_content" ]]; then
      while IFS= read -r match; do
        _errors+=("CONTENT: $path_rel matches pattern: $pattern"$'\n'"  → $match")
      done <<< "$matches_content"
    fi
  done
}





###############################################################################
# CLONE - Simple git clone without init
###############################################################################
# Just clones a repository without running any post-install logic
include() {
  if [[ "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
    cat <<EOF
    $GEET_ALIAS include - add to whitelist then add to git

    This script is intended to be used in lieu of git add, as it has some geet-specific tools to keep you on track.

    Rules:
      - we always add every file you included to the whitelist
      - we never allow commiting a file like \`index.tsx\` if \`index${TEMPLATE_FILE_SUFFIX}.tsx\` exists, we will instead add \`index${TEMPLATE_FILE_SUFFIX}.tsx\` as \`index.tsx\`
      - if you add a file like \`server${TEMPLATE_FILE_SUFFIX}.tsx\` it goes into git as \`server.tsx\`

    Usage: $GEET_ALIAS include <glob>
           $GEET_ALIAS include --migrate   # convert old .geetinclude to new mapping format

    Examples:
      $GEET_ALIAS include src/    # adds the whole src folder and all its contents
      $GEET_ALIAS include package.json    # adds just that file
      $GEET_ALIAS include --migrate        # migrate .geetinclude to explicit local => remote format
EOF
    return 0
  fi

  if [[ -z "$TEMPLATE_DIR" ]]; then
    critical "We could not find your template repo anywhere in this project!"
    warn "Are you sure you are somewhere inside a project which has a template repo?"
    warn "The template repo is a hidden folder at the root of your working directory which contains a .geethier file inside it"
    warn "To debug our search, run \`$GEET_ALIAS status --verbose --filter LOCATE\`"
    warn "If you think we made a mistake, review the code at $GEET_LIB/digest-and-locate.sh detect_template_dir_from_cwd"
    exit 1
  fi
  root=$(dirname -- "${TEMPLATE_DIR%/}")
  need_dotgit
  sync_exclude
  has_flag --discreet DISCREET
  has_flag --discrete DISCRETE
  has_flag -f FORCE
  has_flag --migrate MIGRATE
  if [[ -n "$DISCRETE" ]]; then
    die "Whoops! did you mean --discreet?"
  fi

  # Handle --migrate flag
  if [[ -n "$MIGRATE" ]]; then
    local include_file="$TEMPLATE_DIR/.geetinclude"
    if [[ ! -f "$include_file" ]]; then
      die ".geetinclude file not found at $include_file"
    fi

    log "Migrating .geetinclude to explicit mapping format..."

    # Read and convert
    local temp_file=$(mktemp)
    if [[ ! -f "$temp_file" ]]; then
      die "Failed to create temporary file"
    fi

    local migrated_count=0
    local unchanged_count=0

    # Temporarily disable exit-on-error for migration
    set +e

    while IFS= read -r line || [[ -n "$line" ]]; do
      # Trim whitespace
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"

      # Preserve comments and empty lines as-is
      if [[ -z "$line" ]] || [[ "$line" == \#* ]]; then
        echo "$line" >> "$temp_file"
        continue
      fi

      # Check if already has mapping
      if [[ "$line" == *" => "* ]]; then
        echo "$line" >> "$temp_file"
        ((unchanged_count++))
        continue
      fi

      # Old format: line contains REMOTE path (dst)
      # We need to find if LOCAL path (with suffix) exists
      local remote_path="$line"
      local src_rel="" src_abs="" dst_rel=""

      # Use resolve_paths to find the local variant
      resolve_paths "$remote_path" src_rel src_abs dst_rel 2>/dev/null || {
        # If resolve_paths fails, keep the line as-is
        warn "Failed to resolve path: $remote_path, keeping as-is"
        echo "$remote_path" >> "$temp_file"
        ((unchanged_count++))
        continue
      }

      if [[ "$src_rel" == "$dst_rel" ]]; then
        # No mapping needed, keep simple format
        echo "$remote_path" >> "$temp_file"
        debug "unchanged: $remote_path"
        ((unchanged_count++))
      else
        # Write explicit mapping
        echo "$src_rel => $dst_rel" >> "$temp_file"
        log "  $remote_path -> $src_rel => $dst_rel"
        ((migrated_count++))
      fi
    done < "$include_file"

    # Re-enable exit-on-error
    set -e

    # Replace original file
    mv "$temp_file" "$include_file" || die "Failed to update .geetinclude"

    log "Migration complete!"
    log "  Migrated entries: $migrated_count"
    log "  Unchanged entries: $unchanged_count"

    return 0
  fi

  sync_exclude
  # first, modify .geetinclude
  for arg in "${GEET_ARGS[@]}"; do
    find_matches "$arg" "$root" matches

    # Check patterns before adding files
    file_patterns=$(merge_patterns "${PREVENT_COMMIT_FILE_PATTERNS_1:-}" "${PREVENT_COMMIT_FILE_PATTERNS_2:-}" "${PREVENT_COMMIT_FILE_PATTERNS:-}")
    content_patterns=$(merge_patterns "${PREVENT_COMMIT_CONTENT_PATTERNS_1:-}" "${PREVENT_COMMIT_CONTENT_PATTERNS_2:-}" "${PREVENT_COMMIT_CONTENT_PATTERNS:-}")

    if [[ -n "$file_patterns" ]] || [[ -n "$content_patterns" ]]; then
      errors=()

      for path in "${matches[@]}"; do
        path_rel="$(rel_path "$path")"
        [[ "$path_rel" == .git/* ]] && die "attempted to commit .git"

        resolve_paths "$path_rel" src_rel src_abs dst_rel
        check_file_patterns "$file_patterns" "$src_rel" "$path_rel" errors
        check_content_patterns "$content_patterns" "$src_rel" "$path_rel" errors
      done

      # If errors found, fail the include
      if [[ ${#errors[@]} -gt 0 ]]; then
        echo "❌ [$GEET_ALIAS include] Found patterns that may indicate app-specific code:" >&2
        echo >&2
        for error in "${errors[@]}"; do
          echo "  $error" >&2
        done
        echo >&2
        echo "These patterns suggest implementation-specific code that shouldn't be in the template." >&2
        echo >&2
        echo "To fix: Remove the matched patterns or update template-config.env, semitracked-template-config.env, or untracked-template-config.env" >&2
        exit 1
      fi
    fi
    for path in "${matches[@]}"; do
      path_rel="$(rel_path "$path")"
      resolve_paths "$path_rel" src_rel src_abs dst_rel

      # Write mapping to .geetinclude
      # Format: local => remote (or just path if they're the same)
      local mapping_line
      if [[ "$src_rel" == "$dst_rel" ]]; then
        mapping_line="$dst_rel"
      else
        mapping_line="$src_rel => $dst_rel"
      fi

      # Check if this mapping already exists (check both formats)
      if ! grep -qxF "$mapping_line" "$TEMPLATE_DIR/.geetinclude" && \
         ! grep -qxF "$dst_rel" "$TEMPLATE_DIR/.geetinclude" && \
         ! grep -qF "$src_rel => $dst_rel" "$TEMPLATE_DIR/.geetinclude" && \
         ! grep -qF "$dst_rel => " "$TEMPLATE_DIR/.geetinclude"; then
        debug "adding mapping to .geetinclude: $mapping_line"
        printf '%s\n' "$mapping_line" >> "$TEMPLATE_DIR/.geetinclude"
      fi
    done
    sync_exclude


    geet_git add -- "$TEMPLATE_DIR/.geetinclude" "$TEMPLATE_DIR/.geetexclude"
    for path in "${matches[@]}"; do
      path_rel="$(rel_path "$path")"
      resolve_paths "$path_rel" src_rel src_abs dst_rel

      debug "src_rel:$src_rel"
      debug "dst_rel:$dst_rel"

      if [[ "$src_rel" == "$dst_rel" ]]; then
        debug "calling git add"
        if [[ -n "$DISCREET" ]]; then
          # --discreet mode: hide LOCAL path from parent repo
          if [[ -n "$APP_GIT_INFO_EXCLUDE" ]]; then
            if ! grep -qxF "$src_rel" "$APP_GIT_INFO_EXCLUDE"; then
              debug "appending $src_rel to $APP_GIT_INFO_EXCLUDE"
              echo "$src_rel" >> "$APP_GIT_INFO_EXCLUDE"
            else
              debug "$src_rel already in $APP_GIT_INFO_EXCLUDE"
            fi
          fi
          touch "$TEMPLATE_DIR/parent-git-info-exclude"
          echo "$src_rel" >> "$TEMPLATE_DIR/parent-git-info-exclude"
        fi
        if [[ -n "$FORCE" ]]; then
          geet_git add -f -- "$dst_rel"
        else
          geet_git add -- "$dst_rel"
        fi
      else
        debug "adding $src_rel as $dst_rel"
        hash=$(geet_git hash-object -w -- "$src_abs")
        geet_git update-index --add --cacheinfo 100644 "$hash" "$dst_rel"
      fi
    done
  done
}
