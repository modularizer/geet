# git.sh — template git operations
# Usage:
#   source git.sh
#   (exposed functions are used via geet.sh command dispatcher)
#
# Provides git wrapper functions for template repo operations



# Helper: sync .geetinclude to .geetexclude
sync_exclude() {
  source "$GEET_LIB/sync.sh"
  sync
}

# Helper: check if template git repo exists
need_dotgit() {
  [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]] || die "missing $DOTGIT (run: $GEET_ALIAS init)"
}


###############################################################################
# CLONE - Simple git clone without init
###############################################################################
# Just clones a repository without running any post-install logic
include() {
  if [[ -z "$TEMPLATE_DIR" ]]; then
    critical "We could not find your template repo anywhere in this project!"
    warn "Are you sure you are somewhere inside a project which has a template repo?"
    warn "The template repo is a hidden folder at the root of your working directory which contains a .geethier file inside it"
    warn "To debug our search, run \`$GEET_ALIAS status --verbose --filter LOCATE\`"
    warn "If you think we made a mistake, review the code at $GEET_LIB/digest-and-locate.sh detect_template_dir_from_cwd"
    exit 1
  fi
  need_dotgit
  sync_exclude
  # first, modify .geetinclude
  source "$GEET_LIB/ignored.sh"
  for arg in "$@"; do
    status="$(is_ignored $arg)"
    debug "status of $arg is \"$status\""
    if [[ "$status" == "ignored" ]]; then
      echo "$arg" >> "$TEMPLATE_DIR/.geetinclude"
      sync_exclude
      status="$(is_ignored $arg)"
      if [[ "$status" == "ignored" ]]; then
          die "failed to unignore $arg"
      fi
    fi
    geet_git add "$arg"
  done


}
