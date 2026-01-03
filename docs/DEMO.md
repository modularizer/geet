# geet Demo

This guide walks you through testing geet's core features in under 10 minutes.

## Prerequisites

```bash
# Install geet globally
npm install -g geet

# Or install from source:
git clone https://github.com/modularizer/geet.git
cd geet
npm install -g .
```

---

## Demo 1: Create and use a basic template

### Step 1: Create normal sample git repo

```bash
# Create a minimal Expo Router app template (5 tiny files)
mkdir myapp
cd myapp

git init

# Create app directory FIRST
mkdir -p app/settings

# 1) Expo Router layout (required)
cat > app/_layout.tsx <<'EOF'
import { Stack } from "expo-router";
export default function Layout(){ return <Stack/>; }
EOF

# 2) Home screen
cat > app/index.tsx <<'EOF'
import { View, Text } from "react-native";
export default ()=> <View><Text>Home</Text></View>;
EOF

# 3) About screen
cat > app/about.tsx <<'EOF'
import { View, Text } from "react-native";
export default ()=> <View><Text>About</Text></View>;
EOF

# 4) Nested route
cat > app/settings/index.tsx <<'EOF'
import { View, Text } from "react-native";
export default ()=> <View><Text>Settings</Text></View>;
EOF

# 5) Minimal Expo config (enables expo-router)
cat > app.json <<'EOF'
{ "expo": { "name":"my-template", "slug":"my-template", "plugins":["expo-router"] } }
EOF

cat > .gitignore <<'EOF'
.idea/
.claude/
.vscode/
EOF

git add .
git commit -m "Minimal Expo Router sample with multiple routes"
```

### Step 2: Initialize the template layer
```bash
geet template mytemplate

# Add files to the template layer
geet add -A
geet commit -m "Initial template layer"

# Push to GitHub (optional)
# geet gh pub
```

### Step 2: Use the template in a new app

```bash
# Clone the template
cd ..
geet clone ./my-template MyApp

# Or if published to GitHub:
# geet clone https://github.com/you/my-template MyApp

cd MyApp

# You now have:
# - A fresh app repo (.git)
# - The template layer (.geet/dot-git)
# - Template files (app/shared/Button.tsx, package.json)
```

### Step 3: Customize your app

```bash
# Add app-specific files
mkdir -p app/custom
cat > app/custom/HomePage.tsx <<'EOF'
import Button from '../shared/Button';

export default function HomePage() {
  return <Button label="Click me" />;
}
EOF

# Commit to your app repo (normal git)
git add .
git commit -m "Add custom home page"

# Your custom files are NOT in the template
geet status  # Should show clean (Button.tsx is in template)
git status   # Should show clean (HomePage.tsx is in app)
```

### Step 4: Update the template

```bash
# Go back to template repo
cd ../my-template

# Update a shared file
cat > app/shared/Button.tsx <<'EOF'
export default function Button({ label, onClick }: { label: string; onClick?: () => void }) {
  return <button onClick={onClick}>{label}</button>;
}
EOF

# Commit to template layer
geet add app/shared/Button.tsx
geet commit -m "Add onClick to Button"
geet push  # Push to template remote
```

### Step 5: Pull template updates in your app

```bash
# Back in your app
cd ../MyApp

# Pull template updates
geet pull

# The changes appear in your working tree
git diff  # Shows Button.tsx changed

# Commit with normal git
git commit -am "Update template"

# Your app now has the updated template
# Your custom files (HomePage.tsx) are untouched
```

---

## Demo 2: Testing include/exclude modes

### Whitelist mode (default)

```bash
mkdir test-whitelist
cd test-whitelist
git init

# Copy geet
cp -r /path/to/geet/.geet .

# Create files
echo "shared" > shared.txt
echo "custom" > custom.txt

# Define whitelist
cat > .geet/.geetinclude <<'EOF'
shared.txt
EOF

git add . && git commit -m "Initial"
./.geet/lib/init.sh

# Check what's in template
geet tree tree
# Output: shared.txt

geet tree contains shared.txt
# Output: included

geet tree contains custom.txt
# Output: excluded
```

### Blacklist mode

```bash
mkdir test-blacklist
cd test-blacklist
git init

# Copy geet
cp -r /path/to/geet/.geet .

# Create files
echo "shared" > shared.txt
echo "custom" > custom.txt

git add . && git commit -m "Initial"
./.geet/lib/init.sh

# Check what's in template
geet tree tree
# Output: shared.txt, .geet/ files

geet tree contains shared.txt
# Output: included

geet tree contains custom.txt
# Output: excluded
```

---

## Demo 3: Post-init hooks

### Create template with post-init hook

```bash
mkdir template-with-hook
cd template-with-hook
git init

# Copy geet
cp -r /path/to/geet/.geet .

# Create a post-init hook
cat > .geet/post-init.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Running post-init setup..."

APP_NAME="${1:-MyApp}"
BUNDLE_ID="${2:-com.example.app}"

echo "App name: $APP_NAME"
echo "Bundle ID: $BUNDLE_ID"

# Example: create .env from template
if [[ -f .env.sample && ! -f .env ]]; then
  cp .env.sample .env
  echo "Created .env from .env.sample"
fi

# Example: update config file
cat > app.config.json <<JSON
{
  "name": "$APP_NAME",
  "bundleId": "$BUNDLE_ID"
}
JSON

echo "Post-init complete!"
EOF

chmod +x .geet/post-init.sh

# Create sample files
echo "API_KEY=your-key-here" > .env.sample

cat > .geet/.geetinclude <<'EOF'
.env.sample
.geet/**
EOF

git add . && git commit -m "Template with post-init"
./.geet/lib/init.sh
geet add -A && geet commit -m "Template layer"
```

