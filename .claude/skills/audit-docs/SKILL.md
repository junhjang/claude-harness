---
name: audit-docs
description: Audit docs/ for drift — index reachability, doc-pattern conformance, dead markdown links, frontmatter validity, ADR id density, staleness, in-prose citation resolution, cross-doc duplication. Run when about to edit anything under docs/, when asked to review docs, when asked if docs are healthy, when asked to check for stale frontmatter / dead links / index drift / doc-pattern violations. Deterministic ($0, no LLM calls), read-only against docs/, writes AUDIT-typed report to .claude/audits/.
---

# /audit-docs

_Note: Ships with a foundation stub at [`scripts/cron/c1_docs_audit.py`](../../../scripts/cron/c1_docs_audit.py) covering D1–D3 + D5 (index reachability, frontmatter, dead links, ADR id density). The full SPEC defines D1–D11 — extend the stub in your consuming repo as you adopt the remaining checks. Contract: [`cron-c1-docs-audit/SPEC.md`](../../../docs/harness/components/cron-c1-docs-audit/SPEC.md)._

Trigger the docs-auditor cron in manual mode to scan `docs/` and `CLAUDE.md` for:

1. **Index consistency**: every file under `docs/` is reachable from `CLAUDE.md` (transitively); every entry in `CLAUDE.md` resolves to a real file.
2. **Doc-pattern conformance** ([`docs/harness/doc-pattern.md`](../../../docs/harness/doc-pattern.md)): every doc has the required frontmatter, status / type values are valid, ADR ids are unique and dense.
3. **Dead links**: relative markdown links resolve.
4. **Drift between SPECs and code**: e.g., a SPEC mentions a function that does not exist; a SPEC's referenced file path is missing.
5. **Doc-pattern violations**: a "PRD" file that talks like a SPEC, an ADR with no "Decision" section, a POSTMORTEM written without an incident, etc.

## When invoked

1. Run the implementation in manual mode:

   ```
   python3 scripts/cron/c1_docs_audit.py --source manual
   ```

   - `--source manual` makes the script exit 1 on any BLOCKER (CI-gate behavior). Cron mode (`--source cron`) always exits 0 and surfaces blockers via the run-record only.
   - **Same-day idempotency**: if a same-day audit exists AND no audited file mtime is newer, the script exits 0 with `cached audit at <path> is current; skipping run`. Pass `--force` to bypass and run anyway. This makes auto-fire from the SessionStart trigger hook safe under repeated sessions: if nothing changed, the cached audit is reused.
   - The script writes the AUDIT-typed report to `.claude/audits/<YYYY-MM-DD>-docs-audit.md` (suffixing `-N` if `--force` is used or the cache is invalidated mid-day) and appends one record to `var/<env>/cron-c1-runs.jsonl`.
   - **Deterministic-only**: this cron makes zero LLM calls. For semantic doc/code review, use operator-triggered `/review-doc <path>` or `/audit-docs-semantic <subtree>` — those use subagent dispatch on the operator's Claude Code subscription.

2. The SPEC at [`cron-c1-docs-audit/SPEC.md §3.1`](../../../docs/harness/components/cron-c1-docs-audit/SPEC.md) declares D1–D11. **The foundation stub implements D1–D3 + D5 only:**
   - **D1 — Index reachability**: every doc under `docs/` is transitively reachable from `CLAUDE.md`. BLOCKER on orphan.
   - **D2 — Frontmatter conformance**: required keys (`type`, `status`, `last-reviewed`), valid `status` and `type` values, navigation-file carve-out. BLOCKER on missing key / invalid value. WARNING on stale (`last-reviewed` >180d).
   - **D3 — Dead links**: every relative markdown link resolves. BLOCKER on dead link.
   - **D5 — ADR id density**: if `docs/decisions/` exists, ids are dense (no gaps). WARNING on gap.
   - **D4 / D6–D11** are described in the SPEC but **not implemented in the foundation stub** (e.g., disabled-hook orphans, in-prose citation resolution, cross-doc duplication detection). Consuming repos extend the stub as they adopt the remaining checks.

3. After the script returns, report to operator: blockers count, warnings count, infos count, audit file path.

4. For each BLOCKER, optionally open a GitHub Issue with label `docs-audit`. **Operator confirms before opening** — never auto-create tickets.

## Rules

- **Read-only against `docs/`**. Never auto-fix doc text. Audits report; humans edit.
- **Deterministic-only.** No LLM calls under any flag. Semantic review is a different surface (`/review-doc` / `/audit-docs-semantic`).
- **Honour `doc-pattern` skill** — auto-loaded on `docs/**`, encodes the same rules this skill enforces.

## Forbidden

- Modifying any file under `docs/` (audits report; do not patch).
- Skipping a category if it produced no output — list zero counts explicitly.
- Auto-creating tickets without operator confirmation.
- Running anything destructive (`rm`, `mv`) under `docs/`.
