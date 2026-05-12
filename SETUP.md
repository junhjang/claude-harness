# Setup

Adapting `claude-harness` to your project takes ~5 minutes. The defaults are tuned for Rust/Python repos; this guide covers what to change for other stacks.

## 1. Install

> Replace `junhjang` with the actual GitHub owner (your handle / org).

```bash
git clone https://github.com/junhjang/claude-harness.git target-dir
# Or: copy just .claude/, CLAUDE.md, and (optionally) scripts/ into an existing repo.
```

Claude Code picks up `.claude/settings.json` automatically on session start. No further wiring needed for the hooks to register.

## 2. Choose your language profile

[`.claude/settings.json`](.claude/settings.json) `permissions.allow` lets specific shell commands run without prompting. The default list assumes Rust + Python. Edit it to match your stack.

**Rust + Python (default):**
```json
"allow": [
  "Bash(cargo check:*)", "Bash(cargo build:*)", "Bash(cargo test:*)",
  "Bash(cargo clippy:*)", "Bash(cargo fmt:*)",
  "Bash(pytest:*)", "Bash(ruff:*)", "Bash(mypy:*)",
  ...
]
```

**TypeScript / Node:**
```json
"allow": [
  "Bash(npm:*)", "Bash(pnpm:*)", "Bash(yarn:*)",
  "Bash(tsc:*)", "Bash(eslint:*)", "Bash(prettier:*)",
  "Bash(vitest:*)", "Bash(jest:*)",
  ...
]
```

**Go:**
```json
"allow": [
  "Bash(go build:*)", "Bash(go test:*)", "Bash(go vet:*)",
  "Bash(gofmt:*)", "Bash(golangci-lint:*)",
  ...
]
```

Keep the universal entries: `git status:*`, `git diff:*`, `ls:*`, `find:*`, `grep:*`, `jq:*`. Keep the `deny` block as-is — it's language-agnostic.

## 3. Decide which hooks fit your stack

Some hooks are truly universal; others are Rust/Python presets that no-op silently on other languages. To disable a hook, remove its block from `.claude/settings.json` `hooks` and (optionally) `rm` the file from `.claude/hooks/`.

**Truly universal (work as-is in any repo):**
- `secret-guard.sh` — blocks reads/writes on `.env`, keys, credentials
- `pr-create-gate.sh` — blocks `gh pr create` until review state is fresh
- `rule-stub-check.sh` — keeps `.claude/rules/` files structured
- `session-start-meta-index.sh` — surfaces the skill index on session start
- `session-start-docs-audit-trigger.sh` — nudges `/audit-docs` when docs are stale

**Rust + Python preset (silently no-op on other languages — extend the case-statement for your stack):**
- `pre-commit-fast.sh` — runs `cargo fmt` / `cargo clippy` / `ruff` only when `Cargo.toml` / `pyproject.toml` is present
- `tdd-check.sh` — enforces test-first on `*.rs` (`src/**`) and `*.py` only
- `auto-format.sh` — formats `.rs` via `rustfmt`, `.py` via `ruff`; other extensions silently skipped

Note: `.claude/skills/review-changes/SKILL.md` §"reviewable kinds" table currently routes `.rs` / `.py` / `.sh` / `.yaml` / `.json` to the code-reviewer agent. TypeScript, Go, etc. files are not dispatched — extend the table for your stack to get per-file PR review.

After editing settings.json, restart your Claude Code session for changes to take effect.

## 4. Configure your language's failure-mode rules

`.claude/rules/` contains LLM-authoring failure-mode catalogues for Rust and Python. If you're on a different stack:

- **Drop the irrelevant one(s)**: `rm .claude/rules/rust-llm-failures.md` if no Rust.
- **Add your own**: create `<lang>-llm-failures.md` listing the anti-patterns LLMs reach for in that language. The skill at `.claude/skills/<lang>-failure-modes/` cross-references it during review.

Look at the existing Rust/Python files for the template — start with 5–10 specific anti-patterns the model actually produces.

## 5. Fill in the rule-stub placeholders

`.claude/rules/rust-llm-failures.md` and `python-llm-failures.md` each end with a `<!-- TODO: project owner — ... -->` placeholder. Replace with patterns you've seen the model produce on your codebase. The `rule-stub-check.sh` hook will refuse new rule files missing this section, but it doesn't enforce content quality — that's on you.

## 6. (Optional) Wire `/audit-docs` and `/audit-harness-coverage` to CI

The foundation ships working stubs at:
- `scripts/cron/c1_docs_audit.py` — D1–D3 + D5 docs auditor (see [`docs/harness/components/cron-c1-docs-audit/SPEC.md`](docs/harness/components/cron-c1-docs-audit/SPEC.md))
- `scripts/audit_harness_coverage.py` — settings-wiring + discoverability check (see [`docs/harness/components/skill-audit-harness-coverage/SPEC.md`](docs/harness/components/skill-audit-harness-coverage/SPEC.md))

Both exit `1` on BLOCKER under `--source manual`, so they slot into CI:

```yaml
# .github/workflows/ci.yml
- run: python3 scripts/cron/c1_docs_audit.py --source manual
- run: python3 scripts/audit_harness_coverage.py --source manual
```

The full SPECs define more checks than the stubs implement (D4 / D6–D11 for docs audit; cron-impl parity + state-store consistency for harness coverage). Extend the stubs as your harness grows.

## 7. (Optional) Customise `CLAUDE.md`

`CLAUDE.md` ships with seven working principles. Add a "Project-specific extensions" section at the bottom for your repo's local rules. The principles 1–7 should stay; they encode the discipline the rest of the harness enforces.

## 8. Try it

Open a Claude Code session in your repo. The session-start hooks should print:
- A pointer to the skill catalogue.
- A nudge if `/audit-docs` is stale.

Then try:
```
/grill-me
/audit-docs
/audit-harness-coverage
/verification-before-completion
```

If any of these fail with "command not found", verify `.claude/skills/<name>/SKILL.md` exists and `name:` in frontmatter matches the dir name.

## What's next

- Read [`docs/harness/principles.md`](docs/harness/principles.md) to understand the discipline this harness enforces.
- Read [`docs/harness/architecture.md`](docs/harness/architecture.md) to see how the pieces compose.
- Add your own skills and agents following the patterns under `.claude/skills/` and `.claude/agents/`.
- See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) when a hook blocks unexpectedly.
