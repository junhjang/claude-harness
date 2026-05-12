# Troubleshooting

Hooks in this harness **block, they don't advise** — a failing hook fails the tool call. The fix is usually to address the root cause, not bypass. Common cases:

## A hook blocked my edit unexpectedly

### `secret-guard` blocked a read or write

```
[secret-guard] refusing to read/write <path>
```

The hook treats anything matching `.env`, `*.key`, `*.pem`, `**/.ssh/id_*`, `**/secrets/**`, `**/.aws/credentials` as sensitive. If the path is a false positive (e.g., a non-secret file named `keystore`):
- Rename the file if you can.
- If you can't, edit `.claude/hooks/secret-guard.sh` `is_secret_path()` to add an explicit allow for your specific path.

**Do not** wholesale disable the hook to push past a single false positive.

### `pre-commit-fast` failed

```
[pre-commit-fast] formatter/linter check failed
```

The hook runs your formatter + linter before any `git commit`. Run them manually, fix the issues, commit.

If your stack doesn't use the default tools (Rust `cargo fmt`/`clippy`, Python `ruff`), edit `.claude/hooks/pre-commit-fast.sh` to invoke your tools. Or remove the hook from `.claude/settings.json` `hooks.PreToolUse.Bash` and rely on `auto-format.sh` only.

### `tdd-check` refused a Write

```
[tdd-check] no test precedes this source file
```

Write the test first, then create the source file. The hook checks that for a new file at `src/foo.rs`, a matching `tests/foo*.rs` or `src/foo_test.rs` exists somewhere in the tree (it checks existence, not mtime ordering — co-located test files satisfy the check). If you legitimately need a test-less file (e.g., a binary entry point, a config struct with no logic), the hook may need a path-skip exception — edit it.

### `pr-create-gate` blocked `gh pr create`

```
[pr-create-gate] review state for current SHA not refreshed — run /review-changes first
```

The gate keys local review state by git SHA. If you amended a commit since the last review, the state is stale. Run `/review-changes` to refresh, then `gh pr create`.

Hotfix bypass: `BYPASS_REVIEW_CHANGES=1 gh pr create ...` (use sparingly; reviewer-skipped PRs lose the principle backstop).

### `rule-stub-check` blocked a `.claude/rules/` edit

```
[rule-stub-check] new rule file missing 'Project-specific tips' section
```

Every rule file under `.claude/rules/` needs a section the project owner fills in with codebase-observed patterns. Add the section (the hook will scaffold one in stderr telling you the expected shape).

## A slash skill refused to run

### `disable-model-invocation: true`

Some skills (`/critic-review`, `/review-changes`, `/audit-docs-semantic`) carry this flag because they fan out to multiple LLM dispatches and have non-trivial cost. Claude won't auto-invoke them.

**Operator escape valve**: drive the procedure manually. Each affected SKILL.md documents the steps; the Edit/Write/Agent tools the chat session uses are not locked, only the slash trigger is. Run the steps turn-by-turn.

### Script not found

```
python3: can't open file 'scripts/cron/c1_docs_audit.py': [Errno 2] No such file or directory
```

The foundation ships stubs at `scripts/cron/c1_docs_audit.py` and `scripts/audit_harness_coverage.py`. If they're missing from your install:
- Re-copy from the original `claude-harness` repo.
- Or run the skill body's procedure manually (the SKILL.md describes what the script does in plain English).

## A subagent dispatch returned no results

### Agent didn't find the file

The `explore`, `tracer`, and `localizer` subagents are read-only and depend on your repo's actual structure. If they return "no match," the symbol/file genuinely doesn't exist where you said it does. Re-check the search query.

### Agent's verdict is wrong

Subagents (especially `code-reviewer`, `critic`) emit verdicts based on what they read. If a verdict seems off:
- Read the agent's structured `RESULT:` output — the cited file:line evidence usually reveals where the model misread.
- Dispatch a second agent (`/critic-review` on the original review) to find drift.
- If the failure pattern repeats, capture it in `.claude/rules/<lang>-llm-failures.md` so the next session has the rule preloaded.

## `/audit-docs` reports BLOCKERS I don't understand

The audit report at `.claude/audits/<date>-docs-audit.md` lists each BLOCKER with a rule ID (D1–D11) and file:line. Look up the rule definition in [`docs/harness/components/cron-c1-docs-audit/SPEC.md`](docs/harness/components/cron-c1-docs-audit/SPEC.md) §3.1.

Common BLOCKERs:
- **D1 orphan doc**: a `docs/*.md` file isn't transitively reachable from `CLAUDE.md`. Add a link from a relevant CLAUDE.md section.
- **D2 missing frontmatter**: a doc under `docs/` is missing `type` / `status` / `last-reviewed`. Add the frontmatter (see [`docs/harness/doc-pattern.md`](docs/harness/doc-pattern.md) §3 for the schema).
- **D3 dead link**: `[text](path.md)` where `path.md` doesn't exist. Fix the path or remove the link.

## I disabled a hook and now CI is broken

CI scripts (e.g., `pre-commit-fast.sh` invoked from `.github/workflows/ci.yml`) may depend on the hooks being present. If you removed a hook, also update the CI config to remove its check.

## I want to extend the harness with my own skill / agent / hook

1. **Skill**: create `.claude/skills/<name>/SKILL.md` with frontmatter `name: <name>`, `description: <one-line>`, optional `paths: ["..."]`. The skill is now invocable as `/<name>`.
2. **Agent**: create `.claude/agents/<name>.md` with frontmatter `name: <name>`, `description: ...`, `model: claude-haiku-4-5-20251001` (or sonnet/opus), optional `disallowedTools: ...`. Use the body shape `<Agent_Prompt>` → `<Role>` / `<Why_This_Matters>` / `<Success_Criteria>` / `<Constraints>` / `<Investigation_Protocol>` (see existing agents).
3. **Hook**: create `.claude/hooks/<name>.sh` with `#!/usr/bin/env bash` + `set -uo pipefail`. Wire in `.claude/settings.json` under the right matcher (PreToolUse / PostToolUse / SessionStart).

Then run `/audit-harness-coverage` — it'll verify the new component is discoverable and complain if you missed wiring.

## Still stuck

- Read the relevant SKILL.md or agent.md fully — the body usually documents the contract clearly.
- Check the audit reports under `.claude/audits/` for context.
- See [`docs/harness/principles.md`](docs/harness/principles.md) for the discipline a hook may be enforcing.
