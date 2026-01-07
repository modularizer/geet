# Demos

We use git submodules for the "soccer" demo source-code.

Yes! You read that right! We are proud to recognize that `geet` and `git submodules` have two very distinct purposes.
For the purpose of tracking a single, self-contained folder, submodules are perfect.

## Setup
```bash
git submodule update --init --recursive
```

## 1. Setup your "App"
1.1. Clone soccer repo and setup initial state
```bash
git clone https://github.com/modularizer/geet-soccer-demo.git soccer
cd soccer
```

1.2. Try out soccer app (it is SUPER basic)
```bash
cp example.env .env
npm install
npm start
```

**NOTE:** So far, `soccer` has absolutely no clue we plan to use `geet` to build a template from it. Think of `soccer` as ANY git project you may have.

## 2. Setup your "Template"
### 2.1. Make a template git repo
```bash
geet template sport "a sport template built from the geet-soccer-app"
```

### 2.2. Start telling `soccer` about `sport`
The cat is out of the bag! We are planning to build a template from `soccer`.

Here is the thing...
- it is **not mandatory** for you to commit `.sport` or any template-specific files to your repo
- but I don't see much reason **not** to do so, and there are many benefits
- you **must** ensure tyour app repo (`soccer`) does not accidentally commit `.sport/dot-git` folder

2.2.1. Ignore "soccer" in `.sport/semitracked-config.env` to avoid committing anything soccer-specific to the template repo
```bash
sed -i 's/PREVENT_COMMIT_FILE_PATTERNS_2=""/PREVENT_COMMIT_FILE_PATTERNS_2="soccer"/g' .sport/semitracked-template-config.env
sed -i 's/PREVENT_COMMIT_CONTENT_PATTERNS_2=""/PREVENT_COMMIT_CONTENT_PATTERNS_2="soccer"/g' .sport/semitracked-template-config.env
```

2.2.2. (optional) Commit the new template (.sport) to "soccer" repo
```bash
git add .sport
git commit -m "add sport template"
```

### 2.3. Build the template
2.3.1. Use `geet include` to add any fully generic files to the template repo (it should )
```bash
geet include app/_layout.tsx
geet include app/index.tsx
geet include app/stats.tsx
geet include components/StatItem.tsx
geet include theme/colors.ts
geet include consts.ts
geet include tsconfig.json
geet include quickstart.sh
```

2.3.2. "Accidentally" include a file containing one of our patterns ("soccer") to see it barf
```bash
geet include app/teams.tsx
#>>> ❌ [geet include] Found patterns that may indicate app-specific code:
#>>> 
#>>>   CONTENT: app/teams.tsx matches pattern: soccer
#>>>   → 3:import SoccerTeamCard from '../components/SoccerTeamCard';
#>>>   CONTENT: app/teams.tsx matches pattern: soccer
#>>>   → 18:              <SoccerTeamCard
#>>> 
#>>> These patterns suggest implementation-specific code that shouldn't be in the template.
#>>> 
#>>> To fix: Remove the matched patterns or update template-config.env, semitracked-template-config.env, or untracked-template-config.env
```

2.3.3. Make a `app/teams.template.tsx` from `app/teams.tsx` for your template to use
This is **special**...
- `app/teams.template.tsx` will enter the `sport` repo as `app/teams.tsx` but show up in your `soccer/` working directory as `app/teams.template.tsx`
- `app/teams.template.tsx` will be ignored by the soccer repo

```bash
sed 's/Soccer/Sport/g; s/soccer/sport/g' app/teams.tsx >  app/teams.template.tsx

geet include app/teams.template.tsx
```

2.3.4. Make a generic `SportTeamCard.tsx` from `SoccerTeamCard.tsx` for your template to use
```bash
sed 's/Soccer/Sport/g; s/soccer/sport/g' components/SoccerTeamCard.tsx >  components/SportTeamCard.tsx

geet include components/SportTeamCard.tsx --discreet  # adding as --discreet will keep it untracked by `soccer` by adding to soccer's .git/info/exclude
```

2.3.5. Do the same for `app/sample-data`
```bash
cp sample-data/index.ts sample-data/index.template.ts
sed -i 's/Soccer/Sport/g; s/soccer/sport/g;' sample-data/index.template.ts
geet include sample-data/index.template.ts

echo -e 'export const stats = [{ label: "Total Goals", value: 0 },];\n' >> sample-data/sport-stats.ts
geet include sample-data/sport-stats.ts --discreet

cat <<'EOF' > sample-data/sport-teams.ts
export interface SportTeam {
    name: string;
    wins: number;
    losses: number;
    goalsScored: number;
    cleanSheets: number;
    formation: string;
}

export const teams: SportTeam[] = [
  { name: 'Hornets', wins: 3, losses: 2, goalsScored: 5, cleanSheets: 1, formation: '4-3-3' },
];
EOF
geet include sample-data/sport-teams.ts --discreet
```

2.3.6. Add a new favicon as favicon.template.svg
```bash
cat <<'EOF' > favicon.template.svg
<svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
  <!-- circle -->
  <circle cx="16" cy="16" r="15" fill="white" stroke="#333" stroke-width="1"/>
</svg>
EOF

geet include favicon.template.svg
```

2.3.7. Setup app.json, package.json, package-lock.json
```bash
sed 's/Soccer/Sport/g; s/soccer/sport/g' app.json > app.template.json
geet include app.template.json
sed 's/Soccer/Sport/g; s/soccer/sport/g' package.json > package.template.json
geet include package.template.json
sed 's/Soccer/Sport/g; s/soccer/sport/g' package-lock.json > package-lock.template.json
geet include package-lock.template.json
```

