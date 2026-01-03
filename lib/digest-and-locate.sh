# digest-and-locate.sh
# Usage:
#   source digest-and-locate.sh "$@"
# Voila! you now have
# 1. cleaned your args, digesting and removing --geet-dir, moving the value arg to $GEET_TEMPLATE_DIR
# 2. you have access to the following:
#
# === PATHS & DIRECTORIES ===
#   $GEET_LIB                         # e.g. node_modules/geet-geet/lib
#   $GEET_CMD                         # e.g. node_modules/geet-geet/bin/geet.sh
#   $APP_DIR                          # e.g. MyApp/
#   $APP_NAME                         # e.g. "MyApp"
#   $TEMPLATE_DIR                     # e.g. MyApp/.mytemplate
#   $DOTGIT                           # e.g. MyApp/.mytemplate/dot-git
#   $GEET_GIT                         # e.g. MyApp/.mytemplate/geet-git.sh
#   $SOFT_DETACHED          # e.g. MyApp/.mytemplate/dot-git/info/geet-protected
#
# === CONFIG VALUES (from MyApp/.mytemplate/.geet-template.env and .geet-metadata.env) ===
#   $TEMPLATE_NAME                    # e.g. "mytemplate" from MyApp/.mytemplate/.geet-template.env
#   $TEMPLATE_DESC                    # e.g. "A cool react native base project example" from MyApp/.mytemplate/.geet-template.env
#   $GEET_ALIAS                       # e.g. "mytemplate" from MyApp/.mytemplate/.geet-template.env, defaults to "geet"
#   $TEMPLATE_GH_USER                 # e.g. <repo-owner>, the template owner's github username
#   $TEMPLATE_GH_NAME                 # e.g. "mytemplate", the project name on github
#   $TEMPLATE_GH_URL                  # e.g. https://github.com/<repo-owner>/mytemplate
#   $TEMPLATE_GH_SSH           # e.g. git@github.com:<repo-owner>/mytemplate.git
#   $TEMPLATE_GH_HTTPS         # e.g. https://github.com/<repo-owner>/mytemplate.git
#   $DD_APP_NAME                # e.g. "MyApp" from MyApp/.mytemplate/.geet-metadata.env
#   $DD_TEMPLATE_NAME           # e.g. "mytemplate" from MyApp/.mytemplate/.geet-metadata.env
#
# === DETECTED USER INFO ===
#   $GH_USER                          # Detected GitHub username (from gh CLI or git config)
#
# === LOGGING & FILTER (from flags) ===
#   $MIN_LOG_LEVEL                    # e.g. "DEBUG", "INFO", "WARN", "ERROR", "CRITICAL", "NEVER" computed based on --verbose, --quiet, --silent flags
#   $LOG_FILTER                       # Filter pattern for log messages (use ~ prefix to invert/exclude)  from --filter flag, e.g. --filter APPLE or --filter ~ORANGE
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
#   $PATH_TO                          # "/path/to" - placeholder for docs
#   $DEFAULT_GEET_ALIAS               # "geet" - default alias
#   $DEFAULT_GH_USER                  # "<repo-owner>" - default placeholder
#   $DDD_APP_NAME        # "MyApp" - default app name for docs
#   $DDD_TEMPLATE_NAME   # "mytemplate" - default template name for docs
#
# === FUNCTIONS ===
#   read_config                       # read_config KEY [DEFAULT] - get config value by key name
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
PATH_TO="/path/to" # could be configurable in the future, used in comments

# hard-coded defaults which get overwritten
DEFAULT_GEET_ALIAS="geet"
DEFAULT_GH_USER="<repo-owner>"
DDD_APP_NAME="MyApp"
DDD_TEMPLATE_NAME="mytemplate"
TEMPLATE_NAME=""

# Directory this script lives in (.geet/lib)
SRC="${BASH_SOURCE[0]}"

GEET_ROOT="$(cd -- "$(dirname "$(dirname -- "$SRC")")" && pwd)"
GEET_LIB="$GEET_ROOT/lib"
GEET_BIN="$GEET_ROOT/bin"
GEET_CMD="$GEET_ROOT/geet.sh"
source "$GEET_LIB/flags.sh"
source "$GEET_LIB/logger.sh"
get_specified_level
get_log_filter


