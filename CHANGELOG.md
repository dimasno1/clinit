# Changelog

## [0.2.1] - 2026-06-29

### Fixed
- `setup_gitignore`: `awk -v new="..."` rejected multiline strings; replaced with temp-file + `getline` approach. The update path (when `.gitignore` already has a `claude-kit-begin` block) now works correctly.

## [0.2.0] - 2026-06-29

### Added
- Local path support: `clinit use ./path/to/kit` and `clinit use /abs/path`
- JSON config URL support: `clinit use https://host/path/to/clinit.json` — fetches manifest, reads `repo` and `subdir`, then clones
- Auto-detect `subdir` from root-level `clinit.json` when cloning a git URL — eliminates `--subdir` for known monorepos
- `_resolve_subdir` helper: follows `subdir` pointer only when the template directory is absent at the root (distinguishes pointer files from full kit manifests)
- `_require_cmd` helper: consistent dependency checks with install hint
- Smoke test suite: `tests/test_clinit.sh`

### Changed
- `cmd_use` refactored into three clear source paths: JSON URL, local path, git URL
- `usage()` updated to document all source types
- VERSION bumped to 0.2.0

### Fixed
- VERSION string now matches the published tag (was "0.1.1" in the v0.1.2 release)

## [0.1.2] - 2026-06-28

### Fixed
- Trap cleanup crash: `_TMP` is now a global variable initialized before the trap fires, preventing `set -u` unbound-variable error after `cmd_use` returns

## [0.1.1] - 2026-06-28

### Added
- `--subdir <path>` flag for monorepo kit layouts

## [0.1.0] - 2026-06-28

### Added
- Initial release
- `clinit` — apply local template from `~/.claude/project-template/`
- `clinit use <git-url>` — clone and apply remote kit
- `.gitignore` claude-kit block injection and update
- `--force` mode with timestamped backup
