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

Re-running `init` is safe — it detects prior setup and exits cleanly.

## Day-to-day development

Nothing changes from normal Git:

```bash
git status
git commit
git push
```

You work exactly as you always have.

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