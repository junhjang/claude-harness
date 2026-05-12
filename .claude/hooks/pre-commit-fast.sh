#!/usr/bin/env bash
# PreToolUse hook: fast pre-commit gate. Runs only fmt + clippy.
# Heavier checks (test, build, full clippy) live in CI.
# Fires on every Bash call but exits in microseconds when the command is not `git commit ...`.
# Rust + Python preset — extend the `run()` calls + project-file detection for other stacks.
set -uo pipefail

# Claude Code's hook execution context does not inherit the user's interactive PATH,
# so cargo / rustfmt / clippy installed via rustup at ~/.cargo/bin are not found by default.
# Prepend the standard rustup bin dir (and CARGO_HOME if customized).
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // "."')

# Only fire on `git commit ...`
if [[ ! "$cmd" =~ (^|[[:space:];&|])git[[:space:]]+commit([[:space:]]|$) ]]; then
  exit 0
fi

cd "$cwd"

run() {
  local label="$1"; shift
  echo ">>> $label" >&2
  if ! "$@" >&2; then
    echo "[pre-commit-fast] FAILED: $label" >&2
    echo "  (heavier checks — test/build — run in CI)" >&2
    exit 2
  fi
}

# Loop over both workspaces — root and benches/ — to match CI's rust-lint job.
# When benches/ is an independent workspace, `cargo fmt --all` from root does
# NOT format it. Without this loop the local pre-commit gate would miss
# fmt/clippy diffs that CI catches.
for dir in . benches; do
  if [[ -f "$dir/Cargo.toml" ]]; then
    # Skip fmt/clippy on virtual workspaces with no members yet. cargo fmt
    # and clippy both fail with "Failed to find targets" / "no packages
    # selected" on an empty workspace; that is not a lint failure, and gating
    # commits on it would prevent bootstrap PRs that add the workspace shell
    # before any member crate exists.
    members=$(cd "$dir" && cargo metadata --no-deps --format-version=1 2>/dev/null \
              | jq -r '.workspace_members | length' 2>/dev/null || echo "0")
    if [[ "$members" != "0" ]]; then
      ( cd "$dir" && run "$dir cargo fmt --check" cargo fmt --all -- --check )
      ( cd "$dir" && run "$dir cargo clippy"      cargo clippy --workspace --all-targets -- -D warnings )
    else
      echo ">>> $dir empty workspace (members = 0) — skipping cargo fmt/clippy" >&2
    fi
  fi
done

if [[ -f pyproject.toml || -f requirements.txt || -f setup.py ]]; then
  if command -v ruff >/dev/null 2>&1; then
    run "ruff format --check" ruff format --check .
    run "ruff check"          ruff check .
  fi
fi

exit 0
