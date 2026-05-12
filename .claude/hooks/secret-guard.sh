#!/usr/bin/env bash
# PreToolUse hook: blocks reads/writes/bash that touch credentials.
# A leaked credential is harder to remediate than to prevent — better to
# false-positive (operator allowlists the path) than to miss.
#
# Scope: first-line check against accidental secret-path reads/writes.
# Pattern-based; bypassable by shell-meta tricks ($VAR expansion, eval,
# bash -c, case-mismatched paths on case-sensitive filesystems). Use a real
# secret scanner (truffleHog, gitleaks) in CI as the security boundary.
set -uo pipefail

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // ""')

is_secret_path() {
  case "$1" in
    *.env|*.env.*|*/.env|*/.env.*) return 0 ;;
    *.pem|*.key|*.p12|*.pfx) return 0 ;;
    */secrets/*|*/secret/*|*/credentials/*) return 0 ;;
    */.aws/credentials|*/.aws/config) return 0 ;;
    */.config/gcloud/*) return 0 ;;
    */.ssh/id_*|*/id_rsa|*/id_ed25519) return 0 ;;
    *) return 1 ;;
  esac
}

block() {
  echo "[secret-guard] BLOCKED: $1" >&2
  echo "If you intentionally need access, edit the case patterns in the is_secret_path() function (.claude/hooks/secret-guard.sh) to allowlist the specific path." >&2
  exit 2
}

case "$tool" in
  Read|Write|Edit|NotebookEdit)
    fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')
    if is_secret_path "$fp"; then
      block "$tool on secret-like path: $fp"
    fi
    ;;
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
    if echo "$cmd" | grep -qE '(\.env(\.[a-zA-Z0-9_-]+)?(\b|$)|\.pem\b|\.p12\b|/\.aws/credentials|/\.ssh/(id_rsa|id_ed25519))'; then
      block "Bash references secret-like path: $cmd"
    fi
    # Match `printenv` / `env` only at command position (line start or after a shell separator)
    # AND followed by an arg that looks secret-like. Avoids false positives where the words
    # "env" or "secret"/"token"/etc appear in commit messages, PR bodies, doc text, etc.
    if echo "$cmd" | grep -qiE '(^|[;&|][[:space:]]*)(printenv|env)[[:space:]]+\S*(api[_-]?key|secret|token|password|private)'; then
      block "Bash appears to print secret env vars: $cmd"
    fi
    ;;
esac

exit 0
