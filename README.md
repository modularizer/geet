# geet — layered template system
https://github.com/modularizer/geet

> **One working directory**. **Multiple Git repositories**. Each repo tracks a different subset of files.

Nothing moves.
Nothing is copied.
Only Git's *view* of the filesystem changes.

## Why?
>   “I built something useful, and I think that **SOME but not all of my code is re-usable**.
    I want to publish some of my code for other's to use (or to re-use myself)...
    but **I don't want to spend weeks refactoring** to split apart the reusable code from the implementation-specific code.
    In fact, it may not even be possible to move around all my files without breaking things. 
    Plus, supporting this template is my **secondary task** which I want to do in tandem with my **primary development**, using my main repository's working directory and publishing some pieces to the template repo.”

- **Making code re-usable is a struggle**, especially if you want to ship an incomplete template that is not easily separated into a standalone module.
- Modern React Native / Expo apps are **extremely path-sensitive**:
  * file-based routing
  * config files at exact paths
  * native folders
  * toolchains that assume canonical layouts
- templates are not static: they evolve over time. I don't want to wait until a template is fully perfect before adding to my project, and I want to get features and fixes as the come
- syncing sucks
- submodules don't support interleaving files and folders of template code with custom app code
- I want to simultaneously develop many apps with a similar architecture

---

## Quickstart
```bash
npm install -g geet-geet
geet
```

Try our [Demo](/docs/DEMO.md)

---

## Table of Contents

1. [Understanding geet](/docs/UNDERSTANDING_GEET.md)
2. [Using a geet template](/docs/USING_A_TEMPLATE.md)
3. [Publishing a geet template](/docs/PUBLISHING_A_TEMPLATE.md)
4. [Multi-layered repos](/docs/MULTI_LAYERED_TEMPLATES.md)
5. [Advanced: File promotion](/docs/AUTO_PROMOTE.md)
6. [Advanced: Merge keep-ours strategy](/docs/MERGE_KEEP_OURS.md)
7. [Advanced: Preventing app-specific code](/docs/PREVENT_COMMIT_PATTERNS.md)
8. [Contributing to geet](/docs/CONTRIBUTING.md)
9. [FAQ](/docs/FAQ.md)
10. [Demo](/docs/DEMO.md)