# help.sh — display overview of all geet commands
# Usage:
#   source help.sh
#   help

help() {

# digest-and-locate.sh provides: GEET_ALIAS, TEMPLATE_NAME, die, log

cat <<EOF
$GEET_ALIAS — Git-based template layering system

Usage: $GEET_ALIAS <command> [args...]

TEMPLATE MANAGEMENT:
  template <name> [desc]    Create a new template layer from current app
  init                      Initialize a freshly-cloned template repo as your app
  install <repo>            Clone a template repo and initialize it (clone + init)
  clone <repo>              Clone a git repository (standard git clone)

FILE MANAGEMENT:
  tree [list|tracked|all]   Show what files the template includes
  split <dest> [mode]       Export template files to external folder
  sync                      Compile .geetinclude whitelist into .geetexclude

OPERATIONS:
  session run [opts] -- cmd Run command in isolated template snapshot
  publish [opts]            Publish template to GitHub (auto-detects repo name)
  gh <subcommand> [...]     GitHub CLI integration (pr, issue, etc.)
  doctor                    Run health checks on your geet setup

GIT ACCESS:
  git <command> [...]       Direct git access to template repo
  <git-command> [...]       Any git command (auto-forwarded to template repo)

Get help on any command:
  $GEET_ALIAS <command> --help

Examples:
  $GEET_ALIAS template my-stack "A modern web stack"
  $GEET_ALIAS install https://github.com/user/template-repo
  $GEET_ALIAS tree list
  $GEET_ALIAS publish --public
  $GEET_ALIAS status
  $GEET_ALIAS commit -m "Update template"

Current layer: ${TEMPLATE_NAME:-none}
EOF

}  # end of help()
