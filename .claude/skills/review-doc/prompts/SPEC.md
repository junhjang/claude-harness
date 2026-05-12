# SPEC review prompt (base)

Loaded by [`doc-reviewer`](../../../agents/doc-reviewer.md) when the dispatched doc has `type: SPEC`. The base prompt below applies to **every** SPEC; the path appendix (`appendix-<area>.md`) layers on per-doc specifics.

## Required sections (BLOCKER if missing)

A SPEC must specify a contract. The shape varies by area, but the contract elements below are universal:

- **Contract** — input / output / error kinds with type and range.
- **Invariants** — preconditions, postconditions, and class invariants separated.
- **Performance-critical declaration (conditional)** — if the SPEC declares the component is performance-critical, it must state a numeric latency or throughput budget.

## Checklist

| # | Category | Check | Severity |
|---|---|---|---|
| 1 | Contract | Input / output / error kinds specified with type and range | BLOCKER |
| 2 | Invariants | Precondition / postcondition / invariant separated | CHANGE-REQUEST |
| 3 | State machine completeness | Every (state, event) pair has defined behavior — total transition table | BLOCKER |
| 4 | Performance budget | **If** the SPEC declares the component is performance-critical → verify a numeric latency / throughput budget is stated. Otherwise → skip. | BLOCKER (when performance-critical) |
| 5 | Allocation profile | **If** the SPEC declares the component is performance-critical → verify allocation count = 0 (or its actual allocation profile) is stated. Otherwise → skip. | CHANGE-REQUEST (when performance-critical) |
| 6 | Cross-ref integrity | Cited SPECs / ADRs have no dead links | BLOCKER |
| 7 | Self-rule vs. self-example | Body-text rules not violated by body-text examples | BLOCKER |
| 8 | Type-name consistency | Same type referred to by the same name throughout | CHANGE-REQUEST |
| 9 | Cross-doc consistency | Type / enum names match those in cited SPECs | BLOCKER |

## Self-rule vs. self-example

This is a high-yield check. SPECs commonly state a rule in prose and then violate it in their own example:

- A SPEC body says "type X is forbidden in this subsystem" then its example uses type X.
- A state-machine SPEC lists N states; the example state machine omits one.
- A parser SPEC body says "every wire message has a round-trip test"; the example shows a parser without one.

Read the body's prose rules. Then read the body's examples (code blocks, tables). Diff: any violation is a BLOCKER.

## Cross-doc consistency

For every type / enum / function name the SPEC introduces, grep the rest of `docs/` for the same name. If the name appears in another SPEC with a different definition, the second SPEC's referent is broken — BLOCKER.

## Classification guidance

Per the agent's `<Investigation_Protocol>` step 4. Lean toward **unenforced** when the SPEC claims a runtime invariant ("the gate fails closed on stale data") and no test or runtime monitor backs it. For state-machine SPECs, "tested-by" requires the test to actually exercise the (state, event) pair in question — not just construct the state.

## Path-appendix dispatch

The orchestrator (`/review-doc`) selects the appendix per the doc's path. Read the dispatched appendix in addition to this base prompt before issuing the verdict. Findings from the appendix layer with the same severity scale.

## Output

Cite `<spec-path>:<line>` for every finding. Output per the agent's `<Output_Format>` block.
