#!/usr/bin/env bash
set -euo pipefail

BASE="$1"   # %O
OURS="$2"   # %A
THEIRS="$3" # %B
PATH_IN_REPO="$4" # %P
TEMPLATE_FILE_SUFFIX="$5"

# Compute suffix path: index.ts -> index.sample.ts
dir="$(dirname "$PATH_IN_REPO")"
base="$(basename "$PATH_IN_REPO")"
name="${base%.*}"
ext="${base##*.}"

suffix_path="$dir/${name}${TEMPLATE_FILE_SUFFIX}.${ext}"

echo "handling merge of $PATH_IN_REPO, suffix_path:$suffix_path"

# Attempt a real 3-way merge output to stdout
set +e
merged="$(git merge-file -p "$OURS" "$BASE" "$THEIRS")"
rc=$?
set -e

if [[ $rc -eq 0 ]]; then
  # Clean merge: accept merged into ours
  printf "%s" "$merged" > "$OURS"
  exit 0
fi

# Conflict: keep ours for the real file, divert template change to suffix file
mkdir -p "$(dirname "$suffix_path")"


# Option B: store theirs exactly (simpler)
cp "$THEIRS" "$suffix_path"

echo "suffix-merge-driver: conflict in $PATH_IN_REPO; wrote template version to $suffix_path" >&2
exit 0
