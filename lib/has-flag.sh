# has-flag.sh
# Usage:
#   source has-flag.sh FLAG_NAME VAR_NAME "$@"
# Effects:
#   - Sets VAR_NAME to "true" or ""
#   - Removes FLAG_NAME from the caller's positional args ($@)

flag="$1"
varname="$2"
shift 2

cleaned=()
found=""

while (( $# > 0 )); do
  if [[ "$1" == "$flag" ]]; then
    found="true"
  else
    cleaned+=("$1")
  fi
  shift
done

# Set caller variable by name (safe even if unset)
printf -v "$varname" '%s' "$found"

echo "setting" "${cleaned[@]}"
# ... build cleaned ...
GEET_ARGS=("${cleaned[@]}")

# Reset caller positional params (because this file is sourced)
set -- "${GEET_ARGS[@]}"



