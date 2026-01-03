# help.sh — display overview of all geet commands
# Usage:
#   source help.sh
#   help

help() {

# digest-and-locate.sh provides: GEET_ALIAS, TEMPLATE_NAME, die, log

if [[ "${1:-}" == "--all" ]]; then
cat <<EOF
$GEET_ALIAS — Git-based template layering system (see https://github.com/modularizer/geet)

TEMPLATE MANAGEMENT:
  template <name> [desc] [--public|--private|--internal] Create a new template layer from current app
  init                                                   Initialize a freshly-cloned template repo as your app
  install <repo> <dir> [--public|--private|--internal]  Clone a template repo and initialize it

FILE MANAGEMENT:
  tree [list|tracked|all]                                Show what files the template includes
  split <dest> [mode]                                    Export template files to external folder
  inspect <path>                                         Show which layer tracks a file and its git status
  sync                                                   Compile .geetinclude whitelist into .geetexclude
  include <path>                                         Manage included files
  ignored|included|excluded <path>                       Check if a path is ignored/included/excluded

DETACHMENT (CONFLICT RESOLUTION):
  detach|hard-detach <path>                              Detach a file to always use "keep-ours" on merge conflicts
  soft-detach|soft_detach|slide <path>                   Soft detach (lighter alternative)
  detached                                               List hard-detached files
  soft-detached|soft_detached|slid                       List soft-detached files
  retach <path>                                          Undo a detach command

OPERATIONS:
  session <subcommand>                                   Run commands in isolated template snapshot
  publish|pub [opts]                                     Publish template to GitHub
  gh <subcommand>                                        GitHub CLI integration (pr, issue, etc.)
  doctor                                                 Run health checks on your geet setup
  prework                                                See what we know
  precommit|pc                                           Run pre-commit hook

UTILITIES:
  version|--version|-v                                   Show geet version
  why                                                    Reasons to use geet
  whynot                                                 Reasons not to use geet
  bug|feature|issue|whoops|suggest                       Open an issue on GitHub
  remove|rm                                              Remove template tracking (requires confirmation)
  destroy                                                Remove template tracking (no confirmation)

GIT ACCESS:
  git <command> [...]                                    Direct git access to template repo
  <git-command> [...]                                    Any git command (auto-forwarded to template repo)

Current layer: ${TEMPLATE_NAME:-none}
EOF
else
cat <<EOF
$GEET_ALIAS — Git-based template layering system (see https://github.com/modularizer/geet)

USAGE:
  template <name> [desc] [--public|--private|--internal] Create a new template layer from current app
  install  <repo> <dir>  [--public|--private|--internal] Do a git clone of a repo and convert it into a repo of your own
  tree [list|tracked|all]                                Show what files the template includes
  split <dest> [mode]                                    Export template files to external folder
  inspect <path>                                         Show which layer tracks a file and its git status
  prework                                                See what we know
  why / whynot                                           Reasons to (or not to) use geet
  version / --version                                    Show geet version
  help --all                                             Show all available commands
  <git-command> [...]                                    Any git command (auto-forwarded to template repo)

Current layer: ${TEMPLATE_NAME:-none}
EOF
fi

}  # end of help()
