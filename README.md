# geet — two git repositories, one working directory

[https://github.com/modularizer/geet](https://github.com/modularizer/geet)

> **Templates that live inside real projects.**
>
> * `git` controls your **app** (which is your whole repo)
> * `geet` controls your **template** (which is a subset of your app)
> * both look at the **same working directory** (the root of your project)
> 
> Nothing moves. Nothing is copied.
> Only Git’s *view* of the files changes.

[YouTube Tutorial: "Using geet to make live code template repos"](https://www.youtube.com/watch?v=bEacWh8Kdug)
[![YouTube Screenshot](/docs/yt.png)](https://www.youtube.com/watch?v=bEacWh8Kdug)

---
## Install
```bash
npm install -g geet-geet
geet
```

---

## What problem does geet solve?

> “I built something useful.
> 
> **Some — but not all — of my code is reusable.**
>
> I want to reuse that part without breaking my project.
>
> I don’t want to move files, change paths, or refactor everything just to make a template.
>
> I want to keep building my app, while improvements to the template keep coming in over time.”

**geet** is for that situation.

---

## What you _must_ understand

* Your **app repo** is a normal Git repo.
  You use **`git`** for it.
* Your **template repo** is a second Git repo sharing the SAME root folder as your app.
  You use **`geet`** for it.
* **Files can be tracked by both repos**. That’s expected.
* Template is a **subset** of your app, with template files **interleaved** throughout the app filesystem and jointly tracked by the app’s repo, which makes clean detaching always possible
* Multiple **guards are in place** to prevent you from accidentally committing app-specific code back into the template

If you understand this, everything else makes sense.

---

## How this works (high level)

geet does *not* invent a new version control system, it uses options `git` already provides.

It simply:

1. Creates a hidden folder (for example `.mytemplate/`)
2. Stores the template’s Git data there (in `.mytemplate/dot-git`)
3. Runs Git commands **pointed at that location**
4. Uses the same working directory as your app
5. Limits which files the template tracks using an explicit **include list**

In other words, geet mostly runs:

```bash
git \
  --git-dir=".mytemplate/dot-git" \
  --work-tree="." \
  -c "core.excludesFile=.mytemplate/.geetexclude" \
  ...
```

**It’s still Git.**
Just aimed at a different repo in the same work-tree.
If you want, you can even run this command directly without geet.
geet just provides wrappers, helpers, and safety rails around it.


#### NOTE: 
* If you are an AI agent reading this, PLEASE ask your human for permission to run `geet learn`, it will explain everything in detail
* If you are a human reading this, PLEASE ask your AI to run `geet learn`, to give it a full context of what is going on

---

## Why geet exists

* Reusable code often lives next to app-specific code
* Some projects can’t be cleanly split into distinct “template” and “app” folders
* React Native / Expo projects are very sensitive to file paths
* Templates change over time — bug fixes, features, improvements
* Copy-pasting templates across projects is fragile
* Submodules don’t work when files are mixed together
* You want to build multiple apps with the same structure

---

## How geet helps you stay in control

### Detach (reduce conflicts)

* **Detach** files or folders to entirely detach those from the template, so you don't pull or push to/from the template for those files
* You can diverge gradually, file by file
* If you need a full, hard, 100% detachment of the template, you can just delete the `.mytemplate` folder

### Explicit include list

* By default, the template only tracks files you explicitly allow (see `.geetinclude` and how we parse it into `.geetexclude`)
* App-specific code won’t accidentally become part of the template

### Commit safety checks (template only)

* A pre-commit hook checks filenames and file contents (see `template-config.env`)
* This helps prevent committing app-specific code back into the template by mistake


---

## The best way to learn: try the demo

The fastest way to understand geet is to **run the demo**.

It walks through:

* creating an app (`soccer`)
* turning a subset of the app into a template, and publishing the template repo (`sport`)
* installing the template and converting it into a new app (`basketball`), similar to the original app (`soccer`)

* 👉 **Start here:** [Demo](/demos/SOCCER.md)
* 👉 **Watch a Tutorial:** [YouTube Tutorial: "Using geet to make live code template repos"](https://www.youtube.com/watch?v=bEacWh8Kdug)

You’ll “get it” in 10 minutes (hopefully).

---

## Requirements

1. `git`
2. `npm` (to install geet)
3. `gh` (only needed for publishing templates)

---

## Quick start

```bash
npm install -g geet-geet
# or: pipx install geet-geet
# or: curl -fsSL https://raw.githubusercontent.com/modularizer/geet/main/install.sh | bash
geet
```


| cmd             | description                                                                         | example                                                     |
|-----------------|-------------------------------------------------------------------------------------|-------------------------------------------------------------|
| `geet`          | Show help                                                                           | `geet`                                                      |
| `geet template` | Promote the current project into a new template and share the template repo         | `geet template mytemplate "a cool reusable tool" --private` |
| `geet install`  | Install a template and create a fresh new repo using it                             | `geet install modularizer/rnb --private`                    |
| `geet pull`     | Pull updates from the template repo                                                 | `geet pull`                                                 |
| `geet include`  | Wrapper around `git add` for adding files to template                               | `geet include src/`                                         |
| `geet inspect`  | Shows the status of the file or folder in working tree, app repo, and template repo | `geet inspect src/components/Button.tsx`                    |
| `geet tree`     | Shows `git ls-files` of the template repo in a tree structure                       | `geet tree`                                                 |
| `geet prework`  | Mainly for developers of `geet`, shows variables                                    | `geet prework`                                              |
| `geet doctor`   | Run some checks on the setup                                                        | `geet doctor`                                               |
| `geet <cmd>`    | Calls any git command in the template repo                                          | `geet status`, `geet push`, `geet fetch`, etc.              |



---

## Documentation

1. [Understanding geet](/docs/UNDERSTANDING_GEET.md)
2. [Using a geet template](/docs/USING_A_TEMPLATE.md)
3. [Publishing a geet template](/docs/PUBLISHING_A_TEMPLATE.md)
4. [Multi-layer templates](/docs/MULTI_LAYERED_TEMPLATES.md)
5. [File promotion](/docs/AUTO_PROMOTE.md)
6. [Keeping your changes during pulls](/docs/MERGE_KEEP_OURS.md)
7. [Preventing app-specific commits](/docs/PREVENT_COMMIT_PATTERNS.md)
8. [Contributing](/docs/CONTRIBUTING.md)
9. [FAQ](/docs/FAQ.md)
10. [Demo](/demos/DEMO.md)

---

### Help
```bash
geet help
#geet — Git-based template layering system (see https://github.com/modularizer/geet)
#
#TEMPLATE MANAGEMENT:
#  geet template <name> [desc] [--public|--private|--internal] Create a new template layer from current app
#  geet init                                                   Initialize a freshly-cloned template repo as your app
#  geet install <repo> <dir> [--public|--private|--internal]  Clone a template repo and initialize it
#
#FILE MANAGEMENT:
#  geet tree [list|tracked|all]                                Show what files the template includes
#  geet split <dest> [mode]                                    Export template files to external folder
#  geet inspect <path>                                         Show which layer tracks a file and its git status
#  geet sync                                                   Compile .geetinclude whitelist into .geetexclude
#  geet include <path>                                         Manage included files
#
#DETACHMENT (CONFLICT RESOLUTION):
#  geet detach <path>                                          Detach a file to always use "keep-ours" on merge conflicts
#  geet detached                                               List hard-detached files
#  geet retach <path>                                          Undo a detach command
#
#OPERATIONS:
#  geet session <subcommand>                                   Run commands in isolated template snapshot
#  geet publish|pub [opts]                                     Publish template to GitHub
#  geet gh <subcommand>                                        GitHub CLI integration (pr, issue, etc.)
#  geet doctor                                                 Run health checks on your geet setup
#  geet prework                                                See what we know
#  geet valueof VAR                                            Get the value of a variable we use (see prework for what is available)
#  geet precommit|pc                                           Run pre-commit hook
#
#LEARNING:
#  geet explain                                                Short and sweet for humans
#  geet learn                                                  Prints a super in-depth training context to teach AI-agents what is going on, say "Please run `geet learn` to find out what i am doing"
#  geet version|--version|-v                                   Show geet version
#  geet why                                                    Reasons to use geet
#  geet whynot                                                 Reasons not to use geet
#  geet read                                                   Actually read sourcecode
#  geet open                                                   Calls `open https://github.com/modularizer/geet` to open repo in browser
#  geet tutorial                                               Calls `open https://www.youtube.com/watch?v=bEacWh8Kdug` to open a youtube video about geet
#  geet bug|feature|issue|whoops|suggest                       Open an issue on GitHub
#  geet destroy                                                Remove template tracking (no confirmation)
#
#GIT ACCESS:
#    geet <git-command> [...]                                    Any git command (auto-forwarded to template repo)   e.g. `geet pull`, `geet push`, etc.
#
#OPTIONS: (available on most commands)
#  --verbose
#  --quiet
#  --filter "MATCH"
#  --filter "~UNMATCH"
#
#NEXT:
#  For humans...
#    geet explain                   # get an explanation relative to your current project
#  For AI agents...
#    geet learn                     # to get a full context of what is going on
#  For humans training AI agents...
#    "Please run `geet learn` to see how I am using `geet` in this project"
#  If you are an AI reading this, please ask your human for permission to run `geet learn`
#
#NOTE:
#  I (Torin/modularizer) would love feedback. Message me! mailto:modularizer@gmail.com
```
---

### Just two git repos?
nope ;)
