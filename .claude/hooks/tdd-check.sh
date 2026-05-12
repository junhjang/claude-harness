#!/usr/bin/env bash
# PreToolUse hook on Write: enforces test-first for new source files.
# Rust  (src/**/*.rs): allow if content has #[cfg(test)] or tests/<name>*.rs exists.
# Python (non-top-level *.py): require test_<name>.py or <name>_test.py somewhere.
#
# Note: fires on Write of new source files. Edit of existing source is
# unconstrained — assumption is test-first happened at the original Write
# and subsequent Edits inherit that.
set -uo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
content=$(printf '%s' "$input"   | jq -r '.tool_input.content   // ""')
cwd=$(printf '%s' "$input"       | jq -r '.cwd // "."')

[[ -z "$file_path" ]] && exit 0

block() {
  echo "[tdd-check] BLOCKED: $1" >&2
  echo "TDD: write the test first, then create the source file." >&2
  exit 2
}

case "$file_path" in
  */tests/*) exit 0 ;;            # writing a test itself
  */benches/*|*/examples/*) exit 0 ;;
  */build.rs) exit 0 ;;
esac

case "$file_path" in
  */src/*.rs)
    # Strip line comments and double-quoted regions before grepping so that
    # a string literal like `let s = "#[cfg(test)] not a real attribute"` or
    # a `// #[cfg(test)] discussed below` comment does not satisfy the check.
    stripped=$(printf '%s' "$content" | sed -e 's|//.*$||' -e 's|"[^"]*"||g')
    if printf '%s' "$stripped" | grep -qE '#\[cfg\(test\)\]'; then
      exit 0
    fi
    base=$(basename "$file_path" .rs)
    # Find repo root (Cargo.toml dir) walking up from file
    dir=$(dirname "$file_path")
    while [[ "$dir" != "/" && ! -f "$dir/Cargo.toml" ]]; do dir=$(dirname "$dir"); done
    if [[ -d "$dir/tests" ]]; then
      # Found a candidate tests/<base>*.rs — require it contains at least one
      # real test function (`#[test]` attribute or `fn ` declaration). An empty
      # / comment-only test file does NOT satisfy the gate.
      found_test=$(find "$dir/tests" -type f -name "${base}*.rs" 2>/dev/null | head -n 1)
      if [[ -n "$found_test" ]] && grep -qE '^\s*(#\[test\]|fn\s+)' "$found_test"; then
        exit 0
      fi
    fi
    block "$file_path has no inline #[cfg(test)] and no non-empty tests/${base}*.rs"
    ;;

  *.rs)
    exit 0  # non-src .rs (top-level, scripts) — out of scope
    ;;

  *.py)
    base=$(basename "$file_path" .py)
    case "$base" in
      __init__|__main__|conftest|setup|test_*|*_test) exit 0 ;;
    esac
    # Skip top-level scripts (no parent dir under cwd)
    rel="${file_path#"$cwd"/}"
    case "$rel" in
      */*) ;;          # nested — keep checking
      *)   exit 0 ;;   # top-level — skip
    esac
    found_test=$(find "$cwd" -type f \( -name "test_${base}.py" -o -name "${base}_test.py" \) \
        -not -path '*/.venv/*' -not -path '*/node_modules/*' -not -path '*/.git/*' \
        2>/dev/null | head -n 1)
    if [[ -n "$found_test" ]] && grep -qE '^\s*(def\s+test_|fn\s+|#\[test\])' "$found_test"; then
      exit 0
    fi
    block "$file_path has no non-empty test_${base}.py or ${base}_test.py"
    ;;
esac

exit 0
