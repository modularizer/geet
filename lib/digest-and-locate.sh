# digest-and-locate.sh
# Usage:
#   source digest-and-locate.sh "$@"
# Voila! you now have
# 1. cleaned your args, digesting and removing --geet-dir, moving the value arg to $GEET_TEMPLATE_DIR
# 2. you have access to the following:
#
# === PATHS & DIRECTORIES ===
#   $GEET_LIB                         # e.g. node_modules/geet/lib
#   $GEET_CMD                         # e.g. node_modules/geet/bin/geet.sh
#   $APP_DIR                          # e.g. MyApp/
#   $APP_NAME                         # e.g. "MyApp"
#   $TEMPLATE_DIR                     # e.g. MyApp/.mytemplate
#   $DOTGIT                           # e.g. MyApp/.mytemplate/dot-git
#   $GEET_GIT                         # e.g. MyApp/.mytemplate/geet-git.sh
#   $SOFT_DETACHED          # e.g. MyApp/.mytemplate/dot-git/info/geet-protected
#   $TEMPLATE_JSON                    # e.g. MyApp/.mytemplate/config.json
#
# === CONFIG VALUES (from config.json) ===
#   $TEMPLATE_NAME                    # e.g. "mytemplate" from config.json["name"]
#   $TEMPLATE_DESC                    # e.g. "A cool react native base project example" from config.json["desc"]
#   $GEET_ALIAS                       # e.g. "mytemplate" from config.json["geetAlias"], defaults to "geet"
#   $TEMPLATE_GH_USER                 # e.g. <repo-owner>, the template owner's github username
#   $TEMPLATE_GH_NAME                 # e.g. "mytemplate", the project name on github
#   $TEMPLATE_GH_URL                  # e.g. https://github.com/<repo-owner>/mytemplate
#   $TEMPLATE_GH_SSH           # e.g. git@github.com:<repo-owner>/mytemplate.git
#   $TEMPLATE_GH_HTTPS         # e.g. https://github.com/<repo-owner>/mytemplate.git
#   $DD_APP_NAME                # e.g. "MyApp" from config.json["demoDocAppName"]
#   $DD_TEMPLATE_NAME           # e.g. "mytemplate" from config.json["demoDocTemplateName"]
#
# === DETECTED USER INFO ===
#   $GH_USER                          # Detected GitHub username (from gh CLI or git config)
#
# === LOGGING & FILTER (from logger.sh) ===
#   $MIN_LOG_LEVEL                    # e.g. "DEBUG", "INFO", "WARN", "ERROR", "CRITICAL", "NEVER"
#   $LOG_FILTER                       # Filter pattern for log messages (use ~ prefix to invert/exclude)
#   $VERBOSE                          # Set if --verbose flag present
#   $QUIET                            # Set if --quiet flag present
#   $SILENT                           # Set if --silent flag present
#   $MIN_LEVEL                        # Set if --min-level flag present
#
# === FLAGS & GUARDS ===
#   $BRAVE                            # Set if --brave flag present (allows dangerous operations)
#   $GEET_DIGESTED                    # Set to "true" after digest completes (prevents re-digestion)
#
# === TIMING ===
#   $PREWORK_START_TIME               # Prework start time (nanoseconds since epoch)
#   $PREWORK_END_TIME                 # Prework end time (nanoseconds since epoch)
#   $PREWORK_ELAPSED_NS               # Prework elapsed time (nanoseconds)
#   $PREWORK_ELAPSED_MS               # Prework elapsed time (milliseconds)
#
# === HARD-CODED SETTINGS ===
#   $SHOW_LEVEL                       # "true" - show log level in output
#   $COLOR_MODE                       # "light" - color scheme (light|dark|none)
#   $COLOR_SCOPE                      # "line" - color scope (line|level)
#   $CONFIG_NAME                      # "config.json" - config filename
#   $PATH_TO                          # "/path/to" - placeholder for docs
#   $DEFAULT_GEET_ALIAS               # "geet" - default alias
#   $DEFAULT_GH_USER                  # "<repo-owner>" - default placeholder
#   $DDD_APP_NAME        # "MyApp" - default app name for docs
#   $DDD_TEMPLATE_NAME   # "mytemplate" - default template name for docs
#
# === FUNCTIONS ===
#   read_config                       # read_config KEY [DEFAULT] - extract values from config.json
#   geet_git                          # geet_git [args...] - wrapper for geet-git.sh
#   detect_template_dir_from_cwd      # auto-detect template directory from current working directory
#   find_git_root                     # find git root directory (searches upward for .git)
#   log_if_brave                      # log_if_brave MESSAGE - log only if $BRAVE is set
#   brave_guard                       # brave_guard CMD [REASON] - exit unless --brave flag present
#
# === LOGGING FUNCTIONS (from logger.sh) ===
#   debug                             # debug MESSAGE - log at DEBUG level
#   info                              # info MESSAGE - log at INFO level
#   log                               # log MESSAGE - alias for info
#   warn                              # warn MESSAGE - log at WARN level
#   critical                          # critical MESSAGE - log at CRITICAL level
#   die                               # die MESSAGE - log at CRITICAL and exit 1

