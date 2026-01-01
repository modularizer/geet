#!/usr/bin/env bash
set -euo pipefail

# Find the directory of this executable (works whether installed globally or locally)
# Resolve symlinks to find the actual script location
SCRIPT="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT" ]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT")" && pwd)"
  SCRIPT="$(readlink "$SCRIPT")"
  [[ "$SCRIPT" != /* ]] && SCRIPT="$SCRIPT_DIR/$SCRIPT"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_NAME="$(basename -- "$ROOT")"
CLI="$ROOT/lib/cli.sh"

max_lines=-1
max_dir=""
max_file=""


# Find dot-starting subfolders in CWD (exclude . and ..)
while IFS= read -r -d '' dir; do
  file="$dir/.geethier"
  if [[ -f "$file" ]]; then
    lines=$(wc -l < "$file")
    if (( lines > max_lines )); then
      max_lines=$lines
      max_dir="$dir"
      max_file="$file"
    fi
  fi
done < <(find . -maxdepth 1 -mindepth 1 -type d -name '.*' ! -name '.' ! -name '..' -print0)


if (( max_lines >= 0 )); then
  CLI="$max_dir/lib/cli.sh"
  TEMPLATE_NAME="$(basename -- "$max_dir")"
  TEMPLATE_NAME="${TEMPLATE_NAME#.}"

fi


geetcmd="$(basename -- "$0")"
geetname="$TEMPLATE_NAME"
source "$CLI"
