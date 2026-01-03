# version.sh — display geet version
# Usage:
#   source version.sh
#   version

version() {
  local pkg_json="$GEET_LIB/../package.json"
  if [[ -f "$pkg_json" ]]; then
    local ver=$(grep '"version"' "$pkg_json" | head -1 | sed 's/.*"version": *"\([^"]*\)".*/\1/')
    echo "geet version $ver"
  else
    echo "geet version unknown (package.json not found)"
  fi
}
