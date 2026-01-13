# git-ref.sh — git reference tracking
# Usage:
#   source git-ref.sh
#   update_git_ref
#   read_git_ref
#
# Tracks the current git state (branch or commit) of the template repo
# Writes to $TEMPLATE_DIR/git-ref.env

# Update git ref tracking file with current state
update_git_ref() {
  if [[ -z "$TEMPLATE_DIR" ]]; then
    debug "TEMPLATE_DIR not set, skipping git ref update"
    return 0
  fi

  if [[ ! -d "$DOTGIT" ]]; then
    debug "DOTGIT not found at $DOTGIT, skipping git ref update"
    return 0
  fi

  local ref_file="$TEMPLATE_DIR/git-ref.env"
  local ref=""
  local detached="false"

  # Check if we're in detached HEAD state
  if ! geet_git symbolic-ref HEAD >/dev/null 2>&1; then
    # Detached HEAD - use commit hash
    ref=$(geet_git rev-parse HEAD 2>/dev/null || echo "")
    detached="true"
    debug "detached HEAD detected: $ref"
  else
    # On a branch - use branch name
    ref=$(geet_git symbolic-ref --short HEAD 2>/dev/null || echo "")
    debug "on branch: $ref"
  fi

  if [[ -z "$ref" ]]; then
    debug "unable to determine git ref, skipping git ref update"
    return 0
  fi

  # Only update file if ref has changed
  local old_ref=""
  local old_detached=""
  if [[ -f "$ref_file" ]]; then
    # Use subshell to avoid polluting current environment
    old_ref=$(
      source "$ref_file" 2>/dev/null || true
      echo "${TEMPLATE_GIT_REF:-}"
    )
    old_detached=$(
      source "$ref_file" 2>/dev/null || true
      echo "${TEMPLATE_GIT_DETACHED:-}"
    )
  fi

  if [[ "$old_ref" == "$ref" && "$old_detached" == "$detached" ]]; then
    debug "git ref unchanged: $ref (detached=$detached)"
    return 0
  fi

  # Write to file
  cat > "$ref_file" <<EOF
# Git reference tracking (auto-generated)
# This file tracks the current git state of the template repo

TEMPLATE_GIT_REF=$ref
TEMPLATE_GIT_DETACHED=$detached
EOF

  debug "updated git ref: $ref (detached=$detached)"
}

# Read git ref info from tracking file
# Sets TEMPLATE_GIT_REF, TEMPLATE_GIT_DETACHED
read_git_ref() {
  if [[ -z "$TEMPLATE_DIR" ]]; then
    return 0
  fi

  local ref_file="$TEMPLATE_DIR/git-ref.env"
  if [[ -f "$ref_file" ]]; then
    load_env_file "$ref_file"
    debug "loaded git ref: ${TEMPLATE_GIT_REF:-} (detached=${TEMPLATE_GIT_DETACHED:-})"
  fi
}

# Display current git ref info
show_git_ref() {
  read_git_ref

  if [[ -z "${TEMPLATE_GIT_REF:-}" ]]; then
    log "No git ref tracking found"
    return 0
  fi

  log "Template git state:"

  if [[ "${TEMPLATE_GIT_DETACHED:-false}" == "true" ]]; then
    log "  Ref:      ${TEMPLATE_GIT_REF:0:12} (detached HEAD)"
  else
    log "  Ref:      $TEMPLATE_GIT_REF"
  fi
}
