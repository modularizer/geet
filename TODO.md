# Possible future features

### A. Better `geet init` or `geet setup` step for apps that already track a template repo
This feature would allow for quick setup/clone of a app/template combo.

1. first, the user clones the app repo which already tracked the template repo's $TEMPLATE_DIR
2. we already know the template repo's git ref, so we can clone it directly into the app repo's working directory, using the .geetinclude mappping file to help resolve conflicts
3. make sure to also sync "$TEMPLATE_DIR/parent-git-info-exclude" line by line to the app repo's .git/info/exclude so the app doesn't track template files it is supposed to ignore


### B. Major feature: "Follower mode"
Use hooks (pre-commit, post-checkout, etc.) or a differnet cli in the APP repo to make the template repo intelligently "follow" the app repo

- app repo makes a branch -> template repo makes a branch with the same name
- app repo switches branches -> template repo switches branches
- app adds/removes files -> template repo adds/removes files that are in the .geetinclude mapping
- app repo commits -> template repo commits
- app repo pushes -> template repo pushes
- app repo pulls -> template repo pulls
- app repo resets -> template repo resets

This feature is not ready yet and could easily go wrong, it needs more brainstorming before we decide how/if to proceed


### C. Medium Feature: "live split"
A live-split folder using symlinks  or similar to allow a file-system view of the template repo and maybe even a file-system view of the app repo.

e.g. Most of the time you work in the joint working directory, but sometimes you want to work in only the template repo or only the app repo.
We already have `geet split` and `geet session`, so this would be similar. Not positive if this is necessary, but it's a possibility.


### D. Separate mini-project: IDE tools
Brainstorm ways to integrate geet into popular IDEs like VSCode, IntelliJ, etc.

Kinda saving this for later, because the more we can simplify the geet CLI, the less plugins we'll need.

### E. Auto-convert/ Cleaner divergence files
Maybe when we diverge a file we could record either a git diff, a patch, or a sed command and then reapply on updates.

* Scene: we have a index.tsx that references "soccer" which is not allowed in our "sport" template.
* index.tsx is not yet tracked
* we copy the file to index.template.tsx, simply replacing the "soccer" with "sport" on one line
* we commit index.template.tsx to the template repo as index.tsx
* the template repo updates index.tsx, which is locally known as index.template.tsx with an unrelated change
* how can we automatically update index.tsx to match index.template.tsx, without losing the "soccer" -> "sport" change?
* or in the reverse scenario, the app repo updates index.tsx, how can we apply those changes to index.template.tsx, without losing the "soccer" -> "sport" change?
* can we somehow record that index.template.tsx = index.tsx + diff(index.tsx, index.template.tsx)??

Look into patch files, maybe we can use them to record the diff?

### F. Auto-import checker
When we include a new file, automatically check its imports and references to see if we are missing another file it depends on that we must include as well.

### H. Add `geet spawn`
Similar to `geet install`, but run from inside the source template repo or even the source app repo.

### I. make `geet` work in standalone template repo installs
or atleast make it super clear why it doesn't work...
I get it, but I want to make sure everyone understands why they should just use normal `git` in a standalone install.

### J. Add `geet mod` to modify a file into a `.template` version
basically just call `sed`

### H. Add instructions for Intellij "External Tools" setup

### K. Add `geet bind`
"bind" a normal app repo to an unrelated template repo that is similar but has no true connection.

e.g. maybe someone has an app they previously cloned from a template repo, not using geet, and now the template has been update and they want to use `geet` to manage the relationship.

### L. Assess windows support