# Hard-coded config
SHOW_LEVEL="true"
COLOR_MODE="light" # light|dark|none/empty
COLOR_SCOPE="line" # line|level|empty
CONFIG_NAME="config.json"
PATH_TO="/path/to" # could be configurable in the future, used in comments

# hard-coded defaults which get overwritten
DEFAULT_GEET_ALIAS="geet"
DEFAULT_GH_USER="<repo-owner>"
DDD_APP_NAME="MyApp"
DDD_TEMPLATE_NAME="mytemplate"

# Directory this script lives in (.geet/lib)
GEET_LIB="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$GEET_LIB/logger.sh"
MIN_LOG_LEVEL="$(get_specified_level "$@")"
LOG_FILTER="$(get_log_filter "$@")"

TEMPLATE_NAME=""
debug "VERBOSE MODE ENABLED"

source "$GEET_LIB/has-flag.sh" --brave "BRAVE" "$@"
debug "BRAVE='$BRAVE'"
log_if_brave() {
  if [[ -n "${BRAVE:-}" ]]; then
    log "$*"
  fi
  return 0
}


brave_guard() {
  local cmd=${1-"an unknown command"}
  if [[ "$BRAVE" ]]; then
    log "passed brave_guard for $cmd"
    return 0
  else
    local reason=${2:-"Please review the docs to find out why."}
    die "WHOOPS! This action ($cmd) could be dangerous. $reason If you still wish to proceed, re-run with your command with --brave"
  fi
}


if [[ "${GEET_DIGESTED:-false}" == "true" ]]; then
  debug "already digested"
  return 0
fi

# Start timing prework
PREWORK_START_TIME=$(date +%s%N)
debug "digesting input"


