# Appendix: rules-catalog

Loaded by [`doc-reviewer`](../../../agents/doc-reviewer.md) when the dispatched doc is under `.claude/rules/`. Layered on top of the SPEC base prompt (treating each rule entry as a mini-SPEC for the antipattern it documents).

## What a rules catalog is

Antipattern catalog files (`*-llm-failures.md`, etc.) — patterns the LLM should not produce, paired with corrected alternatives.

## Required closing section

Every `*-llm-failures.md` file must end with `## Project-specific tips`. The `rule-stub-check.sh` PostToolUse hook enforces this on writes; the doc-reviewer verifies it for completeness. Catalog files that follow a different shape (e.g., debug-hypotheses catalogs) end with their own canonical closing section.

## Checklist

| # | Category | Check | Severity |
|---|---|---|---|
| 1 | Antipattern coverage | ≥3 entries per category | CHANGE-REQUEST |
| 2 | Per-entry 3-part shape | (bad pattern / why this is bad in context / correct alternative) | CHANGE-REQUEST |
| 3 | Code brevity | Code examples ≤6 lines | NIT |
| 4 | Severity declared | catastrophic / important / nit per entry | CHANGE-REQUEST |
| 5 | Citations | Source citations (gh issue / PR / language nomicon) when claiming a pattern is bad | NIT |
| 6 | Closing section present | `## Project-specific tips` (failures files) or equivalent canonical closing (catalog files) | BLOCKER |

## Per-entry shape

Each rule entry should have these three parts visible at a glance:

```markdown
## N. Don't <X>

- <bad pattern, 3-6 lines>
- <why this is bad in this codebase's context — not just generic language advice>
- <correct alternative, 3-6 lines>
```

Missing the "why this is bad in context" part is the most common smell — the entry then reads as a generic style preference rather than a domain rule. CHANGE-REQUEST.

## Severity labeling

The catalog should mark entries by severity:

- **catastrophic** — the antipattern, if shipped, causes incidents. Examples: `.unwrap()` in performance- or safety-critical paths; logging credentials.
- **important** — degrades correctness or performance noticeably. Examples: `.clone()` to escape borrow checker; bare `except:` swallowing.
- **nit** — style preference; no incident risk.

Entries without severity labels read as if all rules are equal — they are not. CHANGE-REQUEST.

## Common smells

- **Generic Rust / Python lint advice** dressed up as project-specific — flag honestly. The "why this is bad" line should explain the *project / domain* consequence, not just the language consequence.
- **3+ lines of unrelated code** in an example — readers stop reading. NIT, but recurrent.
- **No closing section** — the file looks unfinished; `rule-stub-check.sh` already catches this on writes, but the doc-reviewer flags it as BLOCKER for confirmation.
- **"Use X instead of Y" without saying when** — recommendations need scope; CHANGE-REQUEST.

## Output

Cite `<rules-path>:<line>`. For each missing severity label, list the entry and the recommended severity tier.
