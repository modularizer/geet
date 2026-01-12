#!/usr/bin/env bash
set -euo pipefail

BIN_NAME="geet"
ALT_BIN_NAME="geet-geet"

PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="${BIN_DIR:-$PREFIX/bin}"

USER_PREFIX="${USER_PREFIX:-$HOME/.local}"
USER_BIN_DIR="${USER_BIN_DIR:-$USER_PREFIX/bin}"

DATA_DIR="${DATA_DIR:-$HOME/.local/share/geet-geet}"

echo "Uninstalling geet-geet…"

remove_bin() {
  local dir="$1"
  if [[ -e "$dir/$BIN_NAME" || -L "$dir/$BIN_NAME" ]]; then
    rm -f "$dir/$BIN_NAME"
    echo "Removed: $dir/$BIN_NAME"
  fi
  if [[ -e "$dir/$ALT_BIN_NAME" || -L "$dir/$ALT_BIN_NAME" ]]; then
    rm -f "$dir/$ALT_BIN_NAME"
    echo "Removed: $dir/$ALT_BIN_NAME"
  fi
}

remove_bin "$BIN_DIR"
remove_bin "$USER_BIN_DIR"

if [[ -d "$DATA_DIR" ]]; then
  rm -rf "$DATA_DIR"
  echo "Removed data dir: $DATA_DIR"
fi

echo "Done."
