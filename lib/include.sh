

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

  # Normalize path_dir: convert "." to empty string to avoid ./ prefix
  if [[ "$path_dir" == "." ]]; then
    path_dir=""
  fi

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
  if [[ -n "$path_dir" ]]; then
    _dst_rel="$path_dir/${stem}${ext}"
  else
    _dst_rel="${stem}${ext}"
  fi

  # Check for conflict: both template variants exist
  local template1="${path_dir:+$path_dir/}${stem}${TEMPLATE_FILE_SUFFIX}${ext}"
  local template2="${path_dir:+$path_dir/}${stem}${TEMPLATE_FILE_SUFFIX_2}${ext}"
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

  if [[ -n "$path_dir" ]]; then
    _src_rel="$path_dir/$src_base"
  else
    _src_rel="$src_base"
  fi
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

# Get list of modified files (relative to root)
get_modified_files() {
  local -n _modified="$1"
  _modified=()

  # Get modified, added, or untracked files from working tree
  # This includes: modified, added, deleted, renamed, untracked
  local status_output
  status_output=$(git --git-dir="$DOTGIT" --work-tree="$APP_DIR" status --porcelain 2>/dev/null || true)

  if [[ -n "$status_output" ]]; then
    while IFS= read -r line; do
      # Parse git status --porcelain format: XY filename
      # X = index status, Y = working tree status
      # We care about working tree modifications (Y column)
      local file="${line:3}" # Skip "XY " prefix

      # Handle renames (format: "R  old -> new")
      if [[ "$file" == *" -> "* ]]; then
        file="${file##* -> }"
      fi

      # Only add if file exists
      [[ -n "$file" && -e "$file" ]] && _modified+=("$file")
    done <<< "$status_output"
  fi
}

# Load all tracked files from .geetinclude into an associative array
load_tracked_files() {
  local -n _tracked="$1"
  _tracked=()

  [[ -f "$TEMPLATE_DIR/.geetinclude" ]] || return 0

  source "$GEET_LIB/mapping.sh"

  local local_path remote_path
  while IFS= read -r line || [[ -n "$line" ]]; do
    if parse_mapping_line "$line" local_path remote_path; then
      # Store both local and remote paths for flexible matching
      _tracked["$local_path"]=1
      _tracked["$remote_path"]=1
    fi
  done < "$TEMPLATE_DIR/.geetinclude"
}

