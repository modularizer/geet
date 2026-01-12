#!/usr/bin/env bash
# refresh.sh
#
# Purpose:
#   - Ensure template repo gitdir exists at $DOTGIT
#   - Ensure origin remote exists (SSH preferred, HTTPS fallback)
#   - Fetch origin
#   - Act checkout-like:
#       1) die if template repo has modifications (dirty index or working tree)
#       2) before switching refs, delete "template-only tracked" files from parent workdir
#          so branch switches that remove those paths don't leave junk behind
#       3) update template HEAD/refs to the new ref (branch-like vs detached)
#   - Export snapshot of that ref to a temp dir
#   - Apply .geetinclude file mappings into the parent working tree
#   - Sync managed blocks into parent .gitignore and .git/info/exclude
#
# Usage:
#   refresh [<git-ref>]
#     <git-ref> behaves like `git checkout <ref>` (branch, tag, sha, origin/foo, etc.)
#     If omitted, falls back to TEMPLATE_GIT_* envs.

ensure_template_repo() {
  # Step 1: ensure we have a git directory setup
  if ! [[ -d "$DOTGIT" ]]; then
    log "cloning the template's repo"
    CLONE_TMP="$(mktemp -d)"

    debug "attempting to clone $TEMPLATE_GH_SSH"
    if git clone "$TEMPLATE_GH_SSH" "$CLONE_TMP" >/dev/null 2>&1; then
      debug "added template repo using SSH remote"
    else
      debug "SSH failed, falling back to HTTPS $TEMPLATE_GH_HTTPS"
      if git clone "$TEMPLATE_GH_HTTPS" "$CLONE_TMP" >/dev/null 2>&1; then
        debug "added template repo using HTTPS remote"
      else
        die "failed to add template repo"
      fi
    fi

    mkdir -p "$(dirname -- "$DOTGIT")"
    debug "moving $CLONE_TMP/.git to $DOTGIT"
    mv "$CLONE_TMP/.git" "$DOTGIT"
    rm -rf "$CLONE_TMP"
    CLONE_TMP=""
  fi

  # Step 2: ensure we have a remote setup
  if geet_git remote get-url origin >/dev/null 2>&1; then
    debug "git remote already set"
  else
    if geet_git remote add origin "$TEMPLATE_GH_SSH" >/dev/null 2>&1; then
      log "added SSH remote: $TEMPLATE_GH_SSH"
    else
      debug "SSH failed, falling back to HTTPS"
      geet_git remote add origin "$TEMPLATE_GH_HTTPS" >/dev/null 2>&1 || die "failed to add origin remote"
      log "added HTTPS remote: $TEMPLATE_GH_HTTPS"
    fi
  fi

  # Step 3: ensure our remote is up to date
  log "calling fetch"
  geet_git fetch origin >/dev/null 2>&1 || die "failed to fetch origin"
}

