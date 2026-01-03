# why.sh — explain when to use (or not use) geet
# Usage:
#   source why.sh
#   why
#   whynot

why() {
printf '%b' "$(cat <<'EOF'
Use geet if this resonates with you...
\033[3m
   "I built something useful, and I think that SOME but not all of my code is re-usable.
    I want to publish some of my code for others to use (or to re-use myself)...
    but I don't want to spend weeks refactoring to split apart the reusable code from the implementation-specific code.
    In fact, it may not even be possible to move around all my files without breaking things.
    Plus, supporting this template is my secondary task which I want to do in tandem with my primary development,
    using my main repository's working directory and publishing some pieces to the template repo."

\033[0m

EOF
)"

}

whynot() {
printf '%b' "$(cat <<'EOF'
As much as I love this package, it is not for every use case...
\033[3m
    You probably do not need geet if you can super cleanly separate your template from your app or make your source code fully modular.
    If you can use a package distribution like pypi or npm that is probably best. If git submodules work for you, that is good too.
    If those solutions are not working for you, then check back here.

\033[0m

EOF
)"
}
