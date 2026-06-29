#!/usr/bin/env bash
# clinit — Claude Code project scaffolder
set -euo pipefail

VERSION="0.2.0"
LOCAL_TEMPLATE="$HOME/.claude/project-template"
_TMP=""
trap '[ -n "$_TMP" ] && rm -rf "$_TMP"' EXIT

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
  clinit                    Apply default template from ~/.claude/project-template/
  clinit use <source>       Apply template from a source:

    git URL:      clinit use git@github.com:user/repo.git
    local dir:    clinit use ./path/to/kit
    config URL:   clinit use https://host/path/to/clinit.json

  clinit --force            Back up existing files, then overwrite all
  clinit --version          Show version
  clinit --help             Show this help

Options:
  --subdir <path>  Kit is in this subdirectory of the source (overrides clinit.json)
  --force          Back up CLAUDE.md and .claude/, then overwrite
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

_require_cmd() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || { echo "❌ $cmd is required (brew install $cmd)"; exit 1; }
  done
}

# Resolve kit_root from clinit.json at $root_dir, following "subdir" only if
# the template directory does not already exist at $root_dir (pointer vs full kit).
_resolve_subdir() {
  local root_dir="$1" subdir_flag="$2"
  local subdir="$subdir_flag"

  if [ -z "$subdir" ] && [ -f "$root_dir/clinit.json" ]; then
    local detected; detected=$(jq -r '.subdir // empty' "$root_dir/clinit.json")
    if [ -n "$detected" ]; then
      local template_check; template_check=$(jq -r '.template // "project-template"' "$root_dir/clinit.json")
      if [ ! -d "$root_dir/$template_check" ]; then
        subdir="$detected"
      fi
    fi
  fi

  if [ -n "$subdir" ]; then
    echo "$root_dir/$subdir"
  else
    echo "$root_dir"
  fi
}

_apply_kit_root() {
  local kit_root="$1" force="$2"

  _require_cmd jq
  local manifest="$kit_root/clinit.json"
  [ ! -f "$manifest" ] && { echo "❌ clinit.json not found in: $kit_root"; exit 1; }

  local template_rel; template_rel=$(jq -r '.template // "project-template"' "$manifest")
  local template="$kit_root/$template_rel"
  [ ! -d "$template" ] && { echo "❌ Template directory '$template_rel' not found in kit"; exit 1; }

  apply_template "$template" "$force"
}

cmd_use() {
  local source="$1" force="$2" subdir_flag="$3"
  local kit_root=""

  if [[ "$source" =~ ^https?://.+\.json$ ]]; then
    # JSON config URL: fetch manifest, read repo + subdir, then clone
    _require_cmd jq curl
    echo "⬇️  Fetching config from $source..."
    local json; json=$(curl -fsSL "$source") || { echo "❌ Failed to fetch $source"; exit 1; }
    local repo subdir_json
    repo=$(echo "$json" | jq -r '.repo // empty')
    subdir_json=$(echo "$json" | jq -r '.subdir // empty')
    [ -z "$repo" ] && { echo "❌ clinit.json missing 'repo' field"; exit 1; }
    _TMP=$(mktemp -d)
    echo "⬇️  Cloning $repo..."
    git clone --depth 1 --quiet "$repo" "$_TMP/kit"
    local subdir="${subdir_flag:-$subdir_json}"
    kit_root="$_TMP/kit"
    [ -n "$subdir" ] && kit_root="$kit_root/$subdir"

  elif [[ "$source" == ./* || "$source" == /* || "$source" == ~/* || "$source" == ../* ]]; then
    # Local path — user points at kit or repo root
    _require_cmd jq
    local expanded="${source/#\~/$HOME}"
    [ ! -d "$expanded" ] && { echo "❌ Not a directory: $expanded"; exit 1; }
    kit_root=$(_resolve_subdir "$expanded" "$subdir_flag")

  else
    # Git URL — clone, then auto-detect subdir from root clinit.json
    _require_cmd jq
    _TMP=$(mktemp -d)
    echo "⬇️  Cloning $source..."
    git clone --depth 1 --quiet "$source" "$_TMP/kit"
    kit_root=$(_resolve_subdir "$_TMP/kit" "$subdir_flag")
  fi

  _apply_kit_root "$kit_root" "$force"
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
      echo "Usage: clinit use <source> [--subdir <path>]"
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
