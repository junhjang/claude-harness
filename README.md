English | [한국어](README.ko.md)

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-green.svg"></a>
  <img alt="Claude Code" src="https://img.shields.io/badge/Claude%20Code-compatible-blueviolet">
  <img alt="Foundation" src="https://img.shields.io/badge/scope-foundation%20cut-orange">
  <img alt="Deps" src="https://img.shields.io/badge/python-stdlib%20only-blue">
</p>

# claude-harness

A portable Claude Code harness — subagents, skills, hooks, rules, and the methodology docs that justify them — distilled from production use on an autonomous engineering project.

LLM coding agents default to *plausible*, not *correct*. Drop these defaults into a fresh repo and you get guardrails for the failure modes that actually happen: silent over-engineering, premature "done" claims, force-pushes under pressure, and codebases that drift from their own rules.

This repo ships two layers, side by side:

- **`.claude/`** — the wired-up components (subagents, skills, hooks, rules) Claude Code loads at session start.
- **[`docs/harness/`](./docs/harness/)** — the principles, doc-pattern matrix, and PRD+SPEC pairs that justify each component. The wiring is the *what*; these docs are the *why*.

Both layers are small, composable, and survive being copied piecewise. Steal what helps; ignore what doesn't.

## Quickstart

> Replace `junhjang` with the actual GitHub owner (your handle / org).

```bash
git clone https://github.com/junhjang/claude-harness.git target-dir
# Or copy just the pieces you want into an existing repo:
cp -R claude-harness/.claude claude-harness/CLAUDE.md path/to/your/repo/
cp -R claude-harness/scripts path/to/your/repo/         # optional — for /audit-docs + /audit-harness-coverage
```

Claude Code picks up `.claude/settings.json` automatically — hooks register, slash skills route, and `CLAUDE.md` loads at session start.

Then in a Claude Code session:

```
/audit-harness-coverage    # verify the harness is wired correctly (~1 second)
/audit-docs                # audit your docs/ for drift (~2 seconds)
/grill-me                  # try the Socratic-interrogation skill
```

The defaults assume Rust + Python. For other stacks, see [`SETUP.md`](SETUP.md). If a hook blocks you unexpectedly, see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

## How it works

The harness assumes one fact about LLM coding agents: they default to *plausible*, not *correct*. Five primitives (hooks, cron, subagents, skills, slash commands) compose into a closed loop that catches the failure modes that actually happen.

1. **Session starts.** SessionStart hooks inject the skill index + a nudge if `docs/` is stale since the last audit.
2. **You ask for code.** Slash skills (`/grill-me`, `/grill-with-docs`) surface ambiguity before the model commits to a wrong interpretation.
3. **Model writes code.** `Write|Edit` hooks block specific anti-patterns: secrets written to tracked paths, source written before tests.
4. **Model claims "done".** `/verification-before-completion` + the `validator` subagent enforce that tests actually ran and exercised the changed path.
5. **You open a PR.** `pr-create-gate` blocks `gh pr create` until `/review-changes` has dispatched per-file reviewers (`code-reviewer` / `security-reviewer` / `doc-reviewer`) against the current SHA.
6. **Docs drift.** A daily `/audit-docs` cron catches dead links, frontmatter rot, index drift, ADR-numbering gaps — deterministic, $0, no LLM call.
7. **The harness itself drifts.** `/audit-harness-coverage` verifies every component claimed in `docs/harness/components/` is actually wired in `.claude/`.

Steps 3, 5, and 6 are the load-bearing parts: deterministic guards that block the failure mode regardless of how convincing the model's prose is.

## Why These Components Exist

Every piece in this harness exists because some specific LLM failure mode kept happening without it.

| Failure mode | Components |
|---|---|
| Agent claims "done" without verifying. | [`/verification-before-completion`](./.claude/skills/verification-before-completion/SKILL.md), [`tdd-check`](./.claude/hooks/tdd-check.sh) hook, [`validator`](./.claude/agents/validator.md) subagent. |
| Agent and human aren't aligned. | [`/grill-me`](./.claude/skills/grill-me/SKILL.md), [`/grill-with-docs`](./.claude/skills/grill-with-docs/SKILL.md). |
| Agent reaches for `--force` under pressure. | [`secret-guard`](./.claude/hooks/secret-guard.sh), [`pr-create-gate`](./.claude/hooks/pr-create-gate.sh), `settings.json` deny list. |
| Agent edits without reading. | `CLAUDE.md` §3, [`explore`](./.claude/agents/explore.md), [`tracer`](./.claude/agents/tracer.md), [`localizer`](./.claude/agents/localizer.md). |
| Codebase drifts from own rules. | [`/audit-docs`](./.claude/skills/audit-docs/SKILL.md), [`/audit-docs-semantic`](./.claude/skills/audit-docs-semantic/SKILL.md), [`/audit-harness-coverage`](./.claude/skills/audit-harness-coverage/SKILL.md), `rule-stub-check`. |
| Subagents leak context. | [`.claude/agents/`](./.claude/agents/) — single-contract specialists with fresh context windows. |
| Failure modes the model knows but reaches for anyway. | [`rules/rust-llm-failures.md`](./.claude/rules/rust-llm-failures.md), [`rules/python-llm-failures.md`](./.claude/rules/python-llm-failures.md). |

