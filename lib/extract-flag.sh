# extract-flag.sh
#
# Usage:
#   source extract-flag.sh FLAG_NAME VAR_NAME "$@"
#
# Example:
#   source extract-flag.sh --template-dir TEMPLATE_DIR "$@"
#
# Effects:
#   - Sets $TEMPLATE_DIR to the extracted value (empty if not present)
#   - Removes --template-dir and its value from "$@"
#   - Mutates caller's positional parameters
#   - if FLAG_NAME is specified multiple times in "$@" then all get removed, and the last one wins, gets set to VAR_NAME

extract_flag() {
  local flag="$1"
  local -n out_var="$2"
  shift 2

  local cleaned=()
  local value=""

  while [ "$#" -gt 0 ]; do
    if [ "$1" = "$flag" ] && [ "$#" -gt 1 ]; then
      value="$2"
      shift 2
    else
      cleaned+=("$1")
      shift
    fi
  done

  out_var="$value"
  set -- "${cleaned[@]}"
}

extract_flag "$@"

