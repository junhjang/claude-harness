# Appendix: skill-shape

Loaded by [`doc-reviewer`](../../../agents/doc-reviewer.md) when the dispatched doc is `.claude/skills/<x>/SKILL.md` or `.claude/agents/<x>.md`. Layered on top of the SPEC base prompt (treating the SKILL.md / agent.md as a SPEC for that skill / agent's contract).

## Skill checklist

| # | Category | Check | Severity |
|---|---|---|---|
| 1 | Frontmatter | `name` and `description` required; `name` matches folder name | BLOCKER |
| 2 | Body length | **Discipline skills** (auto-load via `paths:`) ≤300 tokens — bodies should be terse rule citations. **Slash skills / orchestration skills** (frontmatter has `disable-model-invocation: true` OR `argument-hint:`) ≤1500 tokens — multi-step procedure prose is inherent to the shape. Apply the right cap per skill kind. | CHANGE-REQUEST |
| 3 | Description trigger | Auto-trigger phrase clear and non-ambiguous | CHANGE-REQUEST |
| 4 | Path scope | `paths:` glob is precise (not `**/*.rs`) | CHANGE-REQUEST |
| 5 | Reference links | `docs/<x>.md` cited in body actually exists | BLOCKER |
| 6 | Skill shape indication | Rule skill vs. reasoning skill clearly indicated | NIT |
| 7 | Index registration | Row exists in the project's meta-index | BLOCKER |

## Agent checklist

When the dispatched path is `.claude/agents/<x>.md`:

| # | Category | Check | Severity |
|---|---|---|---|
| 1 | Frontmatter | `name`, `description`, `model` required | BLOCKER |
| 2 | Read-only declaration | `disallowedTools: Write, Edit, NotebookEdit` if the agent should not land code | BLOCKER for review/critic/explorer agents |
| 3 | XML body | `<Agent_Prompt>` with `<Role>` / `<Why_This_Matters>` / `<Success_Criteria>` / `<Constraints>` / `<Investigation_Protocol>` / `<Tool_Usage>` / `<Output_Format>` | BLOCKER if missing any |
| 4 | Model justification | Model choice traceable to a difficulty × importance rationale | CHANGE-REQUEST |
| 5 | Tool scope | `Tool_Usage` list matches the agent's job (no over-broad tool grants) | CHANGE-REQUEST |
| 6 | Output format | Ends with structured `RESULT:` JSON for orchestrator ingestion | CHANGE-REQUEST |
| 7 | Index registration | Row exists in `docs/harness/components/README.md` agents table | BLOCKER |

## Common smells

- **Skill body that paraphrases a doc** — should link, not duplicate. CHANGE-REQUEST.
- **`paths: **/*.rs`** — too broad; the skill will auto-load on every Rust file. CHANGE-REQUEST.
- **Description starts with "Tool to..."** — Claude Code skill descriptions should start with a verb describing the discipline ("Enforce X", "Review Y").
- **Agent without `<Output_Format>`** — orchestrators cannot ingest free-form output. BLOCKER.
- **Agent claiming Opus without difficulty × importance justification** — model-choice violation; CHANGE-REQUEST.
- **Skill / agent body referencing a doc that does not exist** — dead link; BLOCKER.

## Classification guidance

Most SKILL.md / agent.md prose maps to `convention-only` (the skill is the convention). Flag claims like "this skill enforces rule X" — those should map to `enforced-by` only if a hook actually backs the skill. Mismatches between the skill's framing and its actual enforcement are CHANGE-REQUEST.

## Output

Cite `<skill-or-agent-path>:<line>`.
