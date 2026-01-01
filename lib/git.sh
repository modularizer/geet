#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# LAYER TEMPLATE GIT WRAPPER (WHITELIST-BASED)
#
# This script gives you a SECOND Git repository ("template repo") over the SAME
# working tree as your normal app repository.
#
# Why?
# - Expo / RN projects are path-sensitive (routing, config, etc.).
# - We want a reusable template WITHOUT moving files, copying files, or codegen.
#
# How?
# - App repo lives at:            ./ .git
# - Template repo git database:   ./ .geet/dot-git   (or any other layer folder)
# - Both use the SAME work tree (project root), but track DIFFERENT files.
#
# The template repo tracks ONLY a whitelist defined by:
#   <layer>/.geetinclude
#
# We compile that whitelist into Git's repo-local ignore mechanism:
#   <layer>/.geetexclude
#
# IMPORTANT:
# - dot-git/ contains Git internals and MUST NOT be committed to the app repo.
# - The app repo should ignore: **/dot-git/
# - This is non-standard Git usage. Read comments carefully.
###############################################################################
source digest-and-locate.sh "$@"


###############################################################################
# TEMPLATE GIT LOCATION (GIT_DIR)
###############################################################################

# Template repo's Git database directory.
# This is analogous to .git/ for a normal repo, but layer-scoped.
DOTGIT="$LAYER_DIR/dot-git"


###############################################################################
# INCLUDE/EXCLUDE SPEC (AUTHOR-FACING)
###############################################################################

# Templates can use EITHER .geetinclude (whitelist) OR .geetexclude (blacklist).
# NEVER both.
#
# .geetinclude = WHITELIST mode (only listed files are tracked)

GEETINCLUDE_SPEC="$LAYER_DIR/.geetinclude"

# Determine which mode we're in
SPEC_FILE="$GEETINCLUDE_SPEC"
SPEC_MODE="include"

# Backwards compatibility
geetinclude_SPEC="$SPEC_FILE"

###############################################################################
# COMPILED EXCLUDES (EFFECTIVE)
###############################################################################

# Git supports repo-local ignore rules via .geetexclude.
# This affects ONLY the template repo, not the app repo.
EXCLUDE_FILE="$LAYER_DIR/.geetexclude"

#echo "exclude $EXCLUDE_FILE"


gitx() {
  git \
    "--git-dir=$DOTGIT" \
    "--work-tree=$ROOT" \
    -c "core.excludesFile=$EXCLUDE_FILE" \
    "$@"
}


###############################################################################
# OTHER LAYER TOOLS
###############################################################################

# init.sh is responsible for converting a freshly cloned template repo into:
# - a captured layer repo in <layer>/dot-git
# - a new app repo in ./ .git
INIT_SH="$SCRIPT_DIR/init.sh"

###############################################################################
# FORCE GIT INTO TEMPLATE MODE
###############################################################################
export GIT_DIR="$DOTGIT"
export GIT_WORK_TREE="$ROOT"

###############################################################################
# HELPERS
###############################################################################
die() { echo "[$LAYER_NAME] $*" >&2; exit 1; }
log() { echo "[$LAYER_NAME] $*" >&2; }

need_dotgit() {
  [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]] || die "missing $DOTGIT (run: $LAYER_DIR/lib/init.sh)"
}

