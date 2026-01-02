sync() {
  [[ -n "$TEMPLATE_GEETINCLUDE" ]] || return 0

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
  done < "$TEMPLATE_GEETINCLUDE"

  # Read existing .geetexclude or create default structure
  local before_marker=""
  local after_marker=""

  if [[ -f "$TEMPLATE_GEETEXCLUDE" ]]; then
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
    done < "$TEMPLATE_GEETEXCLUDE"
  else
    die "$TEMPLATE_GEETEXCLUDE not found"
  fi

  # Write new .geetexclude with compiled rules between markers
  {
    printf "%s" "$before_marker"
    echo "$START_MARKER"
    echo "# Autopopulated from .geetinclude, do not modify"
    printf "%s" "$compiled_rules"
    echo "$END_MARKER"
    printf "%s" "$after_marker"
  } > "$EXCLUDE_FILE"
}