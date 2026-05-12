---
type: PRD
status: draft
owner: <author@example.com>
last-reviewed: 2026-05-05
---

# C2 — Daily Docs Auditor — PRD

## 1. Problem

The `docs/` subtree is the canonical narrative for how the system under harness and the harness itself work. As code lands and decisions are made, docs drift:

- New files appear without a `CLAUDE.md` index entry (Principle 7 violation).
- ADRs accumulate but the decisions index isn't updated.
- A SPEC mentions a function that no longer exists in the code.
- Frontmatter goes stale (`last-reviewed` from 6 months ago).
- Doc-pattern violations creep in (PRDs that duplicate SPECs, ADRs missing the Decision section).
- Markdown links rot.

Without a periodic audit, the docs become unreliable. Once unreliable, the doc-discipline skills (doc-pattern enforcement + new-doc scaffolding + the AI-native narrative as a whole) lose force.

## 2. Users / triggers

- **Scheduled**: daily, via platform cron (`launchd` / `systemd` / GitHub Actions cron / Kubernetes CronJob / etc.). Off-hours preferred.
- **On-demand**: operator runs `/audit-docs`.

Reads from:
- `docs/`
- `CLAUDE.md`
- `.claude/skills/`, `.claude/agents/`, `.claude/hooks/`, `.claude/rules/` (cross-references)

Writes to:
- `.claude/audits/<YYYY-MM-DD>-docs-audit.md` (AUDIT-typed doc per [`../../doc-pattern.md`](../../doc-pattern.md))
- Optional: GitHub Issues (with operator confirmation) for blocker-class findings

## 3. Success criteria

1. **Deterministic-only audit (D1–D11).** Index consistency, dead-link, frontmatter-presence, in-prose citation, and cross-doc duplication checks all run as scripts. LLM coverage is delegated to `/review-doc` + `/review-changes` on operator dispatch — per SPEC §10.1, the cron carries no LLM layer.
2. **One audit doc per run.** Date-stamped, append-only history of audit findings.
3. **Three severity tiers** in output:
   - **BLOCKERS**: index violations, broken inter-doc links, missing required frontmatter on new files.
   - **WARNINGS**: stale `last-reviewed` (>180 days), inconsistent severity wording.
   - **INFO**: observations not requiring action.
4. **Honour the circuit-breaker** — every tick checks `var/cron.killed` first.
5. **Read-only against `docs/`.** Audits report; humans edit.

## 4. Non-goals

- C2 does NOT auto-fix docs. Scope creep that would erode review discipline.
- C2 does NOT enforce per-component coverage (e.g., "every component must have a TDD") — that is a project-management concern, not a doc-quality one.
- C2 does NOT replace inline editor lints (markdown linters in CI / pre-commit) — those handle syntax; this handles semantics + cross-references.

## 5. Open questions

- **Issue auto-creation policy**: should BLOCKER findings auto-create GH Issues with operator-confirmation, or always require manual `/promote-incident`-style step? SPEC defaults to "operator confirms" — discuss after first runs.
- **Stale-frontmatter threshold**: 180 days is a guess. Tune after data.
- **LLM-class findings**: see SPEC §10.1 amendment — moved to per-PR operator-dispatched slashes (`/review-doc` + `/review-changes`).
