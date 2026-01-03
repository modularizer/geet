# inspect.sh — inspect which layer tracks a file and its git status
# Usage:
#   source inspect.sh
#   inspect <path>

inspect() {

# digest-and-locate.sh provides: APP_DIR, TEMPLATE_DIR, DOTGIT, TEMPLATE_NAME,
# GEET_ALIAS, die, log, debug

# Color helpers
_color_enabled() {
  [[ -t 1 ]] || return 1
  case "${COLOR_MODE:-}" in
    light|dark) return 0 ;;
    *) return 1 ;;
  esac
}

# ANSI color codes
if _color_enabled; then
  c_reset=$'\033[0m'
  c_bold=$'\033[1m'
  c_green=$'\033[32m'
  c_red=$'\033[31m'
  c_yellow=$'\033[33m'
  c_blue=$'\033[34m'
  c_cyan=$'\033[36m'
  c_gray=$'\033[90m'
else
  c_reset=""
  c_bold=""
  c_green=""
  c_red=""
  c_yellow=""
  c_blue=""
  c_cyan=""
  c_gray=""
fi

usage() {
  cat <<EOF
$GEET_ALIAS inspect — inspect which layer tracks a file and its git status

Given a file path, tells you which layer tracks it and what Git thinks about it.

Usage:
  $GEET_ALIAS inspect <path>

Examples:
  $GEET_ALIAS inspect src/auth/login.ts
  $GEET_ALIAS inspect README.md
  $GEET_ALIAS inspect --help

Output includes:
- File modification time (mtime)
- Tracking status (tracked|excluded|ignored|untracked) for both repos
- Detachment state for template repo (attached|slid|detached)
- Last commit hash and commit time for each repo
- Git status (clean|modified|deleted|added)
- Diff summary when tracked in both repos (identical or +X -Y lines)
- Color-coded indicators:
  - Green: tracked, attached, clean, identical
  - Yellow: excluded (template), ignored (app), modified, detached, diff
  - Cyan: slid, added
  - Red: untracked, deleted
  - Gray: metadata (times, commits)
- Informational note when file is tracked in both layers
EOF
}

# Handle help
if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" || -z "${1:-}" ]]; then
  usage
  return 0
fi

path="${1}"

# Convert absolute path to relative if needed
if [[ "$path" == "$APP_DIR/"* ]]; then
  path="${path#"$APP_DIR/"}"
fi

# Strip leading ./ if present
path="${path#./}"

echo
echo "${c_bold}Path:${c_reset} $path"

# Show file mtime if file exists
if [[ -e "$APP_DIR/$path" ]]; then
  if stat -c '%y' "$APP_DIR/$path" >/dev/null 2>&1; then
    # GNU stat
    file_mtime=$(stat -c '%y' "$APP_DIR/$path" 2>/dev/null | cut -d'.' -f1)
  else
    # BSD stat (macOS)
    file_mtime=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$APP_DIR/$path" 2>/dev/null)
  fi
  [[ -n "$file_mtime" ]] && echo "${c_gray}File modified: $file_mtime${c_reset}"
fi

echo