## Reference

<details>
<summary><b>Subagents</b> — 11 single-contract specialists (click to expand)</summary>

Single-contract specialists. Invoke via `Agent` tool with the matching `subagent_type`.

- **[code-reviewer](./.claude/agents/code-reviewer.md)** — PR-style review (correctness, style, invariants).
- **[critic](./.claude/agents/critic.md)** — adversarial principle-level review for high-stakes diffs.
- **[security-reviewer](./.claude/agents/security-reviewer.md)** — auth, credentials, secrets, fail-closed checks.
- **[test-engineer](./.claude/agents/test-engineer.md)** — author unit/integration/property tests; verify coverage.
- **[validator](./.claude/agents/validator.md)** — deterministic test/compile/new-test gate before "done."
- **[doc-reviewer](./.claude/agents/doc-reviewer.md)** — single-doc semantic review.
- **[document-specialist](./.claude/agents/document-specialist.md)** — fetch external docs, distil into structured form.
- **[explore](./.claude/agents/explore.md)** — read-only code/symbol/reference finder.
- **[tracer](./.claude/agents/tracer.md)** — data and control flow tracing across files.
- **[localizer](./.claude/agents/localizer.md)** — pinpoint exact lines for an error variant or symbol.
- **[pr-author](./.claude/agents/pr-author.md)** — open or update a pull request.

</details>

<details>
<summary><b>Skills</b> — 18 slash-invocable workflows (click to expand)</summary>

- **[/audit-docs](./.claude/skills/audit-docs/SKILL.md)** — deterministic docs audit (frontmatter, dead links, index drift).
- **[/audit-docs-semantic](./.claude/skills/audit-docs-semantic/SKILL.md)** — semantic docs audit fan-out.
- **[/audit-harness-coverage](./.claude/skills/audit-harness-coverage/SKILL.md)** — confirm harness components match their stated coverage.
- **[/budget-status](./.claude/skills/budget-status/SKILL.md)** — token budget tracking for the session.
- **[/caveman](./.claude/skills/caveman/SKILL.md)** — strip a problem to its rawest form when stuck.
- **[/configuration](./.claude/skills/configuration/SKILL.md)** — config discipline (schema validation, layered overrides, hot-reload).
- **[/critic-review](./.claude/skills/critic-review/SKILL.md)** — principle-level adversarial review.
- **[/doc-pattern](./.claude/skills/doc-pattern/SKILL.md)** — pick the right doc type (PRD / RFC / ADR / SPEC / TDD / AUDIT / POSTMORTEM / README).
- **[/error-taxonomy](./.claude/skills/error-taxonomy/SKILL.md)** — add a new error variant or wire an error path between layers.
- **[/grill-me](./.claude/skills/grill-me/SKILL.md)** — Socratic questioning to surface hidden assumptions.
- **[/grill-with-docs](./.claude/skills/grill-with-docs/SKILL.md)** — doc-driven design interrogation against `CONTEXT.md` and ADRs.
- **[/new-doc](./.claude/skills/new-doc/SKILL.md)** — scaffold a new document with the right frontmatter and shape.
- **[/python-failure-modes](./.claude/skills/python-failure-modes/SKILL.md)** — cross-reference Python LLM-authoring failure modes during review.
- **[/review-changes](./.claude/skills/review-changes/SKILL.md)** — multi-agent review of a PR or local diff.
- **[/review-doc](./.claude/skills/review-doc/SKILL.md)** — semantic review of a single document.
- **[/rust-failure-modes](./.claude/skills/rust-failure-modes/SKILL.md)** — cross-reference Rust LLM-authoring failure modes during review.
- **[/verification-before-completion](./.claude/skills/verification-before-completion/SKILL.md)** — pre-"done" verification checklist.
- **[/zoom-out](./.claude/skills/zoom-out/SKILL.md)** — pull back to surrounding code/system context before deep-diving.

</details>

### Hooks

