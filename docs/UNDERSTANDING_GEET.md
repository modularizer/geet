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

## Who this is for

* Teams maintaining **multiple similar apps**
* Templates that must live at **canonical paths**
* Developers who want **git-native updates**
* Anyone burned by starter kits drifting over time

If your template can't afford to move files, this is the least-bad solution.

---