# Template repo inspection
if [[ -d "$DOTGIT" ]]; then
  template_name="${TEMPLATE_NAME:-template}"
  echo "${c_bold}Template repo${c_reset} ${c_blue}($template_name)${c_reset}:"

  # Check if tracked in template repo
  is_tracked_template=false
  is_ignored_template=false

  if git --git-dir="$DOTGIT" --work-tree="$APP_DIR" ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    is_tracked_template=true
  fi

  # Check if ignored by template repo (whitelist system via .geetexclude)
  if geet_git check-ignore -q -- "$path" 2>/dev/null; then
    is_ignored_template=true
  fi

  # Display tracking status
  if [[ "$is_tracked_template" == "true" ]]; then
    echo "  ${c_green}✔ tracked${c_reset}"

    # Determine detachment state
    # Check if hard-detached (skip-worktree)
    ls_v_output=$(git --git-dir="$DOTGIT" --work-tree="$APP_DIR" ls-files -v -- "$path" 2>/dev/null || echo "")
    if [[ "$ls_v_output" =~ ^S ]]; then
      echo "  ${c_yellow}state: detached${c_reset}"
    else
      # Check if soft-detached (merge=keep-ours)
      merge_attr=$(git --git-dir="$DOTGIT" --work-tree="$APP_DIR" check-attr merge -- "$path" 2>/dev/null | awk -F': ' '{print $3}')
      if [[ "$merge_attr" == "keep-ours" ]]; then
        echo "  ${c_cyan}state: slid${c_reset}"
      else
        echo "  ${c_green}state: attached${c_reset}"
      fi
    fi

    # Get the commit hash and time for this file (last commit that touched it)
    commit_hash=$(git --git-dir="$DOTGIT" --work-tree="$APP_DIR" log -1 --format="%h" -- "$path" 2>/dev/null || echo "")
    if [[ -n "$commit_hash" ]]; then
      echo "  ${c_gray}commit: $commit_hash${c_reset}"

      # Get commit time
      commit_time=$(git --git-dir="$DOTGIT" --work-tree="$APP_DIR" log -1 --format="%ci" -- "$path" 2>/dev/null | cut -d'.' -f1 || echo "")
      [[ -n "$commit_time" ]] && echo "  ${c_gray}commit time: $commit_time${c_reset}"
    fi

    # Check status (modified, deleted, etc.)
    status_output=$(git --git-dir="$DOTGIT" --work-tree="$APP_DIR" status --porcelain -- "$path" 2>/dev/null || echo "")

    if [[ -z "$status_output" ]]; then
      echo "  ${c_green}status: clean${c_reset}"
    else
      # Parse status code
      status_code="${status_output:0:2}"
      case "$status_code" in
        " M"|"M "|"MM") echo "  ${c_yellow}status: modified${c_reset}" ;;
        " D"|"D "|"DD") echo "  ${c_red}status: deleted${c_reset}" ;;
        "A "|"AM") echo "  ${c_cyan}status: added${c_reset}" ;;
        "??") echo "  ${c_gray}status: untracked${c_reset}" ;;
        *) echo "  status: ${status_code}" ;;
      esac
    fi

    template_tracked=true
  else
    # Not tracked - check if excluded or just untracked
    if [[ "$is_ignored_template" == "true" ]]; then
      echo "  ${c_yellow}✖ excluded${c_reset}"
    else
      echo "  ${c_red}✖ untracked${c_reset}"
    fi
    template_tracked=false
  fi
else
  echo "${c_bold}Template repo:${c_reset}"
  echo "  ${c_red}✖ not initialized${c_reset}"
  template_tracked=false
fi

echo

# App repo inspection
# Find app repo .git directory
if [[ -d "$APP_DIR/.git" ]]; then
  app_name="${APP_NAME:-app}"
  echo "${c_bold}App repo${c_reset} ${c_blue}($app_name)${c_reset}:"

  # Check if tracked in app repo
  is_tracked_app=false
  is_ignored_app=false

  if git -C "$APP_DIR" ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    is_tracked_app=true
  fi

  # Check if ignored by app repo
  if git -C "$APP_DIR" check-ignore -q -- "$path" 2>/dev/null; then
    is_ignored_app=true
  fi

  # Display tracking status
  if [[ "$is_tracked_app" == "true" ]]; then
    echo "  ${c_green}✔ tracked${c_reset}"

    # Get the commit hash and time for this file (last commit that touched it)
    commit_hash=$(git -C "$APP_DIR" log -1 --format="%h" -- "$path" 2>/dev/null || echo "")
    if [[ -n "$commit_hash" ]]; then
      echo "  ${c_gray}commit: $commit_hash${c_reset}"

      # Get commit time
      commit_time=$(git -C "$APP_DIR" log -1 --format="%ci" -- "$path" 2>/dev/null | cut -d'.' -f1 || echo "")
      [[ -n "$commit_time" ]] && echo "  ${c_gray}commit time: $commit_time${c_reset}"
    fi

    # Check status
    status_output=$(git -C "$APP_DIR" status --porcelain -- "$path" 2>/dev/null || echo "")

    if [[ -z "$status_output" ]]; then
      echo "  ${c_green}status: clean${c_reset}"
    else
      # Parse status code
      status_code="${status_output:0:2}"
      case "$status_code" in
        " M"|"M "|"MM") echo "  ${c_yellow}status: modified${c_reset}" ;;
        " D"|"D "|"DD") echo "  ${c_red}status: deleted${c_reset}" ;;
        "A "|"AM") echo "  ${c_cyan}status: added${c_reset}" ;;
        "??") echo "  ${c_gray}status: untracked${c_reset}" ;;
        *) echo "  status: ${status_code}" ;;
      esac
    fi

    app_tracked=true
  else
    # Not tracked - check if ignored or just untracked
    if [[ "$is_ignored_app" == "true" ]]; then
      echo "  ${c_yellow}✖ ignored${c_reset}"
    else
      echo "  ${c_red}✖ untracked${c_reset}"
    fi
    app_tracked=false
  fi