refresh() {
  set -euo pipefail

  local ARG_REF="${1:-}"
  local PARENT_DIR
  PARENT_DIR="$(pwd)"

  local CLONE_TMP=""
  local EXPORT_TMP=""

  cleanup() {
    [[ -n "${EXPORT_TMP:-}" && -d "${EXPORT_TMP:-}" ]] && rm -rf "$EXPORT_TMP" || true
    [[ -n "${CLONE_TMP:-}"  && -d "${CLONE_TMP:-}"  ]] && rm -rf "$CLONE_TMP"  || true
  }
  trap cleanup RETURN

  # Load .geetinclude mapping lib
  source "$GEET_LIB/mapping.sh"
  source "$GEET_LIB/git-ref.sh"

  ensure_template_repo

  has_flag -b NEW_BRANCH
  if [[ -n "$NEW_BRANCH" ]]; then
    geet_git checkout "$@"
    update_git_ref
    return 0
  fi

  # -----------------------------------------
  # Step 4: resolve REF (arg wins)
  # -----------------------------------------
  local REF=""
  if [[ -n "$ARG_REF" ]]; then
    REF="$ARG_REF"
  else
    if [[ "${TEMPLATE_GIT_DETACHED:-false}" == "true" ]]; then
      [[ -n "${TEMPLATE_GIT_COMMIT:-}" ]] || die "TEMPLATE_GIT_DETACHED=true but TEMPLATE_GIT_COMMIT is empty"
      REF="$TEMPLATE_GIT_COMMIT"
    elif [[ -n "${TEMPLATE_GIT_BRANCH:-}" ]]; then
      REF="$TEMPLATE_GIT_BRANCH"
      if [[ -n "${TEMPLATE_GIT_COMMIT:-}" ]]; then
        if geet_git merge-base --is-ancestor "$TEMPLATE_GIT_COMMIT" "origin/$TEMPLATE_GIT_BRANCH" >/dev/null 2>&1; then
          REF="$TEMPLATE_GIT_COMMIT"
        fi
      fi
    elif [[ -n "${TEMPLATE_GIT_COMMIT:-}" ]]; then
      REF="$TEMPLATE_GIT_COMMIT"
    else
      die "no ref arg and no TEMPLATE_GIT_BRANCH or TEMPLATE_GIT_COMMIT provided"
    fi
  fi

  log "refresh using ref: $REF"

  # Resolve commit (and fail like checkout would)
  local NEW_COMMIT
  NEW_COMMIT="$(geet_git rev-parse --verify "$REF^{commit}" 2>/dev/null)" || die "ref does not resolve to a commit: $REF"

  # Identify current template commit (if any)
  local OLD_COMMIT=""
  OLD_COMMIT="$(geet_git rev-parse --verify HEAD^{commit} 2>/dev/null || true)"


  # -----------------------------------------
  # Step 4.5: checkout-like safety: die if dirty
  # -----------------------------------------
  # If the template repo was already setup (DOTGIT exists) and we're changing refs,
  # refuse if there are modifications that would be clobbered.
  if [[ -n "${OLD_COMMIT:-}" && "$OLD_COMMIT" != "$NEW_COMMIT" ]]; then
    # Equivalent to "git checkout" safety: block if index or working tree differs from HEAD.
    if ! geet_git diff --quiet --ignore-submodules --; then
      die "template repo has unstaged changes; refusing to switch refs"
    fi
    if ! geet_git diff --cached --quiet --ignore-submodules --; then
      die "template repo has staged changes; refusing to switch refs"
    fi
  fi

  # -----------------------------------------
  # Helper: compute branch-like name for a ref (or empty)
  # -----------------------------------------
  _ref_to_branch_name() {
    local ref="$1"

    # If user passed origin/foo, treat as branch foo
    local maybe_branch="${ref#origin/}"

    if geet_git show-ref --verify --quiet "refs/heads/$ref"; then
      echo "$ref"
      return 0
    fi

    if geet_git show-ref --verify --quiet "refs/remotes/origin/$maybe_branch"; then
      echo "$maybe_branch"
      return 0
    fi

    echo ""
    return 1
  }

  # -----------------------------------------
  # Step 4.6: pre-checkout cleanup in parent workdir
  # -----------------------------------------
  # We must remove template-tracked files from the OLD ref that:
  #   - are NOT tracked by the app repo, and
  #   - will NOT exist in the NEW ref (template branch switch deletes them),
  # otherwise they'd stick around / get removed unexpectedly later.
  #
  # Only do this if we're actually switching refs.
  if [[ -n "${OLD_COMMIT:-}" && "$OLD_COMMIT" != "$NEW_COMMIT" ]]; then
    log "switching template ref: $OLD_COMMIT -> $NEW_COMMIT (pre-cleanup template-only tracked files)"

    # File lists (relative paths within the *template* repo snapshot)
    local old_list new_list
    old_list="$(mktemp)"
    new_list="$(mktemp)"
    trap 'rm -f "$old_list" "$new_list" >/dev/null 2>&1 || true' RETURN

    # List paths tracked by each commit
    geet_git ls-tree -r --name-only "$OLD_COMMIT" > "$old_list"
    geet_git ls-tree -r --name-only "$NEW_COMMIT" > "$new_list"

    # Iterate paths that disappear between refs
    while IFS= read -r path; do
      [[ -n "$path" ]] || continue
      if grep -Fxq -- "$path" "$new_list"; then
        continue
      fi

      # Map remote->local (if explicit mapping exists); else local==remote.
      local local_path=""
      get_local_from_remote "$path" local_path || true

      # Only consider safe, relative paths
      if [[ -z "$local_path" || "$local_path" == /* || "$local_path" == *".."* ]]; then
        debug "skipping unsafe mapped path for cleanup: remote=$path local=$local_path"
        continue
      fi

      local abs_local="$PARENT_DIR/$local_path"

      # Only delete if:
      #  - exists in parent workdir, AND
      #  - is NOT tracked by the app repo (git), AND
      #  - is a file/symlink (we don't manage directories here)
      if [[ -e "$abs_local" ]]; then
        if git -C "$PARENT_DIR" ls-files --error-unmatch "$local_path" >/dev/null 2>&1; then
          # tracked by app repo; do not touch
          continue
        fi

        if [[ -f "$abs_local" || -L "$abs_local" ]]; then
          rm -f -- "$abs_local"
          debug "removed template-only file disappearing in new ref: $local_path"
        fi
      fi
    done < "$old_list"
  fi

  # -----------------------------------------
  # Step 5: checkout-like update of template HEAD/refs
  # -----------------------------------------
  checkout_like() {
    local ref="$1"
    local commit="$2"

    local branch=""
    branch="$(_ref_to_branch_name "$ref" || true)"

    if [[ -n "$branch" ]]; then
      geet_git update-ref "refs/heads/$branch" "$commit"
      geet_git symbolic-ref HEAD "refs/heads/$branch"
      geet_git branch --set-upstream-to="origin/$branch" "$branch" >/dev/null 2>&1 || true
      log "now on branch: $branch @ $commit"
    else
      geet_git update-ref HEAD "$commit"
      log "now detached at: $commit"
    fi
  }

  checkout_like "$REF" "$NEW_COMMIT"

  # --------------------------------------------
  # Step 6: export template snapshot to temp dir
  # --------------------------------------------
  EXPORT_TMP="$(mktemp -d)"
  geet_git archive "$NEW_COMMIT" | tar -x -C "$EXPORT_TMP" || die "failed to archive template commit: $NEW_COMMIT"
  log "wrote $REF to archive"

  # -------------------------------------------------------
  # Step 7: apply mappings from .geetinclude (FILES ONLY)
  # -------------------------------------------------------
  if [[ ! -f "$TEMPLATE_DIR/.geetinclude" ]]; then
    debug "no .geetinclude found at $TEMPLATE_DIR/.geetinclude; nothing to apply"
    return 0
  fi

  _geet_safe_relpath() {
    local p="$1"
    [[ -n "$p" ]] || return 1
    [[ "$p" != /* ]] || return 1
    [[ "$p" != *".."* ]] || return 1
    return 0
  }

  apply_one_mapping() {
    local local_path="$1"
    local remote_path="$2"

    _geet_safe_relpath "$local_path"  || { debug "unsafe local path in .geetinclude: $local_path";  return 1; }
    _geet_safe_relpath "$remote_path" || { debug "unsafe remote path in .geetinclude: $remote_path"; return 1; }

    local src="$EXPORT_TMP/$remote_path"
    local dst="$PARENT_DIR/$local_path"

    if [[ ! -f "$src" ]]; then
      debug "missing in template snapshot (skipping): $remote_path"
      return 0
    fi

    mkdir -p "$(dirname -- "$dst")"
    rsync -a "$src" "$dst"
    debug "applied: $remote_path -> $local_path"
  }

  # mapping.sh old-format resolver checks -e relative to cwd; run from TEMPLATE_DIR.
  ( cd "$TEMPLATE_DIR" && for_each_mapping apply_one_mapping )

  # -------------------------------------------------------
  # Step 8: sync parent ignore files (managed blocks)
  # -------------------------------------------------------
  sync_managed_block() {
    local target_file="$1"
    local marker="$2"
    local content_file="$3"

    [[ -f "$content_file" ]] || return 0
    mkdir -p "$(dirname -- "$target_file")"
    touch "$target_file"

    local begin="# >>> geet:${marker}"
    local end="# <<< geet:${marker}"

    awk -v b="$begin" -v e="$end" '
      $0==b {in=1; next}
      $0==e {in=0; next}
      !in {print}
    ' "$target_file" > "${target_file}.geet.tmp"

    {
      cat "${target_file}.geet.tmp"
      echo "$begin"
      cat "$content_file"
      echo "$end"
    } > "$target_file"

    rm -f "${target_file}.geet.tmp"
    debug "synced managed block: $marker -> $target_file"
  }

  sync_managed_block "$PARENT_DIR/.gitignore"        "template-gitignore"      "$EXPORT_TMP/parent.gitignore"
  sync_managed_block "$PARENT_DIR/.git/info/exclude" "template-info-exclude"   "$EXPORT_TMP/parent-git-info-exclude"
  update_git_ref
  log "refresh complete"
}
