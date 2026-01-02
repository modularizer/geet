# has-flag.sh

has_flag() {
  local flag="$1"
  local outvar="$2"

  local -a cleaned=()
  local found=""

  for arg in "${GEET_ARGS[@]}"; do
    if [[ $arg == "$flag" ]]; then
      found="true"
    else
      cleaned+=("$arg")
    fi
  done

  GEET_ARGS=("${cleaned[@]}")
  local -n out="$outvar"
  out="$found"
}

extract_flag() {
  local flag="$1"
  local outvar="$2"

  local -a cleaned=()
  local value=""
  local i=0

  while (( i < ${#GEET_ARGS[@]} )); do
    local arg="${GEET_ARGS[i]}"

    if [[ $arg == "$flag" ]]; then
      # consume optional value
      if (( i+1 < ${#GEET_ARGS[@]} )); then
        value="${GEET_ARGS[i+1]}"
        i=$((i+2))
      else
        i=$((i+1))
      fi
      continue
    fi

    cleaned+=("$arg")
    i=$((i+1))
  done

  GEET_ARGS=("${cleaned[@]}")
  local -n out="$outvar"
  out="$value"
}
