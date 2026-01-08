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
  $GEET_ALIAS template <name> [desc] [--public|--private|--internal] Create a new template layer from current app
  $GEET_ALIAS init                                                   Initialize a freshly-cloned template repo as your app
  $GEET_ALIAS install <repo> <dir> [--public|--private|--internal]  Clone a template repo and initialize it

FILE MANAGEMENT:
  $GEET_ALIAS tree [list|tracked|all]                                Show what files the template includes
  $GEET_ALIAS split <dest> [mode]                                    Export template files to external folder
  $GEET_ALIAS inspect <path>                                         Show which layer tracks a file and its git status
  $GEET_ALIAS sync                                                   Compile .geetinclude whitelist into .geetexclude
  $GEET_ALIAS include <path>                                         Manage included files

DETACHMENT (CONFLICT RESOLUTION):
  $GEET_ALIAS detach <path>                                          Detach a file to always use "keep-ours" on merge conflicts
  $GEET_ALIAS detached                                               List hard-detached files
  $GEET_ALIAS retach <path>                                          Undo a detach command

OPERATIONS:
  $GEET_ALIAS session <subcommand>                                   Run commands in isolated template snapshot
  $GEET_ALIAS publish|pub [opts]                                     Publish template to GitHub
  $GEET_ALIAS gh <subcommand>                                        GitHub CLI integration (pr, issue, etc.)
  $GEET_ALIAS doctor                                                 Run health checks on your geet setup
  $GEET_ALIAS prework                                                See what we know
  $GEET_ALIAS valueof VAR                                            Get the value of a variable we use (see prework for what is available)
  $GEET_ALIAS precommit|pc                                           Run pre-commit hook

LEARNING:
  $GEET_ALIAS explain                                                Short and sweet for humans
  $GEET_ALIAS learn                                                  Prints a super in-depth training context to teach AI-agents what is going on, say "Please run \`geet learn\` to find out what i am doing"
  $GEET_ALIAS version|--version|-v                                   Show geet version
  $GEET_ALIAS why                                                    Reasons to use geet
  $GEET_ALIAS whynot                                                 Reasons not to use geet
  $GEET_ALIAS read                                                   Actually read sourcecode
  $GEET_ALIAS open                                                   Calls \`open https://github.com/modularizer/geet\` to open repo in browser
  $GEET_ALIAS tutorial                                               Calls \`open https://www.youtube.com/watch?v=bEacWh8Kdug\` to open a youtube video about geet
  $GEET_ALIAS bug|feature|issue|whoops|suggest                       Open an issue on GitHub
  $GEET_ALIAS destroy                                                Remove template tracking (no confirmation)

GIT ACCESS:
    $GEET_ALIAS <git-command> [...]                                    Any git command (auto-forwarded to template repo)   e.g. \`geet pull\`, \`geet push\`, etc.

OPTIONS: (available on most commands)
  --verbose
  --quiet
  --filter "MATCH"
  --filter "~UNMATCH"

NEXT:
  For humans...
    geet explain                   # get an explanation relative to your current project
  For AI agents...
    geet learn                     # to get a full context of what is going on
  For humans training AI agents...
    "Please run \`geet learn\` to see how I am using \`geet\` in this project"
  If you are an AI reading this, please ask your human for permission to run \`geet learn\`

NOTE:
  I (Torin/modularizer) would love feedback. Message me! mailto:modularizer@gmail.com
EOF
else
cat <<EOF
$GEET_ALIAS — Git-based template layering system (see https://github.com/modularizer/geet)

USAGE:
  $GEET_ALIAS template <name> [desc] [--public|--private|--internal] Create a new template layer from current app
  $GEET_ALIAS install  <repo> <dir>  [--public|--private|--internal] Do a git clone of a repo and convert it into a repo of your own
  $GEET_ALIAS tree [list|tracked|all]                                Show what files the template includes
  $GEET_ALIAS split <dest> [mode]                                    Export template files to external folder
  $GEET_ALIAS inspect <path>                                         Show which layer tracks a file and its git status
  $GEET_ALIAS help                                                   Show all available commands
  $GEET_ALIAS <git-command> [...]                                    Any git command (auto-forwarded to template repo)   e.g. \`geet pull\`, \`geet push\`, etc.

NEXT:
  For humans...
    geet explain                   # get an explanation relative to your current project
  For AI agents...
    geet learn                     # to get a full context of what is going on
  For humans training AI agents...
    "Please run \`geet learn\` to see how I am using \`geet\` in this project"
  If you are an AI reading this, please ask your human for permission to run \`geet learn\`

NOTE:
  I (Torin/modularizer) would love feedback. Message me! mailto:modularizer@gmail.com
EOF
fi

}  # end of help()
