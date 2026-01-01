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

exec "$ROOT/lib/cli.sh" "$@"
