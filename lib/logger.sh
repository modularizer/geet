_get_min_level() {
  local min_level="INFO"

  # explicit flag wins if provided (e.g. --min-level WARN)
  if [[ -n "$MIN_LOG_LEVEL" ]]; then
    min_level="$MIN_LOG_LEVEL"
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
  extract_flag --min-level MIN_LOG_LEVEL
  has_flag --verbose VERBOSE
  has_flag --quiet QUIET
  has_flag --silent SILENT

  MIN_LOG_LEVEL="$(_get_min_level)"
}

get_log_filter() {
  extract_flag --filter LOG_FILTER
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

# Feature toggles - set to true/false to enable/disable message colorization
COLORIZE_BACKTICKS=true
COLORIZE_BACKTICKS_MODE="bold"  # Options: normal|bold|highlight|italic
COLORIZE_COMMENTS=true

# Colorize message text: backticks and comments
# $1 = text to colorize
# $2 = color to restore after backticks (optional, defaults to reset)
_colorize_message() {
  local text="$1"
  local restore_color="${2:-$'\033[0m'}"

  # Define color codes
  local grey=$'\033[90m'
  local reset=$'\033[0m'

  # Set highlight codes based on mode
  local highlight unhighlight
  case "${COLORIZE_BACKTICKS_MODE}" in
    bold)
      highlight=$'\033[1m'       # Bold text
      unhighlight=$'\033[22m'    # Turn off bold
      ;;
    highlight)
      highlight=$'\033[7m'       # Reverse video
      unhighlight=$'\033[27m'    # Turn off reverse video
      ;;
    italic)
      highlight=$'\033[3m'       # Italic text
      unhighlight=$'\033[23m'    # Turn off italic
      ;;
    normal|*)
      highlight=""               # No styling
      unhighlight=""             # No styling
      ;;
  esac

  # First, handle comments: everything after # becomes grey
  # We need to handle this before backticks to avoid conflicts
  if [[ "$COLORIZE_COMMENTS" == true ]] && [[ "$text" =~ (#.*)$ ]]; then
    local before="${text%#*}"
    local comment="${BASH_REMATCH[1]}"
    text="${before}${grey}${comment}${reset}"
  fi

  # Then handle backticks: replace `text` with highlight (reverse video)
  # Remove the backticks themselves, just colorize the content
  local result=""
  local remainder="$text"
  local in_backtick=false

  if [[ "$COLORIZE_BACKTICKS" == true ]]; then
    while [[ -n "$remainder" ]]; do
      if [[ "$remainder" =~ ^([^\`]*)\`(.*)$ ]]; then
        # Found a backtick
        result="${result}${BASH_REMATCH[1]}"
        remainder="${BASH_REMATCH[2]}"

        if [[ "$in_backtick" == false ]]; then
          # Start backtick - don't include the ` character, just add highlight
          result="${result}${highlight}"
          in_backtick=true
        else
          # End backtick - don't include the ` character, turn off reverse video
          result="${result}${unhighlight}"
          in_backtick=false
        fi
      else
        # No more backticks
        result="${result}${remainder}"
        break
      fi
    done

    # Close any unclosed backtick
    if [[ "$in_backtick" == true ]]; then
      result="${result}${unhighlight}"
    fi
  else
    # Backtick colorization disabled - just use text as-is
    result="$remainder"
  fi

  printf "%s" "$result"
}

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
        # For line scope, colorize the entire line including level
        # Pass line color so backticks restore to it
        local colored_plain
        colored_plain="$(_colorize_message "$plain" "$c")"
        echo "${c}${colored_plain}${r}" >&2
        ;;
      level)
        # For level scope, colorize level prefix and message separately
        # Message isn't colored by level, so backticks restore to default
        local colored_msg
        colored_msg="$(_colorize_message "${template_label}${pre}${msg}")"
        echo "${c}${level_prefix}${r}${colored_msg}" >&2
        ;;
    esac
  else
    # No level coloring, but still apply message coloring if enabled
    if _color_enabled; then
      local colored_full
      colored_full="$(_colorize_message "$plain")"
      echo "$colored_full" >&2
    else
      echo "$plain" >&2
    fi
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