### Clone with post-init args

```bash
cd ..

# Clone with arguments
geet clone ./template-with-hook MyNewApp -- "My Cool App" "com.mycoolapp"

cd MyNewApp

# Check results
cat app.config.json
# Output: {"name": "My Cool App", "bundleId": "com.mycoolapp"}

cat .env
# Output: API_KEY=your-key-here (copied from .env.sample)
```

### Skip post-init

```bash
cd ..

# Clone without running post-init
GEET_RUN_POST_INIT=0 geet clone ./template-with-hook AnotherApp

cd AnotherApp

# No app.config.json or .env created
ls -la
```

---

## Demo 4: Multi-layer templates

### Create a base template

```bash
mkdir base-template
cd base-template
git init
cp -r /path/to/geet/.geet .

# Base template files
mkdir -p components
echo "export default function Button() {}" > components/Button.tsx

cat > .geet/.geetinclude <<'EOF'
components/**
EOF

git add . && git commit -m "Base template"
./.geet/lib/init.sh
geet add -A && geet commit -m "Base layer"
```

### Extend it with a second layer

```bash
# Create new layer
geet template mycompany

# Add company-specific files
mkdir -p branding
echo "export const colors = { primary: '#007bff' }" > branding/theme.ts

# Define what this layer tracks
cat > .mycompany/.geetinclude <<'EOF'
branding/**
EOF

# Initialize and commit to the new layer
cd .mycompany
./lib/init.sh
./lib/git.sh add -A
./lib/git.sh commit -m "Company branding layer"
cd ..

# Commit to app repo
git add .
git commit -m "Add company layer"
```

### Clone and get both layers

```bash
cd ..
geet clone ./base-template ExtendedApp

cd ExtendedApp

# You now have:
# - .geet/ layer (base template)
# - .mycompany/ layer (company extensions)

# Pull from base template
./.geet/lib/cli.sh git pull
git commit -am "Update base template"

# Pull from company layer
./.mycompany/lib/cli.sh git pull
git commit -am "Update company template"
```

---

## Demo 5: GitHub integration

### Publish template to GitHub

```bash
cd my-template
# Publish repository
geet gh pub
```

### Use GitHub CLI features

```bash
# List PRs
geet gh pr list

# View repo
geet gh repo view

# Create issue
geet gh issue create --title "Bug report" --body "Something broke"

# Any gh command works
geet gh <any-gh-command>
```

---

## Demo 6: Health checks

### Run doctor

```bash
cd MyApp

# Check repository health
geet doctor
```

**Expected output:**
```
[geet doctor]    repo root: /path/to/MyApp
[geet doctor]    this layer: geet

[geet doctor] ✅ app repo present (.git exists)
[geet doctor] ✅ layer git wrapper present
[geet doctor] ✅ layer init script present
[geet doctor] ✅ include spec present (whitelist mode)

[geet doctor] ✅ layer initialized (dot-git exists)
[geet doctor] ✅ compiled exclude present

[geet doctor] ✅ dot-git is not tracked by app repo
[geet doctor] ✅ app .geetexclude appears to ignore dot-git/

[geet doctor] ✅ layer git wrapper can run git commands
[geet doctor] ✅ layer HEAD resolves

[geet doctor]    detected layers at repo root:
[geet doctor]      .geet  (initialized)

[geet doctor] ✅ doctor looks good
```

---

## Demo 7: Export and session workflows

### Export template files

```bash
cd my-template

# Export tracked files to a clean directory
geet split /tmp/template-export

# Check what was exported
ls -la /tmp/template-export
# Output: Only files from .geetinclude

# Export all whitelisted files (even untracked)
geet split /tmp/template-export-all all
```

### Run isolated builds

```bash
# Run build in isolated environment
geet session run -- npm run build

# Run and copy results back
geet session run --copy-back dist:dist -- npm run build

# Keep temp directory for inspection
geet session run --keep -- npm test
```

---

## Common patterns

### Check what's in template

```bash
geet tree tree              # List all tracked files
geet tree tree all          # List all whitelisted files (even untracked)
geet tree contains app.tsx  # Check if specific file is included
```

### View template status

```bash
geet status                 # Template repo status
geet diff                   # Template repo diff
geet log                    # Template repo log
```

### Commit template changes

```bash
# Make changes to shared files
vim app/shared/Button.tsx

# Commit to template
geet add app/shared/Button.tsx
geet commit -m "Update Button"
geet push

# Changes are now in template repo
# Other apps can: geet pull
```

---

## Cleanup

```bash
# Remove demo directories
rm -rf my-template MyApp test-whitelist test-blacklist
rm -rf template-with-hook MyNewApp AnotherApp
rm -rf base-template ExtendedApp
```

---

## Next steps

1. Read [Understanding geet](../README.md#1-understanding-geet) for concepts
2. Read [Using a geet template](../README.md#2-using-a-geet-template) for user docs
3. Read [Publishing a geet template](../README.md#3-publishing-a-geet-template) for creator docs
4. Try creating your own template for your use case
5. Share your template with your team

---

## Troubleshooting during demo

**Template changes not showing up:**
```bash
geet status    # Check template status
geet doctor    # Run health checks
```

**Confused about what's tracked:**
```bash
geet tree contains path/to/file
geet tree tree
```

**Accidentally committed dot-git/:**
```bash
git rm -r --cached .geet/dot-git
echo "**/dot-git/" >> .geetexclude
git commit -m "Remove dot-git from tracking"
```

**Post-init not running:**
```bash
# Check if executable
ls -la .geet/post-init.sh
chmod +x .geet/post-init.sh

# Check if skipped
echo $GEET_RUN_POST_INIT  # Should be unset or "1"
```
