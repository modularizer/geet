###############################################################################
# AUTO-PROMOTE README
###############################################################################
# If .mytemplate/README.md is being committed, also promote to README.md
auto_promote_readme(){
  # README is being committed, promote it
  readme_path="$TEMPLATE_DIR/README.md"
  if "$geet_git" diff --cached --name-only | grep -Fxq "$TEMPLATE_DIR_NAME/README.md"; then
      # Get hash of the staged version (not working tree)
      hash=$("$geet_git" hash-object -w "$readme_path")
      echo "hash: $hash"

      # Stage it at promoted location
      "$geet_git" update-index --add --cacheinfo 100644 "$hash" "README.md"
      echo "✅ [pre-commit] Auto-promoted $readme_path → README.md"
  else
    echo "readme_path not in diff"
  fi
}
