# geet — layered template system
https://github.com/modularizer/geet

> **One working directory**. **Multiple Git repositories**. Each repo tracks a different subset of files.

Nothing moves.
Nothing is copied.
Only Git's *view* of the filesystem changes.

## Why?

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

## Table of Contents

1. [Understanding geet](/docs/UNDERSTANDING_GEET.md)
2. [Using a geet template](/docs/USING_A_TEMPLATE.md)
3. [Publishing a geet template](/docs/PUBLISHING_A_TEMPLATE.md)
4. [Multi-layered repos](/docs/MULTI_LAYERED_TEMPLATES.md)
5. [Contributing to geet](/docs/CONTRIBUTING.md)
6. [FAQ](/docs/FAQ.md)
7. [Demo](/docs/DEMO.md)


## Quickstart
```bash
git clone https://github.com/modularizer/geet.git
cd geet
npm install -g .
geet
```