###############################################################################
# INCLUDE/EXCLUDE COMPILATION
###############################################################################
# Compiles .geetinclude into the .geetexclude file between special markers
sync_exclude() {
  [[ -n "$SPEC_FILE" ]] || return 0

  mkdir -p "$(dirname "$EXCLUDE_FILE")"

  # Markers for the auto-populated section
  local START_MARKER="#++++++++++ GEETINCLUDESTART +++++++++++++++++++++"
  local END_MARKER="#+++++++++ GEETINCLUDEEND ++++++++++++++++++++++++"

  # Generate compiled rules
  local compiled_rules=""
  if [[ "$SPEC_MODE" == "include" ]]; then
    # WHITELIST MODE: Process .geetinclude
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"

      [[ -z "$line" ]] && continue
      [[ "$line" == \#* ]] && continue

      if [[ "$line" == "!!"* ]]; then
        compiled_rules+="!${line#!!}"$'\n'
      elif [[ "$line" == "!"* ]]; then
        compiled_rules+="${line#!}"$'\n'
      else
        compiled_rules+="!$line"$'\n'
      fi
    done < "$SPEC_FILE"
  fi

  # Read existing .geetexclude or create default structure
  local before_marker=""
  local after_marker=""

  if [[ -f "$EXCLUDE_FILE" ]]; then
    # File exists - extract parts before and after markers
    local in_marker=0
    while IFS= read -r line; do
      if [[ "$line" == "$START_MARKER" ]]; then
        in_marker=1
        continue
      elif [[ "$line" == "$END_MARKER" ]]; then
        in_marker=2
        continue
      fi

      if [[ $in_marker -eq 0 ]]; then
        before_marker+="$line"$'\n'
      elif [[ $in_marker -eq 2 ]]; then
        after_marker+="$line"$'\n'
      fi
    done < "$EXCLUDE_FILE"
  else
    # File doesn't exist - create default structure
    before_marker="*"$'\n'"!*/"$'\n'"!.$LAYER_NAME/**"$'\n'".$LAYER_NAME/dot-git/"$'\n'"**/dot-git/"$'\n'$'\n'
    after_marker=$'\n'"# Add custom ignore rules below this line"$'\n'
  fi

  # Write new .geetexclude with compiled rules between markers
  {
    printf "%s" "$before_marker"
    echo "$START_MARKER"
    echo "# Autopopulated from .geetinclude, do not modify"
    printf "%s" "$compiled_rules"
    echo "$END_MARKER"
    printf "%s" "$after_marker"
  } > "$EXCLUDE_FILE"
}

###############################################################################
# SAFETY: BLOCK FOOT-GUNS
###############################################################################
block_footguns() {
  case "${1-}" in
    clean|reset|checkout|restore|rm)
      if [[ "${geetGIT_DANGEROUS:-0}" != "1" ]]; then
        die "blocked '$1' (set geetGIT_DANGEROUS=1 to allow)"
      fi
    ;;
  esac
}

###############################################################################
# CLONE HELPER
###############################################################################
# This is a convenience command for first-time users:
#
#   geet clone <repo> [dir] [--recurse-submodules]
#
# It:
#  1) runs `git clone`
#  2) cd's into the directory
#  3) runs this layer's init.sh to convert the clone into an app + layer
#
# NOTE:
# - We deliberately keep this VERY thin.
# - We do NOT run post-init hooks here (you said you'll add that in init.sh next).
clone_cmd() {
  [[ -f "$INIT_SH" ]] || die "missing init script: $INIT_SH"

  local recurse=0
  local -a args=()
  local -a post_init_args=()
  local parsing_post_init=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --recurse-submodules|-r)
        recurse=1
        shift
        ;;
      --help|-h)
        cat <<EOF
Usage:
  $LAYER_NAME clone <repo> [dir] [--recurse-submodules] [-- post-init-args...]

Examples:
  $LAYER_NAME clone git@github.com:me/template.git MyApp
  $LAYER_NAME clone --recurse-submodules git@github.com:me/template.git
  $LAYER_NAME clone git@github.com:me/template.git MyApp -- --app-name "My Cool App"

Notes:
  - After cloning, this runs init automatically
  - Arguments after '--' are passed to the post-init hook (if present)
