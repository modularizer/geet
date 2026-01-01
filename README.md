# geet — layered template system (git-native, path-preserving)

This project uses **multiple Git repositories over the same working tree** to support reusable templates **without moving files, copying files, generators, or path changes**.

This is **intentional, non-standard Git usage**.

This README documents the **template layer system** (the `.geet` folder), not your app itself.

---

## Why this exists

Modern React Native / Expo apps are **extremely path-sensitive**:

* file-based routing
* config files at exact paths
* native folders
* toolchains that assume canonical layouts

Traditional templates fail because they rely on:

* copying files
* generators that drift
* refactors that break paths

This system exists to **share real files at their real paths**, forever, with:

* no syncing
* no duplication
* no codegen
* no abstraction layer

---

## What this gives you

* One **normal app repo** (your project)
* One or more **template repos** (shared layers)
* All repos operate on the **same filesystem**
* Template updates flow via real `git pull`
* You can opt in / opt out at any time

You set it up once, then pull template updates forever.

---

## Core idea (the one thing to understand)

> **One working directory. Multiple Git repositories.
> Each repo tracks a different subset of files.**

Nothing moves.
Nothing is copied.
Only Git’s *view* of the filesystem changes.

---

## High-level model

### 1) App repo (normal Git)

* Git dir: `./.git`
* Tracks: everything
* Used for: day-to-day app development
* Commands: `git …`

You can delete `.geet/` and keep working normally at any time.

---

### 2) Template layer(s) (geet, sk2, etc.)

Each layer is a **self-contained template repo**:

* Git dir: `./.<layer>/dot-git`
* Tracks: **only whitelisted files**
* Used for: shared evolution
* Commands: `./.<layer>/lib/cli.sh …`

All repos operate on the **same files, same paths**.

---

## Folder layout (current)

```text
MyApp/
  .git/                  # app repo (normal)

  .geet/                  # base template layer
    dot-git/             # template git database (ignored by app repo)
    .gitignore           # TOTALLY UNRELATED to the template system, this is the .gitignore of this geet repo
    .geetinclude          # active whitelist
    geetinclude.sample   # documented sample whitelist
    cli.sh               # single entrypoint
    git.sh               # git wrapper (template view)
    init.sh              # convert clone → app + layer
    template.sh          # promote app → new template layer
    tree.sh              # inspect what the layer includes
    split.sh             # export template-visible files
    session.sh           # split → run → optional copy-back
    doctor.sh            # sanity checks
    README.md            # this file
```

**Only `dot-git/` is ignored by the app repo.**
Everything else in `.geet/` is committed so collaborators get the tooling.

---

## Whitelist model (`.geetinclude`)

Each template layer defines **exactly which files it owns** using a whitelist.

Rules:

```text
path        # include
!path       # exclude (override earlier include)
!!path      # escape (literal leading "!")
```

Example:

```text
app/**
!app/custom/**
app/custom/shared/**
package.json
```

This file is compiled into Git’s repo-local ignore system
(`dot-git/info/exclude`) automatically.

---

## First-time setup (template consumer)

### Option 1: Using `clone` command (recommended)

```bash
geet clone <template-repo-url> MyApp
# Or with the full path:
./.geet/lib/git.sh clone <template-repo-url> MyApp
```

This command:
1. Runs `git clone <template-repo-url> MyApp`
2. Automatically runs `init` in the cloned directory
3. Optionally runs post-init hooks (see below)

You can pass arguments to the post-init hook:
```bash
geet clone <template-repo-url> MyApp -- --app-name "My Cool App" --bundle-id com.example.app
```

### Option 2: Manual clone + init

```bash
git clone <template-repo-url> MyApp
cd MyApp
./.geet/lib/init.sh
```

What `init` does:

1. Moves the cloned template repo:

    * `./.git` → `./.geet/dot-git`
2. Initializes a fresh app repo at `./.git`
3. Compiles whitelist rules
4. Runs post-init hook (if present)
5. Leaves you with:

    * normal app repo
    * live template layer wired up

Re-running `init` is safe — it detects prior setup and exits cleanly.

---

## Day-to-day development

Nothing changes.

