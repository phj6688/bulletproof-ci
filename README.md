# bulletproof-ci

*Drop a single-required-check CI gate onto any repo, per stack, without deadlocking branch protection.*

`bulletproof-ci` generates a GitHub Actions workflow whose jobs all funnel into
**one** aggregate gate job (default name `CI passed`). That single context is the
only check branch protection needs to require. The same workflow runs on both
`push` and `pull_request` for every integration branch, so the gate is always
producible and protecting `dev` / `master` / `main` never deadlocks.

## Install

In Claude Code:

```
/plugin marketplace add phj6688/claude-marketplace
/plugin install bulletproof-ci@phj
```

## Use

In any repo:

```
/bulletproof-ci
```

Or run the generator directly:

```
bin/bulletproof-ci [PATH] [flags]
```

Examples:

```
bulletproof-ci                          # auto-detect stack, write .github/workflows/ci.yml
bulletproof-ci --dry-run                # show the plan and the would-be workflow, change nothing
bulletproof-ci . --stack node --e2e     # node app with a Playwright e2e job
bulletproof-ci ~/projects/foo --protect --branches dev,master
bulletproof-ci --stack skill --pr       # open a chore/ci PR adding CI to a skill repo
```

## Flags

| Flag | Default | Effect |
|---|---|---|
| `--stack auto\|python\|node\|shell\|skill\|generic` | `auto` | Template to use. `auto` detects from files. |
| `--branches a,b,c` | `dev,master,main` | Trigger branches, and (with `--protect`) the branches to protect. |
| `--gate-name "NAME"` | `CI passed` | Name of the aggregate gate job (the required context). |
| `--e2e` | off | Add a Playwright e2e job (node stacks only). |
| `--protect` | off | Apply branch protection requiring the gate on each branch (needs `gh` + `jq`). |
| `--enforce-admins` / `--no-enforce-admins` | enforce | Whether protection binds admins (with `--protect`). |
| `--reviews N` | `0` | Required approving reviews for protection. |
| `--pr` | off | Commit to a `chore/ci` branch, push, open a PR (needs `gh`). |
| `--dry-run` | off | Print the plan; change nothing. |
| `-h`, `--help` | | Usage. |

## Stacks

| Stack | Jobs |
|---|---|
| `python` | ruff (or flake8), mypy if configured, pytest matrix (3.11/3.12), install/import sanity |
| `node` | lint, `tsc --noEmit` if tsconfig, test matrix (20/22), build; `--e2e` adds Playwright |
| `shell` | shellcheck, actionlint, YAML + markdown sanity |
| `skill` | validate `SKILL.md` frontmatter + JSON manifests, shellcheck, lenient markdownlint |
| `generic` | actionlint + YAML/JSON/shell sanity |

Every workflow ends with the `CI passed` gate: `needs:` every other job,
`if: always()`, and fails if any needed job's result is not `success`. Each
workflow uses least-privilege permissions (`contents: read`), cancels superseded
runs via `concurrency`, and pins action major versions.

## The gate contract

Branch protection should require exactly the gate context (`CI passed` by
default). Because the workflow triggers on `push` too, a branch with no PR still
produces the check, so protection never blocks an integration branch from
receiving its first qualifying run. Change `--gate-name` and you must change the
protected context to match (re-run with `--protect`).

It standardizes the gate shape. It does not invent tests: a repo with no tests
gets an honest green "no tests yet" step, not a fake pass.

## Requirements

- `bash`, `sed`, `git`, `python3` (YAML validation). `gh` + `jq` only for
  `--protect` / `--pr`.

## License

MIT, see [LICENSE](LICENSE).