EOF
        return 0
        ;;
      --)
        parsing_post_init=1
        shift
        ;;
      *)
        if [[ "$parsing_post_init" -eq 1 ]]; then
          post_init_args+=("$1")
        else
          args+=("$1")
        fi
        shift
        ;;
    esac
  done

  [[ ${#args[@]} -ge 1 ]] || die "clone requires <repo> (and optional [dir])"

  local repo="${args[0]}"
  local dir=""
  if [[ ${#args[@]} -ge 2 ]]; then
    dir="${args[1]}"
  else
    # Derive a directory name from the repo URL (best-effort)
    dir="$(basename "$repo")"
    dir="${dir%.git}"
    [[ -n "$dir" ]] || die "could not infer directory name (pass an explicit [dir])"
  fi

  local -a clone_args=()
  if [[ "$recurse" -eq 1 ]]; then
    clone_args+=(--recurse-submodules)
  fi

  log "cloning template repo:"
  log "  repo: $repo"
  log "  dir:  $dir"
  gitx clone "${clone_args[@]}" "$repo" "$dir"

  log "running init in cloned directory"
  (
    cd "$dir"
    # We intentionally use the init script from INSIDE the clone (not from caller),
    # so this works even when geet is installed globally.
    if [[ -x "./.geet/lib/init.sh" ]]; then
      "./.geet/lib/init.sh" "${post_init_args[@]}"
    elif [[ -x "./$LAYER_DIR/lib/init.sh" ]]; then
      # Fallback: extremely unlikely to hit; keep for completeness.
      "./$LAYER_DIR/lib/init.sh" "${post_init_args[@]}"
    else
      die "could not find init.sh in clone (expected .geet/lib/init.sh)"
    fi
  )

  log "clone + init complete"
}

###############################################################################
# COMMAND DISPATCH
###############################################################################
cmd="${1:-help}"
shift || true

case "$cmd" in
  help|-h|--help)
    cat <<EOF
Layer template git wrapper (whitelist-based)

This runs git against a SECOND repo ($LAYER_NAME), which is a template repo owning SOME of the working tree:
  - gitdir:   $DOTGIT
  - worktree: $ROOT

Include/Exclude spec:
  - source:   ${SPEC_FILE:-"(none)"}
  - mode:     ${SPEC_MODE:-"(not set)"}
  - compiled: $EXCLUDE_FILE

Usage:
  $LAYER_NAME clone <repo> [dir] [--recurse-submodules] [-- post-init-args...]
  $LAYER_NAME init [remote] [branch]
  $LAYER_NAME pull [remote] [branch]
  $LAYER_NAME status | diff | log
  $LAYER_NAME add -A
  $LAYER_NAME commit -m "msg"
  $LAYER_NAME push [remote] [branch]
  $LAYER_NAME <any git args>

Notes:
- 'clone' runs git clone + init; args after '--' are passed to post-init hook
- After 'pull', commit changes with the APP repo (normal git).
- dot-git/ must be ignored by the app repo (it is git internals).
EOF
    ;;

  clone)
    clone_cmd "$@"
    ;;

  init)
    remote="${1:-}"
    branch="${2:-main}"

    mkdir -p "$DOTGIT"
    if [[ ! -f "$DOTGIT/HEAD" ]]; then
      gitx init "$DOTGIT" >/dev/null
    fi

    sync_exclude

    if [[ -n "$remote" ]]; then
      gitx remote add origin "$remote" 2>/dev/null || gitx remote set-url origin "$remote"
    fi

    gitx show-ref --verify --quiet "refs/heads/$branch" \
      || gitx checkout -b "$branch" >/dev/null 2>&1 || true

    log "initialized template layer (gitdir: $DOTGIT)"
    ;;

  status)
    sync_exclude
    need_dotgit
    gitx status
    ;;

  diff)
    sync_exclude
    need_dotgit
    gitx diff
    ;;

  log)
    sync_exclude
    need_dotgit
    gitx log --oneline --decorate -n 30
    ;;

  add)
    sync_exclude
    need_dotgit
    gitx add "$@"
    ;;

  commit)
    sync_exclude
    need_dotgit
    gitx commit "$@"
    ;;

  pull)
    sync_exclude
    need_dotgit
    gitx pull "$0"
    ;;

  push)
    sync_exclude
    need_dotgit
    gitx push "$0"
esac
