#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# tree.sh — show what files a layer template includes (and check membership)
#
# This script is intentionally NOT a git wrapper.
# It is a READ-ONLY introspection tool to answer:
#
#   1) "What files are included in this template layer?"
#   2) "Is this specific file included? Why / why not?"
#
# It works per-layer, based on where this script lives:
#   MyApp/.geet/lib/tree.sh
#   MyApp/.mytemplate/lib/tree.sh
#
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$LAYER_DIR/.." && pwd)"

LAYER_NAME="$(basename "$LAYER_DIR")"
LAYER_NAME="${LAYER_NAME#.}"

DOTGIT="$LAYER_DIR/dot-git"
geetinclude_SPEC="$LAYER_DIR/.geetinclude"
EXCLUDE_FILE="$LAYER_DIR/.gitignore"

die() { echo "[$LAYER_NAME tree] $*" >&2; exit 1; }
log() { echo "[$LAYER_NAME tree] $*" >&2; }

###############################################################################
# Preconditions
###############################################################################

need_dotgit() {
  [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]] || die "missing $DOTGIT (run: $LAYER_NAME init)"
}

# We rely on compiled excludes existing to ensure the whitelist semantics are
# actually in effect. The compiler lives in git.sh (single responsibility).
need_compiled_exclude() {
  [[ -f "$EXCLUDE_FILE" ]] || die "missing compiled exclude: $EXCLUDE_FILE (run: $LAYER_NAME status)"
}

# Run git in the layer view (read-only usage only)
git_layer() {
  GIT_DIR="$DOTGIT" GIT_WORK_TREE="$ROOT" git "$@"
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
  awk '
    BEGIN { FS="/"; }
    {
      paths[NR] = $0
    }
    END {
      n = asorti(paths, idx)
      for (i = 1; i <= n; i++) {
        path = paths[idx[i]]
        split(path, parts, "/")
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
    }
  '
}

###############################################################################
# Commands
###############################################################################
usage() {
  cat <<EOF
[$LAYER_NAME tree] Show which files are included in this layer template

Usage:
  $LAYER_NAME tree list [tracked|all]
  $LAYER_NAME tree tree [tracked|all]
  $LAYER_NAME tree contains <path>

Modes:
  tracked  - only files currently tracked by the layer template repo (fast)
  all      - any file in working tree that is INCLUDED by whitelist (slower)

Notes:
- Requires layer gitdir: $DOTGIT
- Requires compiled exclude: $EXCLUDE_FILE
  If missing, run: $LAYER_NAME status
EOF
}

cmd="${1:-help}"; shift || true

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
        git -C "$ROOT" ls-files -co --exclude-standard \
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
        die "usage: $LAYER_NAME tree list [tracked|all]"
        ;;
    esac
    ;;

  tree)
    need_dotgit
    need_compiled_exclude
    mode="${1:-tracked}"

    case "$mode" in
      tracked)
        git_layer ls-files | print_tree_from_paths
        ;;
      all)
        "$SCRIPT_DIR/tree.sh" list all | print_tree_from_paths
        ;;
      *)
        die "usage: $LAYER_NAME tree tree [tracked|all]"
        ;;
    esac
    ;;

  contains)
    need_dotgit
    need_compiled_exclude
    p="${1:-}"
    [[ -n "$p" ]] || die "usage: $LAYER_NAME tree contains <path>"

    # If user provides an absolute path inside the repo, convert to relative
    if [[ "$p" == "$ROOT/"* ]]; then
      p="${p#"$ROOT/"}"
    fi

    # Existence is informative, but not required
    if [[ ! -e "$ROOT/$p" ]]; then
      log "note: path does not exist in working tree: $p"
    fi

    if is_included "$p"; then
      included="YES"
      reason="not ignored by layer whitelist (.geetinclude -> .gitignore)"
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

    echo "layer: $LAYER_NAME"
    echo "path:  $p"
    echo "included-by-whitelist: $included"
    echo "tracked-by-template:  $tracked"
    echo "details: $reason"

    if [[ "$included" == "YES" && "$tracked" == "NO" ]]; then
      echo
      echo "hint: included but not tracked. Add it with:"
      echo "  $LAYER_NAME add -- \"$p\""
    fi

    if [[ "$included" == "NO" ]]; then
      echo
      echo "hint: to include it, add a line to:"
      echo "  $geetinclude_SPEC"
      echo "then regenerate excludes by running:"
      echo "  $LAYER_NAME status"
    fi
    ;;

  *)
    die "unknown command '$cmd' (try: $LAYER_NAME tree help)"
    ;;
esac
