resolve() {
  case "${1:-}" in
    help|-h|--help|"")
      cat <<'EOF'
$GEET_ALIAS resolve <file>
  Resolve the location of a file from geet's source code

Examples:
  $GEET_ALIAS resolve README.md
EOF
      return 0
      ;;
  esac

  echo "$(realpath -- "${GEET_LIB}/../$1")"
}

srccat(){
  case "${1:-}" in
      help|-h|--help|"")
        cat <<EOF
  $GEET_ALIAS read <path> [--path]
    Calls \`cat\` on the geet sourcecode if a file was passed in, else calls \`ls -a\`.

  Tip: install \`sudo apt install bat\` then pipe to \`batcat\`
    \`geet read README.md | batcat\`
    or lightmode with \`geet read README.md | batcat --theme=GitHub\`


  Examples:
    $GEET_ALIAS read bin/geet.sh              # the entrypoint
    $GEET_ALIAS read README.md                # the README
    $GEET_ALIAS read lib/resolve-path.sh      # this file
    $GEET_ALIAS read lib/digest-and-locate.sh # the "prework" called by every command
    $GEET_ALIAS read .                        # start navigating the sourcecode by listing files
    $GEET_ALIAS read demos/SOCCER.md          # try a demo
EOF
        return 0
        ;;
      --loc|loc|--path|path)
        echo "$(realpath -- "${GEET_LIB}/../$1")"
        return 0
        ;;
    esac
    path="$(realpath -- "${GEET_LIB}/../$1")"

    if [[ -d "$path" ]]; then
      ls -a "$path"
    else
      cat "$(realpath -- "${GEET_LIB}/../$1")"
    fi
}