debug "SRC=$SRC"
debug "GEET_ROOT=$GEET_ROOT"
debug "GEET_ROOT=$GEET_ROOT"



debug "original args: $@"
debug "cleaned args: ${GEET_ARGS[@]}"


debug "VERBOSE MODE ENABLED"

has_flag --brave BRAVE
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

# Fast .env file loader (no external processes, idempotent)
load_env_file() {
  local file="$1"
  debug "loading $file"
  [[ ! -f "$file" ]] && return 0

  local marker_name="LOADED_${file//[^a-zA-Z0-9]/_}"

  # nounset-safe "is it already true?"
  if [[ "${!marker_name-}" == "true" ]]; then
    return 0
  fi

  # shellcheck disable=SC1090
  source "$file" 2>/dev/null || return 0

  printf -v "$marker_name" 'true'
  debug "loaded env file: $file"
  return 0
}


# Write local cache file (system-specific paths)
write_geet_local_env() {
  local target="${1:-$TEMPLATE_DIR/untracked-template-config.env}"
  [[ -f "$target" ]] && return 0  # Don't overwrite existing

  cat > "$target" <<EOF
# Geet local configuration (DO NOT COMMIT)
# System-specific absolute paths and user preferences
# Auto-generated - edit manually or regenerate with 'geet doctor --fix-cache'

GEET_LIB=$GEET_LIB
GEET_CMD=$GEET_CMD
TEMPLATE_DIR=$TEMPLATE_DIR
APP_DIR=$APP_DIR

# User preference overrides (optional):
# MIN_LOG_LEVEL=DEBUG
# COLOR_MODE=dark
# LOG_FILTER=pattern
EOF
  debug "created local cache: $target"
}

# Lazy GH_USER detection (only call when needed, not in prework)
get_gh_user() {
  # Return cached if available
  if [[ "$GH_USER" != "$DEFAULT_GH_USER" ]] || [[ -z "$GH_USER" ]]; then
    return 0
  fi

  # Expensive detection (200-500ms)
  debug "detecting GitHub user (this is slow, caching result)..."
  local detected="$DEFAULT_GH_USER"

  # Try gh CLI first
  if command -v gh >/dev/null 2>&1; then
    if detected_gh="$(gh api user --jq .login 2>/dev/null)"; then
      [[ -n "$detected_gh" ]] && detected="$detected_gh" && debug "detected GH user from gh CLI: $detected"
    fi
  fi

  # Fallback to git config
  if [[ "$detected" == "$DEFAULT_GH_USER" ]]; then
    if detected_git="$(git config --get github.user 2>/dev/null)"; then
      [[ -n "$detected_git" ]] && detected="$detected_git" && debug "detected GH user from git config: $detected"
    fi
  fi

  GH_USER="$detected"
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



# Load global user preferences from package installation
GEET_GLOBAL_CONFIG="$GEET_LIB/../config.env"
if [[ -f "$GEET_GLOBAL_CONFIG" ]]; then
  load_env_file "$GEET_GLOBAL_CONFIG"
  debug "loaded global config from $GEET_GLOBAL_CONFIG"
fi

# Extract --geet-dir <value> from args (mutates caller positional params)
has_flag --geet-dir TEMPLATE_DIR

# FAST PATH: Try to load cached TEMPLATE_DIR from untracked-template-config.env
if [[ -z "$TEMPLATE_DIR" ]]; then
  debug "no --geet-dir flag, trying fast path (cached untracked-template-config.env)"
  search_dir="$PWD"
  while [[ "$search_dir" != "/" ]]; do
    if load_env_file "$search_dir/untracked-template-config.env"; then
      debug "cache hit: loaded $search_dir/untracked-template-config.env"
      break
    fi
    search_dir="$(dirname "$search_dir")"
  done
fi

# SLOW PATH: Directory walking (only if cache miss)
if [[ -z "$TEMPLATE_DIR" ]]; then
  debug "cache miss - detecting template dir (slow path)"
  TEMPLATE_DIR="$(detect_template_dir_from_cwd)"
elif [[ ! -f "$TEMPLATE_DIR/.geethier" ]]; then
  # Cached path is stale, fall back to detection
  debug "cached TEMPLATE_DIR is stale, re-detecting"
  TEMPLATE_DIR="$(detect_template_dir_from_cwd)"
fi

if [[ -z "$TEMPLATE_DIR" ]]; then
  debug "unable to locate the geet template directory, try specifying --geet-dir. if you are running certain commands (like geet help, geet template, etc) this is fine..."
fi
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
  # Load template .env files in precedence order (lowest to highest)
  load_env_file "$TEMPLATE_DIR/template-config.env"
  load_env_file "$TEMPLATE_DIR/untracked-template-config.env"  # Highest precedence

  # Derive paths (fast string operations, no external commands)
  DOTGIT="$TEMPLATE_DIR/dot-git"
  GEET_GIT="$TEMPLATE_DIR/geet-git.sh"
  SOFT_DETACHED="$DOTGIT/info/geet-protected"
  APP_DIR="${APP_DIR:-$(cd "$(dirname -- "$TEMPLATE_DIR")" && pwd -P)}"
  APP_NAME="${APP_NAME:-$(basename -- "$APP_DIR")}"

  # Create local cache if missing (one-time cost)
  if [[ ! -f "$TEMPLATE_DIR/untracked-template-config.env" ]]; then
    write_geet_local_env
  fi

  debug "loaded template config from .env files"
  debug "APP_DIR=$APP_DIR"
else
  DOTGIT=""
  GEET_GIT=""
  SOFT_DETACHED=""

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
  debug "rc=$rc"
  return "$rc"
}



