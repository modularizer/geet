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
#   $TEMPLATE_GEETINCLUDE           # e.g. MyApp/.mytemplate/.geetinclude
#   $TEMPLATE_GEETEXCLUDE           # e.g. MyApp/.mytemplate/.geetexclude
#   $GEET_GIT              # e.g. MyApp/.mytemplate/geet-git.sh
#   $TEMPLATE_GEET_CMD              # e.g. MyApp/.mytemplate/geet.sh
#   $TEMPLATE_NAME                  # e.g. "mytemplate" but read from .../geet-config.json["name"], falls back to TEMPLATE_NAME
#   $TEMPLATE_DESC                  # e.g. "A cool react native base project example" but read from .../geet-config.json["desc"], falls back to empty
#   $GEET_ALIAS                     # e.g. "mytemplate" but read from .../geet-config.json["geetAlias"], falls back to "geet"
#   $TEMPLATE_CONFIG                # e.g. MyApp/.mytemplate/geet-config.json
#   $TEMPLATE_GH_USER               # e.g. <repo-owner>, the template owner's github username
#   $TEMPLATE_GH_NAME               # e.g. the project name on github, e.g. "mytemplate"
#   $TEMPLATE_GH_URL                # https://github.com/<repo-owner>/mytemplate
#   $TEMPLATE_GH_SSH_REMOTE         # # git@github.com:<repo-owner>/mytemplate.git
#   $TEMPLATE_GH_HTTPS_REMOTE       # https://github.com/<repo-owner>/mytemplate.git
#   read_config                     # helper function for extracting config values from MyApp/.mytemplate/geet-config.json
#   die
#   log
#   debug

# Directory this script lives in (.geet/lib)
GEET_LIB="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$GEET_LIB/has-flag.sh" --verbose "VERBOSE" "$@"

TEMPLATE_NAME=""
debug() {
  [[ "$VERBOSE" ]] || return 0
  if [[ "$TEMPLATE_NAME" ]]; then
    echo "[$TEMPLATE_NAME] $*" >&2
  else
    echo "$*" >&2
  fi
  return 0
}
debug "VERBOSE MODE ENABLED"
debug "1:${1:-}"
debug "2:${2:-}"
debug "3:${3:-}"

source "$GEET_LIB/has-flag.sh" --quiet "QUIET" "$@"
debug "QUIET='$QUIET'"
source "$GEET_LIB/has-flag.sh" --brave "BRAVE" "$@"
debug "BRAVE='$BRAVE'"
die() {
  [[ "$QUIET" ]] && return 1
  if [[ "$TEMPLATE_NAME" ]]; then
    echo "[$TEMPLATE_NAME] ERROR: $*" >&2
  else
    echo "ERROR: $*" >&2
  fi
  return 1
}
log_if_brave() {
  if [[ -n "${BRAVE:-}" ]]; then
    if [[ -n "${QUIET:-}" ]]; then
      echo "$*" >&2
    fi
  else
    if [[ -n "${VERBOSE:-}" ]]; then
      echo "$*" >&2
    fi
  fi
  return 0
}

log() {
  [[ "$QUIET" ]] && return 0
  if [[ "$TEMPLATE_NAME" ]]; then
    echo "[$TEMPLATE_NAME] $*" >&2
  else
    echo "$*" >&2
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


if [[ "${GEET_DIGESTED:-}" ]]; then
  debug "already digested"
  return 0
fi
debug "digesting input"


detect_template_dir_from_cwd() {
  local best_dir=""
  local best_lines=-1

  # Look at immediate hidden directories only (./.*)
  for d in .*/ ; do
    debug "$d"
    [[ -d "$d" ]] || continue
    [[ "$d" == "./.git/" ]] && continue

    local hier="${d}.geethier"   # e.g. ./.mytemplate/.geethier
    [[ -f "$hier" ]] || continue

    local lines
    lines="$(wc -l < "$hier" 2>/dev/null || echo 0)"

    if (( lines > best_lines )); then
      best_lines="$lines"
      best_dir="${d%/}"
    fi
    debug "found ${d}.geethier with $lines lines"
  done
  debug "best dir was $best_dir"
  printf '%s' "$best_dir"
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

debug "unable to locate the geet template directory, try specifying --geet-dir. if you are running certain commands (like geet help, geet template, etc) this is fine..."
#if [[ -z "$TEMPLATE_DIR" ]]; then
#  die "unable to locate the geet template directory, try specifying --geet-dir"
#  return 1
#fi
debug "TEMPLATE_DIR=$TEMPLATE_DIR"
DOTGIT="$TEMPLATE_DIR/dot-git"
TEMPLATE_README="$TEMPLATE_DIR/README.md"
TEMPLATE_GEETINCLUDE="$TEMPLATE_DIR/.geetinclude"
TEMPLATE_GEETEXCLUDE="$TEMPLATE_DIR/.geetexclude"
GEET_GIT="$TEMPLATE_DIR/geet-git.sh"
TEMPLATE_GEET_CMD="$TEMPLATE_DIR/geet.sh"
TEMPLATE_DIRNAME="$(basename -- "$TEMPLATE_DIR")" # e.g. .mytemplate
SOFT_DETACHED_FILE_LIST="$DOTGIT/info/geet-protected"
geet_git (){
  exec "$GEET_GIT" "$@"
}

# Derive repo dir + config path
TEMPLATE_JSON="$TEMPLATE_DIR/geet-config.json"
if [[ -f "$TEMPLATE_JSON" ]]; then
  debug "found $TEMPLATE_JSON"
else
  debug "no $TEMPLATE_JSON found"
fi

APP_DIR="$(dirname -- "$TEMPLATE_DIR")"
APP_NAME="$(basename "$APP_DIR")"
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
GEET_ALIAS="$(read_config geetAlias "geet")"
TEMPLATE_GH_USER="$(read_config ghUser "repo-owner>")"
TEMPLATE_GH_NAME="$(read_config ghName "$TEMPLATE_NAME")"
TEMPLATE_NAME="$(read_config name "$TEMPLATE_NAME")"
TEMPLATE_DESC="$(read_config desc "")"
TEMPLATE_GH_URL="$(read_config ghURL "https://github.com/$TEMPLATE_GH_USER/$TEMPLATE_GH_NAME")"
TEMPLATE_GH_SSH_REMOTE="$(read_config ghSSH "git@github.com:$TEMPLATE_GH_USER/$TEMPLATE_GH_NAME.git")"
TEMPLATE_GH_HTTPS_REMOTE="$(read_config ghHTTPS "$TEMPLATE_GH_URL.git")"
DEMO_DOC_APP_NAME="$(read_config demoDocAppName "MyApp")"
DEMO_DOC_TEMPLATE_NAME="$(read_config demoDocTemplateName "mytemplate")"

# Auto-detect GitHub username
GH_USER="your-github-username"
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
if [[ "$GH_USER" == "your-github-username" ]]; then
  if GH_USER_DETECTED="$(git config --get github.user 2>/dev/null)"; then
    if [[ -n "$GH_USER_DETECTED" ]]; then
      GH_USER="$GH_USER_DETECTED"
      debug "detected GitHub user from git config: $GH_USER"
    fi
  fi
fi

GEET_DIGESTED="true"
debug "digested!"

debug "cleaned here" "${GEET_ARGS[@]}"