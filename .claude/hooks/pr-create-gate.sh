#!/usr/bin/env bash
# PreToolUse hook on Bash(gh pr create*) and Bash(gh pr merge*).
# Blocks the gh command unless /review-changes has produced a non-BLOCK verdict
# for the current HEAD sha (state artifact at var/<env>/review-changes/<head-sha>.json).
#
# Subscription-only LLM with local pre-merge gate.
# SHA-based state keying — state files identified by HEAD sha, not branch slug.
# Required for multi-session correctness: when two Claude Code sessions share
# one working tree, branch is shared mutable state but HEAD sha is the
# authoritative identity of "what's about to be PR'd."
#
# Failure signature: a `gh pr create` / `gh pr merge` runs without semantic
#   review having been done first, OR the working tree's HEAD has moved since
#   the review (commit / amend / rebase / branch switch).
# Detection: this hook fires before the gh tool runs and refuses if state is
#   missing / sha-mismatched / BLOCK.
# Mitigation / graceful degradation: BYPASS_REVIEW_CHANGES=1 env override for
#   hotfixes. Bypasses are logged to var/<env>/review-changes/bypass.log.
#
# Scope: catches accidental gh-pr-create when local review state is stale.
# This is an oversight gate, not a security boundary — a determined operator
# can bypass via `eval`, `bash -c`, subshells `(gh pr create)`, the `gh api`
# endpoint directly, or BYPASS_REVIEW_CHANGES=1. The documented bypass is
# the only one that's logged.
set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Only fire on real `gh pr create` / `gh pr merge` invocations. We require `gh`
# to appear at command position — preceded by command-start, `&&`, `;`, `||`,
# `|`, `&`, or env-var assignments (`VAR=val [VAR=val ...] gh ...`) — and
# never inside a quoted string (commit messages, printf args, git-log greps).
#
# Strip single- and double-quoted regions first to suppress quoted false-
# positives. Then strip leading env-var assignments (and the same after `&&`
# / `;` / `||` / `|` / `&`) so the matcher sees `gh` at command position even
# when prefixed with `BYPASS_REVIEW_CHANGES=1` or any other env var.
cmd_unquoted=$(printf '%s' "$cmd" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

# Strip env-var assignments at command-start AND after shell separators so
# the env-var bypass mechanism below fires intentionally rather than letting
# all env-var-prefixed commands sneak past the matcher.
cmd_normalized=$(printf '%s' "$cmd_unquoted" | sed -E '
  s/^[[:space:]]*([A-Za-z_][A-Za-z_0-9]*=[^[:space:]]*[[:space:]]+)+/ /
  s/(&&|\|\||[;&|])[[:space:]]*([A-Za-z_][A-Za-z_0-9]*=[^[:space:]]*[[:space:]]+)+/\1 /g
')

if printf '%s' "$cmd_normalized" | grep -qE '(^|&&|\|\||[;&|])[[:space:]]*gh[[:space:]]+pr[[:space:]]+(create|merge)([[:space:]]|$)'; then
  :
else
  exit 0
fi

# Bypass override — accept either:
#   (1) BYPASS_REVIEW_CHANGES=1 in the hook's own environment, OR
#   (2) `BYPASS_REVIEW_CHANGES=1` as an env-var prefix in the command string itself.
# (1) covers callers that export the var before invocation. (2) covers Claude
# Code's PreToolUse path, where the hook is launched by the harness (NOT by
# the user's shell), so a `BYPASS_REVIEW_CHANGES=1 gh pr create` typed in the
# Bash tool's command field never reaches the hook's env. We have to inspect
# the original command string for the prefix.
cmd_has_bypass_prefix=0
if printf '%s' "$cmd" | grep -qE '(^|&&|\|\||[;&|])[[:space:]]*([A-Za-z_][A-Za-z_0-9]*=[^[:space:]]*[[:space:]]+)*BYPASS_REVIEW_CHANGES=1([[:space:]]|$)'; then
  cmd_has_bypass_prefix=1
fi

if [ "${BYPASS_REVIEW_CHANGES:-0}" = "1" ] || [ "$cmd_has_bypass_prefix" = "1" ]; then
  ENV_DIR="${CLAUDE_PROJECT_DIR:-.}/var/${HARNESS_ENV:-dev}/review-changes"
  mkdir -p "$ENV_DIR"
  printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)" "$cmd" >> "$ENV_DIR/bypass.log"
  echo "[pr-create-gate] BYPASS_REVIEW_CHANGES=1 — allowing without /review-changes (logged to $ENV_DIR/bypass.log)" >&2
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
ENV_DIR="$PROJECT_DIR/var/${HARNESS_ENV:-dev}/review-changes"

branch=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
head_sha=$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || echo "")

