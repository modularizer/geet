# Understanding geet

## How it works

### App repo (normal Git)

* Git dir: `./.git`
* Tracks: everything
* Used for: day-to-day app development
* Commands: `git …`

You can delete `.geet/` and keep working normally at any time.

### Template layer(s)

Each layer is a **self-contained template repo**:

* Git dir: `./.<layer>/dot-git`
* Tracks: **only specified files** (via include/exclude lists)
* Used for: shared evolution
* Commands: `./.<layer>/lib/cli.sh …`

All repos operate on the **same files, same paths**.

## Folder structure

```text
MyApp/
  .git/                    # app repo (normal)

  .geet/                   # base template layer
    dot-git/               # template git database (ignored by app repo)
    .geetinclude           # whitelist (OR use .geetexclude for blacklist)
    lib/
      cli.sh               # single entrypoint
      git.sh               # git wrapper (template view)
      init.sh              # convert clone → app + layer
      tree.sh              # inspect what the layer includes
      split.sh             # export template-visible files
      session.sh           # split → run → optional copy-back
      doctor.sh            # sanity checks
      gh.sh                # GitHub CLI integration
    post-init.sh           # optional one-time setup hook
```

**Only `dot-git/` is ignored by the app repo.**
Everything else in `.geet/` is committed so collaborators get the tooling.

## Mental model

Think of **layers** as lenses:

* **App lens**: "Everything here belongs to this project."
* **Template lens**: "Only these files exist."

The filesystem never changes.
Only Git's interpretation does.

## Key operations

### `init` — Bootstrap a template layer (idempotent)

Converts a freshly-cloned template repo into an app with a template layer:

1. Moves `.git` → `.geet/dot-git` (preserves template git database)
2. Creates new app repo at `.git`
3. Adds `dot-git/` to `.gitignore`
4. Runs post-init hook if present

**Idempotent**: Safe to run multiple times. If already initialized, runs `refresh` instead.

### `refresh` / `checkout` — Ensure template exists and switch refs

The refresh command (also callable as `checkout`) handles template repo setup and ref switching:

```bash
geet refresh              # Refresh to current tracked ref (from env vars)
geet checkout main        # Switch to branch
geet checkout v1.2.3      # Switch to tag
geet checkout abc123      # Switch to commit
```

**What it does:**

1. Clones template repo if `dot-git/` doesn't exist
2. Adds origin remote if missing (SSH preferred, HTTPS fallback)
3. Fetches latest refs from origin
4. Safety check: refuses to switch if template has uncommitted changes
5. Pre-cleanup: removes template-only files that won't exist in new ref
6. Updates template HEAD to target ref (branch-like or detached)
7. Exports snapshot of target ref to temp directory
8. Applies `.geetinclude` file mappings to working tree
9. Syncs managed blocks in `.gitignore` and `.git/info/exclude`

**Use cases:**

- First-time setup when cloning an app repo that already tracks a template
- Switching between template branches, tags, or commits
- Recovering from template setup issues
- Ensuring template is synced with latest remote refs

## Who this is for

* Teams maintaining **multiple similar apps**
* Templates that must live at **canonical paths**
* Developers who want **git-native updates**
* Anyone burned by starter kits drifting over time

If your template can't afford to move files, this is the least-bad solution.

---