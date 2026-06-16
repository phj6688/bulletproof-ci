---
name: bulletproof-ci
description: >
  Use when the user wants to add, fix, or standardize GitHub Actions CI on a
  repo, asks for a "CI gate" / "bulletproof CI" / a single required status
  check, wants branch protection that requires CI without deadlocking, or says
  "/bulletproof-ci". Generates a per-stack ci.yml whose jobs all funnel into one
  aggregate gate job, and can apply matching branch protection. NEVER trigger
  for unrelated workflow edits (deploy, release, scheduled jobs).
allowed-tools: [Read, Bash, Glob, Grep]
---

# bulletproof-ci

Generate a GitHub Actions workflow whose jobs all funnel into **one** aggregate
gate job (default name `CI passed`). That single context is what branch
protection requires. Because the same workflow runs on both `push` and
`pull_request` for every integration branch, the gate is always producible, so
protecting `dev` / `master` / `main` on one required check never deadlocks.

The work is done by the bundled generator `bin/bulletproof-ci`. This skill is
the contract for invoking it correctly and reading its result. The generator is
dependency-light: `bash`, `sed`, `git`, `gh` (only for `--protect` / `--pr`),
and `python3` (YAML validation).

---

## 1. Activation

Activates from the `/bulletproof-ci` slash command, or when the user asks to add
or repair CI on a repo. The working directory at invocation is the default
target unless the user names a path.

Resolve three things before running anything:

- **Target repo.** Default to the current directory. A path argument overrides it.
- **Stack.** Default `auto`. Only pass `--stack` when detection would be wrong
  (e.g. a polyglot repo where the user wants a specific stack).
- **Branches.** Default `dev,master,main`. Narrow it to the branches the repo
  actually uses; protecting a branch that does not exist is skipped, not an error.

## 2. The generator

```
bulletproof-ci [PATH] [flags]
```

Flags:

| Flag | Default | Effect |
|---|---|---|
| `--stack auto\|python\|node\|shell\|skill\|generic` | `auto` | Pick the template. `auto` detects from files. |
| `--branches a,b,c` | `dev,master,main` | Workflow trigger branches and (with `--protect`) the branches to protect. |
| `--gate-name "NAME"` | `CI passed` | Name of the aggregate gate job (the required context). |
| `--e2e` | off | Add a Playwright e2e job. Node stacks only; ignored elsewhere. |
| `--protect` | off | After writing, apply branch protection requiring the gate on each branch. Needs `gh` + `jq`. |
| `--enforce-admins` / `--no-enforce-admins` | enforce | Whether protection binds admins too (with `--protect`). |
| `--reviews N` | `0` | Required approving reviews for protection. |
| `--pr` | off | Commit to a `chore/ci` branch, push, open a PR instead of only writing the tree. Needs `gh`. |
| `--dry-run` | off | Print the plan and the would-be workflow; change nothing. |
| `-h`, `--help` | | Usage. |

Auto-detection order (first match wins): `SKILL.md` / `.claude-plugin/plugin.json`
/ `skills/*/SKILL.md` → **skill**; `package.json` → **node**; `pyproject.toml`
/ `requirements.txt` / `setup.py` / `setup.cfg` → **python**; mostly `*.sh` →
**shell**; otherwise **generic**.

The generator writes `.github/workflows/ci.yml`, substituting `--branches` and
`--gate-name`, then validates the emitted YAML before exiting. It logs to stderr;
in `--dry-run` the workflow preview goes to stdout.

## 3. Recommended flow

1. **Dry-run first** to confirm the detected stack and the file it will write:
   `bulletproof-ci --dry-run`. Read the detected stack and gate name from the log.
2. **Write** the workflow: `bulletproof-ci` (or `--pr` to open a PR instead of
   touching the working tree directly).
3. **Protect** only after the workflow exists on the target branch and has run at
   least once (so the `CI passed` context is registered): `bulletproof-ci --protect`.
   Protecting before the check has ever reported can require the context before it
   can be produced; the push trigger fixes this on first push, but verify a run
   landed before relying on the gate.
4. **Verify**: confirm `gh run list` shows the workflow and the gate job appears
   as `CI passed`. For `--protect`, confirm with
   `gh api repos/<owner>/<repo>/branches/<branch>/protection`.

## 4. What each stack template does

- **python** — ruff (or flake8 fallback), mypy (only if configured), pytest
  matrix (3.11/3.12; passes with a note when there are no tests), install/import
  build sanity.
- **node** — detects npm/pnpm/yarn from the lockfile; lint (script or eslint),
  `tsc --noEmit` (if tsconfig), test matrix (20/22), build. `--e2e` adds
  Playwright. Each step no-ops with a note when the relevant script is absent.
- **shell** — shellcheck on all `*.sh`, actionlint on the workflows themselves,
  YAML + markdown sanity.
- **skill** — validates `SKILL.md` frontmatter has `name` + `description`,
  validates any `plugin.json` / `marketplace.json` JSON, shellcheck on scripts,
  lenient markdownlint.
- **generic** — actionlint + YAML/JSON/shell sanity. Minimal fallback.

Every template ends with the `CI passed` gate: `needs:` all other jobs,
`if: always()`, fails if any needed job's result is not `success`. Least
privilege (`contents: read`), concurrency cancels superseded runs, action major
versions pinned.

## 5. Guardrails

- The gate name the user picks must match the protected context exactly. If you
  change `--gate-name`, change the protection (re-run with `--protect`).
- `--protect`, `--pr` touch the remote. Do not run them on a repo the user did
  not ask you to change. Per homelab convention, never commit straight to `dev`
  or the default branch: `--pr` opens a `chore/ci` branch.
- This skill standardizes the *gate shape*. It does not invent tests. A stack
  with no tests gets a green-but-honest "no tests yet" step, not a fake pass.
