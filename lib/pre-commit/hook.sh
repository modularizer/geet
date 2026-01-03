#!/usr/bin/env bash

# source code of this file lives at node_modules/geet-geet/lib/pre-commit/hook.sh  which gets copied to .git/hooks/pre-commit
set -euo pipefail


#echo "HOOK GIT_INDEX_FILE=${GIT_INDEX_FILE-<unset>}" >&2
DOTGIT="$(dirname -- $GIT_INDEX_FILE)"
TEMPLATE_DIR="$(dirname -- "$DOTGIT")"
GEET_CMD="$(command -v geet)"
NODE_BIN="$(cd -- "$(dirname -- "${GEET_CMD}")" && pwd)"
GEET_LIB="$(cd -- "$NODE_BIN/../lib/node_modules/geet-geet/lib" && pwd)"
SOFT_DETACHED="$DOTGIT/info/geet-protected"
source "$TEMPLATE_DIR/template-config.env"


# next, source a few preset commands which we are able to locate using GEET_LIB var which was set when we sourced geet above
echo "checking if we need to unstage soft detached files..."
source "$GEET_LIB/pre-commit/unstage-soft-detached-files.sh"
unstage_soft_detached "$@"

echo "checking if we need to auto-promote the template's readme..."
source "$GEET_LIB/pre-commit/auto-promote-readme.sh"
auto_promote_readme "$@"

echo "checking if we need to auto-promote the template's parent gitignore..."
source "$GEET_LIB/pre-commit/auto-promote-pgi.sh"
auto_promote_pgi "$@"

echo "checking if we accidentally commited any protected files..."
source "$GEET_LIB/pre-commit/protect-patterns.sh"
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
echo "checking for more precommit hooks..."
shopt -s nullglob
for f in "$GEET_LIB"/pre-commit/*.sh; do
  [[ "$(basename "$f")" == "hook.sh" ]] && continue
  [[ "$(basename "$f")" == "unstage-soft-detached-files.sh" ]] && continue
  [[ "$(basename "$f")" == "auto-promote-readme.sh" ]] && continue
  [[ "$(basename "$f")" == "auto-promote-pgi.sh" ]] && continue
  [[ "$(basename "$f")" == "protect-patterns.sh" ]] && continue
  echo "sourcing $f ..."
  source "$f"
done
shopt -u nullglob

echo "made it through precommit!"
