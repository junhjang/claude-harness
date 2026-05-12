# AUDIT review prompt

Loaded by [`doc-reviewer`](../../../agents/doc-reviewer.md) when the dispatched doc has `type: AUDIT` (typically under `.claude/audits/<YYYY-MM-DD>-<topic>.md`).

## Provenance rule (BLOCKER)

AUDIT docs are **auto-generated only** per [`audit-docs/SKILL.md`](../../audit-docs/SKILL.md) Forbidden rules. If the AUDIT looks handwritten (no method line, no run-record reference, no deterministic check counts), that is a surface-discipline violation — BLOCKER.

Exception: planning audits and revisit audits that synthesize prior auto-generated audits are acceptable when they cite their inputs. Treat these as `type: AUDIT` synthesis docs and verify the source citations resolve.

## Checklist

| # | Category | Check | Severity |
|---|---|---|---|
| 1 | Method | Auto / manual + which cron / skill / agent generated this | BLOCKER |
| 2 | Provenance | Auto-generation marker present unless synthesis-audit | BLOCKER (if handwritten without synthesis tag) |
| 3 | Counts | Blockers / Warnings / Info explicit even when 0 | CHANGE-REQUEST |
| 4 | Evidence | Every finding cites file:line | BLOCKER |
| 5 | Tickets | Linked tickets opened (when applicable) noted | NIT |
| 6 | Date consistency | `last-reviewed` and audit date in title agree | CHANGE-REQUEST |
| 7 | Immutability (per doc-pattern) | Revisions added as `## Amendments` section, not in-place edits | BLOCKER |
| 8 | Shape labelling | If primary content is *forward-looking* (proposing PRs / sequencing future work), `type: AUDIT` may be the wrong label — `type: RFC` or `type: PRD` may fit better. Audit shape fits when primary content is *findings against existing state*. | NIT |
| 9 | Self-aware role | Audit body acknowledges its role-boundary: findings flow to canonical docs / ADRs / rules; the audit itself is provenance, not authoritative. | NIT |

## Classification guidance

AUDIT docs report findings about other docs/code. The reviewer's job is **methodological**:

- Are the findings cited with `file:line` evidence? If not, the audit is not durable — CHANGE-REQUEST or BLOCKER per row 4.
- Are the severity labels consistent across the audit? Mixed `BLOCKER` and `CRITICAL` for the same severity is a smell — CHANGE-REQUEST.
- Does the audit cite a method (cron run, manual `/audit-docs` invocation, adversarial review)? If absent, BLOCKER.
- Are amendments appended below a clear `## Amendments` header (per doc-pattern AUDIT immutability)? In-place revisions to historical findings is a BLOCKER.

## Common smells

- **Handwritten findings prose without provenance** — the doc reads like an essay; no script ran. BLOCKER unless explicitly a synthesis audit citing source audits.
- **Counts that don't match the body** — header says "3 blockers" but the body lists 4. CHANGE-REQUEST.
- **Findings without `file:line`** — "the docs are stale" with no path reference. BLOCKER.
- **Edits to closed audits without `## Amendments`** — silent revision is an incident-handling immutability violation.

## Format conventions

- **Filename**: `.claude/audits/<YYYY-MM-DD>-<slug>.md`. `<slug>` is free-form descriptive (e.g., `doc-review-system-plan`, `tooling-revisit`, `docs-audit` for the cron output). Synthesis-audits typically use a topical slug; scan-audits typically use `-docs-audit` / `-bench-audit` / etc. On same-day collision, append `-N`.
- **Frontmatter**: `type: AUDIT`, `status: draft|accepted|superseded`, `owner: <author>`, `last-reviewed: YYYY-MM-DD`. Audits are immutable once `status: accepted`; revisions go in `## 11. Amendments` (append-only).
- **Severity scale**: CRIT / HIGH / MED / LOW. CRIT = active contradiction of an architectural commitment; HIGH = known gap with clear corrective action; MED = drift / stale doc; LOW = nit / defer. Floor: agreement by ≥2 independent sources sets minimum HIGH; vote-counting does not downgrade single-source CRIT.
- **Findings citation**: every finding cites `file:line`. Missing citation → CHANGE-REQUEST.
- **Findings ID**: F1, F2, ... audit-local. When a finding consolidates multiple input sources, cite all source IDs.

## Output

Cite `<audit-path>:<line>`. Output per the agent's `<Output_Format>` block.
