# digest-and-locate.sh
# Usage:
#   source digest-and-locate.sh "$@"
# Voila! you now have
# 1. cleaned your args, digesting and removing --geet-dir, moving the value arg to $GEET_TEMPLATE_DIR
# 2. you have access to the following:
#   $GEET_LIB                       # e.g. node_modules/geet/lib
#   $GEET_CMD                       # e.g. node_modules/geet/bin/geet.sh
#   $APP_DIR                        # e.g. MyApp/
#   $TEMPLATE_DIR                   # e.g. MyApp/.mytemplate
#   $DOTGIT                         # e.g. MyApp/.mytemplate/dot-git
#   $TEMPLATE_README                # e.g. MyApp/.mytemplate/README.md
#   $TEMPLATE_DIR/.geetinclude           # e.g. MyApp/.mytemplate/.geetinclude
#   $TEMPLATE_DIR/.geetexclude           # e.g. MyApp/.mytemplate/.geetexclude
#   $GEET_GIT              # e.g. MyApp/.mytemplate/geet-git.sh
#   $TEMPLATE_GEET_CMD              # e.g. MyApp/.mytemplate/geet.sh
#   $TEMPLATE_NAME                  # e.g. "mytemplate" but read from .../config.json["name"], falls back to TEMPLATE_NAME
#   $TEMPLATE_DESC                  # e.g. "A cool react native base project example" but read from .../config.json["desc"], falls back to empty
#   $GEET_ALIAS                     # e.g. "mytemplate" but read from .../config.json["geetAlias"], falls back to "geet"
#   $TEMPLATE_CONFIG                # e.g. MyApp/.mytemplate/config.json
#   $TEMPLATE_GH_USER               # e.g. <repo-owner>, the template owner's github username
#   $TEMPLATE_GH_NAME               # e.g. the project name on github, e.g. "mytemplate"
#   $TEMPLATE_GH_URL                # https://github.com/<repo-owner>/mytemplate
#   $TEMPLATE_GH_SSH_REMOTE         # # git@github.com:<repo-owner>/mytemplate.git
#   $TEMPLATE_GH_HTTPS_REMOTE       # https://github.com/<repo-owner>/mytemplate.git
#   read_config                     # helper function for extracting config values from MyApp/.mytemplate/config.json
#   die
#   log
#   debug

# Hard-coded config
SHOW_LEVEL="true"
COLOR_MODE="light" # light|dark|none/empty
COLOR_SCOPE="line" # line|level|empty
CONFIG_NAME="config.json"
PATH_TO="/path/to" # could be configurable in the future, used in comments

# hard-coded defaults which get overwritten
DEFAULT_GEET_ALIAS="geet"
DEFAULT_GH_USER="<repo-owner>"
DEFAULT_DEMO_DOC_APP_NAME="MyApp"
DEFAULT_DEMO_DOC_TEMPLATE_NAME="mytemplate"

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
DOTGIT="$TEMPLATE_DIR/dot-git"
GEET_GIT="$TEMPLATE_DIR/geet-git.sh"
SOFT_DETACHED_FILE_LIST="$DOTGIT/info/geet-protected"
geet_git () {
  debug "Calling:" "$GEET_GIT" "$@"
  "$GEET_GIT" "$@"
  local rc=$?
  return $rc
}


# Derive repo dir + config path
TEMPLATE_JSON="$TEMPLATE_DIR/$CONFIG_NAME"
if [[ -f "$TEMPLATE_JSON" ]]; then
  debug "found config at $TEMPLATE_JSON"
else
  warn "no config found at $TEMPLATE_JSON"
fi


APP_DIR="$(cd "$(dirname -- "$TEMPLATE_DIR")" && pwd -P)"
APP_NAME="$(basename -- "$APP_DIR")"
debug "APP_DIR=$APP_DIR"
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

# read config
GEET_ALIAS="$(read_config geetAlias "$DEFAULT_GEET_ALIAS")"
TEMPLATE_GH_USER="$(read_config ghUser "$DEFAULT_GH_USER")"
TEMPLATE_GH_NAME="$(read_config ghName "$TEMPLATE_NAME")"
TEMPLATE_NAME="$(read_config name "$TEMPLATE_NAME")"
TEMPLATE_DESC="$(read_config desc "")"
TEMPLATE_GH_URL="$(read_config ghURL "https://github.com/$TEMPLATE_GH_USER/$TEMPLATE_GH_NAME")"
TEMPLATE_GH_SSH_REMOTE="$(read_config ghSSH "git@github.com:$TEMPLATE_GH_USER/$TEMPLATE_GH_NAME.git")"
TEMPLATE_GH_HTTPS_REMOTE="$(read_config ghHTTPS "$TEMPLATE_GH_URL.git")"
DEMO_DOC_APP_NAME="$(read_config demoDocAppName "$DEFAULT_DEMO_DOC_APP_NAME")"
DEMO_DOC_TEMPLATE_NAME="$(read_config demoDocTemplateName "$DEFAULT_DEMO_DOC_TEMPLATE_NAME")"

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


debug "digested!"
GEET_DIGESTED="true"
