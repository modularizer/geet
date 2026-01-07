#!/usr/bin/env bash

THIS_FILE="${BASH_SOURCE[0]}" # e.g. .$LAYER_NAME/geet-git.sh
THIS_DIR="$(cd -- "$(dirname -- "$THIS_FILE")" && pwd)" # e.g. .$LAYER_NAME
PARENT_DIR="$(dirname "$THIS_DIR")" # e.g. # e.g. $PATH_TO/$APP_NAME

# this file behaves like git, but always specifies our correct git directory, working tree, and gitignore
# e.g. exec git --git-dir=".$LAYER_NAME/dot-git" --work-tree="." -c "core.excludesFile=.$LAYER_NAME/.geetexclude" "\$@"
exec git --git-dir="$THIS_DIR/dot-git" --work-tree="$PARENT_DIR" -c "core.excludesFile=$THIS_DIR/.geetexclude" "$@"
