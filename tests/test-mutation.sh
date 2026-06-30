#!/usr/bin/env bash
# Tests for the --mutation scheduled mutation-testing workflow generator.
# Fabricates minimal python/node/shell projects, runs the generator, and asserts
# the emitted mutation.yml is a scheduled, advisory, gate-free workflow. Exits
# non-zero on any failed assertion.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BPC="$ROOT/bin/bulletproof-ci"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail=0
pass() { printf 'PASS: %s\n' "$1"; }
bad()  { printf 'FAIL: %s\n' "$1" >&2; fail=1; }

assert_contains() { # <label> <needle> <haystack>
  if printf '%s' "$3" | grep -qiF -- "$2"; then
    pass "$1: contains '$2'"
  else
    bad "$1: missing '$2'"
  fi
}

assert_absent() { # <label> <needle> <haystack>
  if printf '%s' "$3" | grep -qiF -- "$2"; then
    bad "$1: unexpected '$2'"
  else
    pass "$1: no '$2'"
  fi
}

# Extract the second dash-delimited preview block from a --mutation --dry-run
# stdout (block 1 = ci.yml, block 2 = mutation.yml).
mutation_preview() { # <full-stdout>
  printf '%s\n' "$1" | awk '/^-+$/ { s++; next } s == 3 { print }'
}

# Assert the standard shape of a generated mutation workflow.
assert_mutation_shape() { # <label> <tool> <preview>
  local label="$1" tool="$2" preview="$3"
  [ -n "$preview" ] || bad "$label: mutation preview is empty"
  assert_contains "$label" "schedule:" "$preview"
  assert_contains "$label" "cron:" "$preview"
  assert_contains "$label" "workflow_dispatch:" "$preview"
  assert_absent   "$label" "pull_request:" "$preview"
  assert_absent   "$label" "push:" "$preview"
  assert_contains "$label" "$tool" "$preview"
  assert_contains "$label" "GITHUB_STEP_SUMMARY" "$preview"
  assert_contains "$label" "kill-rate" "$preview"
  assert_absent   "$label" "__GATE_NAME__" "$preview"
  assert_absent   "$label" "ci-passed" "$preview"
}

# ---- python: minimal pyproject.toml ----------------------------------------
mkdir -p "$TMP/py"
printf '[project]\nname = "demo"\nversion = "0.0.0"\n' > "$TMP/py/pyproject.toml"
if ! py_out="$(bash "$BPC" "$TMP/py" --stack python --mutation --dry-run 2>/dev/null)"; then
  bad "python: --mutation --dry-run exited non-zero"; py_out=""
fi
assert_mutation_shape "python" "cosmic-ray" "$(mutation_preview "$py_out")"

# real write lands the file
bash "$BPC" "$TMP/py" --stack python --mutation >/dev/null 2>&1
if [ -f "$TMP/py/.github/workflows/mutation.yml" ]; then
  pass "python: mutation.yml written"
  assert_contains "python(file)" "cron:" "$(cat "$TMP/py/.github/workflows/mutation.yml")"
else
  bad "python: mutation.yml not written"
fi
if [ -f "$TMP/py/.github/workflows/ci.yml" ]; then pass "python: ci.yml still written"; else bad "python: ci.yml missing"; fi

# ---- node: minimal package.json --------------------------------------------
mkdir -p "$TMP/node"
printf '{ "name": "demo", "version": "0.0.0" }\n' > "$TMP/node/package.json"
if ! node_out="$(bash "$BPC" "$TMP/node" --stack node --mutation --dry-run 2>/dev/null)"; then
  bad "node: --mutation --dry-run exited non-zero"; node_out=""
fi
assert_mutation_shape "node" "stryker" "$(mutation_preview "$node_out")"

bash "$BPC" "$TMP/node" --stack node --mutation >/dev/null 2>&1
if [ -f "$TMP/node/.github/workflows/mutation.yml" ]; then
  pass "node: mutation.yml written"
else
  bad "node: mutation.yml not written"
fi

# ---- custom cron is substituted --------------------------------------------
cron_out="$(bash "$BPC" "$TMP/py" --stack python --mutation --cron '30 2 * * 0' --dry-run 2>/dev/null)"
assert_contains "cron" "30 2 * * 0" "$(mutation_preview "$cron_out")"

# ---- unsupported stack: warn, emit no mutation.yml -------------------------
mkdir -p "$TMP/sh"
printf '#!/usr/bin/env bash\necho hi\n' > "$TMP/sh/run.sh"
sh_err="$(bash "$BPC" "$TMP/sh" --stack shell --mutation 2>&1 >/dev/null)"
assert_contains "shell" "only applies to python and node" "$sh_err"
if [ -f "$TMP/sh/.github/workflows/mutation.yml" ]; then
  bad "shell: mutation.yml should not be emitted"
else
  pass "shell: no mutation.yml emitted"
fi
if [ -f "$TMP/sh/.github/workflows/ci.yml" ]; then pass "shell: ci.yml still generated"; else bad "shell: ci.yml missing"; fi

# ---- result ----------------------------------------------------------------
if [ "$fail" -ne 0 ]; then
  echo "SOME MUTATION TESTS FAILED" >&2
  exit 1
fi
echo "ALL MUTATION TESTS PASSED"
