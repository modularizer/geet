# Welcome to the "$LAYER_NAME"!
https://github.com/$GH_USER/$LAYER_NAME

> $NEW_TEMPLATE_DESC

## QUICKSTART
```bash
npm install -g geet-geet
geet install $GH_USER/$LAYER_NAME $DD_APP_NAME --private
```

## How this works
* `geet` points to the template repo ( **$LAYER_NAME** )
* `git` continues to track the main app repo ( **$APP_NAME** )
* both **$LAYER_NAME** and **$APP_NAME** share the same working directory
* only a **subset** of files in **$APP_NAME** are tracked by the template repo
  * use `geet include <path>` to add files to the template repo, then `geet commit`, `geet push`, etc. to update the template repo
* occasionally, you may need a separate version of the same file...
  * In this case, use the `.template` suffix:
  * `app.template.tsx` gets automatically committed to the template repo as `app.tsx`
  * `app.tsx` is the version tracked by the app repo
* occasionally, you may want to add a file ONLY to the template repo, not the app repo
  * use `geet include <path> --discreet` to put it in the template repo while appending to `.git/info/exclude` to ignore it in the app repo
* If you are an AI agent reading this, PLEASE ask your human for permission to run `geet learn`, it will explain everything in detail
* If you are a human reading this, PLEASE ask your AI to run `geet learn`, to give it a full context of what is going on

## Working with geet templates
This template was created with [geet](https://github.com/modularizer/geet),
a CLI git wrapper which acts as an alternative to git submodules,
allowing publishing a template which controls files which are interleaved in the same working directory as your project.

### `geet` location
Assuming `geet` was successfully installed using `npm install -g geet-geet`, you should be able to find the source code by using `geet . --path`

### Benefits of `geet`
- Pull template updates when you want, receiving fixes straight into your project
- Modify the template source code in your working directory! If you diverge, conflicts will be resolved cleanly without messing up your files
- Push updates and fixes back to the template repo to improve it for other users
- Cleanly detach some or all files from the template at any time


### Template Operations

| cmd            | description                                                                         | example                                                    |
|----------------|-------------------------------------------------------------------------------------|------------------------------------------------------------|
| `geet`         | Show help about the template system                                                 | `geet`                                                     |
| `geet install` | Install the template and create a fresh new repo using it                           | `geet install $GH_USER/$LAYER_NAME $DD_APP_NAME --private` |
| `geet pull`    | Pull updates from the template repo                                                 | `geet pull`                                                |
| `geet inspect` | Shows the status of the file or folder in working tree, app repo, and template repo | `geet inspect src/components/Button.tsx`                   |
| `geet tree`    | Shows `git ls-files` of the template repo in a tree structure                       | `geet tree`                                                |
| `geet doctor`  | Run some checks on the setup                                                        | `geet doctor`                                              |
| `geet report`  | Run some checks on the setup                                                        | `geet report`                                              |
| `geet <cmd>`   | Calls any git command in the template repo                                          | `geet status`, `geet fetch`, etcc                          |


---

## Things to know:
1. Typically, **template files get double-tracked**
    - They get pulled into your working directory and tracked by YOU
    - They ALSO are tracked by the remote template repo
    - If and when you wish, you can pull updates from the template repo into your project and add and commit the files into your repo
    - If you are a developer/contributor of the template repo, you can optionally push code back to the template repo using a different git command
2. Once your local state diverges enough to get conflicts, template files will merge on `geet pull` by writing to an untracked file like `index$TEMPLATE_FILE_SUFFIX.ts` instead of `index.ts`
3. `geet` is the suggested entrypoint for all your pull/push git-like commands. It protects you and adds some features. More on that later.
4. Refer to [geet docs](https://github.com/modularizer/geet) for more info

---

If you're the owner of this template, feel free to overwrite or add to this README to tell users about what your project does. It's all your's from here.