# GH_USER: Use cached value from .geet-metadata.env or leave as placeholder
# Don't auto-detect here (expensive) - use get_gh_user() function when needed
GH_USER="$DEFAULT_GH_USER"
debug "GH_USER (from default): $GH_USER"

# read_config: Get config value by key name
# Helper function that maps friendly key names to environment variables
read_config() {
  local key="$1"
  local default="${2-}"

  # Map friendly key names to env var names
  local var_name=""
  case "$key" in
    name) var_name="TEMPLATE_NAME" ;;
    desc) var_name="TEMPLATE_DESC" ;;
    geetAlias) var_name="GEET_ALIAS" ;;
    ghUser) var_name="TEMPLATE_GH_USER" ;;
    ghName) var_name="TEMPLATE_GH_NAME" ;;
    ghURL) var_name="TEMPLATE_GH_URL" ;;
    ghSSH) var_name="TEMPLATE_GH_SSH" ;;
    ghHTTPS) var_name="TEMPLATE_GH_HTTPS" ;;
    demoDocAppName) var_name="DD_APP_NAME" ;;
    demoDocTemplateName) var_name="DD_TEMPLATE_NAME" ;;
  esac

  # Return env var if set (from .env files)
  if [[ -n "$var_name" ]] && [[ -n "${!var_name:-}" ]]; then
    printf '%s' "${!var_name}"
    return 0
  fi

  # Return default if not found
  printf '%s' "$default"
}

# All config values should now be loaded from .env files
# Set defaults only if not already set (allows .env to override)
if [[ -n "$TEMPLATE_DIR" ]]; then
  GEET_ALIAS="${GEET_ALIAS:-$DEFAULT_GEET_ALIAS}"
  TEMPLATE_NAME="${TEMPLATE_NAME:-}"
  TEMPLATE_DESC="${TEMPLATE_DESC:-}"
  TEMPLATE_GH_USER="${TEMPLATE_GH_USER:-}"
  TEMPLATE_GH_NAME="${TEMPLATE_GH_NAME:-}"
  TEMPLATE_GH_URL="${TEMPLATE_GH_URL:-}"
  TEMPLATE_GH_SSH="${TEMPLATE_GH_SSH:-}"
  TEMPLATE_GH_HTTPS="${TEMPLATE_GH_HTTPS:-}"
  DD_APP_NAME="${DD_APP_NAME:-$DDD_APP_NAME}"
  DD_TEMPLATE_NAME="${DD_TEMPLATE_NAME:-$DDD_TEMPLATE_NAME}"
  debug "template config loaded (from .env files or defaults)"
else
  # No template dir - use defaults
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
