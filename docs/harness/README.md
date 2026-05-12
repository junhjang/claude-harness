# Harness

**Scope:** the AI-native development harness — a layered, deterministic-first set of Claude Code primitives (hooks, cron, subagents, skills, slash commands) that audits, maintains, and modifies the codebase under bounded conditions.

The harness exists because keeping a non-trivial codebase current with external API changes, document drift, performance regressions, and runtime errors is mechanical work that scales poorly with humans. The harness automates the mechanical parts and keeps the judgment with the operator.

---

## What lives here

| Path | Purpose |
|---|---|
| [`README.md`](README.md) | This file. Entry point and reading order. |
| [`principles.md`](principles.md) | Locked-in commitments. Append-only. Read before designing any new harness. |
| [`doc-pattern.md`](doc-pattern.md) | Which document types (PRD/RFC/ADR/SPEC/TDD/AUDIT/POSTMORTEM/README) to write for which kind of harness work. |
| [`architecture.md`](architecture.md) | Top-level shape: hooks / cron / subagents / skills / slash commands and how they compose. |
| [`behavior-verification.md`](behavior-verification.md) | The two-phase verification battery: deterministic CI gate + operator runbook. |
| [`components/`](components/) | One folder per harness component (cron implementations, state stores, cross-cutting SPECs). |

---

## Reading order

1. **First time**: `README.md` → `principles.md` → `doc-pattern.md` → `architecture.md`. The four files together define the foundation.
2. **Designing a new harness component**: `principles.md` → `doc-pattern.md` → an analogous component under `components/`.
3. **Modifying an existing component**: that component's `PRD.md` + `SPEC.md` → the referenced principles.

---

## What does not live here

- Subsystem-side architecture, components, or methodology — the harness is a self-contained subtree about *how the LLM-augmented harness is built and bounded*. The system under harness lives elsewhere in the repo.
- Runtime registries (e.g., `config/errors/registry.yaml`) — these are *artifacts the harness operates on*, not docs. Their *shape* is documented under the relevant `components/<name>/SPEC.md`; the artifacts themselves live in `config/` or per-subsystem.
- LLM-behavioral rules for human authors — those live under `.claude/rules/`.

---

## What you build on top

This is a foundation harness. It ships the deterministic spine — generalist subagents, doc-discipline skills, sanity-check hooks, a docs-audit cron, and a harness-coverage meta-audit — and the methodology that says how to extend it. It deliberately does NOT ship the domain-specific layer (typed error registry, incident store, fix-template library, log-scan and bench-validator crons, SapFix orchestration slash).

That second layer is a pattern commitment, not a free-floating exercise. Consuming repos add it by:

- Adopting [`principles.md`](principles.md) §3 (severity is a code commitment) to design a typed error system suitable for the repo's domain.
- Adopting §5 (Outalator-shape) to wire a deterministic dedup-and-group layer with operator-gated ticket promotion.
- Adopting §6 (SapFix-shape) to chain `localizer` → consuming-repo `candidate-generator` → `validator` → `pr-author` with the three deterministic gates.
- Wiring whatever cron components the repo needs (log scanner, bench validator) under `scripts/cron/cN_*.py` and SPEC-ing each under [`components/`](components/).

The foundation guarantees the patterns; the consuming repo picks the schemas. See [`components/README.md`](components/README.md) for what does ship today.
