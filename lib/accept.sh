
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


accept(){
  if [[ "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
      cat <<EOF
      $GEET_ALIAS accept <template-path>

      Copy the template path into place and then remove it.

      Examples:
        $GEET_ALIAS accept app$TEMPLATE_FILE_SUFFIX.json
EOF
      return 0
    fi
    root=$(dirname -- "${TEMPLATE_DIR%/}")
  raw_path="$1"                 # keep what compgen returned
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
      add_base="${path_base/$TEMPLATE_FILE_SUFFIX./.}"
    else
      die "Must specify a template path"
    fi
  fi
  sample_path_rel="$path_dir/$sample_base"
  add_path_rel="$(rel_path "$path_dir/$add_base")"
  cp "$sample_path_rel" "$add_path_rel"
  rm "$sample_path_rel"
}
