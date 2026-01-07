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

* creating an app (`myapp`)
* turning a subset of the app into a template, and publishing the template repo (`mytemplate`)
* installing the template and converting it into a new app (`myapp2`), similar to the original app (`myapp`)
* pulling/pushing changes between your three repos (`myapp`, `mytemplate`, and `myapp2`)

👉 **Start here:** [Demo](/demos/DEMO.md)

You’ll “get it” in 5 minutes (hopefully).

---

## Requirements

1. `git`
2. `npm` (to install geet)
3. `gh` (only needed for publishing templates)

---

## Quick start

```bash
npm install -g geet-geet
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

### One-line summary

> geet lets you reuse and evolve templates **inside real projects**, using Git itself — without refactoring, copying files, or changing layouts.


---

### Technical limitations

##### 1. It is difficult to make the main app ignore files from the template repo. (template repo must be a subset of the app)
It is difficult to ignore files in your app repo but commit them to the template repo. This is because git ALWAYS looks at .gitignore files and gives them a higher priority than the `core.excludesFile` variable we use (See docs [here](https://git-scm.com/docs/gitignore))
Solutions:
 1. just commit the whole template to your app. this is the simplest solution, and the one we are leaning into for now to reduce complexity.
 2. Technically we could modify our `.geet-git.sh` file to move the parent's gitignore out of the way as we do the commit and then back into place after, but we promised you no hacks like that and plan to avoid this unless it becomes necessary.
 3. You can add template files using `-f` arg, but that also ignores the `.geetexclude` so could be dangerous. 

---

### Just two git repos?
nope ;)