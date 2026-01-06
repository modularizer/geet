#!/usr/bin/env bash
# this file behaves like geet, but always specifies our correct template directory, so it can be called from anywhere
THIS_FILE="${BASH_SOURCE[0]}" # e.g. .$LAYER_NAME/geet.sh
THIS_DIR="$(cd -- "$(dirname -- "$THIS_FILE")" && pwd)"  # e.g. .$LAYER_NAME

# now call geet, but tell it the absolute path of the template folder
# e.g. exec geet --geet-dir ".$LAYER_NAME" "\$@"
exec geet --geet-dir "$THIS_DIR" "$@"