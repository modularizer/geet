# extract-flag.sh
#
# Usage:
#   source extract-flag.sh FLAG_NAME VAR_NAME "$@"
#
# Example:
#   source extract-flag.sh --template-dir TEMPLATE_DIR "$@"
#
# Effects:
#   - Sets VAR_NAME to the extracted value ("" if not present)
#   - Removes FLAG_NAME and its value from "$@"
#   - If FLAG_NAME appears multiple times, all are removed; last one wins

flag="$1"
varname="$2"
shift 2

cleaned=()
value=""

while (( $# > 0 )); do
  if [[ "$1" == "$flag" ]]; then
    # If flag has a value, consume it; if it's missing, just drop the flag
    if (( $# > 1 )); then
      value="$2"
      shift 2
      continue
    else
      shift
      continue
    fi
  fi

  cleaned+=("$1")
  shift
done

# Set caller variable by name (safe even if previously unset)
printf -v "$varname" '%s' "$value"
GEET_ARGS=("${cleaned[@]}")

# Mutate caller positional params (because this file is sourced)
set -- "${GEET_ARGS[@]}"


unset flag varname cleaned value
