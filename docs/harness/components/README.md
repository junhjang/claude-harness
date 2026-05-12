# Harness Components

This subtree holds the contract definitions (PRD + SPEC, optionally RFC + TDD + AUDIT) for each component of the AI-native development harness. Implementation lives elsewhere — under `.claude/`, `config/`, and the project's subsystem trees. The contracts here are what those implementations must satisfy.

> **Foundation cut:** This generic harness ships only the cross-cutting SPECs, the docs-audit cron, and the harness-coverage meta-audit. The richer state stores and domain-specific cron components (error registries, incident stores, fix-template libraries, log-scan and bench-validator crons) are deliberately out of scope — they are patterns committed by [`../principles.md`](../principles.md), and the consuming repo wires up its own implementations once it has chosen the right schemas. Steal the methodology; bring your own state.

For the doc-type matrix and section templates, see [`../doc-pattern.md`](../doc-pattern.md). For the architectural shape that places these components, see [`../architecture.md`](../architecture.md).

## Cross-cutting SPECs

| Component | Scope | Status |
|---|---|---|
| [`hooks/`](hooks/SPEC.md) | Stdin JSON schema, exit codes, matcher narrowing, latency budgets per hook layer. Binding for new hooks. | accepted |
| [`ci/`](ci/SPEC.md) | Workflow structure, path-detection, hook-replay defense-in-depth, concurrency control, "adding a new check" procedure. Binding for `.github/workflows/ci.yml` modifications. | draft (design only; impl in consuming repo) |

## Cron components ([architecture.md §1](../architecture.md#1-five-primitives-five-roles))

| Component | PRD | SPEC | Cadence | Schedule via | Status |
|---|---|---|---|---|---|
| [`cron-c1-docs-audit/`](cron-c1-docs-audit/SPEC.md) ([PRD](cron-c1-docs-audit/PRD.md)) | ✅ | ✅ | daily | platform cron (launchd / systemd / GitHub Actions cron / Kubernetes CronJob / etc.) | stub ships at `scripts/cron/c1_docs_audit.py` (D1-D3+D5); full D6-D11 in consuming repo |

## Subagents ([architecture.md §1](../architecture.md#1-five-primitives-five-roles))

Subagent contracts live at `.claude/agents/<name>.md` (Claude Code's discovery path), not under this subtree. All subagents follow the standard XML body template (`<Agent_Prompt>` → `<Role>`/`<Why_This_Matters>`/`<Success_Criteria>`/`<Constraints>`/`<Investigation_Protocol>`/`<Tool_Usage>`/`<Output_Format>`).

### Generalists

| name | model | disallowedTools | role |
|---|---|---|---|
| `explore` | Haiku | Write, Edit, NotebookEdit | locate code, files, references |
| `tracer` | Sonnet | Write, Edit, NotebookEdit | ordered file:line trace through pipelines / state machines |
| `test-engineer` | Sonnet | (none — must write) | author behavior-focused tests for the system under test |
| `security-reviewer` | Opus | Write, Edit, NotebookEdit | review auth / credential / safety-critical paths |
| `code-reviewer` | Opus | Write, Edit, NotebookEdit | per-component invariant adherence on PR diffs |
| `critic` | Opus | Write, Edit, NotebookEdit | adversarial review against `principles.md` (P1–P12) + retired commitments |
| `document-specialist` | Sonnet | Edit, NotebookEdit | fetch external API docs; write only to a designated research subtree |
| `doc-reviewer` | Sonnet (Opus override on high-blast-radius SPECs) | Write, Edit, NotebookEdit | semantic single-doc review; classify each prose rule (enforced-by / tested-by / convention-only / unenforced / AMBIGUOUS) |

### Auto-fix scaffolding

The harness ships three subagents that compose into an auto-fix chain (localize → validate → PR). The candidate-generation step is deliberately not included — it commits to the consuming repo's error system and fix-template library, both of which are pattern-only in this cut.

| name | model | disallowedTools | role |
|---|---|---|---|
| `localizer` | Haiku | Write, Edit, NotebookEdit | locate where an error variant is raised |
| `validator` | Haiku (defensive default; script runner, not LLM-dispatched) | Write, Edit, NotebookEdit | run three deterministic gates (compile / existing tests / new test) |
| `pr-author` | Haiku | Write, Edit, NotebookEdit | open PR with structured message + auto-merge queue |

## Slash-skill SPECs

Most slash skills carry their contract inside `.claude/skills/<name>/SKILL.md` itself — the SKILL.md *is* the SPEC. The exceptions below have a separate SPEC because their behavior is substantive enough to warrant a PRD + SPEC pair (multiple checks, file outputs, cost-class declaration, etc.).

| Component | PRD | SPEC | Status |
|---|---|---|---|
| [`skill-audit-harness-coverage/`](skill-audit-harness-coverage/SPEC.md) ([PRD](skill-audit-harness-coverage/PRD.md)) | ✅ | ✅ | stub ships at `scripts/audit_harness_coverage.py` (3.3-3.5b); full 3.1/3.2 in consuming repo |

## Decision records (ADRs)

Locked architectural decisions are tracked under the project's `docs/decisions/` subtree (not included in this portfolio cut). When in doubt about why a component looks the way it does, the ADR is the cite-worthy source.

The harness assumes ADR conventions described in [`../doc-pattern.md`](../doc-pattern.md) §4 — one decision per file, never edited (superseded). Reference an ADR from a SPEC via `<!-- provenance: <adr-path> -->` HTML comments, not body-text cites (per [`../principles.md`](../principles.md) §11).

## Extending this inventory

The foundation harness is intentionally small. Consuming repos add their own state stores (error registry, incident store, fix-template library), their own cron components (log scanners, bench validators), and their own SapFix-chain slash command — each per the patterns in [`../principles.md`](../principles.md). When such a component lands a SPEC under this subtree, add a row to the appropriate table above and update `CLAUDE.md` (Principle 7 — Index Discipline). The `/new-doc spec <topic>` skill scaffolds the file path and frontmatter automatically.
