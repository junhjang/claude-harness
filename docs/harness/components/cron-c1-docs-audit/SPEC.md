---
type: SPEC
status: draft
owner: <author@example.com>
last-reviewed: 2026-05-05
---

# C2 — Daily Docs Auditor — SPEC

For motivation see [`PRD.md`](PRD.md). For the doc-type matrix this audits against see [`../../doc-pattern.md`](../../doc-pattern.md). For the principles enforced see [`../../principles.md`](../../principles.md).

## 1. Inputs

### 1.1 Configuration

```yaml
# config/cron/c2.yaml
schema_version: 1
roots:
  - docs/
  - CLAUDE.md
  - .claude/skills/
  - .claude/agents/
  - .claude/rules/
  - .claude/hooks/
stale_threshold_days: 180
auto_open_issues: false           # operator-confirm for v1
issue_label_prefix: docs-audit
```

### 1.2 Source-of-truth files (loaded at start)

- `docs/harness/doc-pattern.md` — frontmatter requirements, section templates per type.
- `docs/harness/principles.md` — Principle 7 (Index Discipline) reference.
- `CLAUDE.md` — index of record.

## 2. Outputs

### 2.1 Audit doc

Single file at `.claude/audits/<YYYY-MM-DD>-docs-audit.md` — never overwritten (date-stamped). If two runs same day, append `-N` suffix.

**Idempotency**: a same-day run that finds (a) a cached audit for today AND (b) no audited file mtime newer than the cached audit's mtime returns the cached audit's path **without re-running** the checks or writing a new file. The fast path prints `cached audit at <path> is current; skipping run` and exits 0. To force a fresh run, pass `--force`. This makes auto-fire from the `session-start-docs-audit-trigger.sh` hook safe under repeated session starts: same docs → cached result; changed docs → new audit.

Schema:

```markdown
---
type: AUDIT
status: accepted
owner: docs-auditor
last-reviewed: <YYYY-MM-DD>
---

# Docs audit — <YYYY-MM-DD>

Method: <"C2 cron" | "manual /audit-docs">
Files scanned: <n>  (docs: <n>, .claude/skills: <n>, ...)
Duration: <wall-clock>

## Blockers (<n>)

  - **<file>:<line> — <category>**
    <detail>
    suggested fix: <one line>

## Warnings (<n>)

...

## Info (<n>)

...

## Tickets opened

  - <none> | #<issue-num> <title>
```

### 2.2 GitHub Issues (optional)

If `auto_open_issues: true` AND a finding is a BLOCKER, open one issue per finding with label `<issue_label_prefix>` and the finding text as body. v1 default: `false` — operator reviews + opens manually.

### 2.3 Run record

`var/<env>/cron-c1-runs.jsonl` — one entry per tick.

## 3. Checks

### 3.1 Deterministic checks (always run)

Deterministic checks only; the historical LLM-Haiku check layer was retired in favour of operator-triggered `/review-doc` + `/review-changes` (subscription-only — no direct LLM-SDK / raw-API-key path is available to cron). The PR-time enforcement landed alongside that retirement: `/review-changes` skill + `pr-create-gate.sh` hook block `gh pr create` / `gh pr merge` until the slash produces a non-BLOCK verdict for the current HEAD sha. Replacement mapping:

| Old LLM check | Replacement |
|---|---|
| L1 — PRD why-not-what | `/review-doc` `prompts/PRD.md` via `/review-changes` |
| L2 — ADR single-decision | `/review-doc` `prompts/ADR.md` row 1 |
| L3 — README duplicates SPEC | `/review-doc` `prompts/README.md` + `prompts/cross-cutting.md` |
| L4 — POSTMORTEM tied to incident | Deferred — no POSTMORTEM template exists yet |

| # | Check | Severity |
|---|---|---|
| D1 | Every file under `roots` resolves at the path declared in `CLAUDE.md` (where indexed) | BLOCKER if missing |
| D2 | Every link in `CLAUDE.md` resolves to an existing file | BLOCKER if dead |
| D3 | Every doc with frontmatter has all REQUIRED keys per `doc-pattern.md` §3 | BLOCKER if missing |
| D4 | Frontmatter `type` value is one of the eight valid types | BLOCKER if invalid |
| D5 | ADR ids in `docs/decisions/` are unique and dense (no gaps) (no-op until docs/decisions/ subtree lands) | WARNING if gap |
| D6 | Every relative `[text]` `(path)` markdown link inside `docs/` resolves | BLOCKER if dead within docs/, WARNING if external |
| D7 | `last-reviewed` newer than `stale_threshold_days` ago | WARNING if stale |
| D8 | New doc has corresponding `CLAUDE.md` index entry | BLOCKER if missing |
| D9 | Disabled hooks (`.claude/hooks/*.disabled`) are still referenced somewhere (settings.json or doc) | WARNING if orphaned |
| D10 | In-prose citation resolution: every in-prose reference of the form `ADR-NNN`, `<file>.md §<n>`, or `[text](path)` resolves to a real artifact | BLOCKER if cite is dead within any audited root (per §1.1), WARNING if external |
| D11 | Cross-doc duplication: hash blank-line paragraphs ≥200 chars; any hash in 2+ audited files is BLOCKER. Canonical home = alphabetically-first occurrence; later occurrences flagged for cross-reference or deletion. `.claude/audits/` excluded (audit files quote prior text by design). | BLOCKER |

## 4. State

- Audit file (single per run, durable)
- Run record (jsonl, append-only)
- No cursors — each run scans everything fresh

## 5. Invariants

1. **Circuit-breaker first** — `[ -f var/cron.killed ]` short-circuit at start.
2. **Read-only against docs.** No mutation of any file under `roots`.
3. **Audit doc is immutable.** Once written, edit only via a follow-up audit doc.
4. **Issues opened only with operator confirmation** in v1 (`auto_open_issues: false` default).

## 6. Failure modes

| Failure | Detection | Response |
|---|---|---|
| `roots` path unreachable | startup | Log + skip; continue with available |
| `doc-pattern.md` missing or malformed | startup | Process abort + alert (audit cannot run without spec) |
| Audit doc write fails | end of run | Log to stderr; emit alert via Run record; do not retry |

## 7. Concurrency

- Single instance enforced via `flock var/<env>/cron-c1.lock`.
- C2 may run while sibling crons are running — they touch disjoint paths.

## 8. Versioning

- `schema_version: 1` in config. Increment on check-set change.
- Audit doc format version is implicit in the doc structure (changes appear in git history).

## 9. Implementation pointer

- Implemented at `scripts/cron/c1_docs_audit.py` (D1–D11 deterministic). Daily cron via `.github/workflows/c1-docs-audit.yml`.
- `/audit-docs` invokes the same script with `--source manual` flag.
