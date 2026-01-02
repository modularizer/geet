#!/usr/bin/env bash
# prework.sh - Inspect geet prework variables and config values

prework() {
  local key="${1:-all}"

  # Special case: print all variables
  if [[ "$key" == "all" ]]; then
    debug "Printing all geet prework variables"

    # Color codes
    local key_color=""
    local equals_color=""
    local value_color=""
    local unset_color=""
    local comment_color=""
    local reset=""

    # Check if colors are enabled (TTY + COLOR_MODE set)
    local header_color=""
    if [[ -t 1 ]] && [[ -n "${COLOR_MODE:-}" ]] && [[ "$COLOR_MODE" != "none" ]]; then
      case "${COLOR_MODE}" in
        light)
          key_color='\033[1;34m'    # bold blue
          equals_color='\033[90m'   # gray
          value_color='\033[32m'    # green
          unset_color='\033[90m'    # gray
          comment_color='\033[90m'  # gray
          header_color='\033[1;35m' # bold magenta
          ;;
        dark)
          key_color='\033[1;96m'    # bold bright cyan
          equals_color='\033[90m'   # bright black/gray
          value_color='\033[92m'    # bright green
          unset_color='\033[90m'    # bright black/gray
          comment_color='\033[90m'  # bright black/gray
          header_color='\033[1;95m' # bold bright magenta
          ;;
      esac
      reset='\033[0m'
    fi

    # Helper to print a variable with description
    print_var() {
      local var="$1"
      local desc="$2"
      local value=""
      local value_len padding spaces

      if [[ -n "${!var:-}" ]]; then
        value="${!var}"
        value_len=${#value}

        # Comment should start 30 chars after the = sign
        # If value is <= 28 chars, pad to align comment at position 30
        # If value is > 28 chars, just add 2 spaces
        A=20;
        X=37;
        if (( value_len <= X )); then
          padding=$((X + 2 - value_len))
          spaces=$(printf '%*s' "$padding" '')
          printf "${key_color}%-${A}s${reset}${equals_color}=${reset} ${value_color}%s${reset}${spaces}${comment_color}# %s${reset}\n" "$var" "$value" "$desc"
        else
          printf "${key_color}%-${A}s${reset}${equals_color}=${reset} ${value_color}%s${reset}  ${comment_color}# %s${reset}\n" "$var" "$value" "$desc"
        fi
      else
        # <unset> is 7 chars, so pad to 30
        padding=$((X + 2 - 7))
        spaces=$(printf '%*s' "$padding" '')
        printf "${key_color}%-${A}s${reset}${equals_color}=${reset} ${unset_color}<unset>${reset}${spaces}${comment_color}# %s${reset}\n" "$var" "$desc"
      fi
    }

    # Helper to print section header
    print_header() {
      local title="$1"
      local total=51
      local left=10

      local right=$(( total - left - ${#title} - 2 ))
      (( right < 0 )) && right=0

      printf -v lpad '%*s' "$left"  ''
      printf -v rpad '%*s' "$right" ''

      lpad=${lpad// /==}
      rpad=${rpad// /=}

      printf "\n${header_color}%s %s %s${reset}\n" "$lpad" "$title" "$rpad"
    }



    # Geet Installation
    print_header "GEET INSTALLATION"
    print_var GEET_LIB "Path to geet lib directory"
    print_var GEET_CMD "Path to geet.sh entrypoint"

    # Template Directory
    print_header "TEMPLATE DIRECTORY"
    print_var TEMPLATE_DIR "Template directory (e.g., .mytemplate)"
    print_var DOTGIT "Template's git directory (dot-git)"
    print_var GEET_GIT "Path to geet-git.sh wrapper"
    print_var SOFT_DETACHED "Soft-detached files list"
    print_var TEMPLATE_NAME "Template name"
    print_var TEMPLATE_DESC "Template description"
    print_var TEMPLATE_GH_USER "Template owner's GitHub username"
    print_var TEMPLATE_GH_NAME "GitHub repository name"
    print_var TEMPLATE_GH_URL "GitHub repository URL"
    print_var TEMPLATE_GH_SSH "SSH remote URL"
    print_var TEMPLATE_GH_HTTPS "HTTPS remote URL"

    # App Directory
    print_header "APP DIRECTORY"
    print_var APP_DIR "Your app's root directory"
    print_var APP_NAME "Name of your app"

    # Config values
    print_header "CONFIG VALUES (from .env files)"
    print_var GEET_ALIAS "Command alias (usually 'geet')"
    print_var DD_APP_NAME "App name used in docs"
    print_var DD_TEMPLATE_NAME "Template name used in docs"

    # Detected user info
    print_header "DETECTED USER INFO"
    print_var GH_USER "Your GitHub username (from gh CLI or git config)"

    # Logging & filter
    print_header "LOGGING & FILTER (from logger.sh)"
    print_var MIN_LOG_LEVEL "Current minimum log level"
    print_var LOG_FILTER "Active log filter pattern (~ to exclude)"
    print_var VERBOSE "Set if --verbose flag present"
    print_var QUIET "Set if --quiet flag present"
    print_var SILENT "Set if --silent flag present"
    print_var MIN_LEVEL "Set if --min-level flag present"

    # Flags & guards
    print_header "FLAGS & GUARDS"
    print_var BRAVE "Set if --brave flag present (allows dangerous ops)"
    print_var GEET_DIGESTED "Set to 'true' after prework completes"

    # Timing
    print_header "TIMING"
    print_var PREWORK_START_TIME "Prework start time (nanoseconds)"
    print_var PREWORK_END_TIME "Prework end time (nanoseconds)"
    print_var PREWORK_ELAPSED_NS "Prework elapsed time (nanoseconds)"
    print_var PREWORK_ELAPSED_MS "Prework elapsed time (milliseconds)"

    # Global user preferences
    print_header "GLOBAL PREFERENCES (from config.env)"
    print_var SHOW_LEVEL "Show log level in output (true/false)"
    print_var COLOR_MODE "Color scheme (light/dark/none)"
    print_var COLOR_SCOPE "Color scope (line/level)"

    # Hard-coded constants
    print_header "HARD-CODED CONSTANTS"
    print_var PATH_TO "Placeholder for docs (/path/to)"
    print_var DEFAULT_GEET_ALIAS "Default command alias"
    print_var DEFAULT_GH_USER "Default GitHub user placeholder"
    print_var DDD_APP_NAME "Default app name for docs"
    print_var DDD_TEMPLATE_NAME "Default template name for docs"

    printf "\n"
    return 0
  fi

  debug "Checking for key: $key"

  # List of all variables set by digest-and-locate.sh
  # We'll check if the variable is set in the environment first
  local value=""

  # Try to get the value from environment variable
  if [[ -n "${!key:-}" ]]; then
    value="${!key}"
    debug "Found $key in environment: $value"
    printf '%s\n' "$value"
    return 0
  fi

  # Not found
  debug "$key not found in environment"
  printf '<unset>\n'
  return 0
}
