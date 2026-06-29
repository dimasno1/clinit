# clinit

Claude Code project scaffolder. Copies a `CLAUDE.md` + `.claude/` template into any repository and wires up `.gitignore` to keep local Claude files out of version control.

## Install

```bash
brew tap dzmitry-paplauski/clinit && brew install clinit
```

Requires `jq` for `clinit use` (installed automatically as a dependency).

## Usage

### Apply from local template

After running [ai-dev-setup-kit](https://github.com/dzmitry-paplauski/ai-dev-setup-kit) `install.sh`, scaffold any repo:

```bash
cd your-project
clinit
```

Existing files are not overwritten.

### Apply from a remote kit repo

```bash
clinit use git@github.com:dzmitry-paplauski/ai-dev-setup-kit.git
```

Clones the repo, reads `clinit.json` to find the template path, and applies it.

### Force-apply (overwrite with backup)

```bash
clinit --force
clinit use git@github.com:dzmitry-paplauski/ai-dev-setup-kit.git --force
```

Backs up existing `CLAUDE.md` and `.claude/` with a `.backup.TIMESTAMP` suffix before overwriting.

## What it does

- Copies template files into the current directory, skipping existing ones
- Injects a `# claude-kit-begin … # claude-kit-end` block into `.gitignore` to exclude local Claude files from version control
- Reports what was installed and what was skipped

## `.gitignore` block

clinit manages this block automatically:

```gitignore
# claude-kit-begin
# local-only claude kit files — do not commit
CLAUDE.md
.claude/skills/
.claude/rules/
.claude/skills-ios/
.claude/project_map.md
.claude/.map_checkpoint
.claude.backup.*
CLAUDE.md.backup.*
# claude-kit-end
```
