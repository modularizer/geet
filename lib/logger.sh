_get_min_level() {
  local min_level="INFO"

  # explicit flag wins if provided (e.g. --min-level WARN)
  if [[ -n "$MIN_LEVEL" ]]; then
    min_level="$MIN_LEVEL"
  elif [[ "$SILENT" ]]; then
    min_level="NEVER"
  elif [[ "$VERBOSE" ]]; then
    min_level="DEBUG"
  elif [[ "$QUIET" ]]; then
    min_level="ERROR"
  fi

  printf "%s" "$min_level"
}

get_specified_level() {
  # These helpers should set variables in *this* shell context.
  source "$GEET_LIB/extract-flag.sh" --min-level "MIN_LEVEL" "$@"
  source "$GEET_LIB/has-flag.sh" --verbose "VERBOSE" "$@"
  source "$GEET_LIB/has-flag.sh" --quiet "QUIET" "$@"
  source "$GEET_LIB/has-flag.sh" --silent "SILENT" "$@"

  local min_level
  min_level="$(_get_min_level)"
  printf "%s" "$min_level"
}

get_log_filter() {
  source "$GEET_LIB/extract-flag.sh" --filter "LOG_FILTER" "$@"
  printf "%s" "$LOG_FILTER"
}
_color_enabled() {
  # Enable colors only if:
  # - COLOR_MODE is light|dark
  # - and stderr is a TTY (avoid escape codes in pipes/files)
  [[ -t 2 ]] || return 1
  case "${COLOR_MODE:-}" in
    light|dark) return 0 ;;
    *) return 1 ;;
  esac
}
_color_scope() {
  case "${COLOR_SCOPE:-level}" in
    line)  printf 'line' ;;
    *)     printf 'level' ;;
  esac
}


_color_reset() { printf '\033[0m'; }

# Return an ANSI color code for a level, based on COLOR_MODE
_color_for_level() {
  local level="$1"
  case "${COLOR_MODE:-}" in
    dark)
      case "$level" in
        DEBUG)    printf '\033[90m' ;; # bright black / gray
        INFO)     printf '\033[96m' ;; # bright cyan
        WARN)     printf '\033[93m' ;; # bright yellow
        ERROR)    printf '\033[91m' ;; # bright red
        CRITICAL) printf '\033[97;41m' ;; # white on red bg
        *)        printf '\033[0m'  ;;
      esac
      ;;
    light)
      case "$level" in
        DEBUG)    printf '\033[90m' ;; # gray
        INFO)     printf '\033[34m' ;; # blue
        WARN)     printf '\033[33m' ;; # yellow/brown
        ERROR)    printf '\033[31m' ;; # red
        CRITICAL) printf '\033[1;31m' ;; # bold red
        *)        printf '\033[0m'  ;;
      esac
      ;;
    *)
      printf '' ;;
  esac
}
log_with_level() {
  # usage: log_with_level LEVEL MIN_LEVEL message...
  # levels: DEBUG INFO WARN ERROR CRITICAL NEVER
  local level="${1:-INFO}"
  shift
  local min_level_str="${1:-INFO}"
  shift

  local lvl_num
  case "$level" in
    DEBUG)    lvl_num=0 ;;
    INFO)     lvl_num=1 ;;
    WARN)     lvl_num=2 ;;
    ERROR)    lvl_num=3 ;;
    CRITICAL) lvl_num=4 ;;
    NEVER)    lvl_num=5 ;;
    *)        lvl_num=1 ;;
  esac

  local min_num
  case "$min_level_str" in
    DEBUG)    min_num=0 ;;
    INFO)     min_num=1 ;;
    WARN)     min_num=2 ;;
    ERROR)    min_num=3 ;;
    CRITICAL) min_num=4 ;;
    NEVER)    min_num=5 ;;
    *)        min_num=1 ;;
  esac

  (( lvl_num < min_num )) && return 0

  local msg="$*"

  local template_label=""
  [[ -n "$TEMPLATE_NAME" ]] && template_label="[$TEMPLATE_NAME] "

  local level_prefix=""
  [[ "$SHOW_LEVEL" == "true" ]] && level_prefix="[$level] "

  local pre=""
  [[ "${GEET_DIGESTED:-false}" != "true" ]] && pre="[PREWORK] "

  # IMPORTANT: filter against the *plain* string (no ANSI codes)
  local plain="${level_prefix}${template_label}${pre}${msg}"
  if [[ -n "${LOG_FILTER:-}" ]]; then
    if [[ "$LOG_FILTER" == \~* ]]; then
      # exclude mode: !pattern
      local pat="${LOG_FILTER:1}"
      [[ "$plain" == *"$pat"* ]] && return 0
    else
      # include mode: pattern
      [[ "$plain" != *"$LOG_FILTER"* ]] && return 0
    fi
  fi


  # Colorize only the level prefix (keeps the rest readable)
    if _color_enabled && [[ "$SHOW_LEVEL" == "true" ]]; then
      local c r scope
      c="$(_color_for_level "$level")"
      r="$(_color_reset)"
      scope="$(_color_scope)"

      case "$scope" in
        line)
          echo "${c}${plain}${r}" >&2
          ;;
        level)
          echo "${c}${level_prefix}${r}${template_label}${msg}" >&2
          ;;
      esac
    else
      echo "$plain" >&2
    fi

}



debug(){
  log_with_level "DEBUG" "$MIN_LOG_LEVEL" "$@"
}
info(){
  log_with_level "INFO" "$MIN_LOG_LEVEL" "$@"
}
log(){
  info "$@"
}
warn(){
  log_with_level "WARN" "$MIN_LOG_LEVEL" "$@"
}
critical(){
  log_with_level "CRITICAL" "$MIN_LOG_LEVEL" "$@"
}
die(){
  critical "$@"
  exit 1
}