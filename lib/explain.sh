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

* .$TEMPLATE_NAME/.geetinclude shows the files that wee included in the template
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

learn(){
  echo "Welcome to \`geet\` - a git wrapper CLI that allows you two track two git repos in a single working directory"
  echo "\`geet\` is used to allow sharing a subset of your primary app repo as a template/quickstart repo that you can use to spin off new versions of your project"
  echo "Let's talk specifics. The following explanation comes from the output of \`geet explain\`"
  echo "------------------------------------- geet explain -------------------------------------------------------------"
  explain
  echo "----------------------------------------------------------------------------------------------------------------"
  common_workflows
  echo "----------------------------------------------------------------------------------------------------------------"
  echo "Now, for all the commands you have available let's see \`geet help\`"
  echo "------------------------------------- geet help ----------------------------------------------------------------"
  geet help
  echo "----------------------------------------------------------------------------------------------------------------"
  echo "Let's REALLY hammer home the purpose of the project"
  echo "------------------------------------- geet readme --------------------------------------------------------------"
  geet readme
  echo "----------------------------------------------------------------------------------------------------------------"
  explain_hidden
  echo "----------------------------------------------------------------------------------------------------------------"
  echo "My final tip if you are still confused is to use \`geet read\` to explore the \`geet\` source code"
  echo "----------------------------------------------------------------------------------------------------------------"
  echo "NEXT: to see the current state of the files, please run \`geet inspect .\`"
  echo "THEN: ask the user "
}