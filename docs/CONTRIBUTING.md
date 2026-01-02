# 5. Contributing to geet

## Development setup

```bash
# Clone the repo
git clone https://github.com/anthropics/geet.git
cd geet

# The scripts are in lib/
ls lib/

# Test any script
bash lib/doctor.sh help
bash lib/ghcli.sh help
```

## Project structure

```text
geet/
  lib/
    cli.sh          # Main router
    git.sh          # Git operations wrapper
    init.sh         # Initialize layer
    tree.sh         # Inspect layer contents
    split.sh        # Export layer files
    session.sh      # Isolated build helper
    doctor.sh       # Health checks
    gh.sh           # GitHub integration
    template.sh     # Create new layer

  bin/
    geet.sh         # npm executable wrapper

  geetinclude.sample   # Whitelist example
  package.json         # npm package config
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

## Testing changes

```bash
# Run doctor to check for issues
bash lib/doctor.sh

# Test in a real project
cd /path/to/test-project
/path/to/geet/lib/cli.sh doctor
```

## Common tasks

### Adding a new command

1. Create `lib/mycommand.sh`
2. Add to `lib/cli.sh` router
3. Update help text
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
- ✅ Cloning templates
- ✅ Init workflow
- ✅ Layered templates
- ✅ Include/exclude modes
- ✅ Introspection tools
- ✅ Export functionality
- ✅ Build sessions
- ✅ Safety rails
- ✅ Post-init hooks
- ✅ GitHub integration
- ✅ Multi-layer support

That's the core. Everything else is optional.
