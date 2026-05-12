---
type: SPEC
status: draft
owner: <author@example.com>
last-reviewed: 2026-05-07
---

# `/audit-harness-coverage` — SPEC

For motivation see [`PRD.md`](PRD.md). For where this fits in the AI-native development harness see [`../../architecture.md`](../../architecture.md). For the cost-class rule that puts this skill in the LLM-invokable column see [`../../principles.md`](../../principles.md) §12.

## 1. Inputs

### 1.1 Configuration

No config file. The script enumerates from fixed repo paths:

- `docs/harness/components/<name>/SPEC.md` — declared primitives (SPECs).
- `.claude/skills/<name>/SKILL.md` — deployed slash skills.
- `.claude/agents/<name>.md` — deployed subagents.
- `.claude/hooks/<name>.sh` — deployed hooks (excluding `test_*.sh`).
- `scripts/cron/cN_*.py` — cron implementations (where the consuming repo wires them).
- `var/<env>/<file>` — state-store paths referenced by SPECs (where applicable).

`HARNESS_ENV` (default `dev`) substitutes for `<env>` in state-path references.

## 2. Outputs

### 2.1 Audit doc

Single file at `.claude/audits/<YYYY-MM-DD>-harness-coverage.md` — never overwritten. If two runs same day, append `-N` suffix (mirrors the docs-audit cron's convention; same-day idempotency is *not* implemented for this skill — re-runs are intentional and cheap).

Schema:

```markdown
---
type: AUDIT
status: accepted
owner: harness-coverage-auditor
last-reviewed: <YYYY-MM-DD>
---

# Harness coverage audit — <YYYY-MM-DD>

Method: deterministic walk ...
Components scanned: <n> SPECs / <m> skills / <a> agents / <h> hooks

## Blockers (<n>)
...
## Warnings (<n>)
...
## Info (<n>)
...
```

### 2.2 Run record

No `var/<env>/cron-*-runs.jsonl` record — this skill is currently operator-fired only, not on cron. If a cron entry is added later, the record convention follows the docs-audit cron's pattern.

## 3. Checks

### 3.1 Cron implementation parity

For every SPEC under `docs/harness/components/cron-cN-*/`:

- Expected impl: `scripts/cron/cN_*.py` (any matching glob).
- If impl exists → no finding.
- If impl missing AND SPEC body / frontmatter says "not yet implemented", "planned", "deferred", or `status: draft` → **INFO** (planned-but-not-built, acceptable, visible).
- If impl missing AND SPEC has none of those signals → **BLOCKER** (production-claimed but not built).

### 3.2 State-store presence

For every SPEC that names inline-code paths to durable state files (any `<root>/...` mentioned as an artifact location):

- Resolve the path against the repo and any env-variable substitution the SPEC describes (e.g., `${HARNESS_ENV:-dev}`).
- If the concrete path exists on disk → no finding.
- If absent AND the SPEC has a "not yet implemented" / "draft" signal → **INFO**.
- If absent otherwise → **WARNING** (state stores can be intentionally cold; the goal is visibility, not enforcement of every named path).

The general pattern: every claimed harness component should be implemented where it claims to be. The check enumerates the paths a SPEC names; it does not hard-code paths that belong to specific components.

### 3.3 Skill discoverability

For every `.claude/skills/<name>/SKILL.md`:

- Frontmatter parses → required.
- `name` and `description` keys present and non-empty.
- Directory name matches frontmatter `name` (so the SessionStart pointer resolves).

Severity: **BLOCKER** for any failure (CC's auto-load needs the frontmatter; the runtime won't surface a malformed skill).

### 3.4 Agent discoverability

For every `.claude/agents/<name>.md`:

- Frontmatter parses; required keys: `name`, `description`, `model`.

Severity: **BLOCKER** for missing required keys.

### 3.5 Hook discoverability

For every `.claude/hooks/<name>.sh` (excludes `test_*.sh`):

- Shebang present (`#!`) → required (BLOCKER otherwise — hooks without shebang silently fail).
- Executable bit set → required (BLOCKER otherwise — a hook that's not `chmod +x` can't be invoked).
- Header comment block ≥40 chars between shebang and `set -...` line → expected (WARNING if shorter).

The test-file convention is currently advisory: not every hook needs `test_<name>.sh`, so we don't enforce it as a finding. The smoke tests are run by CI's gate-health job; this skill doesn't duplicate that check.

### 3.6 Referenced-but-missing (reverse check)

For every backtick-quoted name or path-style reference in the documentation set (CLAUDE.md, README*.md, SETUP.md, TROUBLESHOOTING.md, `docs/harness/**/*.md`, `.claude/**/*.md` excluding `.claude/audits/`, and `.claude/settings.json`):

- `` `/<name>` `` (slash-prefixed) → expect `.claude/skills/<name>/SKILL.md` to exist.
- `` `.claude/agents/<name>.md` `` (path form) → expect that agent file.
- `` `.claude/skills/<name>/SKILL.md` `` (path form) → expect that skill.
- `` `.claude/hooks/<name>.sh` `` (path form) → expect that hook.

If the referenced file does not exist → **BLOCKER** (catches deletion / rename drift where a doc still points at a removed component).

The check is conservative: it only flags references whose target file does not exist. It does NOT enforce that every existing component is referenced somewhere.

## 4. State

No persistent state. Every run is a fresh enumeration. Inputs change → output changes deterministically.

## 5. Invariants

- **No LLM calls** under any flag (per §12 cost-class rule criterion 1).
- **No mutation outside `.claude/audits/`** (per §12 criterion 3).
- **No GitHub artifact creation** — findings surface in the audit doc; the operator opens issues / PRs as appropriate (per Principle 5 — Outalator-shape).
- **Idempotent within a run** — re-running on the same repo state produces the same audit doc (different filename suffix `-N`, same content).

## 6. Failure modes

| Failure | Detection | Mitigation |
|---|---|---|
| `docs/harness/components/` removed | `enumerate_specs()` returns empty | result.specs_scanned=0; no findings emitted; downstream confusion is visible to operator via the count |
| Skill / agent file is binary or non-UTF-8 | `parse_frontmatter` returns `{}` | "frontmatter unparseable" BLOCKER |
| `HARNESS_ENV` mis-set | state-path concretizes to wrong env | WARNING-class noise; operator overrides via env var |

## 7. Concurrency

No locks. Multiple instances may run concurrently — they enumerate the same files, produce same content, write to different `<date>-N.md` filenames (the same `-N` collision pattern the docs-audit cron uses). State is read-only across runs.

## 8. Versioning

The check set (3.1–3.6) defines v1. Adding a new check = increment to v2 (and add to this SPEC's amendments). Removing a check requires a `## Retired commitments`–style entry in `principles.md` if the check enforced something cited elsewhere.

## 9. Implementation pointer

- Foundation stub: [`scripts/audit_harness_coverage.py`](../../../../scripts/audit_harness_coverage.py) — implements checks 3.3 / 3.4 / 3.5 / 3.5b / 3.6. Checks 3.1 (cron-impl parity) and 3.2 (state-store presence) are described above as the SPEC contract; the consuming repo extends the stub to cover them.
- Tests: `scripts/test_audit_harness_coverage.py` (consuming repo).
- Slash skill: [`.claude/skills/audit-harness-coverage/SKILL.md`](../../../../.claude/skills/audit-harness-coverage/SKILL.md).
- Cost class: §12 LLM-invokable (description-match auto-trigger fires on phrases like "is harness healthy", "audit harness coverage", "harness fit").
