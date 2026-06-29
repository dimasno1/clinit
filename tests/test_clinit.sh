#!/usr/bin/env bash
# Smoke tests for clinit. Run as: bash tests/test_clinit.sh [path-to-clinit.sh]
set -euo pipefail

CLINIT="${1:-$(dirname "$0")/../clinit.sh}"
CLINIT="$(cd "$(dirname "$CLINIT")" && pwd)/$(basename "$CLINIT")"

pass() { echo "✅ $1"; }
fail() { echo "❌ $1"; FAILURES=$((FAILURES + 1)); }

FAILURES=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── version ───────────────────────────────────────────────────────────────

out=$(bash "$CLINIT" --version)
[[ "$out" =~ ^clinit\ [0-9]+\.[0-9]+\.[0-9]+$ ]] && pass "version output" || fail "version: got '$out'"

# ── help ─────────────────────────────────────────────────────────────────

bash "$CLINIT" --help | grep -q "Usage:" && pass "help output" || fail "help output"

# ── apply from local dir ──────────────────────────────────────────────────

KIT="$TMP/kit"
mkdir -p "$KIT/project-template/.claude/skills"
cat > "$KIT/clinit.json" <<'JSON'
{"template": "project-template"}
JSON
echo "# Test CLAUDE.md" > "$KIT/project-template/CLAUDE.md"
echo "skill content" > "$KIT/project-template/.claude/skills/brainstorm.md"

PROJ="$TMP/project"
mkdir -p "$PROJ"
git -C "$PROJ" init -q

# Use command substitution instead of pipe to avoid SIGPIPE from grep -q
actual=$(cd "$PROJ" && bash "$CLINIT" use "$KIT" 2>&1)
echo "$actual" | grep -q "Installed" \
  && pass "local path apply — output" || fail "local path apply — no 'Installed' in output: '$actual'"

[ -f "$PROJ/CLAUDE.md" ] && pass "CLAUDE.md installed" || fail "CLAUDE.md not found"
[ -f "$PROJ/.claude/skills/brainstorm.md" ] && pass ".claude/skills/ installed" || fail ".claude/skills/ not found"
[ -f "$PROJ/.gitignore" ] && pass ".gitignore created" || fail ".gitignore not created"
grep -q "claude-kit-begin" "$PROJ/.gitignore" && pass ".gitignore has kit block" || fail ".gitignore missing kit block"

# ── skip existing files ───────────────────────────────────────────────────

out2=$(cd "$PROJ" && bash "$CLINIT" use "$KIT" 2>&1)
echo "$out2" | grep -q "Skipped" && pass "second apply skips existing" || fail "second apply did not skip: $out2"

# ── subdir auto-detect from root clinit.json ──────────────────────────────

REPO="$TMP/monorepo"
mkdir -p "$REPO/mykit/project-template"
echo '{"subdir": "mykit"}' > "$REPO/clinit.json"
echo '{"template": "project-template"}' > "$REPO/mykit/clinit.json"
echo "# Monorepo CLAUDE" > "$REPO/mykit/project-template/CLAUDE.md"

PROJ2="$TMP/project2"
mkdir -p "$PROJ2"
git -C "$PROJ2" init -q

actual_sub=$(cd "$PROJ2" && bash "$CLINIT" use "$REPO" 2>&1)
echo "$actual_sub" | grep -q "Installed" \
  && pass "subdir auto-detect from root clinit.json" || fail "subdir auto-detect failed: '$actual_sub'"
[ -f "$PROJ2/CLAUDE.md" ] && pass "monorepo CLAUDE.md installed" || fail "monorepo CLAUDE.md not found"

# ── real-kit template structure (runs when kit is a sibling of clinit/) ──

CLINIT_DIR="$(dirname "$CLINIT")"
KIT_DIR="$CLINIT_DIR/../ai-dev-setup-kit"
TMPL="$KIT_DIR/project-template/.claude"
if [ -d "$TMPL" ]; then
  # top-level skill presence
  for skill in swift-code-reviewer swift-concurrency swift-expert swift-testing swiftui-expert-skill swiftui-ui-patterns; do
    [ -f "$TMPL/skills/$skill/SKILL.md" ] \
      && pass "kit: $skill/SKILL.md present" \
      || fail "kit: $skill/SKILL.md missing"
  done

  # no stale directories
  [ ! -d "$TMPL/skills-ios" ] \
    && pass "kit: no stale skills-ios directory" \
    || fail "kit: stale skills-ios still present"
  [ ! -d "$TMPL/skills/swift-code-reviewer/skills" ] \
    && pass "kit: swift-code-reviewer/skills/ removed (sub-skills promoted)" \
    || fail "kit: swift-code-reviewer/skills/ still nested"

  # end-to-end apply
  PROJ3="$TMP/project3"
  mkdir -p "$PROJ3" && git -C "$PROJ3" init -q
  actual_kit=$(cd "$PROJ3" && bash "$CLINIT" use "$KIT_DIR" 2>&1)
  for skill in swift-code-reviewer swift-concurrency swift-expert swift-testing swiftui-expert-skill swiftui-ui-patterns; do
    [ -f "$PROJ3/.claude/skills/$skill/SKILL.md" ] \
      && pass "kit apply: $skill installed" \
      || fail "kit apply: $skill not found"
  done
  [ ! -d "$PROJ3/.claude/skills-ios" ] \
    && pass "kit apply: no skills-ios in scaffolded project" \
    || fail "kit apply: stale skills-ios appeared"
fi

# ── unknown command ───────────────────────────────────────────────────────

out3=$(bash "$CLINIT" badcmd 2>&1 || true)
echo "$out3" | grep -q "Unknown command" && pass "unknown command error" || fail "unknown command: got '$out3'"

# ── summary ───────────────────────────────────────────────────────────────

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "All tests passed."
else
  echo "$FAILURES test(s) failed."
  exit 1
fi
