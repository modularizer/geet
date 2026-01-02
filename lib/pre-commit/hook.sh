#!/usr/bin/env bash

# source code of this file lives at node_modules/geet/lib/pre-commit/hook.sh  which gets copied to .git/hooks/pre-commit
set -euo pipefail

# first: source the geet command to gain access to all the variables and functions it sets
source "$(command -v geet)"


# next, source a few preset commands which we are able to locate using GEET_LIB var which was set when we sourced geet above
log "checking if we need to unstage soft detached files..."
source "$GEET_LIB/pre-commit/unstage-soft-detached-files.sh"
unstage_soft_detached "$@"

log "checking if we need to auto-promote the template's readme..."
source "$GEET_LIB/pre-commit/auto-promote-readme.sh"
auto_promote_readme "$@"

log "checking if we accidentally commited any protected files..."
source "$GEET_LIB/pre-commit/protect.sh"
protect_patterns "$@"

# now, iterate the rest of the scripts which were presumably added by the user
###############################################################################
# USER CUSTOMIZATIONS
###############################################################################
# Add your own pre-commit logic below:
# - Promote other files
# - Run linters
# - Generate files
# - etc.
log "checking for more precommit hooks"
shopt -s nullglob
for f in "$GEET_LIB"/pre-commit/*.sh; do
  [[ "$(basename "$f")" == "$hook_self" ]] && continue
  log "sourcing $f ..."
  source "$f"
done
shopt -u nullglob

log "made it through precommit!"