else
  echo "${c_bold}App repo:${c_reset}"
  echo "  ${c_red}✖ not found${c_reset}"
  app_tracked=false
fi

echo

# Content comparison across all three states
if [[ -e "$APP_DIR/$path" ]] || [[ "$template_tracked" == "true" ]] || [[ "$app_tracked" == "true" ]]; then
  echo "${c_bold}Content comparison:${c_reset}"

  # Get checksums for comparison
  working_hash=""
  template_head_hash=""
  app_head_hash=""

  # Working tree hash
  if [[ -e "$APP_DIR/$path" ]]; then
    working_hash=$(md5sum "$APP_DIR/$path" 2>/dev/null | cut -d' ' -f1 || echo "")
  fi

  # Template HEAD hash
  if [[ "$template_tracked" == "true" ]]; then
    template_head_hash=$(git --git-dir="$DOTGIT" --work-tree="$APP_DIR" show HEAD:"$path" 2>/dev/null | md5sum | cut -d' ' -f1 || echo "")
  fi

  # App HEAD hash
  if [[ "$app_tracked" == "true" ]]; then
    app_head_hash=$(git -C "$APP_DIR" show HEAD:"$path" 2>/dev/null | md5sum | cut -d' ' -f1 || echo "")
  fi

  # Compare and show relationships
  working_exists=$([[ -n "$working_hash" ]] && echo "true" || echo "false")
  template_exists=$([[ -n "$template_head_hash" ]] && echo "true" || echo "false")
  app_exists=$([[ -n "$app_head_hash" ]] && echo "true" || echo "false")

  # Build comparison display
  if [[ "$working_exists" == "true" && "$template_exists" == "true" && "$app_exists" == "true" ]]; then
    # All three exist - compare them
    if [[ "$working_hash" == "$template_head_hash" && "$working_hash" == "$app_head_hash" ]]; then
      echo "  ${c_green}✓ All three states identical${c_reset}"
    elif [[ "$working_hash" == "$template_head_hash" && "$working_hash" != "$app_head_hash" ]]; then
      echo "  ${c_yellow}Working tree = Template HEAD ≠ App HEAD${c_reset}"
    elif [[ "$working_hash" == "$app_head_hash" && "$working_hash" != "$template_head_hash" ]]; then
      echo "  ${c_yellow}Working tree = App HEAD ≠ Template HEAD${c_reset}"
    elif [[ "$template_head_hash" == "$app_head_hash" && "$working_hash" != "$template_head_hash" ]]; then
      echo "  ${c_yellow}Template HEAD = App HEAD ≠ Working tree${c_reset}"
    else
      echo "  ${c_red}✗ All three states differ${c_reset}"
    fi
  elif [[ "$working_exists" == "true" && "$template_exists" == "true" && "$app_exists" == "false" ]]; then
    if [[ "$working_hash" == "$template_head_hash" ]]; then
      echo "  ${c_green}Working tree = Template HEAD${c_reset} ${c_gray}(not in app HEAD)${c_reset}"
    else
      echo "  ${c_yellow}Working tree ≠ Template HEAD${c_reset} ${c_gray}(not in app HEAD)${c_reset}"
    fi
  elif [[ "$working_exists" == "true" && "$template_exists" == "false" && "$app_exists" == "true" ]]; then
    if [[ "$working_hash" == "$app_head_hash" ]]; then
      echo "  ${c_green}Working tree = App HEAD${c_reset} ${c_gray}(not in template HEAD)${c_reset}"
    else
      echo "  ${c_yellow}Working tree ≠ App HEAD${c_reset} ${c_gray}(not in template HEAD)${c_reset}"
    fi
  elif [[ "$working_exists" == "false" && "$template_exists" == "true" && "$app_exists" == "true" ]]; then
    if [[ "$template_head_hash" == "$app_head_hash" ]]; then
      echo "  ${c_green}Template HEAD = App HEAD${c_reset} ${c_gray}(no working tree)${c_reset}"
    else
      echo "  ${c_yellow}Template HEAD ≠ App HEAD${c_reset} ${c_gray}(no working tree)${c_reset}"
    fi
  fi

  echo
