###############################################################################
# AUTO-PROMOTE README
###############################################################################
# If .mytemplate/README.md is being committed, also promote to README.md
auto_promote_readme(){
  if git diff --cached --name-only | grep -q "^$TEMPLATE_DIR/README.md$"; then
    # README is being committed, promote it
    readme_path="$TEMPLATE_DIR/README.md"

    if [[ -f "$readme_path" ]]; then
      # Get hash of the staged version (not working tree)
      hash=$(git hash-object -w "$readme_path")

      # Stage it at promoted location
      git update-index --add --cacheinfo 100644 "$hash" "README.md"

      log "✅ [pre-commit] Auto-promoted $readme_path → README.md"
    fi
  fi
}
