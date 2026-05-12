#!/usr/bin/env bash
# SessionStart hook: nudges the operator/LLM to fire `/audit-docs` when the
# audited file roots have changed since the most recent same-day audit.
#
# Without this nudge, an LLM in a fresh session has to *remember* to run
# /audit-docs. SessionStart context injection is the minimum-friction way
# to surface "docs/ has unaudited changes since last audit" so the LLM
# picks up the slash unprompted.
#
# Pairs with same-day idempotency in c1_docs_audit.py: nudging the LLM is
# safe because if it fires /audit-docs and docs/ is actually still in
# sync, the script's cache-hit fast path returns the existing audit without
# rewriting.
#
# Behavior: stderr nudge only — never blocks the session, never auto-runs the
# audit. The LLM remains in control of whether to invoke /audit-docs.
#
# Hook contract (per docs/harness/components/hooks/SPEC.md):
# - exit 0: silent (no nudge needed; either audit is current, no audit dir
#   yet, or repo not detected).
# - exit 1: stderr nudge surfaced; session continues normally.
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Resolve audit directory (always under the repo, never under HARNESS_ENV-
# scoped var/). Mirrors c1_docs_audit.py _audit_out_dir.
AUDIT_DIR="$PROJECT_DIR/.claude/audits"

# If no audits exist at all, the operator hasn't run /audit-docs since the
# script existed — surface this once at session start.
if [ ! -d "$AUDIT_DIR" ] || ! ls "$AUDIT_DIR"/*-docs-audit*.md >/dev/null 2>&1; then
  echo "[harness] no docs audit on file. Run /audit-docs to baseline (deterministic, \$0, no LLM calls)." >&2
  exit 1
fi

# Find the most recent same-day audit; if none for today, find the most
# recent audit overall.
TODAY=$(date -u +%Y-%m-%d)
latest=""
for candidate in "$AUDIT_DIR/$TODAY-docs-audit"*.md; do
  [ -f "$candidate" ] && latest="$candidate"
done
if [ -z "$latest" ]; then
  # No same-day audit. Find the most recent overall.
  latest=$(ls -t "$AUDIT_DIR"/*-docs-audit*.md 2>/dev/null | head -1)
fi

if [ -z "$latest" ] || [ ! -f "$latest" ]; then
  exit 0  # Defensive: no audit at all (covered above) — silent.
fi

# Compare audit mtime against any audited file's mtime. We mirror the ROOTS
# list in c1_docs_audit.py to keep the trigger-shape aligned.
audit_mtime=$(stat -f %m "$latest" 2>/dev/null || stat -c %Y "$latest" 2>/dev/null || echo 0)

stale=0
for root in "docs" "CLAUDE.md" ".claude/skills" ".claude/agents" ".claude/rules" ".claude/hooks"; do
  target="$PROJECT_DIR/$root"
  [ ! -e "$target" ] && continue
  # find any file newer than audit; -newer is portable (mtime comparison).
  if [ -f "$target" ]; then
    target_mtime=$(stat -f %m "$target" 2>/dev/null || stat -c %Y "$target" 2>/dev/null || echo 0)
    if [ "$target_mtime" -gt "$audit_mtime" ]; then
      stale=1
      break
    fi
  else
    if find "$target" -type f -newer "$latest" -print -quit 2>/dev/null | grep -q .; then
      stale=1
      break
    fi
  fi
done

if [ "$stale" = "1" ]; then
  rel=$(printf '%s' "$latest" | sed "s|$PROJECT_DIR/||")
  echo "[harness] audited file roots have changed since $rel. Consider running /audit-docs (deterministic, \$0, no LLM calls; cached if nothing changed)." >&2
  exit 1
fi

# Audit is current — silent on success.
exit 0
