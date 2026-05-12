---
name: audit-harness-coverage
description: Audit harness coverage — cross-references SPECs declared under docs/harness/components/ against deployed primitives in .claude/skills/, .claude/agents/, .claude/hooks/, and scripts/cron/. Run when asked "is harness healthy", "is the harness fit for use", "audit harness coverage", "is the harness still doing what it claims", "does every SPEC have an impl", "does every deployment have a SPEC", or as step 3 of the harness-fitness-check composite. Deterministic ($0, no LLM calls), read-only against the harness, writes AUDIT-typed report to .claude/audits/.
---

# /audit-harness-coverage

_Note: Ships with a foundation stub at [`scripts/audit_harness_coverage.py`](../../../scripts/audit_harness_coverage.py) covering settings-wiring + skill/agent/hook/SPEC discoverability + referenced-but-missing reverse check. The full SPEC defines six checks (3.1 cron parity, 3.2 state stores, 3.3 skills, 3.4 agents, 3.5 hooks, 3.6 referenced-but-missing); the stub implements 3.3/3.4/3.5 + 3.5b settings-wiring + 3.6. Extend in your consuming repo. Contract: [`skill-audit-harness-coverage/SPEC.md`](../../../docs/harness/components/skill-audit-harness-coverage/SPEC.md)._

Mechanizes the question "is the harness still doing what it claims" — previously answered by manual planning audits. This skill makes it a deterministic check.

## When invoked

1. Run the implementation:

   ```bash
   python3 scripts/audit_harness_coverage.py --source manual
   ```

   - `--source manual` makes the script exit 1 on any BLOCKER (CI-gate behavior). Cron mode (`--source cron`) always exits 0 (metric-only).
   - The script writes to `.claude/audits/<YYYY-MM-DD>-harness-coverage.md` (suffixing `-N` if a same-day audit already exists).
   - **Deterministic-only**: no LLM calls. For semantic SPEC review, dispatch `/review-doc <path-to-SPEC>` separately.

2. The SPEC at [`docs/harness/components/skill-audit-harness-coverage/SPEC.md`](../../../docs/harness/components/skill-audit-harness-coverage/SPEC.md) §3 declares six checks. **The foundation stub implements 3.3 / 3.4 / 3.5 + 3.5b (settings-wiring) + 3.6 only:**

   - **3.3 Skill discoverability** — every `.claude/skills/<name>/SKILL.md` parses, has `name`+`description`, dir matches frontmatter name.
   - **3.4 Agent discoverability** — every `.claude/agents/<name>.md` parses, has `name`+`description`+`model`.
   - **3.5 Hook discoverability** — every `.claude/hooks/<name>.sh` has a shebang (BLOCKER if missing), is executable (BLOCKER if not chmod +x), and carries a >=40-char header comment (WARNING if shorter).
   - **3.5b Settings wiring** — every hook command in `settings.json` resolves to a real file on disk.
   - **3.6 Referenced-but-missing** — backtick-quoted references in docs to harness components that no longer exist on disk (catches deletion / rename drift).
   - **3.1 Cron implementation parity** and **3.2 State-store presence** are described in the SPEC but **not implemented in the foundation stub**. Consuming repos extend the stub as their cron components and state stores land.

3. **Severity categorization**:

   - **BLOCKERS** — production-claimed SPECs without impl, malformed frontmatter, dir/name mismatches, non-executable hooks.
   - **WARNINGS** — state-store paths declared but absent (where SPEC isn't draft); short hook headers.
   - **INFO** — `status: draft` SPECs without impl; absent state stores when SPEC declares draft.

4. After the script returns, report counts to operator: `<n> SPECs / <m> skills / <a> agents / <h> hooks scanned, <B> blockers, <W> warnings, <I> infos`.

5. For each BLOCKER, propose a CHANGE-REQUEST. **Operator confirms before opening any GitHub Issue** — never auto-create tickets.

## Composite usage

This skill is one step of a **Harness fitness check** composite. When the operator types "is the harness healthy" / "verify harness", the LLM should fire (in order):

1. Hook smoke tests (`bash .claude/hooks/test_*.sh`)
2. `/audit-docs` (deterministic D1–D11)
3. `/audit-harness-coverage` (this skill — cross-cutting structural)
4. Synthesize the three layers' findings.

## Rules

- **Read-only against the harness**. Never auto-fix a SPEC, skill, agent, or hook. Findings report; operator edits.
- **Deterministic-only**. No LLM calls under any flag.
- **No semantic SPEC review** — that is `/review-doc <path>`. This skill answers structural questions only ("is this SPEC's impl wired up?"), not "is this SPEC well-written."

## Forbidden

- Modifying any file under `docs/harness/components/`, `.claude/skills/`, `.claude/agents/`, `.claude/hooks/`, or `scripts/cron/`.
- Auto-creating tickets without operator confirmation.
- Treating state-store absence as a BLOCKER when the corresponding SPEC has `status: draft` or "planned" markers.