detect_template_dir_from_cwd() {
  # We are trying to "find" the template repo from the current directory
  # unlike standard git repos, where .git lives at the base of the working tree, in geet templates it works differently
  #
  # We could have a working tree like this and we might have our cwd at MyApp/ (most common) OR ANYWHERE under MyApp/
  # The goal is to return the /path/to/.template-b or return empty if we are unable to identify a template dir at any level
  # there could be 0 to many template dirs, we do not know, only look for the best dir (most .geethier lines) in each level, stop at the closest level with a candidate
  #
  # MyApp/
  #   .git/  <- the app's git repo, NOT what we are looking for, and not guaranteed to exist at all
  #   .<some-random-hidden-folder>
  #     a.txt <- but it does not contain .geethier, so it is not a template dir candidate
  #   .template-a/
  #     .geethier <- 1 line long
  #   .template-b/
  #     .geethier <- 2 lines long
  #   src/
  #   app/
  #   dist/

  local dir="$PWD"
  locate(){
    debug "LOCATE: " "$@"
  }

    while :; do
      locate "checking $dir for template folders..."
      local best_dir=""
      local best_lines=-1

      # look at hidden dirs in this level
      for d in "$dir"/.*; do
        [[ -d "$d" ]] || continue
        [[ "$(basename "$d")" == ".git" ]] && continue
        locate "checking if $d has a .geethier"

        local hier="$d/.geethier"
        [[ -f "$hier" ]] || continue

        local lines
        lines="$(wc -l < "$hier" 2>/dev/null || echo 0)"

        if (( lines > 0)); then
          locate "candidate found at $d with $lines lines"
        fi

        if (( lines > best_lines )); then
          locate "candidate at $d is the best so far"
          best_lines="$lines"
          best_dir="$d"
        fi
      done

      # found a candidate → stop
      if [[ -n "$best_dir" ]]; then
        locate "stopping the search since we found atleast one candidate at this level"
        printf '%s' "$best_dir"
        return 0
      fi

      # early exit: this is a git repo root, but no template here
      if [[ -d "$dir/.git" ]]; then
        locate "found .git at $dir but no template dir — stopping search"
        break
      fi

      # reached filesystem root → stop
      if [[ "$dir" == "/" ]]; then
        locate "We walked all the way up to root without finding a template repo"
        break
      fi

      # walk up
      dir="$(dirname "$dir")"
    done

    # nothing found
    printf '%s' ""
}

# Path to the geet wrapper command (in our package)
GEET_CMD="$GEET_LIB/../bin/geet.sh"
debug "GEET_CMD=$GEET_CMD"


# Extract --geet-dir <value> from args (mutates caller positional params)
source "$GEET_LIB/extract-flag.sh" --geet-dir TEMPLATE_DIR "$@"
if [[ -z "$TEMPLATE_DIR" ]]; then
  debug "no --geet-dir received, trying to autodetect"
  TEMPLATE_DIR="$(detect_template_dir_from_cwd)"
else
  debug "received --geet-dir of $TEMPLATE_DIR"
  if [[ ! -f "$TEMPLATE_DIR/.geethier" ]]; then
    die "$TEMPLATE_DIR does not contain .geethier"
    return 1
  fi
fi
if [[ -z "$TEMPLATE_DIR" ]]; then
  debug "unable to locate the geet template directory, try specifying --geet-dir. if you are running certain commands (like geet help, geet template, etc) this is fine..."
fi
#if [[ -z "$TEMPLATE_DIR" ]]; then
#  die "unable to locate the geet template directory, try specifying --geet-dir"
#  return 1
#fi
debug "TEMPLATE_DIR=$TEMPLATE_DIR"

# Helper to find git root directory
find_git_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  printf '%s' ""
}

# Set template-dependent paths (only if TEMPLATE_DIR exists)
if [[ -n "$TEMPLATE_DIR" ]]; then
  DOTGIT="$TEMPLATE_DIR/dot-git"
  GEET_GIT="$TEMPLATE_DIR/geet-git.sh"
  SOFT_DETACHED="$DOTGIT/info/geet-protected"
  TEMPLATE_JSON="$TEMPLATE_DIR/$CONFIG_NAME"
  APP_DIR="$(cd "$(dirname -- "$TEMPLATE_DIR")" && pwd -P)"
  APP_NAME="$(basename -- "$APP_DIR")"

  if [[ -f "$TEMPLATE_JSON" ]]; then
    debug "found config at $TEMPLATE_JSON"
  else
    warn "no config found at $TEMPLATE_JSON"
  fi
  debug "APP_DIR=$APP_DIR"
else
  DOTGIT=""
  GEET_GIT=""
  SOFT_DETACHED=""
  TEMPLATE_JSON=""

  # Even without a template dir, try to detect APP_DIR from git root
  GIT_ROOT="$(find_git_root)"
  if [[ -n "$GIT_ROOT" ]]; then
    APP_DIR="$GIT_ROOT"
    APP_NAME="$(basename -- "$APP_DIR")"
    debug "no template dir found, but detected APP_DIR from git root: $APP_DIR"
  else
    APP_DIR=""
    APP_NAME=""
    debug "no template dir and no git root found"
  fi
