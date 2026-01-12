# 2. Using a geet template

## Quick start

### Option 1: Install command (recommended)

```bash
geet install <template-repo-url> MyApp
```

This command:
1. Runs `git clone <template-repo-url> MyApp`
2. Automatically runs `init` in the cloned directory
3. Runs post-init hooks (if present)

### Option 2: Manual clone + init

```bash
git clone <template-repo-url> MyApp
cd MyApp
geet init
```

### What `init` does

1. Moves the cloned template repo: `./.git` → `./.geet/dot-git`
2. Initializes a fresh app repo at `./.git`
3. Compiles include/exclude rules
4. Runs post-init hook (if present)
5. Leaves you with:
    * normal app repo
    * live template layer wired up

**Idempotency**: Re-running `init` is safe — it detects prior setup and:
- If the template layer already exists (`dot-git/` present), it runs `refresh` instead
- If the template directory exists but needs setup, it runs `refresh` to ensure everything is up to date
- This makes `init` safe to run multiple times without fear of breaking your setup

## Day-to-day development

Nothing changes from normal Git:

```bash
git status
git commit
git push
```

You work exactly as you always have.

## Refreshing and checking out template refs

### Using `refresh` or `checkout`

The `refresh` (alias: `checkout`) command ensures your template repo is properly set up and switches to a specific ref:

```bash
# Refresh to current tracked ref (uses TEMPLATE_GIT_* environment variables)
geet refresh

# Switch to a specific branch
geet checkout main
geet checkout feature-branch

# Switch to a tag
geet checkout v1.2.3

# Switch to a specific commit
geet checkout abc123

# Switch to a remote branch
geet checkout origin/develop
```

**What `refresh`/`checkout` does:**

1. **Ensures template repo exists** — if `dot-git/` doesn't exist, clones the template repo
2. **Ensures origin remote exists** — adds SSH or HTTPS remote if missing
3. **Fetches from origin** — pulls latest refs from the remote
4. **Safety checks** — refuses to switch refs if template has uncommitted changes (like `git checkout`)
5. **Pre-switch cleanup** — removes template-only tracked files that won't exist in new ref
6. **Updates HEAD/refs** — switches to the target ref (branch-like or detached)
7. **Exports snapshot** — extracts files from the new ref
8. **Applies mappings** — copies files according to `.geetinclude` mappings
9. **Syncs ignore blocks** — updates managed sections in `.gitignore` and `.git/info/exclude`

**Use cases:**

- First-time setup after cloning an app repo that tracks a template
- Switching template branches or tags
- Ensuring template repo is up to date
- Recovering from a corrupted template setup

## Pulling template updates

When you want template changes:

```bash
geet pull
# Or: geet git pull

# Then commit the changes with normal git:
git commit -am "Update template"
```

What happens:

* Template repo pulls + merges updates into the working tree
* You commit the result with **normal git**
* No generators, no manual sync, no path changes

## Post-init hooks

Templates can include a one-time setup script that runs after initialization.

### Using post-init hooks

Pass arguments during install:
```bash
geet install <repo> MyApp -- --app-name "My App" --bundle-id com.example.myapp
```

Arguments after `--` are passed to the post-init hook.

### Skipping post-init

```bash
GEET_RUN_POST_INIT=0 geet install <repo> MyApp
```

## Inspecting what's in the template

### View as tree

```bash
geet tree              # tracked files (default)
geet tree all          # all whitelisted files
```

### Check specific file

```bash
geet tree contains app/index.tsx
```

Output tells you if the file is included and why/why not.

## Troubleshooting

### Run sanity checks

```bash
geet doctor
```

Checks:
* app repo health
* layer initialization
* include/exclude compilation
* `dot-git` not tracked
* detects all layers

Run this whenever something feels "off".

### Common issues

**Template changes aren't showing up:**
```bash
geet status    # Check template repo status
geet pull      # Pull template updates
```

**Confused about what's tracked:**
```bash
geet tree contains <path>    # Check specific file
geet tree tree               # See all tracked files
```