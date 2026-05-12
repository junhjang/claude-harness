#!/usr/bin/env bash
# Smoke tests for pr-create-gate.sh.
# Each case feeds crafted stdin to the hook and verifies the exit code +
# whether the bypass log was updated (when relevant).
#
# Run: bash .claude/hooks/test_pr-create-gate.sh
set -uo pipefail

HOOK="$(dirname "$0")/pr-create-gate.sh"
TMP_PROJECT_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_PROJECT_DIR"' EXIT

# Use a tmp dir as CLAUDE_PROJECT_DIR so we don't pollute real var/.
# The hook will git-rev-parse against the tmp dir; we make it a real repo on
# a known feature branch.
(
  cd "$TMP_PROJECT_DIR"
  git init -q
  git config user.email "test@test"
  git config user.name "test"
  git checkout -qb feature/test-gate
  echo "x" > x.txt
  git add x.txt
  git commit -qm "init"
)

PROJECT_DIR="$TMP_PROJECT_DIR"
HEAD_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)
ENV_DIR="$PROJECT_DIR/var/dev/review-changes"

PASS=0
FAIL=0
run_case() {
  local name="$1" expected_exit="$2" cmd="$3" extra_env="${4:-}"
  local input
  input=$(printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$cmd" | jq -Rs .)")
  local actual_exit
  if [ -n "$extra_env" ]; then
    actual_exit=$(env -i PATH="$PATH" CLAUDE_PROJECT_DIR="$PROJECT_DIR" $extra_env bash "$HOOK" <<< "$input" >/dev/null 2>&1; echo $?)
  else
    actual_exit=$(env -i PATH="$PATH" CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$HOOK" <<< "$input" >/dev/null 2>&1; echo $?)
  fi
  if [ "$actual_exit" = "$expected_exit" ]; then
    printf 'PASS  %-60s (exit=%s)\n' "$name" "$actual_exit"
    PASS=$((PASS+1))
  else
    printf 'FAIL  %-60s (got=%s expected=%s)\n' "$name" "$actual_exit" "$expected_exit"
    FAIL=$((FAIL+1))
  fi
}

# Reset bypass log for clean counting
rm -rf "$ENV_DIR"

# Cases that should NOT fire the matcher (exit 0, hook silent)
run_case "ignores plain echo"                          0 "echo hello"
run_case "ignores quoted gh pr create in printf"        0 "printf 'gh pr create demo'"
run_case "ignores quoted gh pr create in git log"       0 'git log --grep "gh pr create"'

# Cases that should fire the matcher and BLOCK (exit 2; no state file yet)
run_case "blocks bare gh pr create"                    2 "gh pr create --title test"
run_case "blocks bare gh pr merge"                     2 "gh pr merge 1"
run_case "blocks cd && gh pr create"                   2 "cd repo && gh pr create"
run_case "blocks env-var-prefixed gh pr create"        2 "FOO=1 gh pr create"
run_case "blocks BYPASS-typo (env var)"                2 "BYPASS_REVIEW_CHANGE=1 gh pr create"

# Cases that should fire the matcher and BYPASS (exit 0; bypass.log written)
LOG_BEFORE=0
run_case "BYPASS env var allows + logs"                0 "BYPASS_REVIEW_CHANGES=1 gh pr create" "BYPASS_REVIEW_CHANGES=1"
LOG_AFTER=$(wc -l < "$ENV_DIR/bypass.log" 2>/dev/null | tr -d ' ' || echo 0)
if [ "$LOG_AFTER" = "1" ]; then
  printf 'PASS  %-60s (log lines=%s)\n' "BYPASS log was actually written" "$LOG_AFTER"
  PASS=$((PASS+1))
else
  printf 'FAIL  %-60s (got=%s expected=1)\n' "BYPASS log was actually written" "$LOG_AFTER"
  FAIL=$((FAIL+1))
fi

# F13 fix: BYPASS in the cmd string ALONE (no env var) must also bypass.
# This is the real-world Claude Code path — `BYPASS_REVIEW_CHANGES=1 gh pr create`
# typed into the Bash tool's command field; the hook is launched by CC's harness
# (not the user's shell) so the env var only ever lives in the cmd string.
run_case "BYPASS cmd-prefix allows (no env)"           0 "BYPASS_REVIEW_CHANGES=1 gh pr create"
LOG_AFTER2=$(wc -l < "$ENV_DIR/bypass.log" 2>/dev/null | tr -d ' ' || echo 0)
if [ "$LOG_AFTER2" = "2" ]; then
  printf 'PASS  %-60s (log lines=%s)\n' "BYPASS cmd-prefix also logs" "$LOG_AFTER2"
  PASS=$((PASS+1))
else
  printf 'FAIL  %-60s (got=%s expected=2)\n' "BYPASS cmd-prefix also logs" "$LOG_AFTER2"
  FAIL=$((FAIL+1))
fi

# F13 fix: BYPASS prefix mid-pipeline (after &&) must also be honored.
run_case "BYPASS after && allows"                      0 "cd repo && BYPASS_REVIEW_CHANGES=1 gh pr create"

# Case that should fire matcher and ALLOW (exit 0; state file with valid verdict).
# State file is keyed on HEAD sha (not branch slug) for multi-session correctness.
mkdir -p "$ENV_DIR"
cat > "$ENV_DIR/${HEAD_SHA}.json" <<EOF
{"branch":"feature/test-gate","head_sha":"$HEAD_SHA","verdict":"PASS","early_terminated":false}
EOF
run_case "state file with PASS allows"                 0 "gh pr create"

cat > "$ENV_DIR/${HEAD_SHA}.json" <<EOF
{"branch":"feature/test-gate","head_sha":"$HEAD_SHA","verdict":"CHANGE-REQUEST","early_terminated":false}
EOF
run_case "state file with CHANGE-REQUEST allows"       0 "gh pr create"

cat > "$ENV_DIR/${HEAD_SHA}.json" <<EOF
{"branch":"feature/test-gate","head_sha":"$HEAD_SHA","verdict":"BLOCK","early_terminated":false}
EOF
run_case "state file with BLOCK refuses"               2 "gh pr create"

# Defensive: filename and recorded sha disagree (corruption / manual copy).
cat > "$ENV_DIR/${HEAD_SHA}.json" <<EOF
{"branch":"feature/test-gate","head_sha":"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef","verdict":"PASS","early_terminated":false}
EOF
run_case "filename/recorded-sha mismatch refuses"      2 "gh pr create"

cat > "$ENV_DIR/${HEAD_SHA}.json" <<EOF
{"branch":"feature/test-gate","head_sha":"$HEAD_SHA","verdict":"PASS","early_terminated":true}
EOF
run_case "state file with early_terminated refuses"    2 "gh pr create"

# Multi-session correctness: state for a DIFFERENT sha exists; HEAD is at
# HEAD_SHA (no state for it). Hook must block — pretending the other-sha
# review covers HEAD would be unsafe (different commits, different diffs).
rm -f "$ENV_DIR/${HEAD_SHA}.json"
OTHER_SHA="cafebabecafebabecafebabecafebabecafebabe"
cat > "$ENV_DIR/${OTHER_SHA}.json" <<EOF
{"branch":"feature/other-session","head_sha":"$OTHER_SHA","verdict":"PASS","early_terminated":false}
EOF
run_case "multi-session: state for other sha refuses"  2 "gh pr create"
rm -f "$ENV_DIR/${OTHER_SHA}.json"

echo
echo "=== summary: $PASS pass / $FAIL fail ==="
[ "$FAIL" = "0" ]
