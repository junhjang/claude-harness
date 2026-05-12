# ADR review prompt

Loaded by [`doc-reviewer`](../../../agents/doc-reviewer.md) when the dispatched doc has `type: ADR` (typically under `docs/decisions/`).

## Required sections (BLOCKER if missing)

- **Decision** — one sentence stating what was decided.
- **Context** — what changed in the world that forced this decision.
- **Consequences** — what becomes easier and what becomes harder. Includes irreversibility note when applicable.

## Checklist

| # | Category | Check | Severity |
|---|---|---|---|
| 1 | Sections | Decision (1 sentence) / Context / Consequences all present | BLOCKER |
| 2 | Trigger | "Triggered by:" line cites a concrete source (research finding, benchmark result, incident, or RFC outcome) | CHANGE-REQUEST |
| 3 | Numbering | NNN dense (no gaps) — see `docs/decisions/` listing | CHANGE-REQUEST |
| 4 | Implementation pointer | Cited code path actually exists (verify via `Bash ls`) | BLOCKER |
| 5 | Supersedes graph | `supersedes:` and `superseded-by:` are bidirectional when applicable | CHANGE-REQUEST |
| 6 | Reversibility | Irreversibility explicitly marked when the decision is hard to undo | NIT |
| 7 | Cross-ref to principles | Which principle(s) the decision relies on | NIT |
| 8 | Retired-commitment reintroduction | Compare against `docs/harness/principles.md` "## Retired commitments" — re-introducing one is BLOCKER | BLOCKER (if reintroducing) |

## Classification guidance

For each prose rule the ADR states:
- **enforced-by-X** — cite the hook / lint / CI gate that enforces it.
- **tested-by-Y** — cite the test that exercises it.
- **convention-only** — operator discipline; flag explicitly.
- **unenforced** — claim with no backing artifact. CHANGE-REQUEST minimum; BLOCKER if safety-critical.
- **AMBIGUOUS** — multiple plausible enforcement targets or unclear intent.

## Common smells

- **"Will be enforced by future hook X"** — that's `unenforced` today; the ADR cannot count promised enforcement as enforcement.
- **Implementation pointer drifts from code** — file moved, function renamed. Detect via `ls` / `grep` against the cited path.
- **Decision that contradicts a non-superseded ADR** — read sibling ADRs in `docs/decisions/`; flag direct contradictions.
- **"Decided" without a Triggered-by line** — ADRs without provenance are not durable.

## Output

Cite `<adr-path>:<line>` for every finding. Output the verdict per the agent's `<Output_Format>` block.
