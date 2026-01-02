# has-flag.sh
#
# Usage:
#   source has-flag.sh FLAG_NAME VAR_NAME "$@"
#
# Example:
#   source has-flag.sh --template-dir TEMPLATE_DIR "$@"
#
# Effects:
#   - Sets $TEMPLATE_DIR to the hased value (empty if not present)
#   - Removes --template-dir and its value from "$@"
#   - Mutates caller's positional parameters
#   - if FLAG_NAME is specified multiple times in "$@" then all get removed, and the last one wins, gets set to VAR_NAME

has_flag() {
  local flag="$1"
  local -n out_var="$2"
  shift 2

  local cleaned=()
  local value=""

  while [ "$#" -gt 0 ]; do
    if [ "$1" = "$flag" ] && [ "$#" -gt 1 ]; then
      value="true"
    else
      cleaned+=("$1")
      shift
    fi
  done

  out_var="$value"
  set -- "${cleaned[@]}"
}

has_flag "$@"

