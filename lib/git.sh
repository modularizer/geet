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

# Helper: block dangerous git commands
block_footguns() {
  case "${1-}" in
    clean|reset|checkout|restore|rm)
      brave_guard "git $1" "git $1 can be destructive and mess with your app's working directory"
    ;;
  esac
}

###############################################################################
# CLONE - Simple git clone without init
###############################################################################
# Just clones a repository without running any post-install logic
call_cmd() {
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
  block_footguns "$@"
  geet_git "$@"
}
