# mapping.sh — .geetinclude mapping parser
# Usage:
#   source mapping.sh
#   parse_mapping_line "local => remote" local_var remote_var
#   get_local_from_remote "remote/path" local_var
#   get_remote_from_local "local/path" remote_var
#
# Handles the .geetinclude format:
#   local => remote    # explicit mapping
#   path               # implicit mapping (auto-resolved using resolve_paths)

# Helper: resolve local/remote paths using TEMPLATE_FILE_SUFFIX logic
# This is used for backwards compatibility with old .geetinclude format
resolve_mapping_from_path() {
  local path_rel="$1"
  local -n _local_result="$2"
  local -n _remote_result="$3"

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
  if [[ "$name_without_ext" == *"${TEMPLATE_FILE_SUFFIX:-".template"}" ]]; then
    stem="${name_without_ext%"${TEMPLATE_FILE_SUFFIX:-".template"}"}"
    suffix="${TEMPLATE_FILE_SUFFIX:-".template"}"
  elif [[ "$name_without_ext" == *"${TEMPLATE_FILE_SUFFIX_2:-"-template"}" ]]; then
    stem="${name_without_ext%"${TEMPLATE_FILE_SUFFIX_2:-"-template"}"}"
    suffix="${TEMPLATE_FILE_SUFFIX_2:-"-template"}"
  else
    stem="$name_without_ext"
    suffix=""
  fi

  # remote is always clean name (what's tracked in repo)
  if [[ -n "$path_dir" ]]; then
    _remote_result="$path_dir/${stem}${ext}"
  else
    _remote_result="${stem}${ext}"
  fi

  # local is first existing file in priority order
  local template1="${path_dir:+$path_dir/}${stem}${TEMPLATE_FILE_SUFFIX:-".template"}${ext}"
  local template2="${path_dir:+$path_dir/}${stem}${TEMPLATE_FILE_SUFFIX_2:-"-template"}${ext}"

  local src_base
  if [[ -n "$suffix" ]]; then
    # Path already has suffix
    src_base="${stem}${suffix}${ext}"
  elif [[ -e "$template1" ]]; then
    src_base="${stem}${TEMPLATE_FILE_SUFFIX:-".template"}${ext}"
  elif [[ -e "$template2" ]]; then
    src_base="${stem}${TEMPLATE_FILE_SUFFIX_2:-"-template"}${ext}"
  else
    # No template variant exists, local == remote
    src_base="${stem}${ext}"
  fi

  if [[ -n "$path_dir" ]]; then
    _local_result="$path_dir/$src_base"
  else
    _local_result="$src_base"
  fi
}

# Parse a single line from .geetinclude into local and remote parts
# Returns 0 if valid mapping, 1 if comment/empty
# Backwards compatible: resolves old format using TEMPLATE_FILE_SUFFIX logic
parse_mapping_line() {
  local line="$1"
  local -n _local="$2"
  local -n _remote="$3"

  # Trim whitespace
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  # Skip empty lines and comments
  [[ -z "$line" ]] && return 1
  [[ "$line" == \#* ]] && return 1

  # Check for mapping syntax: local => remote
  if [[ "$line" == *" => "* ]]; then
    _local="${line%% => *}"
    _remote="${line##* => }"

    # Trim whitespace from both parts
    _local="${_local#"${_local%%[![:space:]]*}"}"
    _local="${_local%"${_local##*[![:space:]]}"}"
    _remote="${_remote#"${_remote%%[![:space:]]*}"}"
    _remote="${_remote%"${_remote##*[![:space:]]}"}"
  else
    # Old format - auto-resolve using TEMPLATE_FILE_SUFFIX logic
    resolve_mapping_from_path "$line" _local _remote
#    debug "auto-resolved mapping: $line -> $_local => $_remote"
  fi

  return 0
}

# Load all mappings from .geetinclude into associative arrays
# Usage: load_mappings local_to_remote_array remote_to_local_array
load_mappings() {
  local -n _local_to_remote="$1"
  local -n _remote_to_local="$2"

  [[ -f "$TEMPLATE_DIR/.geetinclude" ]] || return 0

  local local_path remote_path
  while IFS= read -r line || [[ -n "$line" ]]; do
    if parse_mapping_line "$line" local_path remote_path; then
      _local_to_remote["$local_path"]="$remote_path"
      _remote_to_local["$remote_path"]="$local_path"
      debug "mapping: $local_path => $remote_path"
    fi
  done < "$TEMPLATE_DIR/.geetinclude"
}

# Get local path for a remote path
# Usage: get_local_from_remote "remote/path" result_var
# Returns 0 if mapping found, 1 otherwise
get_local_from_remote() {
  local remote_path="$1"
  local -n _result="$2"

  declare -A dummy_local_to_remote
  declare -A remote_to_local
  load_mappings dummy_local_to_remote remote_to_local

  if [[ -n "${remote_to_local[$remote_path]:-}" ]]; then
    _result="${remote_to_local[$remote_path]}"
    return 0
  fi

  # No explicit mapping - assume local == remote
  _result="$remote_path"
  return 1
}

# Get remote path for a local path
# Usage: get_remote_from_local "local/path" result_var
# Returns 0 if mapping found, 1 otherwise
get_remote_from_local() {
  local local_path="$1"
  local -n _result="$2"

  declare -A local_to_remote
  declare -A dummy_remote_to_local
  load_mappings local_to_remote dummy_remote_to_local

  if [[ -n "${local_to_remote[$local_path]:-}" ]]; then
    _result="${local_to_remote[$local_path]}"
    return 0
  fi

  # No explicit mapping - assume local == remote
  _result="$local_path"
  return 1
}

# Iterator function - call a function for each mapping
# Usage: for_each_mapping callback_function
# Callback receives: local_path remote_path
for_each_mapping() {
  local callback="$1"

  [[ -f "$TEMPLATE_DIR/.geetinclude" ]] || return 0

  local local_path remote_path
  while IFS= read -r line || [[ -n "$line" ]]; do
    if parse_mapping_line "$line" local_path remote_path; then
      "$callback" "$local_path" "$remote_path"
    fi
  done < "$TEMPLATE_DIR/.geetinclude"
}
