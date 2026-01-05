###############################################################################
# AUTO-PROMOTE PARENT GITIGNORE
###############################################################################
# If .mytemplate/parent.gitignore is being committed, also promote to .gitignore
auto_promote_pgi(){
  pgi_path="$TEMPLATE_DIR/parent.gitignore"
  if "$geet_git" diff --cached --name-only | grep -Fxq "$TEMPLATE_DIR_NAME/parent.gitignore"; then
    # .mytemplate/parent.gitignore is being committed, promote it
      # Get hash of the staged version (not working tree)
      hash=$("$geet_git" hash-object -w "$pgi_path")

      # Stage it at promoted location
      "$geet_git" update-index --add --cacheinfo 100644 "$hash" ".gitignore"

      echo "✅ [pre-commit] Auto-promoted $pgi_path → .gitignore"
  fi
}
