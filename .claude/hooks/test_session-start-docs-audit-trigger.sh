#!/usr/bin/env bash
# Smoke tests for session-start-docs-audit-trigger.sh.
# Run: bash .claude/hooks/test_session-start-docs-audit-trigger.sh
set -uo pipefail

HOOK="$(dirname "$0")/session-start-docs-audit-trigger.sh"

PASS=0
FAIL=0

run_with() {
  local fx="$1"
  CLAUDE_PROJECT_DIR="$fx" bash "$HOOK" 2>&1
}
exit_with() {
  local fx="$1"
  CLAUDE_PROJECT_DIR="$fx" bash "$HOOK" >/dev/null 2>&1
  echo $?
}
assert_exit() {
  local name="$1" got="$2" expected="$3"
  if [ "$got" = "$expected" ]; then
    printf 'PASS  %-60s (exit=%s)\n' "$name" "$got"
    PASS=$((PASS+1))
  else
    printf 'FAIL  %-60s (got=%s expected=%s)\n' "$name" "$got" "$expected"
    FAIL=$((FAIL+1))
  fi
}
assert_stderr_contains() {
  local name="$1" stderr="$2" needle="$3"
  if printf '%s' "$stderr" | grep -q -F -- "$needle"; then
    printf 'PASS  %-60s (stderr contains "%s")\n' "$name" "$needle"
    PASS=$((PASS+1))
  else
    printf 'FAIL  %-60s (stderr missing "%s")\n' "$name" "$needle"
    printf '       stderr was: %s\n' "$stderr"
    FAIL=$((FAIL+1))
  fi
}
assert_silent() {
  local name="$1" stderr="$2"
  if [ -z "$stderr" ]; then
    printf 'PASS  %-60s (silent)\n' "$name"
    PASS=$((PASS+1))
  else
    printf 'FAIL  %-60s (got: %s)\n' "$name" "$stderr"
    FAIL=$((FAIL+1))
  fi
}

# === CASE 1: no audit dir → nudge to baseline ===
fx=$(mktemp -d)
out=$(run_with "$fx" || true)
ec=$(exit_with "$fx")
assert_exit "no audit dir exits 1"                                "$ec" "1"
assert_stderr_contains "no audit dir nudges to baseline"          "$out" "no docs audit on file"
rm -rf "$fx"

# === CASE 2: audit exists, all roots older → silent ===
fx=$(mktemp -d)
mkdir -p "$fx/.claude/audits" "$fx/docs"
echo "# stub" > "$fx/docs/a.md"
sleep 1.1  # mtime granularity is 1s; smaller waits are unreliable
echo "# audit" > "$fx/.claude/audits/2099-01-01-docs-audit.md"
out=$(run_with "$fx" || true)
ec=$(exit_with "$fx")
assert_exit "fresh audit exits 0"                                  "$ec" "0"
assert_silent "fresh audit is silent"                              "$out"
rm -rf "$fx"

# === CASE 3: doc modified after audit → nudge ===
fx=$(mktemp -d)
mkdir -p "$fx/.claude/audits" "$fx/docs"
echo "# audit" > "$fx/.claude/audits/2099-01-01-docs-audit.md"
sleep 1.1  # mtime granularity is 1s; smaller waits are unreliable
echo "# new" > "$fx/docs/a.md"
out=$(run_with "$fx" || true)
ec=$(exit_with "$fx")
assert_exit "stale audit exits 1"                                  "$ec" "1"
assert_stderr_contains "stale audit nudges to re-audit"            "$out" "audited file roots have changed since"
rm -rf "$fx"

# === CASE 4: CLAUDE.md modified after audit → nudge ===
fx=$(mktemp -d)
mkdir -p "$fx/.claude/audits"
echo "# audit" > "$fx/.claude/audits/2099-01-01-docs-audit.md"
sleep 1.1  # mtime granularity is 1s; smaller waits are unreliable
echo "# claude" > "$fx/CLAUDE.md"
out=$(run_with "$fx" || true)
ec=$(exit_with "$fx")
assert_exit "CLAUDE.md change triggers nudge"                      "$ec" "1"
assert_stderr_contains "CLAUDE.md change names roots-changed"      "$out" "audited file roots have changed"
rm -rf "$fx"

# === CASE 5: .claude/skills change after audit → nudge ===
fx=$(mktemp -d)
mkdir -p "$fx/.claude/audits" "$fx/.claude/skills/foo"
echo "# audit" > "$fx/.claude/audits/2099-01-01-docs-audit.md"
sleep 1.1  # mtime granularity is 1s; smaller waits are unreliable
echo "# skill" > "$fx/.claude/skills/foo/SKILL.md"
out=$(run_with "$fx" || true)
ec=$(exit_with "$fx")
assert_exit ".claude/skills change triggers nudge"                 "$ec" "1"
rm -rf "$fx"

# === CASE 6: only audit dir + audit (no docs at all) → silent ===
fx=$(mktemp -d)
mkdir -p "$fx/.claude/audits"
echo "# audit" > "$fx/.claude/audits/2099-01-01-docs-audit.md"
out=$(run_with "$fx" || true)
ec=$(exit_with "$fx")
assert_exit "audit-only fixture exits 0"                           "$ec" "0"
rm -rf "$fx"

echo
echo "=== summary: $PASS pass / $FAIL fail ==="
[ "$FAIL" = "0" ]
