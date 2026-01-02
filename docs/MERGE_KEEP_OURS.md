# Git Merge Strategy: keep-ours

## What is it?

A custom Git merge driver that automatically resolves conflicts by **always keeping your working tree version** and ignoring incoming changes.

## How it works

**Normal merge behavior:**
```bash
# You have: README.md (version A)
# Upstream has: README.md (version B, different)
git pull
# → MERGE CONFLICT! Manual resolution required
```

**With `merge=keep-ours`:**
```bash
# You have: README.md (version A)
# Upstream has: README.md (version B, different)
git pull
# → No conflict! Keeps version A, ignores version B
```

## When to use

✅ **Good use cases:**
- Files that diverge intentionally (app's README vs template's README)
- Local configuration files that should never sync
- Files you want to track upstream changes to UNTIL they diverge, then stop

❌ **Don't use for:**
- Source code that needs actual merging
- Shared configuration that should stay in sync
- Files where you might want upstream changes later

## Setup

### 1. Configure the merge driver

Add to your git config (one-time setup):

```bash
# For a specific repo:
git config merge.keep-ours.name "Always keep our version"
git config merge.keep-ours.driver "true"

# Or globally (affects all repos):
git config --global merge.keep-ours.name "Always keep our version"
git config --global merge.keep-ours.driver "true"
```

**What this does:**
- Creates a merge driver named `keep-ours`
- The driver is just `true` (exits successfully without doing anything)
- Git thinks the merge succeeded, but the file wasn't actually modified

### 2. Mark files to use this driver

Tell git which files should use the `keep-ours` driver:

**Option A: Per-repo `.gitattributes` file:**
```bash
# In .gitattributes at repo root:
README.md merge=keep-ours
config/local.json merge=keep-ours
.env merge=keep-ours
```

Commits this configuration with the repo (shared with everyone).

**Option B: Local `.git/info/attributes` file:**
```bash
# In .git/info/attributes (not committed):
README.md merge=keep-ours
```

Only affects your local repo (not shared).

### 3. Test it

```bash
# Make a change to the file
echo "My local version" > README.md
git commit -am "Update README"

# Pull changes (that modify same file)
git pull

# → No conflict! Your version stays
```

## geet-specific usage

### For template repos

When developing a template alongside an app:

```bash
# Set up driver (if not already):
geet git config merge.keep-ours.driver "true"

# Mark files that should never sync from template to app:
echo "README.md merge=keep-ours" >> .mytemplate/dot-git/info/attributes

# Now pulling template updates won't touch your app's README.md
geet pull
```

### Manual setup for any file

```bash
# For files in template repo:
geet git config merge.keep-ours.driver "true"
echo "path/to/file.txt merge=keep-ours" >> .mytemplate/dot-git/info/attributes

# For files in app repo:
git config merge.keep-ours.driver "true"
echo "path/to/file.txt merge=keep-ours" >> .git/info/attributes
```

## Lifecycle example

**Scenario:** You want to track a config file from upstream until you customize it, then stop syncing.

```bash
# Initial state: config.json is identical
git pull  # ✅ Syncs normally

# You customize it
vim config.json
git commit -am "Customize config for my app"

# Set up keep-ours AFTER divergence
git config merge.keep-ours.driver "true"
echo "config.json merge=keep-ours" >> .git/info/attributes

# Future pulls: upstream changes ignored
git pull  # ✅ No conflict, keeps your version
```

## How it differs from other strategies

### `merge=keep-ours` (custom driver)
- ✅ No conflicts ever
- ✅ Syncs while files are identical
- ✅ Stops syncing after divergence
- ⚠️ Silently ignores upstream changes (can surprise you)

### `git merge --strategy=ours`
- Merges entire branch, keeping everything from your side
- All-or-nothing (can't pick specific files)
- Different use case

### `git merge --strategy-option=ours`
- Resolves conflicts by keeping your version
- Still tries to auto-merge non-conflicting changes
- Different behavior

### `.gitignore`
- File not tracked at all
- Can't sync initially
- Different use case

### `assume-unchanged` / `skip-worktree`
- Tells git to ignore local changes
- Still tries to update from upstream
- Can cause different issues

## Trade-offs

**Pros:**
- ✅ Zero merge conflicts for marked files
- ✅ Files sync until they diverge (convenient)
- ✅ Once diverged, stays diverged (intentional)
- ✅ Simple to set up

**Cons:**
- ⚠️ Silently ignores upstream changes (might miss important updates)
- ⚠️ Can surprise collaborators who don't know about it
- ⚠️ No warning when upstream changes are ignored
- ⚠️ Can't easily "re-sync" later (need to manually merge)

## Removing/disabling

**Stop using keep-ours for a file:**

```bash
# Remove from .gitattributes or .git/info/attributes
vim .git/info/attributes  # Delete the line

# Future merges will behave normally (may conflict)
```

**Manually pull an update after removing:**

```bash
# Remove keep-ours
vim .git/info/attributes  # Delete: README.md merge=keep-ours

# Get upstream version
git checkout origin/main -- README.md

# Manually merge if needed
```

## Debugging

**Check if keep-ours is configured:**

```bash
# Check driver exists:
git config --get merge.keep-ours.driver  # Should output: true

# Check which files use it:
cat .git/info/attributes
# or:
cat .gitattributes
```

**See what strategy git will use:**

```bash
git check-attr merge README.md
# Output: README.md: merge: keep-ours
```

## Related documentation

- [File promotion pattern](/docs/AUTO_PROMOTE.md) - Uses keep-ours for promoted files
- [Git attributes documentation](https://git-scm.com/docs/gitattributes)
- [Custom merge drivers](https://git-scm.com/docs/gitattributes#_defining_a_custom_merge_driver)

## Summary

The `merge=keep-ours` strategy is a powerful tool for files that should:
1. Initially sync from upstream
2. Eventually diverge
3. Never conflict after diverging

Perfect for config files, READMEs, or any file where "your version wins" is the right answer.

Use sparingly and document clearly so collaborators understand the behavior.