# Filter matches to only files that are both tracked and modified
filter_to_tracked_and_modified() {
  local -n _matches="$1"
  local -n _tracked_map="$2"
  local -n _modified_map="$3"
  local -n _filtered="$4"

  _filtered=()

  for path in "${_matches[@]}"; do
    local src_rel src_abs dst_rel
    cached_resolve_paths "$path" src_rel src_abs dst_rel

    # Check if tracked (either src or dst path)
    local is_tracked=0
    [[ -n "${_tracked_map[$src_rel]:-}" ]] && is_tracked=1
    [[ -n "${_tracked_map[$dst_rel]:-}" ]] && is_tracked=1

    # Check if modified
    local is_modified=0
    [[ -n "${_modified_map[$src_rel]:-}" ]] && is_modified=1
    [[ -n "${_modified_map[$dst_rel]:-}" ]] && is_modified=1

    # Only include if both tracked and modified
    if [[ $is_tracked -eq 1 && $is_modified -eq 1 ]]; then
      _filtered+=("$path")
    fi
  done
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
#        debug "match $line"
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

# Sync new files to tracked live folders
# Usage: sync_to_live_folders src_rel dst_rel
sync_to_live_folders() {
  local src_rel="$1"
  local dst_rel="$2"
  local live_folders_file="$TEMPLATE_DIR/live-folders"

  [[ -f "$live_folders_file" ]] || return 0

  source "$GEET_LIB/mapping.sh"

  # Clean up dead folders and build list of active ones
  local temp_file=$(mktemp)
  local -a active_folders=()

  while IFS= read -r live_folder; do
    [[ -n "$live_folder" ]] || continue

    if [[ -d "$live_folder" ]]; then
      active_folders+=("$live_folder")
      echo "$live_folder" >> "$temp_file"
    else
      debug "removing dead live folder: $live_folder"
    fi
  done < "$live_folders_file"

  # Update live-folders file with only active folders
  mv "$temp_file" "$live_folders_file"

  # If no active folders, we're done
  (( ${#active_folders[@]} > 0 )) || return 0

  # For each active live folder, symlink the new file if it doesn't exist
  for live_folder in "${active_folders[@]}"; do
    local src_abs="$root/$src_rel"
    local dest_file="$live_folder/$dst_rel"
    local dest_dir="$(dirname "$dest_file")"

    # Skip if file already exists in live folder
    [[ -e "$dest_file" ]] && continue

    # Create directory if needed
    mkdir -p "$dest_dir"

    # Create symlink
    ln "$src_abs" "$dest_file"
    debug "synced to live folder: $src_abs -> $dest_file"
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


    Examples:
      $GEET_ALIAS include src/            # adds the whole src folder and all its contents
      $GEET_ALIAS include package.json    # adds just that file
      $GEET_ALIAS include -u              # adds all files the template repo is already tracking
      $GEET_ALIAS include --migrate       # migrate .geetinclude to explicit local => remote format
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

    # Cache for resolve_paths results to avoid repeated expensive calls
    declare -A path_cache_src_rel
    declare -A path_cache_src_abs
    declare -A path_cache_dst_rel

    # Cached version of resolve_paths
    cached_resolve_paths() {
      local path_rel="$1"
      local -n _out_src_rel="$2"
      local -n _out_src_abs="$3"
      local -n _out_dst_rel="$4"

      # Check cache first
      if [[ -n "${path_cache_src_rel[$path_rel]:-}" ]]; then
        _out_src_rel="${path_cache_src_rel[$path_rel]}"
        _out_src_abs="${path_cache_src_abs[$path_rel]}"
        _out_dst_rel="${path_cache_dst_rel[$path_rel]}"
        debug "cache hit for: $path_rel"
        return 0
      fi

      # Cache miss - call resolve_paths with temp vars and store results
      local tmp_src_rel tmp_src_abs tmp_dst_rel
      resolve_paths "$path_rel" tmp_src_rel tmp_src_abs tmp_dst_rel
      path_cache_src_rel["$path_rel"]="$tmp_src_rel"
      path_cache_src_abs["$path_rel"]="$tmp_src_abs"
      path_cache_dst_rel["$path_rel"]="$tmp_dst_rel"
      _out_src_rel="$tmp_src_rel"
      _out_src_abs="$tmp_src_abs"
      _out_dst_rel="$tmp_dst_rel"
      debug "cache miss for: $path_rel"
    }

    # Optimize: for -u flag, only check patterns on modified files
    local -a check_matches=()
    if [[ "$arg" == "-u" ]]; then
      # Get list of modified files
      local -a modified_files
      get_modified_files modified_files

      # Build associative array for fast lookup
      declare -A modified_map
      for mf in "${modified_files[@]}"; do
        modified_map["$mf"]=1
      done

      # Filter matches to only modified files for pattern checking
      for path in "${matches[@]}"; do
        local path_rel_check="$(rel_path "$path")"
        if [[ -n "${modified_map[$path_rel_check]:-}" ]]; then
          check_matches+=("$path")
        fi
      done

      debug "include -u: checking patterns on ${#check_matches[@]} modified files (out of ${#matches[@]} total)"
    else
      # For non -u args, check all matches
      check_matches=("${matches[@]}")
    fi

    # Check patterns before adding files
    file_patterns=$(merge_patterns "${PREVENT_COMMIT_FILE_PATTERNS_1:-}" "${PREVENT_COMMIT_FILE_PATTERNS_2:-}" "${PREVENT_COMMIT_FILE_PATTERNS:-}")
    content_patterns=$(merge_patterns "${PREVENT_COMMIT_CONTENT_PATTERNS_1:-}" "${PREVENT_COMMIT_CONTENT_PATTERNS_2:-}" "${PREVENT_COMMIT_CONTENT_PATTERNS:-}")

    if [[ -n "$file_patterns" ]] || [[ -n "$content_patterns" ]]; then
      errors=()

      for path in "${check_matches[@]}"; do
        path_rel="$(rel_path "$path")"
        [[ "$path_rel" == .git/* ]] && die "attempted to commit .git"

        cached_resolve_paths "$path_rel" src_rel src_abs dst_rel
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

    # Optimize: for -u flag, skip writing to .geetinclude
    # (files came from .geetinclude, so they're already there)
    if [[ "$arg" != "-u" ]]; then
      for path in "${check_matches[@]}"; do
        path_rel="$(rel_path "$path")"
        cached_resolve_paths "$path_rel" src_rel src_abs dst_rel

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
    fi
    sync_exclude


    geet_git add -- "$TEMPLATE_DIR/.geetinclude" "$TEMPLATE_DIR/.geetexclude"

    # Optimize: for -u flag, only git add modified files
    # Reuse the modified_map from pattern checking phase
    local -a add_matches=()
    if [[ "$arg" == "-u" ]]; then
      # Only add modified files
      for path in "${matches[@]}"; do
        local path_rel_add="$(rel_path "$path")"
        if [[ -n "${modified_map[$path_rel_add]:-}" ]]; then
          add_matches+=("$path")
        fi
      done
      debug "include -u: adding ${#add_matches[@]} modified files (out of ${#matches[@]} total)"
    else
      # For non -u args, add all matches
      add_matches=("${matches[@]}")
    fi

    for path in "${add_matches[@]}"; do
      path_rel="$(rel_path "$path")"
      cached_resolve_paths "$path_rel" src_rel src_abs dst_rel

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
        # Sync to live folders
        sync_to_live_folders "$src_rel" "$dst_rel"
      else
        debug "adding $src_rel as $dst_rel"
        hash=$(geet_git hash-object -w -- "$src_abs")
        geet_git update-index --add --cacheinfo 100644 "$hash" "$dst_rel"
        # Sync to live folders
        sync_to_live_folders "$src_rel" "$dst_rel"
      fi
    done
  done
}

###############################################################################
# INCLUDEIF - Add tracked modified files to git (no new files)
###############################################################################
# Only adds files that are:
# 1. Matched by the pattern
# 2. Already tracked in .geetinclude
# 3. Modified since last commit
includeif() {
  if [[ "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
    cat <<EOF
    $GEET_ALIAS includeif - add tracked modified files to git

    This command is similar to 'include' but only adds files that are ALREADY tracked in .geetinclude
    and have been modified since the last commit. It will NOT add new files to .geetinclude.

    This is useful when you want to update existing tracked files without accidentally adding new ones.

    Rules:
      - Only adds files that match your pattern AND are in .geetinclude AND are modified
      - Never adds new entries to .geetinclude (unlike 'include')
      - Passes silently if no tracked modified files match (won't fail)
      - Respects template suffix transformation (e.g., adds index.template.tsx as index.tsx)

    Examples:
      $GEET_ALIAS includeif src/            # adds tracked modified files in src/
      $GEET_ALIAS includeif package.json    # adds if tracked and modified
      $GEET_ALIAS includeif "**/*.ts"       # adds tracked modified .ts files
      $GEET_ALIAS includeif -f .env         # force add if tracked and modified

    Flags:
      -f, --force       Force add files
      --discreet        Hide files from parent git repo
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
  if [[ -n "$DISCRETE" ]]; then
    die "Whoops! did you mean --discreet?"
  fi

  # Load tracked files from .geetinclude into a map
  declare -A tracked_map
  load_tracked_files tracked_map

  # Load modified files into a map
  local -a modified_files
  get_modified_files modified_files
  declare -A modified_map
  for mf in "${modified_files[@]}"; do
    modified_map["$mf"]=1
  done

  debug "includeif: loaded ${#tracked_map[@]} tracked paths and ${#modified_files[@]} modified files"

  # Set up path resolution cache (same as include)
  declare -A path_cache_src_rel path_cache_src_abs path_cache_dst_rel
  cached_resolve_paths() {
    local path_rel="$1"
    local -n _out_src_rel="$2"
    local -n _out_src_abs="$3"
    local -n _out_dst_rel="$4"

    # Check cache
    if [[ -n "${path_cache_src_rel[$path_rel]:-}" ]]; then
      _out_src_rel="${path_cache_src_rel[$path_rel]}"
      _out_src_abs="${path_cache_src_abs[$path_rel]}"
      _out_dst_rel="${path_cache_dst_rel[$path_rel]}"
      return
    fi

    # Cache miss - call resolve_paths with temp vars and store results
    local tmp_src_rel tmp_src_abs tmp_dst_rel
    resolve_paths "$path_rel" tmp_src_rel tmp_src_abs tmp_dst_rel
    path_cache_src_rel["$path_rel"]="$tmp_src_rel"
    path_cache_src_abs["$path_rel"]="$tmp_src_abs"
    path_cache_dst_rel["$path_rel"]="$tmp_dst_rel"
    _out_src_rel="$tmp_src_rel"
    _out_src_abs="$tmp_src_abs"
    _out_dst_rel="$tmp_dst_rel"
  }

  # Process each argument
  for arg in "${GEET_ARGS[@]}"; do
    debug "processing arg: $arg"

    # Find all matches for this pattern/file/folder
    local -a matches=()

    # includeif passes silently if no files match (unlike include which fails)
    # Check if file/dir exists before calling find_matches (which calls die)
    if [[ "$arg" != "-u" && "$arg" != *[\*\?\[]* ]]; then
      # Literal file or directory
      if [[ ! -e "$arg" ]]; then
        debug "file does not exist: $arg (passing silently)"
        continue
      fi
    fi

    # Try to find matches
    set +e
    find_matches "$arg" "$root" matches 2>/dev/null
    local find_rc=$?
    set -e

    if [[ $find_rc -ne 0 ]] || [[ ${#matches[@]} -eq 0 ]]; then
      debug "no files matched: $arg (passing silently)"
      continue
    fi

    debug "found ${#matches[@]} matches for: $arg"

    # Filter to only tracked AND modified files
    local -a filtered_matches=()
    filter_to_tracked_and_modified matches tracked_map modified_map filtered_matches

    debug "filtered to ${#filtered_matches[@]} tracked modified files for: $arg"

    # Pass silently if no matches (don't fail)
    if [[ ${#filtered_matches[@]} -eq 0 ]]; then
      debug "no tracked modified files matched: $arg (passing silently)"
      continue
    fi

    # Check patterns before adding files
    file_patterns=$(merge_patterns "${PREVENT_COMMIT_FILE_PATTERNS_1:-}" "${PREVENT_COMMIT_FILE_PATTERNS_2:-}" "${PREVENT_COMMIT_FILE_PATTERNS:-}")
    content_patterns=$(merge_patterns "${PREVENT_COMMIT_CONTENT_PATTERNS_1:-}" "${PREVENT_COMMIT_CONTENT_PATTERNS_2:-}" "${PREVENT_COMMIT_CONTENT_PATTERNS:-}")

    if [[ -n "$file_patterns" ]] || [[ -n "$content_patterns" ]]; then
      errors=()

      for path in "${filtered_matches[@]}"; do
        path_rel="$(rel_path "$path")"
        [[ "$path_rel" == .git/* ]] && die "attempted to commit .git"

        local src_rel src_abs dst_rel
        cached_resolve_paths "$path_rel" src_rel src_abs dst_rel
        check_file_patterns "$file_patterns" "$src_rel" "$path_rel" errors
        check_content_patterns "$content_patterns" "$src_rel" "$path_rel" errors
      done

      # If errors found, fail the includeif
      if [[ ${#errors[@]} -gt 0 ]]; then
        echo "❌ [$GEET_ALIAS includeif] Found patterns that may indicate app-specific code:" >&2
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

    # Skip writing to .geetinclude (files are already tracked)
    # This is a key difference from include()

    # Add tracking files to git
    geet_git add -- "$TEMPLATE_DIR/.geetinclude" "$TEMPLATE_DIR/.geetexclude"

    # Add each filtered file to git
    for path in "${filtered_matches[@]}"; do
      path_rel="$(rel_path "$path")"
      local src_rel src_abs dst_rel
      cached_resolve_paths "$path_rel" src_rel src_abs dst_rel

      if [[ "$src_rel" == "$dst_rel" ]]; then
        # Direct add (no template suffix transformation)
        debug "adding $dst_rel"
        if [[ -n "$DISCREET" ]]; then
          # Add to parent git info/exclude
          echo "$src_rel" >> "$TEMPLATE_DIR/parent-git-info-exclude"
        fi
        if [[ -n "$FORCE" ]]; then
          geet_git add -f -- "$dst_rel"
        else
          geet_git add -- "$dst_rel"
        fi
        # Sync to live folders
        sync_to_live_folders "$src_rel" "$dst_rel"
      else
        # Template suffix transformation (e.g., index.template.tsx -> index.tsx)
        debug "adding $src_rel as $dst_rel"
        hash=$(geet_git hash-object -w -- "$src_abs")
        geet_git update-index --add --cacheinfo 100644 "$hash" "$dst_rel"
        # Sync to live folders
        sync_to_live_folders "$src_rel" "$dst_rel"
      fi
    done
  done
}
