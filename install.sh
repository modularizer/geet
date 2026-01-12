#!/usr/bin/env bash
set -euo pipefail

# ---- config (edit these) ----
REPO="modularizer/geet"
BIN_NAME="geet"
ALT_BIN_NAME="geet-geet"
VERSION="${VERSION:-}"         # allow VERSION=1.3.0 ./install.sh
# -----------------------------

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need curl
need tar

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) arch="x64" ;;
  arm64|aarch64) arch="arm64" ;;
esac

# Pick install locations:
PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="${BIN_DIR:-$PREFIX/bin}"

# No-sudo fallback locations:
USER_PREFIX="${USER_PREFIX:-$HOME/.local}"
USER_BIN_DIR="${USER_BIN_DIR:-$USER_PREFIX/bin}"

# Where we store the extracted scripts:
DATA_DIR_DEFAULT="$HOME/.local/share/geet-geet"
DATA_DIR="${DATA_DIR:-$DATA_DIR_DEFAULT}"

if [[ -z "${VERSION}" ]]; then
  # resolve latest tag via GitHub redirect (no API token)
  VERSION="$(
    curl -fsSLI "https://github.com/$REPO/releases/latest" \
    | tr -d '\r' \
    | awk 'BEGIN{IGNORECASE=1} /^location:/{print; exit}' \
    | sed -E 's|.*\/tag\/v?([^[:space:]]+).*|\1|'
  )"
  VERSION="${VERSION#v}"
fi

TARBALL_URL="https://github.com/$REPO/archive/refs/tags/v${VERSION}.tar.gz"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Installing geet-geet v$VERSION"
echo "Downloading: $TARBALL_URL"
curl -fsSL "$TARBALL_URL" -o "$tmp/geet-geet.tgz"
tar -xzf "$tmp/geet-geet.tgz" -C "$tmp"

src_dir="$tmp/geet-$VERSION"

# Install payload
install_dir="$DATA_DIR/$VERSION"
mkdir -p "$install_dir"
rm -rf "$install_dir"/*
cp -R "$src_dir/bin" "$src_dir/lib" "$src_dir/layer" "$install_dir/" 2>/dev/null || true

# Create launcher script that always runs the installed bash entrypoint
launcher_content='#!/usr/bin/env bash
set -euo pipefail
VERSION="__VERSION__"
BASE="__INSTALL_DIR__"
exec "$BASE/$VERSION/bin/geet.sh" "$@"
'
launcher_path="$tmp/$BIN_NAME"
echo "$launcher_content" \
  | sed "s|__VERSION__|$VERSION|g" \
  | sed "s|__INSTALL_DIR__|$DATA_DIR|g" > "$launcher_path"
chmod +x "$launcher_path"

# Try system install, fall back to user install if no permission
do_install_bin() {
  local target_dir="$1"
  mkdir -p "$target_dir"
  cp "$launcher_path" "$target_dir/$BIN_NAME"
  ln -sf "$target_dir/$BIN_NAME" "$target_dir/$ALT_BIN_NAME"
  echo "Installed: $target_dir/$BIN_NAME"
  echo "Installed: $target_dir/$ALT_BIN_NAME"
}

if mkdir -p "$BIN_DIR" 2>/dev/null && cp "$launcher_path" "$BIN_DIR/$BIN_NAME" 2>/dev/null; then
  chmod +x "$BIN_DIR/$BIN_NAME"
  ln -sf "$BIN_DIR/$BIN_NAME" "$BIN_DIR/$ALT_BIN_NAME"
  echo "Installed to $BIN_DIR"
else
  echo "No permission for $BIN_DIR; installing to $USER_BIN_DIR instead."
  do_install_bin "$USER_BIN_DIR"
  echo ""
  echo "Add this to your shell rc if needed:"
  echo "  export PATH=\"$USER_BIN_DIR:\$PATH\""
fi

echo ""
echo "Done. Try:"
echo "  $BIN_NAME --help"
