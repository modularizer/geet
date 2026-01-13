#!/usr/bin/env bash

THIS_FILE="${BASH_SOURCE[0]}" # e.g. .$LAYER_NAME/geet-git.sh
THIS_DIR="$(cd -- "$(dirname -- "$THIS_FILE")" && pwd)" # e.g. .$LAYER_NAME
PARENT_DIR="$(dirname "$THIS_DIR")" # e.g. # e.g. $PATH_TO/$APP_NAME

# Clear git environment variables that could leak from parent process (e.g., when running in git hooks)
# GIT_INDEX_FILE is critical - if set by a parent hook, it would point to the wrong index
# --git-dir overrides GIT_DIR, but there's no command-line option to override GIT_INDEX_FILE
unset GIT_INDEX_FILE GIT_DIR GIT_WORK_TREE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR 2>/dev/null || true

# this file behaves like git, but always specifies our correct git directory, working tree, and gitignore
# e.g. exec git --git-dir=".$LAYER_NAME/dot-git" --work-tree="." -c "core.excludesFile=.$LAYER_NAME/.geetexclude" "\$@"
exec git --git-dir="$THIS_DIR/dot-git" --work-tree="$PARENT_DIR" -c "core.excludesFile=$THIS_DIR/.geetexclude" "$@"
