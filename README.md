# clinit

Claude Code project scaffolder. Copies a `CLAUDE.md` + `.claude/` template into any repository and wires up `.gitignore` to keep local Claude files out of version control.

## Install

```bash
brew tap dimasno1/clinit && brew install clinit
```

Requires `jq` (installed automatically as a Homebrew dependency).

## Modes

### Default template (no network)

After running `install.sh` from ai-dev-setup-kit, scaffold any project:

```bash
cd your-project
clinit
```

Uses whatever was installed into `~/.claude/project-template/`. No network call.

### Remote kit repo (git URL)

```bash
clinit use git@github.com:dimasno1/ai-stack-setup.git
```

Clones the repo, reads `clinit.json` at the repo root for a `subdir` pointer, navigates into the kit directory, and applies the template. No `--subdir` flag needed when the repo has a root-level `clinit.json`.

### Local kit directory

```bash
clinit use ./ai-dev-setup-kit
clinit use ../ai-stack-setup/ai-dev-setup-kit
```

Useful for local development of the kit. No network call.

### JSON config URL

```bash
clinit use https://raw.githubusercontent.com/dimasno1/ai-stack-setup/main/ai-dev-setup-kit/clinit.json
```

Fetches `clinit.json`, reads `repo` and `subdir` fields, clones the repo, and applies the template. Most portable — works regardless of repo layout.

### Force-apply (overwrite with backup)

```bash
clinit --force
clinit use git@github.com:dimasno1/ai-stack-setup.git --force
```

Backs up existing `CLAUDE.md` and `.claude/` with a `.backup.TIMESTAMP` suffix, then overwrites.

### Override subdir

```bash
clinit use git@github.com:user/repo.git --subdir path/to/kit
```

Explicitly overrides the `subdir` value from `clinit.json`.

## Updating an existing project

- **Via Claude skill**: run `/update-template` in a Claude Code session — compares `.claude/` against `~/.claude/project-template/` and offers per-file updates with backup.
- **Via CLI**: `clinit --force` re-applies the local template with backup.

Future: `clinit update` with smart merge is planned but not yet implemented.

## clinit.json schema

A kit repo's root-level `clinit.json` can act as a pointer for monorepos:

```json
{ "subdir": "ai-dev-setup-kit" }
```

The kit directory's `clinit.json` is the full manifest:

```json
{
  "name": "my-claude-setup",
  "description": "...",
  "version": "0.2.0",
  "repo": "git@github.com:user/repo.git",
  "subdir": "ai-dev-setup-kit",
  "home": "home",
  "template": "project-template"
}
```

Fields consumed by clinit:
- `template` — path to the project template directory (relative to kit root); defaults to `project-template`
- `repo` — git URL; required when clinit.json is fetched via HTTP URL
- `subdir` — kit path within the repo; auto-detected when cloning

## `.gitignore` block

clinit injects and maintains this block in the target project's `.gitignore`:

```gitignore
# claude-kit-begin
# local-only claude kit files — do not commit
CLAUDE.md
.claude/skills/
.claude/rules/
.claude/project_map.md
.claude/.map_checkpoint
.claude.backup.*
CLAUDE.md.backup.*
# claude-kit-end
```

Running clinit again updates the block in place if the template changes.

## Running smoke tests

```bash
bash tests/test_clinit.sh ./clinit.sh
```