fi

geet_git () {
  if [[ -z "$GEET_GIT" ]]; then
    die "geet_git called but GEET_GIT is not set (no template directory found)"
  fi
  debug "Calling:" "$GEET_GIT" "$@"
  "$GEET_GIT" "$@"
  local rc=$?
  return $rc
}



# Auto-detect GitHub username
GH_USER="$DEFAULT_GH_USER"
# Try gh CLI first
if command -v gh >/dev/null 2>&1; then
  if GH_USER_DETECTED="$(gh api user --jq .login 2>/dev/null)"; then
    if [[ -n "$GH_USER_DETECTED" ]]; then
      GH_USER="$GH_USER_DETECTED"
      debug "detected GitHub user from gh CLI: $GH_USER"
    fi
  fi
fi
# Try git config as fallback
if [[ "$GH_USER" == "$DEFAULT_GH_USER" ]]; then
  if GH_USER_DETECTED="$(git config --get github.user 2>/dev/null)"; then
    if [[ -n "$GH_USER_DETECTED" ]]; then
      GH_USER="$GH_USER_DETECTED"
      debug "detected GitHub user from git config: $GH_USER"
    fi
  fi
fi



# Read a key from the template JSON config.
# Uses jq; returns default (or empty string) if key missing or null.
read_config() {
  local key="$1"
  local default="${2-}"
  if [[ -f "$TEMPLATE_JSON" ]]; then
    jq -r --arg key "$key" --arg default "$default" '.[$key] // $default' "$TEMPLATE_JSON"
  else
    printf "$default"
  fi
}

# read config (only if template directory exists)
if [[ -n "$TEMPLATE_DIR" ]]; then
  GEET_ALIAS="$(read_config geetAlias "$DEFAULT_GEET_ALIAS")"
  TEMPLATE_GH_USER="$(read_config ghUser "$GH_USER")"
  TEMPLATE_GH_NAME="$(read_config ghName "$TEMPLATE_NAME")"
  TEMPLATE_NAME="$(read_config name "$TEMPLATE_NAME")"
  TEMPLATE_DESC="$(read_config desc "")"
  if [[ -n "$TEMPLATE_GH_NAME" ]]; then
    TEMPLATE_GH_URL="$(read_config ghURL "https://github.com/$TEMPLATE_GH_USER/$TEMPLATE_GH_NAME")"
    TEMPLATE_GH_SSH="$(read_config ghSSH "git@github.com:$TEMPLATE_GH_USER/$TEMPLATE_GH_NAME.git")"
    TEMPLATE_GH_HTTPS="$(read_config ghHTTPS "$TEMPLATE_GH_URL.git")"
  else
    TEMPLATE_GH_URL=""
    TEMPLATE_GH_SSH=""
    TEMPLATE_GH_HTTPS=""
  fi
  DD_APP_NAME="$(read_config demoDocAppName "$DDD_APP_NAME")"
  DD_TEMPLATE_NAME="$(read_config demoDocTemplateName "$DDD_TEMPLATE_NAME")"
else
  GEET_ALIAS="$DEFAULT_GEET_ALIAS"
  TEMPLATE_GH_USER=""
  TEMPLATE_GH_NAME=""
  TEMPLATE_NAME=""
  TEMPLATE_DESC=""
  TEMPLATE_GH_URL=""
  TEMPLATE_GH_SSH=""
  TEMPLATE_GH_HTTPS=""
  DD_APP_NAME="$DDD_APP_NAME"
  DD_TEMPLATE_NAME="$DDD_TEMPLATE_NAME"
fi


debug "digested!"
GEET_DIGESTED="true"

# Calculate and report prework timing
PREWORK_END_TIME=$(date +%s%N)
PREWORK_ELAPSED_NS=$((PREWORK_END_TIME - PREWORK_START_TIME))
PREWORK_ELAPSED_MS=$((PREWORK_ELAPSED_NS / 1000000))
debug "prework completed in ${PREWORK_ELAPSED_MS}ms"
