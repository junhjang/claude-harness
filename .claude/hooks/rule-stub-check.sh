#!/usr/bin/env bash
# PostToolUse hook on Write|Edit: rejects rule files (`.claude/rules/*-llm-failures.md`)
# that lack a `## Project-specific tips` section at the bottom.
# Every LLM-failure-modes rule file should leave room for project-specific tips
# (war-stories, codebase-specific gotchas) that future sessions append.
#
# Catalogs are NOT rule files — they have their own closing discipline section
# ("Catalog discipline"). Therefore this hook scopes by filename pattern:
# only `<lang>-llm-failures.md` files are enforced.
set -uo pipefail

input=$(cat)
fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')

# Only files in .claude/rules/
case "$fp" in
  */.claude/rules/*|.claude/rules/*) ;;
  *) exit 0 ;;
esac

# Only LLM-failure-modes rule files (other rule-shaped files in this dir may have
# different structures — e.g., catalogs, references).
case "$(basename "$fp")" in
  *-llm-failures.md) ;;
  *) exit 0 ;;
esac

# File must exist on disk (PostToolUse runs after the write).
[[ -f "$fp" ]] || exit 0

if ! grep -q "^## Project-specific tips" "$fp"; then
  echo "[rule-stub-check] BLOCKED: $fp lacks the '## Project-specific tips' section." >&2
  echo "  Per .claude/rules convention: every <lang>-llm-failures.md must end with" >&2
  echo "  a '## Project-specific tips' section so future sessions can append codebase-specific" >&2
  echo "  war-stories without restructuring the file." >&2
  echo "  Add at the bottom:" >&2
  echo "" >&2
  echo "    ---" >&2
  echo "" >&2
  echo "    ## Project-specific tips" >&2
  echo "" >&2
  echo "    <!-- TODO: project owner — patterns observed in this codebase. -->" >&2
  exit 2
fi

exit 0
