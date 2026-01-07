# geet Demo

This guide walks you through testing geet's core features in under 10 minutes.

## Prerequisites

```bash
npm install -g geet-geet
```

---

### Step 1: Create normal sample git repo
There is nothing special about this repo. It has no clue it will become a geet template.
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
#make a template git repo and publish to github
geet template mytemplate "just a demo template" --private  # Note: if you omit --private we wont push to github, if you use --public or --internal it will use that visibility

# Add some of the app files to the template layer (geet include modifies the .geetinclude then calls geet add)
geet include "app/index.tsx" "app/_layout.tsx" "app/about.tsx"
geet commit -m "Initial template layer"
geet push
```

### Step 3: Use the template in a new app

```bash
cd ..
# Clone and set up the template
geet install <your-github-username>/mytemplate MyApp2 --private # Note: if you omit --private we wont push to github, if you use --public or --internal it will use that visibility
```

### Step 3: Customize your app (MyApp2)

```bash
cd MyApp2
# Add app-specific files
cat > app/welcome.tsx <<'EOF'
import { View, Text } from "react-native";
export default ()=> <View><Text>Welcome</Text></View>;
EOF

# Commit to your app repo (normal git)
git add .
git commit -m "Add custom home page"
git push

# Your custom files are NOT in the template
geet status  # Should show clean (welcome.tsx is not in the template (yet) and is ignore by the template layer)
git status   # Should show clean (welcome.tsx is in app)

# validate welcome.tsx is not in the template
geet included app/welcome.tsx
geet ls-files | grep welcome
```

### Step 4: Update the template from MyApp2

```bash
# Later on if you want to add welcome.tsx to the template:
geet include app/welcome.tsx
geet commit -m "Add welcome page to template"
geet push
```

### Step 5: Pull template updates in your app MyApp

```bash
# Back in your app
cd ../MyApp

# Pull template updates
geet pull

# The changes appear in your working tree
git diff  # Shows welcome.tsx changed

# Commit with normal git
git commit -am "Pulled in an update to welcome.tsx made by the template repo"

```
