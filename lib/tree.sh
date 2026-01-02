# tree.sh — show what files a layer template includes (and check membership)
# Usage:
#   source tree.sh
#   tree [subcommand] [args...]
#
# Read-only introspection tool to answer:
#   1) "What files are included in this template layer?"
#   2) "Is this specific file included? Why / why not?"

tree() {
  debug "tree"

# digest-and-locate.sh provides: APP_DIR, TEMPLATE_DIR, DOTGIT, TEMPLATE_NAME,
# TEMPLATE_GEETINCLUDE, TEMPLATE_GEETEXCLUDE, die, log, debug

###############################################################################
# Preconditions
###############################################################################

need_dotgit() {
  [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]] || die "missing $DOTGIT (run: $GEET_ALIAS init)"
}

# We rely on compiled excludes existing to ensure the whitelist semantics are
# actually in effect.
need_compiled_exclude() {
  [[ -f "$TEMPLATE_DIR/.geetexclude" ]] || die "missing compiled exclude: $TEMPLATE_DIR/.geetexclude (run: $GEET_ALIAS sync)"
}

# Run git in the layer view (read-only usage only)
git_layer() {
  GIT_DIR="$DOTGIT" GIT_WORK_TREE="$APP_DIR" git "$@"
}

###############################################################################
# Inclusion checks
###############################################################################

# Returns 0 if NOT ignored (i.e. included by whitelist), nonzero otherwise.
is_included() {
  local p="${1:?missing path}"
  # check-ignore exits 0 if ignored, 1 if not ignored
  if git_layer check-ignore -q -- "$p"; then
    return 1
  else
    return 0
  fi
}

# Returns 0 if tracked by the template repo.
is_tracked() {
  local p="${1:?missing path}"
  git_layer ls-files --error-unmatch -- "$p" >/dev/null 2>&1
}

###############################################################################
# Printing a simple tree from a list of paths (stdin)
###############################################################################
print_tree_from_paths() {
  # Expect newline-separated relative paths on stdin.
  # Prints a simple ascii tree (directories/files) without requiring `tree`.
  # Sort first, then process with awk (portable - no asorti needed)
  sort | awk '
    BEGIN { FS="/"; }
    {
      split($0, parts, "/")
      prefix = ""
      for (j = 1; j <= length(parts); j++) {
        node = prefix parts[j]
        if (!(node in seen)) {
          indent = ""
          for (k = 1; k < j; k++) indent = indent "  "
          print indent parts[j]
          seen[node] = 1
        }
        prefix = node "/"
      }
    }
  '
}

###############################################################################
# Commands
###############################################################################
usage() {
  cat <<EOF
[$TEMPLATE_NAME tree] Show which files are included in this layer template

Usage:
  $GEET_ALIAS tree [tracked|all]          # Show tree view (default)
  $GEET_ALIAS tree list [tracked|all]     # List files
  $GEET_ALIAS tree contains <path>        # Check if path is included

Modes:
  tracked  - only files currently tracked by the layer template repo (fast)
  all      - any file in working tree that is INCLUDED by whitelist (slower)

Notes:
- Requires layer gitdir: $DOTGIT
- Requires compiled exclude: $TEMPLATE_DIR/.geetexclude
  If missing, run: $GEET_ALIAS sync
EOF
}

# Parse first argument - could be subcommand or mode
first_arg="${1:-}"
debug "first_arg=$first_arg"

# Check if it's a known subcommand
case "$first_arg" in
  list|contains|help|-h|--help)
    cmd="$first_arg"
    shift
    ;;
  tracked|all|"")
    # It's a mode or empty, default to tree command
    cmd="tree"
    # Don't shift - let the tree command handle the mode
    ;;
  *)
    # Unknown - could be a path for contains, or error
    # Default to tree and let it handle
    cmd="tree"
    ;;
esac

debug "cmd=$cmd"

case "$cmd" in
  help|-h|--help)
    usage
    ;;

  list)
    need_dotgit
    need_compiled_exclude
    mode="${1:-tracked}"

    case "$mode" in
      tracked)
        # Authoritative and fast: what the layer repo currently tracks
        git_layer ls-files
        ;;
      all)
        # Slower: scan the working tree and filter by whitelist using check-ignore.
        #
        # We use git's own file listing (including untracked) but do NOT depend
        # on the app repo ignores. We then apply the layer's whitelist via the
        # layer repo check-ignore rules.
        #
        # Exclude some common heavy dirs to keep it usable; customize as needed.
        git -C "$APP_DIR" ls-files -co --exclude-standard \
          -- ':!:**/node_modules/**' \
          -- ':!:**/.git/**' \
          -- ':!:**/dot-git/**' \
          -- ':!:**/.expo/**' \
          -- ':!:**/.idea/**' \
          -- ':!:**/.DS_Store' \
          | while IFS= read -r p; do
              if is_included "$p"; then
                echo "$p"
              fi
            done
        ;;
      *)
        die "usage: $GEET_ALIAS tree list [tracked|all]"
        ;;
    esac
    ;;

  tree)
    debug "calling tree"
    need_dotgit
    debug "here"
    need_compiled_exclude
    debug "okay"
    mode="${1:-tracked}"
    debug "mode=$mode"

    case "$mode" in
      tracked)
        geet_git ls-files | print_tree_from_paths
        ;;
      all)
        # Re-invoke tree list all
        tree list all | print_tree_from_paths
        ;;
      *)
        die "usage: $GEET_ALIAS tree [tracked|all]"
        ;;
    esac
    ;;

  contains)
    need_dotgit
    need_compiled_exclude
    p="${1:-}"
    [[ -n "$p" ]] || die "usage: $GEET_ALIAS tree contains <path>"

    # If user provides an absolute path inside the repo, convert to relative
    if [[ "$p" == "$APP_DIR/"* ]]; then
      p="${p#"$APP_DIR/"}"
    fi

    # Existence is informative, but not required
    if [[ ! -e "$APP_DIR/$p" ]]; then
      log "note: path does not exist in working tree: $p"
    fi

    if is_included "$p"; then
      included="YES"
      reason="not ignored by layer whitelist (.geetinclude -> .geetexclude)"
    else
      included="NO"
      # Show the ignore rule that matched (source:line:pattern path)
      rule="$(git_layer check-ignore -v -- "$p" 2>/dev/null || true)"
      reason="ignored by layer view: ${rule:-"(no details)"}"
    fi

    if is_tracked "$p"; then
      tracked="YES"
    else
      tracked="NO"
    fi

    echo "layer: $TEMPLATE_NAME"
    echo "path:  $p"
    echo "included-by-whitelist: $included"
    echo "tracked-by-template:  $tracked"
    echo "details: $reason"

    if [[ "$included" == "YES" && "$tracked" == "NO" ]]; then
      echo
      echo "hint: included but not tracked. Add it with:"
      echo "  $GEET_ALIAS add -- \"$p\""
    fi

    if [[ "$included" == "NO" ]]; then
      echo
      echo "hint: to include it, add a line to:"
      echo "  $TEMPLATE_DIR/.geetinclude"
      echo "then regenerate excludes by running:"
      echo "  $GEET_ALIAS sync"
    fi
    ;;

  *)
    die "unknown command '$cmd' (try: $GEET_ALIAS tree help)"
    ;;
esac

}  # end of tree()
