# README review prompt

Loaded by [`doc-reviewer`](../../../agents/doc-reviewer.md) when the dispatched doc has `type: README` (component READMEs, harness READMEs, top-level README.md).

## What a README is

Operator-facing entry point: how to **run**, **observe**, and **stop** the thing. Not a SPEC paraphrase; not a tutorial; not a marketing page.

## Checklist

| # | Category | Check | Severity |
|---|---|---|---|
| 1 | Operator commands | run / observe / stop — all 3 present | BLOCKER |
| 2 | No SPEC paraphrase | Link to SPEC; do not duplicate body | CHANGE-REQUEST |
| 3 | Failure modes | Common failure modes + operator response listed | CHANGE-REQUEST |
| 4 | Single stop command | Single source of truth for stop command (not "either of these works") | BLOCKER |

## Operator-shape

A good README answers, in this order:

1. **What does this do?** One sentence, no jargon.
2. **How do I run it?** Command + expected first-line output.
3. **How do I see what it's doing?** Log path / metric name / dashboard URL.
4. **How do I stop it?** Single command. If multiple work, that is a safety violation (the operator under stress will pick the wrong one).
5. **Where do I look when it breaks?** Common failure modes + the first place to check.

## Common smells

- **Duplicates the SPEC body verbatim** — drift risk; CHANGE-REQUEST.
- **No `stop` command, or two equivalent ones** — operator under stress needs one. BLOCKER on any runtime component where mis-clicking the wrong stop has high consequence.
- **"Set this env var if you want feature X"** for features that should be enabled by default — README is making the operator opt into safety.
- **Tutorial-shaped** ("first you do A, then B, then watch how cool it is") — that's docs for new contributors, not operators.

## Classification guidance

READMEs rarely state enforcement rules; they document operator commands. Most prose maps to `convention-only`. Flag rules that are operator-binding ("never run with `--force`") as `convention-only` unless an actual hook blocks the dangerous action — then `enforced-by-X`.

## Output

Cite `<readme-path>:<line>`. Output per the agent's `<Output_Format>` block.