if [ -z "$branch" ] || [ -z "$head_sha" ]; then
  echo "[pr-create-gate] WARN: not in a git repo; allowing without review (assumed manual context)" >&2
  exit 0
fi

# Allow gh actions on `main` itself — there's no PR-from-main scenario this gate
# targets. The skill itself refuses to review main; the hook is symmetric.
if [ "$branch" = "main" ]; then
  exit 0
fi

# State file path: keyed on HEAD sha (authoritative identity). Multi-session
# safe: each commit has its own state file. Branch slug appears in the state
# JSON's `branch` field for human readability, not as the lookup key.
state_file="$ENV_DIR/${head_sha}.json"

if [ ! -f "$state_file" ]; then
  echo "[pr-create-gate] BLOCKED: no /review-changes state for HEAD sha $head_sha (branch '$branch')." >&2
  echo "Run \`/review-changes\` first to produce a verdict for this commit." >&2
  echo "  (If another session switched the working tree, switch back to the" >&2
  echo "  intended branch first; gh pr create defaults to current branch.)" >&2
  echo "Bypass for hotfix: BYPASS_REVIEW_CHANGES=1 <gh command>" >&2
  exit 2
fi

# jq-extract head_sha (sanity-check vs filename) + verdict
state_sha=$(jq -r '.head_sha // ""' "$state_file" 2>/dev/null || echo "")
state_verdict=$(jq -r '.verdict // ""' "$state_file" 2>/dev/null || echo "")
state_early_terminated=$(jq -r '.early_terminated // false' "$state_file" 2>/dev/null || echo "false")

if [ -z "$state_sha" ] || [ -z "$state_verdict" ]; then
  echo "[pr-create-gate] BLOCKED: state file '$state_file' is malformed (missing head_sha or verdict)." >&2
  echo "Re-run \`/review-changes\` to regenerate." >&2
  exit 2
fi

# Filename SHA must match the state's recorded sha (defensive — catches
# manually copied / corrupted state files).
if [ "$state_sha" != "$head_sha" ]; then
  echo "[pr-create-gate] BLOCKED: state file's recorded sha does not match its filename." >&2
  echo "  filename sha (HEAD): $head_sha" >&2
  echo "  recorded sha:        $state_sha" >&2
  echo "Re-run \`/review-changes\` to regenerate." >&2
  exit 2
fi

# Verdict must be PASS or CHANGE-REQUEST. BLOCK and EARLY-TERMINATED refuse.
if [ "$state_early_terminated" = "true" ]; then
  echo "[pr-create-gate] BLOCKED: previous /review-changes was early-terminated (cost cap or fan-out failure)." >&2
  echo "Re-run \`/review-changes\` to complete the review." >&2
  exit 2
fi

case "$state_verdict" in
  PASS|CHANGE-REQUEST)
    # CHANGE-REQUEST is allowed at the gate — operator has seen the findings
    # and can decide whether to address them in this PR or follow up.
    exit 0
    ;;
  BLOCK)
    echo "[pr-create-gate] BLOCKED: /review-changes verdict is BLOCK." >&2
    echo "Address the BLOCKER findings and re-run \`/review-changes\` before opening / merging." >&2
    echo "  state file: $state_file" >&2
    exit 2
    ;;
  *)
    echo "[pr-create-gate] BLOCKED: unknown verdict '$state_verdict' in state file." >&2
    echo "Re-run \`/review-changes\` to regenerate." >&2
    exit 2
    ;;
esac
