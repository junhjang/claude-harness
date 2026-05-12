---
name: critic-review
description: Adversarial principle review — dispatches the `critic` agent against the current diff (or named target) to surface violations of `docs/harness/principles.md` (P1–P12 + retired commitments). Use when asked "audit principles", "is this drifting from the principles", "principle review", "is this consistent with our locked-in commitments", "is this re-introducing a retired pattern", or before merging substantial architecture / harness changes. The agent is Opus, read-only, costs apply — confirm before fan-out.
disable-model-invocation: true
---

# /critic-review

Adversarial review wrapper that fires the [`critic`](../../agents/critic.md) agent against the diff (or a named target) to find principle violations.

This skill is the auto-loadable companion to the `critic` agent. Without it, the LLM has to *remember* to dispatch `critic` via the Agent tool with `subagent_type: critic` — which in practice nobody does. The wrapper makes the intent explicit and surfaceable through the same auto-load path the rest of the harness uses.

Per [`docs/harness/principles.md`](../../../docs/harness/principles.md) §12, this skill is locked because (a) it dispatches an Opus agent — real LLM cost, and (b) on principle audits at architectural boundaries, the operator should attend the spend.

## When invoked: `/critic-review [<target>]`

`<target>` defaults to the current branch's diff vs `main` (mirrors `/review-changes`). Otherwise an explicit path or PR number.

### 1. Determine the review target

```bash
TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  BASE=$(git merge-base origin/main HEAD)
  TARGET_DESC="diff vs origin/main since $BASE"
else
  TARGET_DESC="$TARGET"
fi
```

Refuse on `main` itself (no diff to review):

```
'/critic-review' has nothing to review on main; check out a feature branch first.
```

### 2. Operator confirmation gate

Cost estimate: one Opus invocation against the diff scope. Typical: $0.50–$2.00 depending on diff size + how much of `principles.md` the agent reads. Surface the estimate and wait for operator `--yes` or explicit confirmation.

### 3. Dispatch the `critic` agent

Invoke via the Agent tool with `subagent_type: critic`. Pass:

- The full diff (`git diff origin/main..HEAD`).
- A pointer to `docs/harness/principles.md` (the agent reads it itself).
- A pointer to any audits relevant to the diff scope (e.g., recent `.claude/audits/<date>-*`).

The agent's output is a structured critique with cited evidence — see `.claude/agents/critic.md` for the exact contract.

### 4. Surface the result

Print verdict + per-principle findings to the operator. Findings are advisory at this layer (the operator decides whether to address before merge); they do NOT become a gate state file. `/review-changes` is the cost-class peer that produces the merge-blocking artifact.

Optional follow-up: for any P3-critical violation surfaced, suggest the operator open a CHANGE-REQUEST against the offending commit before invoking `/review-changes`.

## Rules

- **Operator-attended.** Never auto-confirm step 2. Even when the auto-trigger fires the slash, the operator must confirm before dispatch.
- **Read-only.** This skill never edits the diff or the principles file. Critic-agent output is surfaced; operator decides.
- **No double-charging.** If `/review-changes` was already run on this HEAD sha and produced a critic-style finding, this slash is redundant — surface the existing state and ask whether to re-run.
- **Per-PR scope.** Critique focuses on the diff. For repo-wide principle audits, use a planning audit (a manual write under `.claude/audits/`).

## Forbidden

- Auto-applying fixes from the critic's findings.
- Skipping the operator-confirmation step.
- Dispatching the agent against `main` itself (no diff scope).

