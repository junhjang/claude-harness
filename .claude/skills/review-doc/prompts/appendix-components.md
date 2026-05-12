# Appendix: components

Loaded by [`doc-reviewer`](../../../agents/doc-reviewer.md) when the dispatched doc is under a "components" subtree (e.g., `docs/harness/components/<x>/SPEC.md` in this repo, or `docs/components/<x>.md` in forks that use a flatter layout). Layered on top of the SPEC base prompt.

## Per-component invariants

For each component SPEC, the body must address its component-specific invariant areas. The invariant set is project-specific; the appendix's job is to check that the component's documented areas are all addressed, that they agree with the matching skill file (if any), and that no examples in the body contradict the rules the body states.

When invoked, read the project's expected-invariants table (typically in a per-project addendum file, or inferred from the existing component SPECs themselves) and verify each row.

## Cross-cutting checks

| # | Check | Severity |
|---|---|---|
| 1 | Component invariants for the dispatched component (project-specific table) all addressed | BLOCKER if any safety-critical area missing; CHANGE-REQUEST otherwise |
| 2 | Invariant consistency with the matching skill at `.claude/skills/<x>/SKILL.md` (or the component's named skill) | BLOCKER on contradiction |
| 3 | Cross-doc consistency: type / enum names referenced match those in cited SPECs | BLOCKER |
| 4 | Self-rule vs. self-example: the body's examples do not violate the body's prose rules | BLOCKER |
| 5 | Cross-doc duplication: per-instance specifics that belong in `docs/external/<source>.md` (or the equivalent per-instance docs directory) are not duplicated here | CHANGE-REQUEST (drift risk) |

## How to verify invariant consistency with skill

Read both at dispatch time. The skill's enforced rules (auto-loaded on the matching `paths:`) must be a subset of (or equal to) the SPEC's invariants. Skill says X; SPEC silent on X → CHANGE-REQUEST. SPEC says X; skill says NOT X → BLOCKER.

## Common smells

- **SPEC body says "type X is forbidden in this subsystem" then the example uses type X** — high-yield self-rule-vs-self-example BLOCKER.
- **State machine declared with N states but the transition table covers fewer** — incomplete state machine; BLOCKER.
- **Component-level invariant area present in sibling SPECs is missing from this one** — likely an oversight; CHANGE-REQUEST.
- **SPEC claims a test exists; no corresponding test directory referenced** — `unenforced`.

## Output

Cite `<spec-path>:<line>`. Reference the per-component invariant the SPEC failed to address.
