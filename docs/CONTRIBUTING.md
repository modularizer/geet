# Contributing to geet

## Development setup

```bash
# Clone the repo
git clone https://github.com/modularizer/geet.git
cd geet
npm install -g .
```

## Project structure

```text
geet/
  lib/
    detach.sh           # File detachment for conflict resolution
    digest-and-locate.sh # Environment setup and routing
    doctor.sh           # Health checks
    flags.sh            # Flag parsing utilities
    ghcli.sh            # GitHub CLI integration
    git.sh              # Git operations wrapper
    help.sh             # Help text and command listing
    ignored.sh          # Check if files are ignored/included/excluded
    include.sh          # Manage included files
    init.sh             # Initialize layer
    install.sh          # Clone and initialize templates
    logger.sh           # Logging utilities
    pre-commit          # Pre-commit hook
    prework.sh          # Show environment info
    session.sh          # Isolated build helper
    split.sh            # Export layer files
    sync.sh             # Compile .geetinclude to .geetexclude
    template.sh         # Create new layer
    tree.sh             # Inspect layer contents
    version.sh          # Version display
    whoops.sh           # Open GitHub issues
    why.sh              # Show reasons to use/not use geet

  bin/
    geet.sh             # Main router and npm executable wrapper

  package.json          # npm package config
```

## Architecture principles

**Single responsibility:** Each script does one thing well.

**Composable:** Scripts call each other via explicit paths.

**Portable:** Pure bash + git. No runtime dependencies (except `gh` for GitHub features).

**Safe by default:** Dangerous operations require explicit flags.

**Idempotent:** Running commands multiple times is safe.

## Code style

- Use `set -euo pipefail` at the top
- Provide clear `die()` and `log()` helpers
- Include comprehensive help text
- Document non-obvious behavior
- Validate inputs early
- Fail fast with clear errors
- Use `source` a lot
- Use `digest-and-locate.sh` for variable definitions and things that all scripts need access to
- Use `has_flag`, `extract_flag`, `log`, and `debug` heavily

## Testing changes

```bash
# Run doctor to check for issues
geet doctor

# Test the main executable
geet help
geet doctor

# Test in a real project
cd /path/to/test-project
/path/to/geet/bin/geet.sh doctor

# Or if installed globally
geet doctor
```

## Common tasks

### Adding a new command

1. Create `lib/mycommand.sh`
2. Add to `bin/geet.sh` router
3. Update help text in `lib/help.sh`
4. Test thoroughly

### Updating documentation

- README.md for user-facing docs
- Inline comments for complex logic
- Help text in each script

## Submitting changes

1. **Fork the repo**
2. **Create a branch:** `git checkout -b feature/my-feature`
3. **Make changes** following code style
4. **Test thoroughly** with `doctor` and real projects
5. **Commit:** Clear, descriptive messages
6. **Push:** `git push origin feature/my-feature`
7. **Open PR** with description of changes

## Feature requests

Open an issue with:
- Clear description of the problem
- Proposed solution (if you have one)
- Use cases / why it's needed

## Bug reports

Open an issue with:
- What you did (exact commands)
- What you expected
- What actually happened
- Output of `geet doctor`
- geet version / git version

## Questions

For questions about:
- **Using geet:** Open a discussion
- **Template design:** Open a discussion
- **Contributing:** Open an issue
- **Bugs:** Open an issue

---

## Status

This system is intentionally small, explicit, and evolvable.

It will grow **only** when real workflows demand it.

Core features:
- ✅ Template creation and initialization
- ✅ Install workflow (clone + init)
- ✅ Layered templates
- ✅ Include/exclude modes with sync
- ✅ File detachment (hard and soft)
- ✅ Introspection tools (tree, prework)
- ✅ Export functionality (split)
- ✅ Build sessions
- ✅ Safety rails
- ✅ Pre-commit hooks
- ✅ GitHub CLI integration (publish, pr, issues)
- ✅ Multi-layer support
- ✅ Doctor health checks

That's the core. Everything else is optional.
