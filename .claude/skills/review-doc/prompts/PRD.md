# PRD review prompt

Loaded by [`doc-reviewer`](../../../agents/doc-reviewer.md) when the dispatched doc has `type: PRD`.

## Required sections (BLOCKER if missing)

A PRD must have all 5:

1. **Problem** — what is broken / unsupported today.
2. **Users** — who calls / observes / stops the thing.
3. **Success** — measurable metric(s) that say "this worked."
4. **Non-goals** — explicit statements of what we are *not* doing.
5. **Open questions** — genuinely undecided items only (no placeholders).

## Checklist

| # | Category | Check | Severity |
|---|---|---|---|
| 1 | Sections | All 5 sections present | BLOCKER |
| 2 | Users | Who calls / observes / stops it — explicitly named (not "the user") | CHANGE-REQUEST |
| 3 | Success | Measurable metric (latency / throughput / drift / hit rate / etc.) | CHANGE-REQUEST |
| 4 | Non-goals | Explicit *not-doing* statements | CHANGE-REQUEST |
| 5 | Open questions | Genuinely undecided items only (no placeholders like "TBD") | BLOCKER |

## Why "non-goals" matters

A repo's principles often include retired commitments (e.g., auto-tickets, auto-merge of LLM-authored PRs). PRDs that don't restate "we are not building X" risk reintroducing them. CHANGE-REQUEST when a PRD's success metric implies behavior that the principles forbid.

## Common smells

- **Success: "users will be happy"** — not measurable.
- **Open questions: "TBD"** — that's a placeholder, not an open question. BLOCKER.
- **No non-goals section** — every PRD has things it's *not* doing. Listing them is the discipline.
- **Users: "developers"** — too broad; name the role (operator / integrator / etc.).

## Classification guidance

PRDs propose; they do not enforce. Most prose maps to `convention-only` (operator discipline once shipped) or `unenforced` (the PRD's success metric needs a check, but no check exists yet). Flag the latter — they are the items that need follow-up.

## Output

Cite `<prd-path>:<line>`. Output per the agent's `<Output_Format>` block.
