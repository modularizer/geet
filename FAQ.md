## FAQ

### What is geet?

**Geet lets you maintain a reusable template as a real Git repo over the same working tree as your app, without copying files, moving paths, or running generators.**

In practice: two or more Git repos, one folder.

---

### How is this different from a normal template?

Normal templates:

* copy files once
* drift immediately as the template owner makes updates and changes
* require regeneration or manual syncing

Geet:

* shares *real files at real paths*
* updates via `git pull`
* never copies or regenerates code

---

### How is this different from Git submodules?

Submodules:

* live in a subdirectory
* can’t interleave files with the app
* break path-sensitive systems (Expo, routing, config)

Geet:

* works **at the project root**
* files stay exactly where the app expects them
* no nested repos in your source tree

**NOTE**: If you have the ability to fully and cleanly separate your template into a separate folder, consider using submodules instead. Geet is made for cases where that is not feasible.

---

### How is this different from Git subtrees?

Subtrees:

* still copy files into the repo
* still requires a separate folder for the template, does not support interleaving
* updates are noisy and opaque
* merges become painful over time

Geet:

* no copying
* no sync step
* updates are normal Git merges

---

### Why not monorepos?

Monorepos:

* assume clear ownership boundaries
* don’t work well when *most* files overlap
* still require indirection or abstraction

Geet is for cases where:

* 50–90% of files are shared
* file locations are non-negotiable
* you want minimal abstraction

---

### Is this safe?

Yes, if used as intended.

* The app repo remains totally standard.
* The template repo is sandboxed via a whitelist.
* Destructive Git commands are blocked by default.
* You can detach at any time by deleting the layer folder.

---

### Is this a Git hack?

Yes — deliberately.

Git already supports:

* separate `GIT_DIR`
* shared working trees
* repo-local ignore rules

Geet just assembles those primitives into a usable tool.

---

### Who is geet for?

* Teams maintaining multiple similar apps
* Path-sensitive frameworks (Expo, RN, Next, native builds)
* Developers who want **Git-native updates**, not generators
* Anyone burned by templates that drift

---

### When should I *not* use geet?

Don’t use geet if:

* your template can live in a subdirectory
* copying files is acceptable
* your shared code is small or purely library-based

Geet is for the “everything overlaps” case.

---

If you want, next we can:

* tighten this FAQ even more
* add a “When geet is the wrong tool” section
* or turn this into a README-ready block