2.3.8. Setup `example.env`
```bash
cat <<'EOF' > example.template.env
EXPO_PUBLIC_APP_NAME="Sport App"
EXPO_PUBLIC_SPORT_NAME=sport
EXPO_PUBLIC_SPORT_EMOJI=🏆
EOF

geet include example.template.env
```


2.3.9. Check the template repo status
- use `geet` custom commands...
    - `geet tree` does `git ls-files` in a tree-like format
    - `geet inspect app` shows an overview of the app/ folders files and statuses
    - `geet inpect app/teams.tsx` shows a more in-depth analysis of that file
    - `geet split [dst]` is a tool which can create a worktree of your template repo
- ...or any git commands...
    - `geet status`
    - `geet ls-files`
    - `geet cat-files -p :app/teams.tsx`

2.3.10. Test using `geet session`

`geet session` will create a temporary worktree of the template repo using `geet split` and run a command inside of it

Therefore, you can run
```bash
geet session -- bash quickstart.sh
# then open http://localhost:8081
```

2.3.11. Commit!
```bash
geet commit -m "add content to sport template"
#checking if we need to auto-promote the template's readme...
#readme_path not in diff
#checking if we need to auto-promote the template's parent gitignore...
#checking if we accidentally commited any protected files...
#checking for more precommit hooks...
#checking for user-define hooks in /home/mod/Code/geet/demos/soccer/.sport/pre-commit...
#made it through precommit!
#[master 8aac0ca] add sport template
# 20 files changed, 12112 insertions(+)
# create mode 100644 app.json
# create mode 100644 app/_layout.tsx
# create mode 100644 app/index.tsx
# create mode 100644 app/stats.tsx
# create mode 100644 app/teams.tsx
# create mode 100644 components/SportTeamCard.tsx
# create mode 100644 components/StatItem.tsx
# create mode 100644 consts.ts
# create mode 100644 example.env
# create mode 100644 favicon.svg
# create mode 100644 package-lock.json
# create mode 100644 package.json
# create mode 100755 quickstart.sh
# create mode 100644 sample-data/index.ts
# create mode 100644 sample-data/sport-stats.ts
# create mode 100644 sample-data/sport-teams.ts
# create mode 100644 theme/colors.ts
# create mode 100644 tsconfig.json
```



### 2.4. (optional) Commit the template changes to your app repo
```bash
git commit -m "add content to sport template"
```

## 3. Setup a new repo from the template
### 3.1. clone and install
```bash
geet split ../sport  # split the template repo into a new folder
cd ..
geet install sport basketball # this will do a clone from the template repo into basketball and then setup a new basketball repo based on it
cd basketball
```

### 3.2 edit files
```bash
cat <<'EOF' > favicon.svg
<svg width="32" height="32" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">
  <!-- basketball base -->
  <circle cx="16" cy="16" r="14" fill="#F28C28"/>

  <!-- basketball lines -->
  <path d="M2 16h28" stroke="#1a1a1a" stroke-width="1.5"/>
  <path d="M16 2v28" stroke="#1a1a1a" stroke-width="1.5"/>
  <path d="M5 5c8 8 8 14 0 22" stroke="#1a1a1a" stroke-width="1.5" fill="none"/>
  <path d="M27 5c-8 8-8 14 0 22" stroke="#1a1a1a" stroke-width="1.5" fill="none"/>
</svg>
EOF
cat <<'EOF' > README.md
# Basketball

This is just a demo repo made using the sport template using [`geet`](https://github.com/modularizer/geet).
EOF
cat <<'EOF' > .env
EXPO_PUBLIC_APP_NAME="Basketball App"
EXPO_PUBLIC_SPORT_NAME=Basketball
EXPO_PUBLIC_SPORT_EMOJI=🏀
EOF
```

### 3.3 install and run
```bash
npm install
npm start
```

### 3.4 commit to the basketball repo
```bash
git commit -am "add basketball template"
```

### 4. Learn how co-development and conflict resolution works
- There are currently THREE git installs of the `sport` repo
    - the original in `soccer/` worktree, with .git at `soccer/.sport/dot-git`
        - use `geet` to refer to the sport repo from `soccer/`
    - the fresh clone of `sport/` worktree, with .git at `sport/.git`
        - this is the "true" representation of the template repo
        - use `git` to refer to the sport repo from `sport/`
    - the install in the `basketball/` worktree, with .git at `basketball/.sport/dot-git`
        - use `geet` to refer to the basketball repo from `basketball/`
- in this demo we did not setup a GitHub repo and remote for `sport`, but we easily could have done so
    - In step 2.1, adding `--private`, `--public`, or `--internal` to the `geet template` command would have created a GitHub repo for use (through use of the `gh` cli)
    - If we had a gh repo, we could have done step 3 as `geet install modularizer/sport basketball`
- ANY of the three installs of `sport/` could push/pull to/from our template repo
- On `geet pull` if the incoming changes conflict with the local files, instead of merging them in, they will be written to a `.template` file
    - e.g. `basketball/app/teams.tsx` was modified locally with basketball-specific changes
    - `sport/app/teams.tsx` was modified remotely with a bugfix
    - `geet pull` from `basketball` will write the bugfix from `sport` to `basketball/app/teams.template.tsx`
    - it will then be up to the user to decide whether to keep the basketball-specific changes or the sport-specific changes
    - the idea behind this approach is it allows the `basketball` repo full privileges to own and modify the files in its worktree
    - the `basketball` repo can pull template feature adds and bugfixes without worrying about overwriting local changes