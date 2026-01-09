# Strip ./ prefix from a path
strip_dot_slash() {
  local path="$1"
  # Remove ./ prefix, handling multiple occurrences
  while [[ "$path" == "./"* ]]; do
    path="${path#./}"
  done
  echo "$path"
}

# Alphabetize .geetinclude file and fix ./ prefixes
alphabetize_include() {
  local include_file="$TEMPLATE_DIR/.geetinclude"
  [[ -f "$include_file" ]] || return 0

  local temp_file=$(mktemp)
  local temp_sorted=$(mktemp)
  local temp_cleaned=$(mktemp)

  # Separate header comments from entries
  local in_header=1
  local header=""
  local entries=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Check if line is empty or a comment
    local trimmed="${line#"${line%%[![:space:]]*}"}"
    if [[ -z "$trimmed" ]] || [[ "$trimmed" == \#* ]]; then
      if [[ $in_header -eq 1 ]]; then
        header+="$line"$'\n'
      else
        # Comment after entries - treat as entry to preserve context
        entries+="$line"$'\n'
      fi
    else
      in_header=0
      # Fix ./ prefixes in the line
      if [[ "$line" == *" => "* ]]; then
        # Mapping format: local => remote
        local local_part="${line%% => *}"
        local remote_part="${line##* => }"

        # Strip leading/trailing whitespace and ./ prefix
        local_part="${local_part#"${local_part%%[![:space:]]*}"}"
        local_part="${local_part%"${local_part##*[![:space:]]}"}"
        local_part="$(strip_dot_slash "$local_part")"

        remote_part="${remote_part#"${remote_part%%[![:space:]]*}"}"
        remote_part="${remote_part%"${remote_part##*[![:space:]]}"}"
        remote_part="$(strip_dot_slash "$remote_part")"

        # Reconstruct the mapping
        if [[ "$local_part" == "$remote_part" ]]; then
          # If they're the same after cleanup, use simple format
          entries+="$local_part"$'\n'
        else
          entries+="$local_part => $remote_part"$'\n'
        fi
      else
        # Simple path format
        local clean_line="$(strip_dot_slash "$trimmed")"
        entries+="$clean_line"$'\n'
      fi
    fi
  done < "$include_file"

  # Sort entries (stable sort, case-insensitive)
  if [[ -n "$entries" ]]; then
    printf "%s" "$entries" | sort -f > "$temp_sorted"
  else
    : > "$temp_sorted"
  fi

  # Write back: header + sorted entries
  {
    [[ -n "$header" ]] && printf "%s" "$header"
    cat "$temp_sorted"
  } > "$temp_file"

  # Replace original file
  mv "$temp_file" "$include_file"
  rm -f "$temp_sorted" "$temp_cleaned"
}

sync() {
  debug "running sync"
  # Show help if requested
  if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
$GEET_ALIAS sync — compile .geetinclude whitelist into .geetexclude

This command processes your .geetinclude file (whitelist) and compiles it
into .geetexclude (gitignore-style format) between special markers.

What it does:
  1. Fixes ./ prefixes in all paths (e.g., ./app.json → app.json)
  2. Alphabetizes .geetinclude entries (preserving header comments)
  3. Reads each line from .geetinclude
  4. Converts whitelist patterns to gitignore format:
     - 'foo' → '!foo' (include this)
     - '!foo' → 'foo' (exclude this - removes the !)
     - '!!foo' → '!foo' (literal ! prefix)
  5. Inserts compiled rules between GEETINCLUDESTART and GEETINCLUDEEND markers
  6. Preserves manual rules before/after the markers

Usage:
  $GEET_ALIAS sync

When to run:
  - After editing .geetinclude
  - Before running git commands on the template
  - Note: Most geet commands auto-sync, so manual sync is rarely needed

File locations:
  Source:   $TEMPLATE_DIR/.geetinclude
  Output:   $TEMPLATE_DIR/.geetexclude

Examples:
  $GEET_ALIAS sync  # Compile whitelist rules
EOF
    return 0
  fi

  [[ -f "$TEMPLATE_DIR/.geetinclude" ]] || return 0

  # Alphabetize .geetinclude before processing
  alphabetize_include

  # Load mapping parser
  source "$GEET_LIB/mapping.sh"

  # Markers for the auto-populated section
  local START_MARKER="# GEETINCLUDESTART"
  local END_MARKER="# GEETINCLUDEEND"

  # Generate compiled rules
  local compiled_rules=""
  # WHITELIST MODE: Process .geetinclude
  # Only write REMOTE paths to .geetexclude (what's tracked in the template repo)
  local local_path remote_path
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Parse the mapping
    if parse_mapping_line "$line" local_path remote_path; then
      # Use remote_path (what the repo tracks) for .geetexclude
      if [[ "$remote_path" == "!!"* ]]; then
        compiled_rules+="!${remote_path#!!}"$'\n'
      elif [[ "$remote_path" == "!"* ]]; then
        compiled_rules+="${remote_path#!}"$'\n'
      else
        compiled_rules+="!$remote_path"$'\n'
      fi
    fi
  done < "$TEMPLATE_DIR/.geetinclude"

  # Read existing .geetexclude or create default structure
  local before_marker=""
  local after_marker=""

  if [[ -f "$TEMPLATE_DIR/.geetexclude" ]]; then
    # File exists - extract parts before and after markers
    local in_marker=0
    while IFS= read -r line; do
      if [[ "$line" == "$START_MARKER" ]]; then
        in_marker=1
        continue
      elif [[ "$line" == "$END_MARKER" ]]; then
        in_marker=2
        continue
      fi

      if [[ $in_marker -eq 0 ]]; then
        before_marker+="$line"$'\n'
      elif [[ $in_marker -eq 2 ]]; then
        after_marker+="$line"$'\n'
      fi
    done < "$TEMPLATE_DIR/.geetexclude"
  else
    die "$TEMPLATE_DIR/.geetexclude not found"
  fi

  # Write new .geetexclude with compiled rules between markers
  {
    printf "%s" "$before_marker"
    echo "$START_MARKER"
    echo "# Autopopulated from .geetinclude, do not modify"
    printf "%s" "$compiled_rules"
    echo "$END_MARKER"
    printf "%s" "$after_marker"
  } > "$TEMPLATE_DIR/.geetexclude"
}