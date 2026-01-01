# Multi-layered repos

## Extending a template as a new template

When your app evolves into its own reusable template:

```bash
geet template           # creates .MyApp/ layer
geet template sk2       # creates .sk2/ layer
```

This:
* copies tooling from base layer
* installs include/exclude sample
* initializes a new template git repo

Users can now clone **that** template and benefit from both layers.

## How layers stack

```text
MyApp/
  .git/              # app repo (your work)

  .geet/             # base template layer
    dot-git/
    .geetinclude     # defines what base template tracks

  .sk2/              # extended template layer
    dot-git/
    .geetinclude     # defines what this extension tracks
```

Each layer:
* Has its own git repo (separate `dot-git/`)
* Tracks its own subset of files
* Can be pulled independently
* Can be pushed independently

## Example workflow

1. **Start with base template:**
   ```bash
   geet clone github.com/you/base-template MyApp
   cd MyApp
   ```

2. **Build on top of it:**
   ```bash
   # Add app-specific features
   git add .
   git commit -m "Add custom features"
   ```

3. **Promote to new template:**
   ```bash
   geet template mycompany
   # Edit .mycompany/.geetinclude to define what to share
   # Commit to .mycompany layer
   ```

4. **Publish new template:**
   ```bash
   cd .mycompany
   geet gh publish --public
   ```

5. **Others can now use your extended template:**
   ```bash
   geet clone github.com/you/mycompany-template NewApp
   ```

   They get:
    - Base template features (from `.geet/`)
    - Your extensions (from `.mycompany/`)
    - Can pull updates from both independently

## Updating layers independently

```bash
# Pull base template updates
./.geet/lib/cli.sh git pull
git commit -am "Update base template"

# Pull extended template updates
./.mycompany/lib/cli.sh git pull
git commit -am "Update company template"
```

Layers stack cleanly and can evolve independently.

---
