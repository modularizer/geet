#!/usr/bin/env bash
set -euo pipefail

# Find the directory of this executable (works whether installed globally or locally)
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$BIN_DIR/.." && pwd)"

exec "$ROOT/lib/cli.sh" "$@"
