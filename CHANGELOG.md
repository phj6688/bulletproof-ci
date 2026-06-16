# Changelog

## 0.1.0

- Initial release.
- `bin/bulletproof-ci` generator with stack auto-detection and flags: `--stack`,
  `--branches`, `--gate-name`, `--e2e`, `--protect`, `--enforce-admins` /
  `--no-enforce-admins`, `--reviews`, `--pr`, `--dry-run`, `--help`.
- Per-stack templates: `python`, `node`, `shell`, `skill`, `generic`. Each
  funnels every job into one `CI passed` aggregate gate with least-privilege
  permissions, concurrency cancellation, and pinned action major versions.
- `--e2e` injects a Playwright job into the node workflow.
- `--protect` applies branch protection (strict, enforce-admins, 0 reviews by
  default) requiring the gate context, skipping branches absent on the remote.
- Packaged as a Claude Code plugin: `/bulletproof-ci` command plus the
  `bulletproof-ci` skill.
