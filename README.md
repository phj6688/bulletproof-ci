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
| `--workdir DIR` | (root) | Run the node package-manifest steps inside `DIR` (relative to the repo), for apps that live in a subdir (e.g. `router/`). Auto-detection looks inside `DIR` too. |
| `--node-versions LIST` | `20,22` | Comma-separated node versions for the test matrix (node stack), e.g. `22` or `20,22,24`. |
| `--gate-name "NAME"` | `CI passed` | Name of the aggregate gate job (the required context). |
| `--e2e` | off | Add a Playwright e2e job (node stacks only). |
| `--mutation` | off | Also emit `.github/workflows/mutation.yml`: a scheduled (cron) + manual mutation-testing run (cosmic-ray for python, Stryker for node). Advisory, never a per-PR blocker. python/node only. |
| `--cron "EXPR"` | `0 4 * * 1` | Schedule for `--mutation` (weekly Mon 04:00 UTC by default). |
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

## Mutation testing (opt-in)

`--mutation` emits a SECOND workflow, `.github/workflows/mutation.yml`, separate
from `ci.yml`. It runs on a schedule (`--cron`, default weekly Mon 04:00 UTC)
plus manual `workflow_dispatch` only: no `pull_request` / `push`, so it is never
a per-PR blocker. It installs the mutation tool inside the job (cosmic-ray for
python via `pip`, Stryker via `npx` for node), runs a scoped pass, and writes a
mutation kill-rate to the run summary. It is advisory: a low score does not fail
the job, only real tooling errors do. There is no aggregate gate job in this
workflow on purpose.

A full mutation run is too slow for CI, so the workflow scopes itself to a
representative module (cosmic-ray `module-path`, default `src`) or glob (Stryker
`--mutate`, default `src/**/*.{js,ts}`) to sample roughly 100-200 mutants. Edit
that scope to your hottest module. Stryker also needs a test-runner plugin (e.g.
`@stryker-mutator/jest-runner`) declared in your repo. `--mutation` applies to
python and node only; other stacks log a warning and are skipped.

## Requirements

- `bash`, `sed`, `git`, `python3` (YAML validation). `gh` + `jq` only for
  `--protect` / `--pr`.

## License

MIT, see [LICENSE](LICENSE).
