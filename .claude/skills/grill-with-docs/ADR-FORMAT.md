# ADR Format

The format `/grill-with-docs` writes when crystallising a decision into an ADR. Convention: `docs/decisions/<YYYY-MM-DD>-NNN-<slug>.md`, single-home, dense numbering.

## File location and naming

**Convention used in this harness.** Other valid conventions: date-only IDs (`2026-05-12-add-foo.md`), per-subsystem ADRs. Pick one and stick to it; the rest of this format spec assumes the dense numbering this harness uses.

ADRs live at `docs/decisions/<YYYY-MM-DD>-NNN-<slug>.md`:

- `<YYYY-MM-DD>` — the date the decision was committed (typically the day the ADR is written).
- `NNN` — three-digit sequential id, **dense** (no gaps). The next id is `max(existing) + 1`. Density is enforced by D5 of `/audit-docs`.
- `<slug>` — kebab-case short summary.

By convention this harness uses a single ADR home (all ADRs in `docs/decisions/`). Consuming repos may use `docs/adr/` or per-subsystem ADR directories. Most architectural decisions in a multi-context codebase end up being cross-cutting, which is why the single home is the default here.

## Decision criteria — when to write an ADR

An ADR warrants creation **only when all three** are true:

1. **Hard to reverse** — reversing the decision carries meaningful cost (refactoring, data migration, retraining operators).
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons.

If any of the three is missing, **skip the ADR**. Trivial decisions, unsurprising choices, and inevitable selections don't warrant ADR documentation. Vocabulary updates in the relevant `CONTEXT.md` are sufficient for non-ADR-worthy choices.

## ADR template

```md
---
type: ADR
status: accepted   # initial value; transitions to {superseded|retired} via dated amendment
owner: <author@example.com>
last-reviewed: <YYYY-MM-DD>
---

# ADR-NNN: <short title>

**Date**: <YYYY-MM-DD>
**Trigger**: <one-sentence cause — research finding, benchmark result, incident, design grilling session, etc.>

## Context

<1-3 paragraphs. What is the current state? What changed recently that
forces this decision? What constraints do we face? Cite the relevant
CONTEXT.md / source-of-truth doc or prior ADR if applicable.>

## Options considered

### Option A: <name>
<one paragraph>

### Option B: <name>
<one paragraph>

### Option C: <name>
<one paragraph>

## Decision

<The chosen option, with the rationale that wasn't already covered in
"Options considered". If the decision is "Option A", say so explicitly —
do not let the reader infer.>

## Consequences

- <positive consequence — what this enables or protects>
- <positive consequence>
- <negative consequence — what this constrains, what it forecloses>
- <follow-up: what other docs / code / CONTEXT.md need updating>

## Implementation pointer

<Path(s) to the code / SPEC / CONTEXT.md that implement this decision.
If the decision is "do not implement X", say "out-of-scope; no impl pointer."
If implementation is deferred, say "deferred to <PR # or future work>"
and note the trigger that will reactivate it.>
```

## Optional sections

The mattpocock original notes that "Status, Considered Options, and Consequences should only be included when they genuinely serve the record." This template promotes them to required because:

- **A locked decision has lasting implications** — the "Consequences" section is the second-order test of whether the writer thought it through.
- **The repo is intended to be a long-lived reference** — future maintainers reading ADRs need the full reasoning, not just the outcome. The cost of a few extra paragraphs is small compared to the cost of an undocumented "why."

If a section genuinely doesn't apply (e.g., for a decision with no real alternatives, "Options considered" can be one line: "No alternatives — the choice was determined by [external constraint]"), keep the heading + the explanation rather than dropping the section entirely.

## Status transitions

ADRs are **append-only at the file level**, but the `status` field transitions:

- `accepted` → `superseded` when a later ADR overrides this one. Add an `## Amendments` section (date-stamped) at the end of the original linking to the superseding ADR. Do not delete the body.
- `accepted` → `retired` when the decision is no longer relevant (e.g., the subsystem it covered was removed). Add `## Amendments` linking to the rationale.

Never silently edit a prior ADR's body. The git history matters; the future reader needs to see what was committed at the time.

## Linking discipline

When the ADR cites a prior decision (e.g., "supersedes ADR-NNN §3"), use the form `ADR-NNN` — D10 of `/audit-docs` enforces that the cited number resolves to a real file in `docs/decisions/`. When citing a SPEC or CONTEXT.md, use a relative markdown link:

- ADR-NNN style: `Per ADR-NNN, the harness is X.`
- File link style: `Per [docs/harness/components/<x>/SPEC.md](../harness/components/<x>/SPEC.md) rule 7, the subsystem reconciles every 30s.`

Both forms are validated by `/audit-docs` (D10 + D6).

## Inline-creation etiquette during a `/grill-with-docs` session

- Confirm **all three** ADR criteria before offering. If even one is shaky, propose a CONTEXT.md update instead.
- The next ADR id is `max(existing in docs/decisions/) + 1` — verify by listing the directory before writing. Reusing an id collides with D5 of `/audit-docs`.
- Write the ADR **inline as the decision crystallises**, not at end of session. The grilling context is freshest while you're still in it.
- If the decision involves an external-source finding (e.g., a published spec from an upstream service violates a current architecture commitment), the ADR should cite the relevant `docs/external/<source>.md` section that documents the finding.
