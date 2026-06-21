# Changelog

## Unreleased

- Add `--workdir DIR` for repos whose package manifest lives in a subdirectory
  (e.g. a Node app entirely under `router/`). Auto-detection looks inside DIR, and
  the node workflow runs install/lint/typecheck/test/build there via a top-level
  `defaults.run.working-directory` plus a `cache-dependency-path: DIR/<lockfile>`
  on each `setup-node`. Empty (default) keeps root-only behavior byte-identical.

- Fix dot-dir-blind discovery in `skill` and `generic` templates: switch from
  `glob.glob('**')` (which skips hidden dirs) to `pathlib.rglob`, so manifests at
  `.claude-plugin/plugin.json` / `marketplace.json` are found and validated. The
  skill gate now fails only when neither a SKILL.md nor a plugin/marketplace
  manifest exists; command-only plugins pass.
- Fix Python template failing on dependency-less repos: drop the unconditional
  `cache: pip` from `actions/setup-python`, which errored when no
  requirements.txt/pyproject.toml was present.
- Fix generator crash when a branch name contains a slash (e.g.
  `feat/phase2-baselines`): switch the `sed` substitution delimiter to `|`.

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
