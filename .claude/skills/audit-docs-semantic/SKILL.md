---
name: audit-docs-semantic
description: Bounded-fan-out semantic review of every doc under a subtree. Dispatches /review-doc against each .md file with concurrency ≤4, hard per-invocation cost cap, and a single combined audit output. Use this when reviewing a whole subtree — `/audit-docs-semantic docs/`, `/audit-docs-semantic .claude/`, `/audit-docs-semantic docs/harness/components/`.
disable-model-invocation: true
argument-hint: "<subtree>"
---

# /audit-docs-semantic

Fan-out wrapper around [`/review-doc`](../review-doc/SKILL.md). Reviews every `.md` file under `<subtree>` semantically, with a hard per-invocation cost cap and concurrency ≤4 to avoid daily-budget exhaustion.

This skill is **operator-only** (`disable-model-invocation: true`). It is the only safe way to fan out semantic review across a subtree — direct multi-doc dispatch via `/review-doc` is forbidden by the agent contract.

## Scope vs the other auditors

| | `/audit-docs` (deterministic) | `/review-doc` (single doc) | `/audit-docs-semantic` (this skill) |
|---|---|---|---|
| Surface | every doc, structural | one doc, semantic | every doc under subtree, semantic |
| Method | D1–D11 (deterministic only) | Sonnet/Opus full read | Fan-out of `/review-doc` per doc |
| Cost | $0 (deterministic only) | ~$0.08 / ~$0.40 per doc | capped at `$5.00`/invocation default |
| Output | `.claude/audits/<date>-docs-audit.md` | inline session verdict | `.claude/audits/<date>-semantic-audit-<subtree-slug>.md` |

## When invoked: `/audit-docs-semantic <subtree>`

### 1. Validate the subtree

Resolve `<subtree>` against the repo. If it does not exist or is not a directory, list closest matches and stop. Reject `.` (whole-repo) outright — the operator must scope intent.

### 2. Pre-flight cost estimate

Enumerate `.md` files under `<subtree>` (respecting the same exemptions as `audit-docs`: skip `.claude/hooks/*.disabled`, `scratch/`, etc.).

For each file, compute the dispatch model per `/review-doc`'s heuristic:
- Safety-critical paths (configured per project) → Opus override (~$0.40)
- All other paths → Sonnet default (~$0.08)

Sum the estimate. Default per-invocation cap: **`max_invocation_cost_usd: 5.00`**. Consuming repos that want a configurable cap can wire it through their own config (e.g., `config/cron/d4.yaml`).

If `estimate > cap`:
- **Refuse**. Print the file count, the estimate (with Sonnet/Opus split), and at least one suggested narrower subtree (e.g., "53 docs / $8.20 — try `<subtree>/components/` (24 docs / $4.10) instead").
- The operator can override by passing `--cap <usd>`; never auto-raise.

### 3. Operator confirmation

Show the count + estimate + concurrency setting. Default: ask before launching. Skip the confirm only when the operator explicitly passes `--yes`.

### 4. Fan-out dispatch

Run `/review-doc <file>` for each enumerated file with bounded concurrency:

- **Concurrency cap: ≤4**. Higher concurrency risks rate-limit thrashing on the Anthropic API and breaks the cost-tracking arithmetic.
- **Mid-flight cost tracking**: after each dispatch returns, accumulate the actual cost (the `RESULT:` JSON includes the model used; map to per-invocation $). If `cumulative > cap`, **abort** the remaining dispatches; emit a partial audit with the dispatched-so-far results plus an `EARLY-TERMINATED` marker.
- **Failure handling**: a single dispatch failing (prompt missing, doc unreadable) does not abort the run. Capture the error in the per-doc record; continue.

### 5. Combine into a single audit doc

Write `.claude/audits/<YYYY-MM-DD>-semantic-audit-<subtree-slug>.md` (suffixing `-N` on same-day collision). Frontmatter `type: AUDIT`. Sections:

```markdown
# Semantic audit — <subtree> — <date>

Method: /audit-docs-semantic
Files dispatched: <n>
Concurrency: <≤4>
Cumulative cost: $<x> / cap $<cap>
Status: completed | EARLY-TERMINATED

## Per-doc verdicts

| Doc | Type | Model | Verdict | B / CR / N / A |
|---|---|---|---|---|

## Aggregated blockers (<n>)
... (each finding cites <doc-path>:<line>)

## Aggregated change-requests (<n>)
...

## Aggregated ambiguous (<n>)
...

## Errors / skipped (<n>)
...
```

### 6. Surface to operator

Report counts: dispatched / blockers / change-requests / nits / ambiguous / errors. Do not auto-create issues. Do not auto-edit any doc.

## Rules

- **Per-invocation cost cap is mandatory.** No `--cap-disable` flag. The cap is configurable but always enforced.
- **Concurrency cap is hard.** Do not raise above 4 even on operator request — the cap reflects API rate-limit shape, not just budget.
- **No auto-issue creation.** Findings are read-only; the operator decides what to escalate.
- **Honour the dispatch model heuristic** from `/review-doc` — do not bulk-promote everything to Opus.
- **Output is ONE audit doc per invocation**, not one per dispatched file. The point of fan-out is consolidated review.

## Forbidden

- Dispatching against the whole repo (`.`) — the operator must scope.
- Concurrency >4.
- Auto-raising the cost cap when the estimate exceeds it.
- Skipping the operator confirmation step (except via explicit `--yes`).
- Modifying any doc under the dispatched subtree.
