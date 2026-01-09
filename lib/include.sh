

# Helper: sync .geetinclude to .geetexclude
sync_exclude() {
  source "$GEET_LIB/sync.sh"
  sync
}

# Helper: check if template git repo exists
need_dotgit() {
  [[ -d "$DOTGIT" && -f "$DOTGIT/HEAD" ]] || die "missing $DOTGIT (run: $GEET_ALIAS init)"
}

rel_path() {
  local p="$1"

  # turn absolute into repo-relative
  if [[ "$p" == /* ]]; then
    [[ "$p" == "$root/"* ]] || die "path outside project: $p"
    p="${p#"$root"/}"
  fi

  p="${p#./}"

  while [[ "$p" == *"//"* ]]; do
    p="${p//\/\//\/}"
  done

  echo "$p"
}

abs_path() {
  local p="$1"

  # if already absolute, keep it
  if [[ "$p" == /* ]]; then
    [[ "$p" == "$root/"* ]] || die "path outside project: $p"
    echo "$p"
    return
  fi

  p="$(rel_path "$p")"
  echo "$root/$p"
}





###############################################################################
# CLONE - Simple git clone without init
###############################################################################
# Just clones a repository without running any post-install logic
include() {
  if [[ "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
    cat <<EOF
    $GEET_ALIAS include - add to whitelist then add to git

    This script is intended to be used in lieu of git add, as it has some geet-specific tools to keep you on track.

    Rules:
      - we always add every file you included to the whitelist
      - we never allow commiting a file like \`index.tsx\` if \`index${TEMPLATE_FILE_SUFFIX}.tsx\` exists, we will instead add \`index${TEMPLATE_FILE_SUFFIX}.tsx\` as \`index.tsx\`
      - if you add a file like \`server${TEMPLATE_FILE_SUFFIX}.tsx\` it goes into git as \`server.tsx\`

    Usage: $GEET_ALIAS include <glob>

    Examples:
      $GEET_ALIAS include src/    # adds the whole src folder and all its contents
      $GEET_ALIAS include package.json    # adds just that file
EOF
    return 0
  fi

  if [[ -z "$TEMPLATE_DIR" ]]; then
    critical "We could not find your template repo anywhere in this project!"
    warn "Are you sure you are somewhere inside a project which has a template repo?"
    warn "The template repo is a hidden folder at the root of your working directory which contains a .geethier file inside it"
    warn "To debug our search, run \`$GEET_ALIAS status --verbose --filter LOCATE\`"
    warn "If you think we made a mistake, review the code at $GEET_LIB/digest-and-locate.sh detect_template_dir_from_cwd"
    exit 1
  fi
  root=$(dirname -- "${TEMPLATE_DIR%/}")
  need_dotgit
  sync_exclude
  has_flag --discreet DISCREET
  has_flag --discrete DISCRETE
  has_flag -f FORCE
  if [[ -n "$DISCRETE" ]]; then
    die "Whoops! did you mean --discreet?"
  fi
  sync_exclude
  # first, modify .geetinclude
  for arg in "${GEET_ARGS[@]}"; do
    matches=()

    if [[ "$arg" == "-u" ]]; then
      include_file="$TEMPLATE_DIR/.geetinclude"
      # read each line, split on # and take the part before the line, trim, discard if empty, otherwise add to matches
      while IFS= read -r line; do
        line="${line%%#*}"          # strip comments
        line="$(echo "$line" | xargs)"  # trim whitespace
        if [[ -n "$line" && -e "$line" ]]; then
          matches+=("$line")
          debug "match $line"
        fi
      done < "$include_file"
    else
      # If user passed a directory (no glob chars), recurse it
      if [[ "$arg" != *[\*\?\[]* && -d "$arg" ]]; then
        while IFS= read -r -d '' m; do
          matches+=("$m")
        done < <(find "$arg" -type f -print0)

      # If user passed a glob, use find -path (supports * matching across /)
      elif [[ "$arg" == *[\*\?\[]* ]]; then
        # anchor search at repo root so globs work regardless of cwd
        while IFS= read -r -d '' m; do
          matches+=("$m")
        done < <(find "$root" -path "$root/$arg" -type f -print0)

      # Otherwise treat as a literal file
      else
        [[ -f "$arg" ]] || die "no files matched: $arg"
        matches+=("$arg")
      fi
    fi

    (( ${#matches[@]} > 0 )) || die "no files matched: $arg"

    # Check patterns before adding files
    file_patterns="${PREVENT_COMMIT_FILE_PATTERNS_1:-}|${PREVENT_COMMIT_FILE_PATTERNS_2:-}"
    file_patterns="${file_patterns#|}"
    file_patterns="${file_patterns%|}"
    file_patterns="${PREVENT_COMMIT_FILE_PATTERNS:-"$file_patterns"}"

    content_patterns="${PREVENT_COMMIT_CONTENT_PATTERNS_1:-}|${PREVENT_COMMIT_CONTENT_PATTERNS_2:-}"
    content_patterns="${content_patterns#|}"
    content_patterns="${content_patterns%|}"
    content_patterns="${PREVENT_COMMIT_CONTENT_PATTERNS:-"$content_patterns"}"

    if [[ -n "$file_patterns" ]] || [[ -n "$content_patterns" ]]; then
      errors=()

      for path in "${matches[@]}"; do
        raw_path="$path"                 # keep what compgen returned
        path_rel="$(rel_path "$raw_path")"
        [[ "$path_rel" == .git/* ]] && die "attempted to commit .git"
        [[ "$path_rel" == .git/* ]] && die "attempted to commit dot-git"
        path_abs="$(abs_path "$raw_path")"

        path_base=$(basename -- "$path_rel")
        path_dir=$(dirname -- "$path_rel")
        ext=""
        stem="$path_base"
        if [[ "$path_base" == *.* ]]; then
          ext=".${path_base##*.}"
          stem="${path_base%.*}"
        fi

        if [[ "$path_base" == *"$TEMPLATE_FILE_SUFFIX."* ]]; then
          src_base="$path_base"
        else
          if [[ "$path_base" == *"$TEMPLATE_FILE_SUFFIX_2."* ]]; then
            src_base="$path_base"
          else
            if [[ -e "$path_dir/${stem}${TEMPLATE_FILE_SUFFIX}${ext}" ]]; then
              src_base="${stem}${TEMPLATE_FILE_SUFFIX}.${ext}"
            else
              if [[ -e "$path_dir/${stem}${TEMPLATE_FILE_SUFFIX_2}${ext}" ]]; then
                src_base="${stem}${TEMPLATE_FILE_SUFFIX_2}${ext}"
              else
                src_base="${stem}"
              fi
            fi
          fi
        fi

        src_rel="$path_dir/$src_base"


        # Check file patterns (pipe-delimited)
        if [[ -n "$file_patterns" ]]; then
          IFS='|' read -ra patterns <<< "$file_patterns"
          for pattern in "${patterns[@]}"; do
            [[ -z "$pattern" ]] && continue
            if echo "$src_rel" | grep -qiE "$pattern"; then
              errors+=("FILE: $path_rel matches pattern: $pattern")
            fi
          done
        fi

        # Check content patterns (pipe-delimited)
        if [[ -n "$content_patterns" ]]; then
          IFS='|' read -ra patterns <<< "$content_patterns"
          for pattern in "${patterns[@]}"; do
            [[ -z "$pattern" ]] && continue

            # Skip if file doesn't exist
            [[ -f "$src_base" ]] || continue

            # Skip binary files
            if file --mime "$src_base" 2>/dev/null | grep -q 'charset=binary'; then
              continue
            fi

            # Skip template config
            [[ "$path_rel" == *template-config.env ]] && continue

            # Search for pattern in file content
            matches_content=$(grep -niE "$pattern" "$src_base" 2>/dev/null || true)
            if [[ -n "$matches_content" ]]; then
              while IFS= read -r match; do
                errors+=("CONTENT: $path_rel matches pattern: $pattern"$'\n'"  → $match")
              done <<< "$matches_content"
            fi
          done
        fi
      done

      # If errors found, fail the include
      if [[ ${#errors[@]} -gt 0 ]]; then
        echo "❌ [$GEET_ALIAS include] Found patterns that may indicate app-specific code:" >&2
        echo >&2
        for error in "${errors[@]}"; do
          echo "  $error" >&2
        done
        echo >&2
        echo "These patterns suggest implementation-specific code that shouldn't be in the template." >&2
        echo >&2
        echo "To fix: Remove the matched patterns or update template-config.env, semitracked-template-config.env, or untracked-template-config.env" >&2
        exit 1
      fi
    fi
    sync_exclude
    for path in "${matches[@]}"; do
      raw_path="$path"                 # keep what compgen returned
      path_rel="$(rel_path "$raw_path")"
      [[ "$path_rel" == .git/* ]] && die "attempted to commit .git"
      [[ "$path_rel" == .git/* ]] && die "attempted to commit dot-git"
      path_abs="$(abs_path "$raw_path")"

      path_base=$(basename -- "$path_rel")
      path_dir=$(dirname -- "$path_rel")
      ext=""
      stem="$path_base"
      if [[ "$path_base" == *.* ]]; then
        ext=".${path_base##*.}"
        stem="${path_base%.*}"
      fi

      if [[ "$path_base" == *"$TEMPLATE_FILE_SUFFIX."* ]]; then
        sample_base="$path_base"
        # path already is the sample, so find the filename to add as
        add_base="${path_base/$TEMPLATE_FILE_SUFFIX./.}"
      else
        if [[ "$path_base" == *"$TEMPLATE_FILE_SUFFIX_2."* ]]; then
          sample_base="$path_base"
          # path already is the sample, so find the filename to add as
          add_base="${path_base/$TEMPLATE_FILE_SUFFIX_2./.}"
        else
          # if the path's filename doesnt contain our suffix, then figure out the version of the filename which does have the suffix
          add_base="$path_base"

          sample_base="${stem}${TEMPLATE_FILE_SUFFIX}.${ext}"
        fi
      fi

      sample_path_rel="$path_dir/$sample_base"
      sample_path_abs="$(abs_path "$sample_path_rel")"

      if [[ "$path_rel" != "$sample_path_rel" && -f "$sample_path_abs" ]]; then
        path_rel="$sample_path_rel"
        path_abs="$sample_path_abs"
      fi

      add_path_rel="$(rel_path "$path_dir/$add_base")"

      debug "checking for $add_path_rel in $TEMPLATE_DIR/.geetinclude"
      if ! grep -qxF "$add_path_rel" "$TEMPLATE_DIR/.geetinclude"; then

        debug "adding $add_path_rel to $TEMPLATE_DIR/.geetinclude"

        # add to our include file
        printf '%s\n' "$add_path_rel" >> "$TEMPLATE_DIR/.geetinclude"
      fi
    done

    sync_exclude
    geet_git add -- "$TEMPLATE_DIR/.geetinclude" "$TEMPLATE_DIR/.geetexclude"
    for path in "${matches[@]}"; do
          raw_path="$path"                 # keep what compgen returned
          path_rel="$(rel_path "$raw_path")"
          og_path_rel="$(rel_path "$raw_path")"
          [[ "$path_rel" == .git/* ]] && die "attempted to commit .git"
          [[ "$path_rel" == .git/* ]] && die "attempted to commit dot-git"
          path_abs="$(abs_path "$raw_path")"

          path_base=$(basename -- "$path_rel")
          path_dir=$(dirname -- "$path_rel")
          ext=""
          stem="$path_base"
          debug "ext:$ext"
          debug "stem:$stem"
          if [[ "$path_base" == *.* ]]; then
            ext=".${path_base##*.}"
            stem="${path_base%.*}"
            debug "ext:$ext"
            debug "stem:$stem"
          fi

          if [[ "$path_base" == *"$TEMPLATE_FILE_SUFFIX."* ]]; then
            sample_base="$path_base"
            # path already is the sample, so find the filename to add as
            add_base="${path_base/$TEMPLATE_FILE_SUFFIX./.}"
          else
            if [[ "$path_base" == *"$TEMPLATE_FILE_SUFFIX_2."* ]]; then
              sample_base="$path_base"
              # path already is the sample, so find the filename to add as
              add_base="${path_base/$TEMPLATE_FILE_SUFFIX_2./.}"
            else
              # if the path's filename doesnt contain our suffix, then figure out the version of the filename which does have the suffix
              add_base="$path_base"

              sample_base="${stem}${TEMPLATE_FILE_SUFFIX}.${ext}"
            fi
          fi

          sample_path_rel="$path_dir/$sample_base"
          sample_path_abs="$(abs_path "$sample_path_rel")"
          debug "sample_path_rel:$sample_path_rel"
          debug "path_rel:$path_rel"

          if [[ "$path_rel" != "$sample_path_rel" && -f "$sample_path_abs" ]]; then
            debug "setting path_rel:$sample_path_rel"
            path_rel="$sample_path_rel"
            path_abs="$sample_path_abs"
          fi

          add_path_rel="$(rel_path "$path_dir/$add_base")"

          if [[ "$add_path_rel" == "$path_rel" ]]; then
            debug "calling git add"
            if [[ -n "$DISCREET" ]]; then
              if [[ -n "$APP_GIT_INFO_EXCLUDE" ]]; then
                if ! grep -qxF "$add_path_rel" "$APP_GIT_INFO_EXCLUDE"; then
                  debug "appending $add_path_rel to $APP_GIT_INFO_EXCLUDE"
                  echo "$add_path_rel" >> "$APP_GIT_INFO_EXCLUDE"
                else
                  debug "$add_path_rel already in $APP_GIT_INFO_EXCLUDE"
                fi
              fi
              touch "$TEMPLATE_DIR/parent-git-info-exclude"
              echo "$add_path_rel" >> "$TEMPLATE_DIR/parent-git-info-exclude"
            fi
            if [[ -n "$FORCE" ]]; then
              geet_git add -f -- "$add_path_rel"
            else
              geet_git add -- "$add_path_rel"
            fi
          else
            debug "adding $sample_path_rel as $add_path_rel"
            debug "using $path_abs"
            hash=$(geet_git hash-object -w -- "$path_abs")
            geet_git update-index --add --cacheinfo 100644 "$hash" "$add_path_rel"
          fi
        done
  done
}