Hooks are wired in [`settings.json`](./.claude/settings.json); see [`CLAUDE.md`](./CLAUDE.md#hooks----claudehooks) for the matcher → hook table.

### Rules

LLM-authoring failure-mode catalogues, auto-loaded as context when relevant skills fire.

- **[rust-llm-failures.md](./.claude/rules/rust-llm-failures.md)** — Rust patterns LLMs get wrong.
- **[python-llm-failures.md](./.claude/rules/python-llm-failures.md)** — Python patterns LLMs get wrong.

### Methodology (`docs/harness/`)

The canonical design docs the wired-up components above operationalise. Read when extending the harness or when "why is it like this" matters.

- **[principles.md](./docs/harness/principles.md)** — P1–P12 locked commitments + retired commitments. Surface / LLM Boundary / Severity-as-code / Cost Discipline / Outalator-shape / SapFix-shape / Index Discipline / external-pattern verdicts / failure-mode discipline / token-cost exposure / audit-distillation / cost-class rule.
- **[architecture.md](./docs/harness/architecture.md)** — five Claude Code primitives (hooks / cron / subagents / skills / slash commands), the closed loop, layered enforcement.
- **[doc-pattern.md](./docs/harness/doc-pattern.md)** — doc-type matrix (PRD / RFC / ADR / SPEC / TDD / AUDIT / POSTMORTEM / README) with trigger rules and frontmatter schema.
- **[behavior-verification.md](./docs/harness/behavior-verification.md)** — Phase A (structural, CI-gated) + Phase B (operator runbook) for verifying the harness behaves the way it claims.
- **[components/](./docs/harness/components/)** — PRD + SPEC pairs:
  - Contracts: [hooks SPEC](./docs/harness/components/hooks/SPEC.md), [ci SPEC](./docs/harness/components/ci/SPEC.md)
  - Cron components: [c1 docs-audit](./docs/harness/components/cron-c1-docs-audit/)
  - Meta-audit: [skill-audit-harness-coverage](./docs/harness/components/skill-audit-harness-coverage/)

  Domain-specific state stores (error registry, incident store, fix-template library) and crons (log-scan, bench-validator) are pattern-only in this cut — consuming repos commit to their own schemas per [`principles.md`](./docs/harness/principles.md) §3 / §5 / §6.

## Inspiration & Attribution

This harness stands on four open-source projects. Direct adaptations are inlined in the relevant files; the table below summarises what came from where.

### Directly adapted

- **[forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)** (MIT) — `CLAUDE.md` sections 1, 2, 4, 5 are adapted from Forrest Chang's CLAUDE.md, which itself distils Andrej Karpathy's observations on LLM coding pitfalls. Attribution is inlined at the top of `CLAUDE.md`. Local additions: §3 Read Before You Edit, §6 Verify Before Claiming Done, §7 Recover Don't Escalate, and the entire harness-routing section.

- **[mattpocock/skills](https://github.com/mattpocock/skills)** — four skills imported from Matt Pocock's catalogue:
  - `/grill-with-docs` (incl. `CONTEXT.md` and ADR format conventions — Language / Relationships / Flagged ambiguities + `_Avoid_:` synonym lists). Local additions: multi-context layout with a shared-kernel doc at the root, dense ADR numbering.
  - `/grill-me` — imported verbatim.
  - `/zoom-out` — imported with the `disable-model-invocation` flag removed (read-only, $0, deterministic).
  - `/caveman` — body imported verbatim; description narrowed (bare "be brief" trigger phrases removed for reliability).

- **[Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)** (OMC, MIT) — the subagent file format used across `.claude/agents/` is adapted from OMC's agent shape: the `<Agent_Prompt>` XML wrapper with `<Role>` / `<Why_This_Matters>` / `<Success_Criteria>` / `<Constraints>` / `<Investigation_Protocol>` sections (plus local additions `<Tool_Usage>` / `<Output_Format>`). Several agent names (`code-reviewer`, `critic`, `document-specialist`, `explore`, `security-reviewer`, `test-engineer`, `tracer`) and rules such as the writer/reviewer separation clause are drawn directly from OMC's agent catalogue. Local additions: per-component invariant focus (vs OMC's broader generalist orientation), Rust/Python failure-mode rules, and the auto-fix agent scaffolding (`localizer`, `validator`, `pr-author`).

### Conceptual inspiration

- **[obra/superpowers](https://github.com/obra/superpowers)** — the *naming and core idea* of the `/verification-before-completion` skill come from Jesse Vincent's Superpowers framework. The implementation in this harness is independent (a concise pre-"done" checklist rather than Superpowers' "Iron Law / Gate Function" style), but the concept of an explicit verification gate before any completion claim is taken from there. The broader notion of curating a small portfolio of repeatable skills as a framework is also shaped by Superpowers.

### Stylistic influence

This README's overall shape — problem-first motivation followed by a flat reference list — follows the structure of [mattpocock/skills](https://github.com/mattpocock/skills)' README. The content is original.

## License

MIT — see [`LICENSE`](LICENSE).
