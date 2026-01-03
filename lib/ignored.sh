is_ignored(){
  r="$(geet_git check-ignore -q -- "$1"  && echo ignored || echo included)"
  printf '%s' "$r"
}