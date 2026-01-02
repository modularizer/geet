# Advanced: File Promotion Pattern

## The Problem

When developing a template and app simultaneously in the same working directory, you may need different versions of certain files:

- **App's `README.md`**: Explains your specific app
- **Template's `README.md`**: Explains how to use the template

Both need to be at the root:
- App repo: `README.md` at root for your app's GitHub
- Template repo: `README.md` at root for template's GitHub

But you can't have two different `README.md` files in the same working directory!

## The Solution: File Promotion

**Promotion** means committing a file to the template repo at a different path than it exists in the working tree.

**Example:**
- Working tree: `.mytemplate/README.md` (template's README source)
- Template repo tree: Both `README.md` AND `.mytemplate/README.md`
- App repo: `README.md` (app's README, different content)

When someone clones the template from GitHub, they get `README.md` at the root.

## How It Works

### Naming Convention (Future Feature)

Files matching `*-{template-name}.*` auto-promote to the base name:

```
README-mytemplate.md    → promotes to README.md
LICENSE-mytemplate.txt  → promotes to LICENSE.txt
package-mytemplate.json → promotes to package.json
```

**Process:**
1. Edit `README-mytemplate.md` in working tree
2. Run `geet add README-mytemplate.md`
3. Git stages it at BOTH locations in template repo:
   - `README-mytemplate.md` (source)
   - `README.md` (promoted)
4. Commit to template
5. GitHub shows `README.md` at root

### Avoiding Merge Conflicts

Promoted files use a custom merge strategy (`merge=keep-ours`):

- Files sync normally when content is identical
- On first divergence: auto-keeps working tree version
- After divergence: files stop syncing (no conflicts!)

This prevents the template's `README.md` from overwriting your app's `README.md` during pulls.

**Learn more:** See [Git Merge Strategy: keep-ours](/docs/MERGE_KEEP_OURS.md) for detailed explanation and other use cases.

## Current Implementation

**As of now, only `README.md` uses promotion**, and it's set up automatically by `geet template`:

- Creates `.mytemplate/README.md` (template README source)
- Promotes to `README.md` in template repo
- Sets `merge=keep-ours` to prevent conflicts
- Creates pre-commit hook to auto-promote on future commits

**Workflow after setup:**
1. Edit `.mytemplate/README.md`
2. Run `geet add .mytemplate/README.md`
3. Run `geet commit -m "Update README"`
4. **Pre-commit hook automatically promotes to `README.md`**
5. Both versions get committed together

## Extending the Pre-commit Hook

The pre-commit hook created by `geet template` can be extended to promote additional files.

**Location:** `.mytemplate/dot-git/hooks/pre-commit`

**Example - promote LICENSE too:**

```bash
# Edit .mytemplate/dot-git/hooks/pre-commit
# Add this section to the "USER CUSTOMIZATIONS" area:

if git --git-dir="$DOTGIT" diff --cached --name-only | grep -q "^.$LAYER_NAME/LICENSE$"; then
  license_path=".$LAYER_NAME/LICENSE"
  if [[ -f "$license_path" ]]; then
    hash=$(git --git-dir="$DOTGIT" hash-object -w "$license_path")
    git --git-dir="$DOTGIT" update-index --add --cacheinfo 100644 "$hash" "LICENSE"
    echo "[pre-commit] Auto-promoted $license_path → LICENSE"
  fi
fi
```

Then set merge strategy for LICENSE:
```bash
geet git config merge.keep-ours.driver "true"  # if not already set
echo "LICENSE merge=keep-ours" >> .mytemplate/dot-git/info/attributes
```

## Manual Promotion (Advanced)

If you need to promote files without the pre-commit hook:

```bash
# Stage file at original location
geet add .mytemplate/LICENSE.md

# Also stage it at promoted location
hash=$(geet git hash-object -w .mytemplate/LICENSE.md)
geet git update-index --add --cacheinfo 100644 "$hash" LICENSE.md

# Prevent merge conflicts
geet git config merge.keep-ours.driver "true"
echo "LICENSE.md merge=keep-ours" >> .mytemplate/dot-git/info/attributes

# Commit
geet commit -m "Add LICENSE"
```

## When to Use

✅ **Good use cases:**
- `README.md` (essential for GitHub)
- `LICENSE` (if template has different license than app)

⚠️ **Use sparingly for:**
- Config files (consider alternatives first)
- Package manifests (can be confusing)

❌ **Avoid for:**
- Source code (use include/exclude instead)
- Files that change frequently
- Files with complex merge requirements

## Alternatives

**Simple approach (recommended for most files):**

Store template files at their normal location:
- `.mytemplate/docs/USAGE.md`
- `.mytemplate/examples/`

Users get them at these paths when cloning. No promotion needed.

**Post-init hook:**

Copy files during initialization:

```bash
# In .mytemplate/post-init.sh
cp .mytemplate/README.md README.md
```

Works great if you don't need the file visible on GitHub before clone.

## Trade-offs

**Pros:**
- ✅ Template repo looks complete on GitHub
- ✅ Files at expected locations after clone
- ✅ No merge conflicts

**Cons:**
- ⚠️ Adds complexity to git operations
- ⚠️ Can confuse collaborators
- ⚠️ Files exist at two paths in repo
- ⚠️ Custom merge strategy might surprise people

**Recommendation:** Use only when necessary, document clearly, prefer simpler alternatives when possible.
