# git-ref.sh — git reference tracking
# Usage:
#   source git-ref.sh
#   update_git_ref
#   read_git_ref
#
# Tracks the current git state (branch, commit, detached HEAD) of the template repo
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
  local branch=""
  local commit=""
  local detached="false"

  # Get current commit hash
  commit=$(geet_git rev-parse HEAD 2>/dev/null || echo "")

  if [[ -z "$commit" ]]; then
    debug "unable to get commit hash, skipping git ref update"
    return 0
  fi

  # Check if we're in detached HEAD state
  if ! geet_git symbolic-ref HEAD >/dev/null 2>&1; then
    detached="true"
    branch=""
    debug "detached HEAD detected"
  else
    # Get the current branch name
    branch=$(geet_git symbolic-ref --short HEAD 2>/dev/null || echo "")
    debug "on branch: $branch"
  fi

  # Write to file
  cat > "$ref_file" <<EOF
# Git reference tracking (auto-generated)
# Updated: $(date -Iseconds)
# This file tracks the current git state of the template repo

TEMPLATE_GIT_COMMIT=$commit
TEMPLATE_GIT_BRANCH=$branch
TEMPLATE_GIT_DETACHED=$detached
EOF

  debug "updated git ref: commit=$commit branch=$branch detached=$detached"
}

# Read git ref info from tracking file
# Sets TEMPLATE_GIT_COMMIT, TEMPLATE_GIT_BRANCH, TEMPLATE_GIT_DETACHED
read_git_ref() {
  if [[ -z "$TEMPLATE_DIR" ]]; then
    return 0
  fi

  local ref_file="$TEMPLATE_DIR/git-ref.env"
  if [[ -f "$ref_file" ]]; then
    load_env_file "$ref_file"
    debug "loaded git ref: commit=${TEMPLATE_GIT_COMMIT:-} branch=${TEMPLATE_GIT_BRANCH:-} detached=${TEMPLATE_GIT_DETACHED:-}"
  fi
}

# Display current git ref info
show_git_ref() {
  read_git_ref

  if [[ -z "${TEMPLATE_GIT_COMMIT:-}" ]]; then
    log "No git ref tracking found"
    return 0
  fi

  log "Template git state:"
  log "  Commit:   ${TEMPLATE_GIT_COMMIT}"
  if [[ "${TEMPLATE_GIT_DETACHED}" == "true" ]]; then
    log "  Branch:   (detached HEAD)"
  else
    log "  Branch:   ${TEMPLATE_GIT_BRANCH}"
  fi
}
