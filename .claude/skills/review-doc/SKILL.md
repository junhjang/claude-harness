---
name: review-doc
description: Semantic review of a single doc — classify each prose rule (enforced-by / tested-by / convention-only / unenforced / AMBIGUOUS) and emit BLOCKER / CHANGE-REQUEST / NIT / AMBIGUOUS findings. Dispatches the doc-reviewer agent. Use when reviewing an ADR / SPEC / AUDIT / README / PRD / SKILL.md / agent file before merge, or when the operator says "doc looks good", "ship this spec", "review this doc", "is this doc accurate", "check this spec", "look at this doc", "verify this doc". For multi-doc fan-out (e.g., "review every doc"), use `/audit-docs-semantic` instead — that one is operator-only with a $5 cap.
argument-hint: "<doc-path>"
---

# /review-doc

Semantic review of a single doc, complementary to `/audit-docs` (deterministic structural). This skill dispatches the [`doc-reviewer`](../../agents/doc-reviewer.md) agent to read the dispatched doc end-to-end, classify every prose rule against a base prompt + path appendix, and emit a verdict with cited evidence.

This skill is **operator-invocable AND auto-loadable** — typing `/review-doc <path>` works, and the description-match auto-trigger fires when the operator types intent like "doc looks good", "ship this spec", "review this doc". The auto-trigger is a **soft-trigger**: it is a *suggestion* mechanism gated on operator-typed intent, not an autonomous loop. Operator opt-out: flip `disable-model-invocation: true` in this file's frontmatter to make `/review-doc` slash-only.

## Scope vs `/audit-docs`

| | `/audit-docs` | `/review-doc` (this skill) |
|---|---|---|
| Surface | `docs/`, `CLAUDE.md`, `.claude/{skills,agents,rules,hooks}` (all docs) | One dispatched doc |
| Method | D1–D11 (deterministic only) for upstream `/audit-docs`, semantic review here | Sonnet (default) / Opus (safety-critical paths), full doc read |
| Catches | Index gaps, dead links, frontmatter, citations, ADR id density, staleness | Prose-rule classification, internal contradictions, missing required sections, unenforced claims |
| Cost | $0 (deterministic only) | ~$0.08 (Sonnet) / ~$0.40 (Opus) per doc |
| Output | `.claude/audits/<date>-docs-audit.md` | Inline verdict in current session (cached for re-dispatch) |

If the operator's intent is "scan everything for structural drift," route to `/audit-docs`. If the intent is "did I write this SPEC's prose carefully enough," route here.

## When invoked: `/review-doc <doc-path>`

1. **Validate the path.** Resolve `<doc-path>` against the repo. If it does not exist or is not a markdown file, list the closest matches and stop.

2. **Read the doc's frontmatter `type:`** and full relative path. These select the base prompt and path appendix:
   - **Base prompt** — `.claude/skills/review-doc/prompts/<type>.md` for `type ∈ {`[ADR](prompts/ADR.md), [SPEC](prompts/SPEC.md), [AUDIT](prompts/AUDIT.md), [README](prompts/README.md), [PRD](prompts/PRD.md)`}`. For `type ∈ {RFC, TDD, POSTMORTEM}` (currently 0 instances each), fall back to [`prompts/cross-cutting.md`](prompts/cross-cutting.md) and emit a NIT noting the type-specific prompt is missing.
   - **Path appendix** — chosen by path heuristic:
     - `docs/harness/components/**` (or `docs/components/**` in forks with a flatter layout) → [`prompts/appendix-components.md`](prompts/appendix-components.md)
     - `.claude/skills/**` or `.claude/agents/**` → [`prompts/appendix-skill-shape.md`](prompts/appendix-skill-shape.md)
     - `.claude/rules/**` → [`prompts/appendix-rules-catalog.md`](prompts/appendix-rules-catalog.md)
     - Multiple matches → load both; let the agent reconcile.
     - No match → load no appendix; the base prompt covers it.

3. **Choose the model**. Default: **Sonnet** (`claude-sonnet-4-6`). Override to **Opus** (`claude-opus-4-7`) when the dispatched path matches a safety-critical SPEC the project has declared (configure the list in this skill's project config). Set `model_override: claude-opus-4-7` on the agent dispatch for those paths.

4. **Dispatch the `doc-reviewer` agent.** Pass:
   - The doc path.
   - The base-prompt path and appendix path(s).
   - `model_override` (if applicable).
   - The cache directory hint (`var/<env>/review-cache/`).

5. **Surface the verdict** to the operator: PASS / CHANGE-REQUEST / BLOCK + counts of blockers / change-requests / nits / ambiguous + the cited `RESULT:` JSON line. Do not auto-create issues. Do not auto-edit the doc.

6. **Cache write** is the agent's responsibility (see `doc-reviewer.md` `<Cache>` section). If the cache write fails, the operator sees a warning but the verdict still lands.

## Status

Live. The agent + skill + prompt templates are present:

- `prompts/{ADR,SPEC,AUDIT,README,PRD,cross-cutting}.md`
- `prompts/appendix-{components,skill-shape,rules-catalog}.md`

Dispatching `/review-doc <path>` proceeds end-to-end. A failed prompt load is a hard error (missing prompt → re-add the template), not an expected stub state.

## Rules

- **One doc per dispatch.** N-doc fan-out is `/audit-docs-semantic` (PR-C). If the operator passes a directory, refuse and route to that skill.
- **Read-only.** The agent's `disallowedTools` enforces no Write / Edit / NotebookEdit.
- **No auto-issue creation.** Findings stay in-session; the operator decides what to escalate (P5 — Outalator-shape).
- **Honour the model tier.** Sonnet by default (recoverable consequence — operator overrides verdict). Opus only on the listed safety-critical paths. Do not promote to Opus on operator hunch; document the path-list amendment first.

## Forbidden

- Dispatching against multiple docs in one invocation.
- Running the agent without first selecting the right base prompt + path appendix.
- Auto-creating GitHub Issues from findings.
- Modifying the dispatched doc in any way.
- Promoting to Opus outside the listed safety-critical path set without an audit amendment.
