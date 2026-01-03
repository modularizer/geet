###############################################################################
# AUTO-PROMOTE PARENT GITIGNORE
###############################################################################
# If .mytemplate/parent.gitignore is being committed, also promote to .gitignore
auto_promote_pgi(){
  if git diff --cached --name-only | grep -q "^$TEMPLATE_DIR/parent.gitignore$"; then
    # .mytemplate/parent.gitignore is being committed, promote it
    pgi_path="$TEMPLATE_DIR/parent.gitignore"

    if [[ -f "$pgi_path" ]]; then
      # Get hash of the staged version (not working tree)
      hash=$(git hash-object -w "$pgi_path")

      # Stage it at promoted location
      git update-index --add --cacheinfo 100644 "$hash" ".gitignore"

      log "✅ [pre-commit] Auto-promoted $pgi_path → .gitignore"
    fi
  fi
}
