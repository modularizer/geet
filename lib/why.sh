# why.sh — explain when to use (or not use) geet
# Usage:
#   source why.sh
#   why
#   whynot

why() {
cat <<'EOF'
Why use geet?

I built something useful, and I think that SOME but not all of my code is re-usable.
I want to publish some of my code for other's to use (or to re-use myself)...
but I don't want to spend weeks refactoring to split apart the reusable code from the implementation-specific code.
In fact, it may not even be possible to move around all my files without breaking things.
Plus, supporting this template is my secondary task which I want to do in tandem with my primary development,
using my main repository's working directory and publishing some pieces to the template repo.
EOF
}

whynot() {
cat <<'EOF'
Why NOT use geet?

If you can super cleanly separate your template from your app or make your sourcecode fully modular,
you don't need geet, use a normal repo or maybe submodules.
EOF
}
