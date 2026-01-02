open_issue() {
  local title="${2:-}"
  local body="${3:-}"

  case "$title" in
    help|-h|--help)
      cat <<'EOF'
Usage:
  $GEET_ALIAS issue "<title>" ["body"]

Examples:
  $GEET_ALIAS issue "Bug: crash on launch"
  $GEET_ALIAS issue "Feature request: something cool" "It would be great if..."

Notes:
  - Opens a browser to create a GitHub issue
EOF
      return 0
      ;;
  esac

  local q_title q_body
  q_title="$(urlencode "$title")"
  q_body="$(urlencode "$body")"

  local url="$TEMPLATE_GH_URL/issues/new"
  [[ -n "$q_title" ]] && url+="?title=${q_title}"
  [[ -n "$q_body"  ]] && url+="${q_title:+&}body=${q_body}"

  if command -v open >/dev/null; then
    open "$url"
  elif command -v xdg-open >/dev/null; then
    xdg-open "$url"
  else
    echo "$url"
  fi
}
