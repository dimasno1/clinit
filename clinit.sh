#!/usr/bin/env bash
# clinit — Claude Code project scaffolder
set -euo pipefail

VERSION="0.1.1"
LOCAL_TEMPLATE="$HOME/.claude/project-template"

GITIGNORE_BLOCK='# claude-kit-begin
# local-only claude kit files — do not commit
CLAUDE.md
.claude/skills/
.claude/rules/
.claude/skills-ios/
.claude/project_map.md
.claude/.map_checkpoint
.claude.backup.*
CLAUDE.md.backup.*
# claude-kit-end'

usage() {
  cat <<EOF
clinit $VERSION — Claude Code project scaffolder

Usage:
  clinit                          Apply template from ~/.claude/project-template/
  clinit use <git-url>            Fetch and apply template from a remote kit repo
  clinit use <git-url> --subdir <path>  Kit is inside a subdirectory of the repo
  clinit --force                  Back up existing files, then overwrite all
  clinit --version                Show version
  clinit --help                   Show this help
EOF
}

setup_gitignore() {
  local begin='# claude-kit-begin'

  if [ ! -f .gitignore ]; then
    printf '%s\n' "$GITIGNORE_BLOCK" > .gitignore
    echo "✅ .gitignore created"
    return
  fi

  if grep -qF "$begin" .gitignore; then
    awk -v new="$GITIGNORE_BLOCK" \
      '/^# claude-kit-begin$/{print new; skip=1; next} /^# claude-kit-end$/{skip=0; next} !skip{print}' \
      .gitignore > .gitignore.tmp && mv .gitignore.tmp .gitignore
    echo "✅ .gitignore updated"
  else
    printf '\n%s\n' "$GITIGNORE_BLOCK" >> .gitignore
    echo "✅ .gitignore updated"
  fi
}

apply_template() {
  local template="$1" force="$2"

  if $force; then
    local ts; ts=$(date +%Y%m%d_%H%M%S)
    for item in CLAUDE.md .claude; do
      if [ -e "./$item" ]; then
        cp -R "./$item" "./${item}.backup.$ts"
        echo "📦 Backed up: $item → ${item}.backup.$ts"
      fi
    done
    cp -Rf "$template/." .
    echo "✅ Template force-applied"
  else
    local installed=() skipped=()
    while IFS= read -r src; do
      local rel="${src#"$template"/}"
      local dst="./$rel"
      if [ -e "$dst" ]; then
        skipped+=("$rel")
      else
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        installed+=("$rel")
      fi
    done < <(find "$template" -type f -not -name ".map_checkpoint" | sort)

    [ ${#installed[@]} -gt 0 ] && echo "✅ Installed:" && printf "   %s\n" "${installed[@]}"
    if [ ${#skipped[@]} -gt 0 ]; then
      echo "⏭️  Skipped (already exist):"
      printf "   %s\n" "${skipped[@]}"
      echo ""
      echo "   To inspect updates: diff -rq ~/.claude/project-template/.claude ./.claude"
      echo "   To force-apply:     clinit --force"
    fi
  fi

  setup_gitignore
  echo ""
  echo "Next: fill in CLAUDE.md with build/test commands, then run /update-map"
}

cmd_use() {
  local git_url="$1" force="$2" subdir="$3"

  if ! command -v jq &>/dev/null; then
    echo "❌ jq is required for 'clinit use' (brew install jq)"
    exit 1
  fi

  local tmp; tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  echo "⬇️  Cloning $git_url..."
  git clone --depth 1 --quiet "$git_url" "$tmp/kit"

  local kit_root="$tmp/kit"
  [ -n "$subdir" ] && kit_root="$tmp/kit/$subdir"

  local manifest="$kit_root/clinit.json"
  if [ ! -f "$manifest" ]; then
    echo "❌ clinit.json not found${subdir:+ in '$subdir'}"
    exit 1
  fi

  local template_rel; template_rel=$(jq -r '.template // "project-template"' "$manifest")
  local template="$kit_root/$template_rel"

  if [ ! -d "$template" ]; then
    echo "❌ Template directory '$template_rel' not found"
    exit 1
  fi

  apply_template "$template" "$force"
}

# ── argument parsing ───────────────────────────────────────────────────────

FORCE=false
SUBDIR=""
ARGS=()

i=1
while [ $i -le $# ]; do
  arg="${!i}"
  case "$arg" in
    --force)   FORCE=true ;;
    --version) echo "clinit $VERSION"; exit 0 ;;
    --help|-h) usage; exit 0 ;;
    --subdir)
      i=$((i + 1))
      SUBDIR="${!i}"
      ;;
    *)         ARGS+=("$arg") ;;
  esac
  i=$((i + 1))
done

# ── dispatch ───────────────────────────────────────────────────────────────

case "${ARGS[0]:-}" in
  use)
    if [ ${#ARGS[@]} -lt 2 ]; then
      echo "Usage: clinit use <git-url> [--subdir <path>]"
      exit 1
    fi
    cmd_use "${ARGS[1]}" "$FORCE" "$SUBDIR"
    ;;
  "")
    if [ ! -d "$LOCAL_TEMPLATE" ]; then
      echo "❌ ~/.claude/project-template/ not found"
      echo "   Run install.sh from your ai-dev-setup-kit clone first"
      exit 1
    fi
    apply_template "$LOCAL_TEMPLATE" "$FORCE"
    ;;
  *)
    echo "Unknown command: ${ARGS[0]}"
    usage
    exit 1
    ;;
esac
