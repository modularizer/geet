quick_status(){
  if [[ -n "$TEMPLATE_NAME" ]]; then
    local template_files_count=$(geet ls-files 2>/dev/null | wc -l)
    local template_modified=$(geet status --short 2>/dev/null | grep -c '^ M' || echo 0)
    local app_modified=$(git status --short 2>/dev/null | grep -c '^ M' || echo 0)
    local app_branch=$(git branch --show-current 2>/dev/null || echo "unknown")

cat <<EOF
=== QUICK CONTEXT ===
App Repo: $APP_NAME (branch: $app_branch)
Template Repo: $TEMPLATE_NAME
Working Directory: $APP_DIR
Template tracking: $template_files_count files
Uncommitted changes: $template_modified template files, $app_modified app files
=====================
EOF
  fi
}

machine_metadata(){
  if [[ -n "$TEMPLATE_NAME" ]]; then
    local template_files=$(geet ls-files 2>/dev/null | wc -l)
cat <<EOF
# GEET_METADATA_V1
app_repo: $APP_NAME
template_repo: $TEMPLATE_NAME
working_dir: $APP_DIR
template_files_count: $template_files
has_template: true
# END_METADATA
EOF
  fi
}

explain(){
  if [[ -n "$TEMPLATE_NAME" ]]; then
cat <<EOF
1. \`geet\` points to the template repo ( $TEMPLATE_NAME )
  * you can use normal git commands like \`geet pull\`, \`geet commit\`, \`geet push\`, etc.

2. \`git\` continues to track the main app repo ( $APP_NAME )
  * use \`git\` for your app repo ( $APP_NAME ) exactly as you normally would

3. both $TEMPLATE_NAME and $APP_NAME share the same working directory ( $APP_DIR )

4. only a subset of files in the app repo ( $APP_NAME ) are tracked by the template repo ( $TEMPLATE_NAME )
  * use \`geet include <path>\` to add files to the template repo ( $TEMPLATE_NAME ), then \`geet commit\`, \`geet push\`, etc. to update the template repo

5. occasionally, you may need a separate version of the same file...
  * In this case, use the \`.template\` suffix:
    * \`app.template.tsx\` gets automatically committed to the template repo ( $TEMPLATE_NAME ) as \`app.tsx\`
    * \`app.tsx\` is the version tracked by the app repo ( $APP_NAME )

6. occasionally, you may want to add a file ONLY to the template repo ( $TEMPLATE_NAME ), not the app repo ( $APP_NAME )
  * use \`geet include <path> --discreet\` to put it in the template repo while appending to \`.git/info/exclude\` to ignore it in the app repo

7. use \`geet help\` to see more commands, or read more at https://github.com/modularizer/geet

8. I (Torin/modularizer) would love receive feedback or provide help. Message me! mailto:modularizer@gmail.com
EOF

else
  cat <<EOF
It looks like you are not in a geet project yet...
If you were...

1. \`geet\` would point to the template repo ( e.g. sport )
  * you can use normal git commands like \`geet pull\`, \`geet commit\`, \`geet push\`,

2. \`git\` would continues to track the main app repo ( e.g. soccer )

3. both sport and soccer would share the same working directory ( e.g. ~/soccer/ )

4. only a subset of files in the app repo ( soccer ) would get tracked by the template repo ( sport )
  * use \`geet include <path>\` to add files to the template repo ( sport ), then \`geet commit\`, \`geet push\`, etc. to update the template repo

5. occasionally, you may need a separate version of the same file...
  * In this case, use the \`.template\` suffix:
    * \`app.template.tsx\` gets automatically committed to the template repo as \`app.tsx\`
    * \`app.tsx\` is the version tracked by the app repo

6. occasionally, you may want to add a file ONLY to the template repo ( sport ), not the app repo ( soccer )
  * use \`geet include <path> --discreet\` to put it in the template repo while appending to \`.git/info/exclude\` to ignore it in the app repo

7. use \`geet help\` to see more commands, or read more at https://github.com/modularizer/geet

8. I (Torin/modularizer) would love receive feedback or provide help. Message me! mailto:modularizer@gmail.com
EOF

fi
}

explain_hidden(){
  if [[ -n "$TEMPLATE_NAME" ]]; then
cat <<EOF
The "admin" files for controlling the template repo ( $TEMPLATE_NAME ) from inside the app repo ( $APP_NAME ) are located in the .$TEMPLATE_NAME/ folder

* .$TEMPLATE_NAME/semitracked-template-config.env defines some case-insensitive patterns used by our precommit hooks to avoid commiting app-specific code to the template repo
  * these patterns are also used when we call \`geet include\` so we see the error as early as possible

* .$TEMPLATE_NAME/.geetinclude shows the files that are included in the template
  * you should not need to manually edit .$TEMPLATE_NAME/.geetinclude as that is handled by  \`geet include\`
EOF
fi
}

common_workflows(){
cat <<EOF
    === COMMON WORKFLOWS ===
    Adding a file to template:
      geet include path/to/file
      geet commit -m "message"
      geet push

    Pulling template updates into app:
      geet pull
      # resolve conflicts if any
      git commit -m "merged template updates"

    Checking what's in the template:
      geet tree

    Finding which repo tracks a file:
      geet inspect path/to/file
    ===========================
EOF
}

critical_warnings(){
  if [[ -n "$TEMPLATE_NAME" ]]; then
cat <<EOF
=== CRITICAL: WHAT NOT TO DO ===
❌ DON'T use \`git add\` to add NEW files to template - use \`geet include\` instead
❌ DON'T manually edit .$TEMPLATE_NAME/.geetexclude (auto-generated from .geetinclude)
❌ DON'T commit app-specific code to template (pre-commit hooks will block)

NOTE: Template files are often tracked by BOTH repos
  • Use \`git commit\` to commit changes to the app repo
  • Use \`geet commit\` to commit changes to the template repo
  • Same file can be in both - they're independent repos sharing a working directory

✅ DO use \`geet inspect <file>\` when unsure which repo tracks a file
✅ DO use \`geet tree\` to see what's in the template
================================
EOF
  else
cat <<EOF
=== CRITICAL: WHAT NOT TO DO ===
❌ DON'T use \`git add\` to add NEW files to template - use \`geet include\` instead
❌ DON'T manually edit .template/.geetexclude (auto-generated from .geetinclude)
❌ DON'T commit app-specific code to template (pre-commit hooks will block)

NOTE: Template files are often tracked by BOTH repos
  • Use \`git commit\` to commit changes to the app repo
  • Use \`geet commit\` to commit changes to the template repo
  • Same file can be in both - they're independent repos sharing a working directory

✅ DO use \`geet inspect <file>\` when unsure which repo tracks a file
✅ DO use \`geet tree\` to see what's in the template
================================
EOF
  fi
}

learn(){
  # 1. Quick context first (most important for AI agents)
  quick_status
  echo ""

  # 2. Machine-readable metadata
  machine_metadata
  echo ""

  # 3. Welcome and core explanation
  echo "Welcome to \`geet\` - a git wrapper CLI that allows you to track two git repos in a single working directory"
  echo "\`geet\` is used to allow sharing a subset of your primary app repo as a template/quickstart repo that you can use to spin off new versions of your project"
  echo ""
  echo "Let's talk specifics. The following explanation comes from the output of \`geet explain\`"
  echo "------------------------------------- geet explain -------------------------------------------------------------"
  explain
  echo "----------------------------------------------------------------------------------------------------------------"
  echo ""

  # 4. Common workflows (most actionable information)
  common_workflows
  echo ""

  # 5. Critical warnings (prevent common mistakes)
  critical_warnings
  echo ""

  # 6. Commands available
  echo "Now, for all the commands you have available let's see \`geet help\`"
  echo "------------------------------------- geet help ----------------------------------------------------------------"
  geet help
  echo "----------------------------------------------------------------------------------------------------------------"
  echo ""

  # 7. Admin files explanation
  explain_hidden
  echo "----------------------------------------------------------------------------------------------------------------"
  echo ""

  # 8. Full README for comprehensive documentation
  echo "Let's REALLY hammer home the purpose of the project"
  echo "------------------------------------- geet readme --------------------------------------------------------------"
  geet readme
  echo "----------------------------------------------------------------------------------------------------------------"
  echo ""

  # 9. Final tips and next steps
  echo "My final tip if you are still confused is to use \`geet read\` to explore the \`geet\` source code"
  echo ""
  echo "================================================================================================================"
  echo "RECOMMENDED NEXT STEPS FOR AI AGENTS:"
  echo "  1. Run: \`geet inspect .\`     → See which files are tracked by which repo"
  echo "  2. Run: \`geet status\`        → See uncommitted template changes"
  echo "  3. Run: \`geet tree\`          → See all template files in tree format"
  echo "  4. If confused, run: \`geet read\` to explore the source code"
  echo "================================================================================================================"
}