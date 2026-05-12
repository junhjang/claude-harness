#!/usr/bin/env bash
# PostToolUse hook: format the file Claude just wrote/edited.
# Non-blocking — formatter failures only warn.
# Rust + Python preset — extend the case-statement for other languages.
set -uo pipefail

input=$(cat)
fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
[[ -z "$fp" || ! -f "$fp" ]] && exit 0

case "$fp" in
  *.rs)
    if command -v rustfmt >/dev/null 2>&1; then
      rustfmt "$fp" 2>/dev/null || echo "[auto-format] rustfmt warned on $fp" >&2
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      ruff format "$fp" >/dev/null 2>&1 || echo "[auto-format] ruff format warned on $fp" >&2
    fi
    ;;
esac

exit 0
