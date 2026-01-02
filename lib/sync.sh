sync() {
  echo "SYNC"
  # Show help if requested
  if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
$GEET_ALIAS sync — compile .geetinclude whitelist into .geetexclude

This command processes your .geetinclude file (whitelist) and compiles it
into .geetexclude (gitignore-style format) between special markers.

What it does:
  1. Reads each line from .geetinclude
  2. Converts whitelist patterns to gitignore format:
     - 'foo' → '!foo' (include this)
     - '!foo' → 'foo' (exclude this - removes the !)
     - '!!foo' → '!foo' (literal ! prefix)
  3. Inserts compiled rules between GEETINCLUDESTART and GEETINCLUDEEND markers
  4. Preserves manual rules before/after the markers

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

  # Markers for the auto-populated section
  local START_MARKER="# GEETINCLUDESTART"
  local END_MARKER="# GEETINCLUDEEND"

  # Generate compiled rules
  local compiled_rules=""
  # WHITELIST MODE: Process .geetinclude
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue

    if [[ "$line" == "!!"* ]]; then
      compiled_rules+="!${line#!!}"$'\n'
    elif [[ "$line" == "!"* ]]; then
      compiled_rules+="${line#!}"$'\n'
    else
      compiled_rules+="!$line"$'\n'
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