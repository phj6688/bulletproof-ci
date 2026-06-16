---
description: Generate a single-aggregate-gate GitHub Actions CI workflow for this repo (per stack), and optionally apply matching branch protection.
argument-hint: "[path] [--stack auto|python|node|shell|skill|generic] [--branches dev,master,main] [--gate-name \"CI passed\"] [--e2e] [--protect] [--pr] [--dry-run]  (default: current repo, auto-detected stack, write ci.yml only)"
---

# Role: CI gate generator

Add or standardize GitHub Actions CI on the target repo using the bundled
`bulletproof-ci` generator. The output is a workflow whose every job funnels
into one aggregate gate job (default `CI passed`). That single context is what
branch protection requires; because the workflow runs on `push` and
`pull_request` for every integration branch, requiring it never deadlocks.

You do not hand-write workflow YAML. You run the generator, read its result, and
verify. Keep the change scoped to what the user asked for.

**Raw argument:** `$ARGUMENTS`

## Steps

1. **Locate the generator.** It ships with this plugin at `bin/bulletproof-ci`
   (templates in `templates/`). Resolve its absolute path from the plugin
   install dir. If running outside the plugin, the repo root's `bin/bulletproof-ci`.

2. **Parse `$ARGUMENTS`.** Pull out a leading path (default: current directory)
   and pass every flag through verbatim. Supported flags: `--stack`,
   `--branches`, `--gate-name`, `--e2e`, `--protect`, `--enforce-admins` /
   `--no-enforce-admins`, `--reviews N`, `--pr`, `--dry-run`, `-h`/`--help`.

3. **Dry-run first.** Run with `--dry-run` to confirm the detected stack, the
   gate name, and the branches. Read the log (stderr) for `auto-detected stack`.
   Surface that to the user if it looks wrong, and suggest an explicit `--stack`.

4. **Write.** Re-run without `--dry-run`. Default writes
   `.github/workflows/ci.yml` in the working tree. If the user passed `--pr`,
   the generator opens a `chore/ci` branch and PR instead. Never commit straight
   to `dev` or the default branch.

5. **Protect (only if asked).** With `--protect`, the generator applies branch
   protection requiring the gate on each `--branches` branch (strict,
   enforce-admins, 0 reviews by default), skipping branches absent on the remote.
   Only do this when the user wants the gate enforced, and ideally after the
   workflow has run once so the context is registered.

6. **Verify and report.** Confirm the file parses (the generator validates the
   emitted YAML itself). Report: the stack chosen, the path written (or the PR
   URL), the gate name, and any protection applied. If `--protect` ran, confirm
   with `gh api repos/<owner>/<repo>/branches/<branch>/protection`.

## Notes

- The gate name and the protected context must match exactly. Change one, change
  the other.
- The generator is dependency-light (`bash`, `sed`, `git`, `python3`, plus `gh`
  for `--protect` / `--pr`).
- It standardizes the gate shape; it does not fabricate tests. A repo with no
  tests gets an honest green "no tests yet" step.
