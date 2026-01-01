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
#   $TEMPLATE_README                # e.g. MyApp/.mytemplate/README.md
#   $TEMPLATE_GEETINCLUDE           # e.g. MyApp/.mytemplate/.geetinclude
#   $TEMPLATE_GEETEXCLUDE           # e.g. MyApp/.mytemplate/.geetexclude
#   $TEMPLATE_GEET_GIT              # e.g. MyApp/.mytemplate/geet-git.sh
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

die() { echo "error: $*" >&2; return 1; }  # harmless fallback if caller doesn't provide one

detect_template_dir_from_cwd() {
  local best_dir=""
  local best_lines=-1

  # Look at immediate hidden directories only (./.*)
  for d in .*/ ; do
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
  done

  printf '%s' "$best_dir"
}

# Directory this script lives in (.geet/lib)
GEET_LIB="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Path to the geet wrapper command (in our package)
GEET_CMD="$GEET_LIB/../bin/geet.sh"

# Repo dir (defaults to cwd; may be overridden if --geet-dir is provided)
APP_DIR="$(pwd)"

# Template directory (set via --geet-dir)
TEMPLATE_DIR=""

# Values loaded from template config
TEMPLATE_NAME=""
GEET_ALIAS=""

# Extract --geet-dir <value> from args (mutates caller positional params)
source "$GEET_LIB/extract-flag.sh" --geet-dir TEMPLATE_DIR "$@"

if [[ -z "$TEMPLATE_DIR" ]]; then
  TEMPLATE_DIR="$(detect_template_dir_from_cwd)"
else
  if [[ ! -f "$TEMPLATE_DIR/.geethier" ]]; then
    die "$TEMPLATE_DIR does not contain .geethier"
    return 1
  fi
fi

if [[ -z "$TEMPLATE_DIR" ]]; then
  die "unable to locate the geet template directory, try specifying --geet-dir"
  return 1
fi
DOT_GIT="$TEMPLATE_NAME/dot-git"
TEMPLATE_README="$TEMPLATE_DIR/README.md"
TEMPLATE_GEETINCLUDE="$TEMPLATE_DIR/.geetinclude"
TEMPLATE_GEETEXCLUDE="$TEMPLATE_DIR/.geetexclude"
TEMPLATE_GEET_GIT="$TEMPLATE_DIR/geet-git.sh"
TEMPLATE_GEET_CMD="$TEMPLATE_DIR/geet.sh"
TEMPLATE_DIRNAME="$(basename -- "$TEMPLATE_DIR")" # e.g. .mytemplate

# Derive repo dir + config path
TEMPLATE_JSON="$TEMPLATE_DIR/geet-config.json"
APP_DIR="$(dirname -- "$TEMPLATE_DIR")"

# Read a key from the template JSON config.
# Uses jq; returns default (or empty string) if key missing or null.
read_config() {
  local key="$1"
  local default="${2-}"
  jq -r --arg key "$key" --arg default "$default" '.[$key] // $default' "$TEMPLATE_JSON"
}

# Defaults (used if config missing)
GEET_ALIAS="geet"
TEMPLATE_GH_USER="<repo-owner>"
TEMPLATE_GH_NAME="$TEMPLATE_NAME"
TEMPLATE_DESC=""

# Load config only if the JSON file exists
if [[ -f "$TEMPLATE_JSON" ]]; then
  TEMPLATE_NAME="$(read_config name "$TEMPLATE_NAME")"
  TEMPLATE_DESC="$(read_config desc "$TEMPLATE_DESC")"
  GEET_ALIAS="$(read_config geetAlias "$GEET_ALIAS")"
  TEMPLATE_GH_USER="$(read_config ghUser "$TEMPLATE_GH_USER")"
  TEMPLATE_GH_NAME="$(read_config ghName "$TEMPLATE_GH_NAME")"
fi

TEMPLATE_GH_URL="https://github.com/$TEMPLATE_GH_USER}/${TEMPLATE_GH_NAME}"
TEMPLATE_GH_SSH_REMOTE="git@github.com:$TEMPLATE_GH_USER}/${TEMPLATE_GH_NAME}.git"
TEMPLATE_GH_HTTPS_REMOTE="${TEMPLATE_GH_URL}.git"
if [[ -f "$TEMPLATE_JSON" ]]; then
  TEMPLATE_GH_URL="$(read_config ghURL "$TEMPLATE_GH_URL")"
  TEMPLATE_GH_SSH_REMOTE="$(read_config ghSSH "$TEMPLATE_GH_SSH_REMOTE")"
  TEMPLATE_GH_HTTPS_REMOTE="$(read_config ghHTTPS "$TEMPLATE_GH_HTTPS_REMOTE")"
fi