fi

# Show all three pairwise diffs
echo "${c_bold}Diffs:${c_reset}"

# Create temp files for all three states
tmp_working=$(mktemp)
tmp_template_head=$(mktemp)
tmp_app_head=$(mktemp)

# Get contents
working_file_exists=false
template_head_exists=false
app_head_exists=false

if [[ -e "$APP_DIR/$path" ]]; then
  cp "$APP_DIR/$path" "$tmp_working" 2>/dev/null && working_file_exists=true
fi

if [[ "$template_tracked" == "true" ]]; then
  git --git-dir="$DOTGIT" --work-tree="$APP_DIR" show HEAD:"$path" > "$tmp_template_head" 2>/dev/null && template_head_exists=true
fi

if [[ "$app_tracked" == "true" ]]; then
  git -C "$APP_DIR" show HEAD:"$path" > "$tmp_app_head" 2>/dev/null && app_head_exists=true
fi

# Helper function to compute diff stats on one line
compute_diff() {
  local file1="$1"
  local file2="$2"
  local name1="$3"
  local name2="$4"
  local show_status="${5:-false}"  # Show ahead/behind for HEAD comparisons

  if cmp -s "$file1" "$file2"; then
    echo "  ${c_green}${name1} → ${name2}: identical${c_reset}"
  else
    local tmp_d=$(mktemp)
    diff -u "$file1" "$file2" > "$tmp_d" 2>/dev/null || true
    set +o pipefail
    local add=$(grep "^\+" "$tmp_d" | grep -v "^\+\+\+" | wc -l | tr -d ' \n\r')
    local rem=$(grep "^\-" "$tmp_d" | grep -v "^\-\-\-" | wc -l | tr -d ' \n\r')
    set -o pipefail
    add=${add:-0}
    rem=${rem:-0}
    rm -f "$tmp_d"

    # Build descriptive diff summary
    local summary=""
    local status=""

    if [[ "$add" -eq 0 && "$rem" -gt 0 ]]; then
      summary="${name2} has ${rem} fewer line(s)"
      [[ "$show_status" == "true" ]] && status=" ${c_cyan}(${name2} is behind ${name1})${c_reset}"
    elif [[ "$add" -gt 0 && "$rem" -eq 0 ]]; then
      summary="${name2} has ${add} more line(s)"
      [[ "$show_status" == "true" ]] && status=" ${c_cyan}(${name2} is ahead ${name1})${c_reset}"
    elif [[ "$add" -gt 0 && "$rem" -gt 0 ]]; then
      summary="${name2} has ${add} more, ${rem} fewer lines"
      status=" ${c_red}(diverged)${c_reset}"
    fi

    echo "  ${c_yellow}${name1} → ${name2}:${c_reset} ${summary}${status}"
  fi
}

# Diff 1: Working tree vs Template HEAD
if [[ "$working_file_exists" == "true" && "$template_head_exists" == "true" ]]; then
  compute_diff "$tmp_working" "$tmp_template_head" "Working tree" "Template HEAD" "true"
fi

# Diff 2: Working tree vs App HEAD
if [[ "$working_file_exists" == "true" && "$app_head_exists" == "true" ]]; then
  compute_diff "$tmp_working" "$tmp_app_head" "Working tree" "App HEAD" "true"
fi

# Diff 3: Template HEAD vs App HEAD (show ahead/behind status)
if [[ "$template_head_exists" == "true" && "$app_head_exists" == "true" ]]; then
  compute_diff "$tmp_template_head" "$tmp_app_head" "Template HEAD" "App HEAD" "true"
fi

# Cleanup
rm -f "$tmp_working" "$tmp_template_head" "$tmp_app_head"
echo

}  # end of inspect()
