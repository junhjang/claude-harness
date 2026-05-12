---
type: PRD
status: draft
owner: <author@example.com>
last-reviewed: 2026-05-07
---

# `/audit-harness-coverage` — PRD

## Why

The harness ships skills, agents, hooks, cron implementations, state stores, and SPECs across five directories (`docs/harness/components/`, `.claude/skills/`, `.claude/agents/`, `.claude/hooks/`, `scripts/cron/`). Each addition is verified at PR time by `code-reviewer`, the gate-health hook, and the c2 docs auditor. None of those check the **cross-cutting** question: *do the SPEC, the deployment, the implementation, and the state store agree on what exists and what's planned?*

A prior manual harness review answered that question once. Until the answer is mechanized, "is the harness fit" remains an opinion. With this skill, it's a check.

## Measurable success

- Operator runs `/audit-harness-coverage` (or `python3 scripts/audit_harness_coverage.py`) and gets one structured AUDIT-typed report with exact counts: SPECs declared, primitives deployed, BLOCKERs / WARNINGs / INFOs.
- The report distinguishes `status: draft` SPECs (informational — planned, no impl yet) from undocumented gaps (BLOCKER — built without SPEC, or SPEC without impl + no draft marker).
- A drift class that a manual review previously caught (e.g., a cron SPEC describing an LLM-driven half that an ADR later retired) would now be visible in the report's Cron implementation parity section.

## Out of scope

- Semantic review of SPECs — that is `/review-doc` against the offending file.
- Validating runtime behavior — that is `docs/harness/behavior-verification.md` Phase B (operator-driven).
- LLM-based correlation between SPEC text and implementation behavior — deterministic-only per ADR-NNN (subscription-only LLM-gate; not in this portfolio cut). If a SPEC describes 5 sections and the impl has 7, this skill doesn't catch the divergence; `/review-changes` does.

## Dependencies

- Reads: `docs/harness/components/<x>/SPEC.md`, `.claude/skills/*/SKILL.md`, `.claude/agents/*.md`, `.claude/hooks/*.sh`, `scripts/cron/cN_*.py`, `var/<env>/<file>`.
- Writes: `.claude/audits/<YYYY-MM-DD>-harness-coverage.md`, suffixing `-N` if a same-day audit already exists. No mutation outside `.claude/audits/`.
- Honors: circuit-breaker flag at `var/cron.killed` (skipped if present) — same convention as the docs-audit cron.

## Cost class

Per [`docs/harness/principles.md`](../../principles.md) §12:

- LLM cost: **$0** (deterministic file walks).
- Fan-out: no LLM sub-dispatches.
- Mutation: writes only to `.claude/audits/`.
- GitHub artifacts: none.
- Circuit-breaker: no.

→ **`disable-model-invocation: false`** (LLM-invokable). The deterministic + $0 + audit-write profile qualifies for unlocked under §12.