```bash
git status
git commit
git push
```

You work exactly as you always have.

---

## Pulling template updates

When you want template changes:

```bash
./.geet/lib/cli.sh git pull
git commit -am "Update template"
```

What happens:

* Template repo pulls + merges updates into the working tree
* You commit the result with **normal git**
* No generators, no manual sync, no path changes

---

## Inspecting what the template includes

```bash
./.geet/lib/cli.sh tree tree        # tree of tracked template files
./.geet/lib/cli.sh tree tree all    # tree of everything whitelisted
./.geet/lib/cli.sh tree contains app/index.tsx
```

This answers:

> “Is this file part of the template? Why or why not?”

---

## Exporting a clean template snapshot

```bash
./.geet/lib/cli.sh split /tmp/geet-export
./.geet/lib/cli.sh split /tmp/geet-export all
```

Use cases:

* publish a clean snapshot
* debug what’s actually included
* run builds in isolation

---

## Common workflow helper (`session`)

Very common pattern:

1. split to temp
2. run a command
3. optionally copy results back
4. clean up

Supported directly:

```bash
./.geet/lib/cli.sh session run -- npm run build
./.geet/lib/cli.sh session run --copy-back dist:dist -- npm run build
./.geet/lib/cli.sh session run --keep -- npm test
```

No config. No state. Just a convenience wrapper.

---

## Post-init hooks

Templates can include a one-time setup script that runs after initialization:

### Creating a post-init hook

Create `<layer>/post-init.sh` in your template:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Available environment variables:
# - GEET_LAYER_DIR   (e.g., /path/to/MyApp/.geet)
# - GEET_LAYER_NAME  (e.g., geet)
# - GEET_ROOT        (e.g., /path/to/MyApp)
# - GEET_DOTGIT      (e.g., /path/to/MyApp/.geet/dot-git)

echo "Running post-init setup..."

# Example: copy .env.sample to .env
[[ -f .env.sample && ! -f .env ]] && cp .env.sample .env

# Example: parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name)
      APP_NAME="$2"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

echo "Setup complete!"
```

Make it executable:
```bash
chmod +x .geet/post-init.sh
```

### Using post-init with clone

```bash
geet clone <repo> MyApp -- --app-name "My App" --bundle-id com.example.myapp
```

Arguments after `--` are passed to the post-init hook.

### Skipping post-init

To skip the post-init hook:
```bash
GEET_RUN_POST_INIT=0 geet clone <repo> MyApp
```

---

## Creating a new template layer

When your app evolves into its own reusable template:

```bash
./.geet/lib/cli.sh template        # creates .MyApp/
./.geet/lib/cli.sh template sk2    # creates .sk2/
```

This:

* copies tooling
* installs a whitelist sample
* initializes a new template git repo

Users can now clone **that** template and run `.<layer>/lib/init.sh`.

Layers stack cleanly.

---

## Safety model

Template repos **do not own the filesystem**.

Destructive Git commands are blocked by default:

* `clean`
* `reset`
* `checkout`
* `restore`
* `rm`

Override only if you know what you’re doing:

```bash
geetGIT_DANGEROUS=1 ./.geet/lib/cli.sh git reset --hard
```

---

## Sanity checks

```bash
./.geet/lib/cli.sh doctor
```

Checks:

* app repo health
* layer initialization
* whitelist compilation
* `dot-git` not tracked
* detects all layers

Run this whenever something feels “off”.

---

## Mental model (final)

Think of **layers** as lenses:

* **App lens**: “Everything here belongs to this project.”
* **Template lens**: “Only these files exist.”

The filesystem never changes.
Only Git’s interpretation does.

---

## Who this is for

* Teams maintaining **multiple similar apps**
* Templates that must live at **canonical paths**
* Developers who want **git-native updates**
* Anyone burned by starter kits drifting over time

If your template can’t afford to move files, this is the least-bad solution.

---

## Status

This system is intentionally small, explicit, and evolvable.

It will grow **only** when real workflows demand it.

You now have:

* cloning
* init
* layered templates
* introspection
* export
* build sessions
* safety rails

That’s the core.

Everything else is optional.
