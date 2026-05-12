---
name: grill-with-docs
description: Grilling session that challenges your plan against the existing domain model in this repo, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise. Use when the user wants to stress-test a plan against the repo's locked vocabulary and architectural decisions.
disable-model-invocation: true
---

# /grill-with-docs

_Requires the consuming repo to have at least one of: a root `CONTEXT.md`, per-subsystem `CONTEXT.md` files, or `docs/decisions/` ADRs. The foundation cut ships no CONTEXT.md or ADRs — adopt the conventions in [`CONTEXT-FORMAT.md`](./CONTEXT-FORMAT.md) and [`ADR-FORMAT.md`](./ADR-FORMAT.md) first._

Same interview shape as `/grill-me`, but every question stress-tests against the existing repo documentation: any `CONTEXT-MAP.md` at the root, per-subsystem `CONTEXT.md` files, shared-kernel docs, locked design decisions, and ADRs under `docs/decisions/`. Updates the relevant `CONTEXT.md` (vocabulary) and writes new ADRs (locked decisions) **inline as decisions crystallise**.

This skill is operator-fired only (writes to `docs/` + meaningful LLM cost from the extended interview session). Every question + recommendation is an LLM-orchestrated turn.

## When invoked: `/grill-with-docs`

Interview the user relentlessly about every aspect of the plan until you reach shared understanding. Walk down each branch of the design tree, resolving dependencies one-by-one. **For each question, recommend an answer.**

Ask one question at a time, waiting for feedback before continuing. If a question can be answered by exploring the codebase or reading the relevant CONTEXT.md / ADR, explore instead of asking.

### 1. Read the existing language first

Before the first question, scan:

- The root `CONTEXT-MAP.md` (if present) — to identify which subsystems / bounded contexts the plan touches.
- The relevant per-subsystem `CONTEXT.md` (or equivalent) for each touched context — to absorb the canonical vocabulary and the `_Avoid_:` synonyms.
- The shared-kernel doc (if present) — for primitive newtypes referenced across multiple contexts.
- The locked design-decisions doc — architectural commitments that constrain the plan.
- `docs/decisions/` — dated ADR amendments.

Treat this scan as the prerequisite — the domain-awareness phase. Do not start interviewing until you can name the relevant contexts and at least the locked decisions that the plan touches.

### 2. Challenge against the glossary

When the user uses a term that conflicts with the canonical vocabulary in the relevant `CONTEXT.md` / shared-kernel doc, **call it out immediately**. Recommend the canonical term, cite where it lives, and ask the user to confirm before proceeding.

### 3. Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term **from the existing vocabulary first**. Adding a new term should be a last resort — and if added, it must land in the relevant `CONTEXT.md`'s Language section in the same session.

Watch for words that look domain-specific but mean different things in different subsystems (a "channel", "limit", "request", "intent" may each be defined by the local `CONTEXT.md`; cross-checking is what makes the grilling useful).

### 4. Discuss concrete scenarios

When domain relationships are being discussed, **stress-test with specific scenarios**. Invent edge cases that probe boundaries between concepts. The point is to surface the rules a clean abstract description hides.

### 5. Cross-reference with code

When the user states how something works, check whether the existing source / CONTEXT / ADR agrees. If you find a contradiction, surface it — quote the conflicting doc line, ask whether the plan is to override (which would need an ADR) or whether the user has misremembered the rule.

### 6. Update CONTEXT.md inline

When a term is resolved, **update the relevant `CONTEXT.md` right there**. Don't batch updates — capture them as they happen. Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

Discipline:

- Decide the **owner context** before adding the term. Composite types stay with their owner; only atomic newtypes referenced across all contexts are kernel candidates.
- Mirror the addition in the source's surface form: a new term in the subsystem's `CONTEXT.md` Language section + a matching `_Avoid_:` line for any synonym you ruled out during the session.
- Operator review during `/grill-with-docs` is the discipline that closes the loop: when a synonym you ruled out shows up in source later, catch it in the next interview session and rename it together. `/audit-docs` does not enforce vocabulary discipline — only structural drift (D1–D11).

### 7. Offer ADRs sparingly

Offer to write an ADR only when **all three** are true:

1. **Hard to reverse** — cost of changing your mind later is meaningful.
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons.

If any of the three is missing, skip the ADR — vocabulary updates alone are sufficient. When all three hold, write the ADR using the format in [ADR-FORMAT.md](./ADR-FORMAT.md), into `docs/decisions/<YYYY-MM-DD>-NNN-<slug>.md` (next dense `NNN`).

By convention this harness uses a single ADR home (`docs/decisions/`). Consuming repos may use `docs/adr/` or per-subsystem ADR directories — adapt the refusal rule to your repo's convention. Most ADRs in a multi-context codebase end up being cross-cutting, which is why the single-home default works for many repos.

### 8. End-of-session summary

When the interview converges (no more open branches, all terms resolved, all decisions either documented in CONTEXT.md or escalated to ADRs), produce a one-paragraph summary:

- Contexts touched + vocabulary added (per file).
- ADRs written (with paths) or `none — no decision met all three ADR criteria`.
- Open follow-ups (if any) for the operator to decide later.

## Operator escape valve

Drive steps 1-8 above turn-by-turn through chat (Edit/Write tools are not locked; only the slash is).

## Failure modes

| Failure | Detection | Mitigation |
|---|---|---|
| Plan touches a context the interviewer hasn't read yet | The interviewer makes a recommendation that contradicts an existing CONTEXT.md term it didn't see | Operator catches it in review; interviewer re-reads the missed CONTEXT.md and re-frames the recommendation. **Discipline**: step 1 is non-negotiable — never skip the language scan. |
| Term resolved in session but CONTEXT.md never updated | Operator notices in a subsequent `/grill-with-docs` interview that source uses a synonym the CONTEXT.md should have ruled out | The interview itself is the gate — no automated check fires. **Discipline**: update CONTEXT.md *during* the session per step 6, not after. |
| Operator wants an ADR for a decision that fails the three-criteria gate | Interviewer offers, operator accepts; resulting ADR is noise that will get retired | Reject offers proactively — when in doubt, vocabulary update only; no ADR. |
| ADR home convention mismatch | Operator writes an ADR to a path that conflicts with the repo's configured ADR home (e.g., the repo uses `docs/decisions/` and the operator writes to `<subsystem>/docs/adr/`) | Surface the mismatch and ask the operator which convention this repo follows; adapt to it. |

## Forbidden

- Skipping step 1 (language scan) — interviewing without absorbing the existing vocabulary contradicts the skill's purpose.
- Adding a new term to CONTEXT.md without checking whether an existing term already covers it.
- Writing an ADR to a path that conflicts with the repo's ADR-home convention — confirm the convention with the operator before writing.
- Updating invariant docs (e.g., `docs/harness/components/<x>/SPEC.md`) with new vocabulary — those are invariant docs; vocabulary lives in `CONTEXT.md`; rules in the SPEC cite the vocabulary, they don't define it.
- Auto-merging or auto-committing — this skill produces edits in the working tree; the operator decides when to stage / commit / PR.
