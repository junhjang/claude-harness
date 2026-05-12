# Cross-cutting review prompt

Loaded by [`doc-reviewer`](../../../agents/doc-reviewer.md) **for every dispatched doc** in addition to the type-specific base prompt and the path appendix. Also serves as the fallback base prompt for `type ∈ {RFC, TDD, POSTMORTEM}` (currently 0 instances each — when the first lands, write a type-specific prompt).

## Checks that apply universally

| # | Category | Check | Severity |
|---|---|---|---|
| 1 | Freshness | `last-reviewed` > 90 days AND any cited code path has been modified since | CHANGE-REQUEST |
| 2 | Content duplication | Contiguous duplication with another doc (≥30 lines verbatim) | BLOCKER |
| 3 | Retired forwarding | If `status: retired`, forwarding pointer to the replacement is present | CHANGE-REQUEST |
| 4 | Generated provenance | If `type: AUDIT`, auto-generation marker present (or synthesis-citation) | BLOCKER |
| 5 | Index registration | One-line index entry in `CLAUDE.md` — transitively reachable | BLOCKER (index-discipline violation) |
| 6 | Audit-cite discipline | Canonical doc body cites an AUDIT-typed file as authoritative source | CHANGE-REQUEST |

## Freshness check

Two-part: doc says "last-reviewed: 2025-12-01" but a file it cites was modified after that date. Use `git log -1 --format=%ai <cited-path>` to compare. CHANGE-REQUEST surface — the doc's claims may be stale.

## Content duplication check

Most yield comes from this. If a doc verbatim-copies a paragraph from another doc (≥30 contiguous lines), one of the two will drift first; the second becomes the source of bugs. BLOCKER. Detect via:

- Read the dispatched doc.
- For each paragraph >5 lines, check whether the same prose appears in another doc under `docs/`.
- A single shared sentence is fine; a shared paragraph is duplication.

## Index registration check

Every doc must be transitively reachable from `CLAUDE.md`. The `audit-docs` cron's D1/D8 covers the structural path-walk; this prompt's job is to verify the *index entry text* is informative — `- [x](path) — short hook`, not a bare path.

## Retired forwarding check

If a doc's frontmatter has `status: retired`, the body must point readers to the replacement: "Superseded by `<path>`. Read that instead." CHANGE-REQUEST otherwise — readers landing on a retired doc need direction.

## Audit-cite discipline check

When reviewing a canonical doc (NOT another audit), grep its body for these patterns and flag each as CHANGE-REQUEST against the dispatched doc:

- Body-text phrases like `Per audit <name>`, `per audit <path> F<N>`, `audit X finding Y`, `Promoted from ... per audit ...`.
- Markdown links to `.claude/audits/*.md` in body text **when the link is cited as authoritative for a rule** (e.g., "see audit X for the rule"). Links pointing at audits as **worked-format-examples** are acceptable (e.g., "Worked examples in this repo: [audit-A], [audit-B]" — the link is to a format reference, not a rule authority). Use judgement: does the surrounding prose treat the audit as an *authority for what the rule is* (flag), or as a *concrete instance of the format* (carve-out)?
- ADR `## Context` / `## Implementation pointer` sections that cite audit findings as authoritative (acceptable in the `**Triggered by:**` opening header line only).

What does NOT trigger this check:
- HTML provenance comments: `<!-- provenance: <audit-path> F5 -->` — designed for grep-only use.
- ADR `Triggered by:` frontmatter or first-paragraph line — the audit is the trigger, the ADR is the decision.
- The dispatched doc IS itself an audit (audit-to-audit cites are normal — synthesis audits cite source audits).
- PR bodies / commit messages (out of doc-reviewer scope anyway).

Severity: CHANGE-REQUEST against the canonical doc. The fix is one of three: state the rule on the canonical doc's own authority (most common), promote the decision to a new ADR (architectural commitments), or move the audit reference to an HTML provenance comment (provenance-only).

Why CHANGE-REQUEST not BLOCKER: the doc is still useful while the cite is mid-flight; cleaning up the cite is a discipline issue, not a safety hazard. Dead-link detection (audit file no longer exists at the cited path) is the structural-audit cron's responsibility — when a cited audit is deleted those checks fire as BLOCKER independently of this rule.

## How to combine with the base prompt

The orchestrator dispatches both this prompt and the type-specific prompt. Findings from both layer additively. If a finding qualifies under both (e.g., a SPEC has a duplicated paragraph), report it once with the more specific source — the SPEC base prompt's row that triggered it.

## Output

Findings here are "cross-cutting" in the verdict — tag them as such so the operator can distinguish them from type-specific findings.
