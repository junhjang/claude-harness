# Harness behavior verification

The harness ships two layers of verification:

| Layer | Cadence | Owner | What it verifies |
|---|---|---|---|
| **Phase A — deterministic** | every PR (CI gate-health job) | machine | static harness shape: cost-class justification, escape valves, auto-trigger description shape |
| **Phase B — dynamic** | once per release / when something feels wrong | operator (≈10 min) | the harness actually FIRES during real work — slashes auto-load, composites sequence correctly, SessionStart hooks surface useful context |

Phase A is formatter-focused; Phase B closes the structural-vs-behavioral gap with a small operator-driven smoke set.

## Phase A — deterministic battery

_Note: the implementation script `scripts/verify_harness_behavior.py` is **not shipped in this foundation cut** — it lives in the consuming repo. The contract below describes what the script must satisfy; consuming repos wire it once the harness has enough surface to verify._

Planned implementation path: `scripts/verify_harness_behavior.py`.

CI runs it on every PR (gate-health job, after the smoke tests). Local equivalent (once wired):

```bash
CLAUDE_PROJECT_DIR=$(pwd) python3 scripts/verify_harness_behavior.py
```

Exit code 0 = no BLOCKERs. Exit code 1 = at least one BLOCKER; full per-finding list on stderr.

The checks each catch a specific drift class:

| Check | Catches |
|---|---|
| Cost-class justification (§12) | a slash sets `disable-model-invocation: true` without surfacing a §12 keyword (LLM cost / fan-out / mutation / GitHub artifact / circuit-breaker) — likely cargo-cult lock |
| F1b escape valve (§12) | a locked slash has no operator path documented (no concrete bash, no agent dispatch, no BYPASS) — slash is unfirable from any path |
| Auto-trigger description shape | an unlocked slash has no recognized trigger phrase — CC's auto-load won't pick it up on real operator language |

## Phase B — operator runbook

Run this once per release, or when the harness "feels off." Time budget: ~10 minutes per release. Each test below is a single chat-session task; record the result in your release log.

### B.1 — Self-fire test

**Setup**: a fresh Claude Code session in this repo (or after `/compact`).

**Prompt**:
```
is docs healthy?
```

**Expected behavior**: Claude autonomously fires `/audit-docs` (no manual slash typing). Verify by checking the docs-audit cron's run record (`var/<env>/cron-c1-runs.jsonl`) — a new entry should appear with `method: "manual"`. The output should surface blockers / warnings / infos.

**Failure mode**: Claude reads files manually instead of firing the slash. This means the auto-trigger description didn't match — broaden the description or check the cost-class lock.

### B.2 — Auto-load coverage

**Prompts** (each in its own fresh session):

| Phrase | Expected slash to auto-fire |
|---|---|
| "is docs healthy" | `/audit-docs` |
| "is the harness fit" | `/audit-harness-coverage` |
| "how much budget have we spent today" | `/budget-status` |
| "review this doc" + path | `/review-doc <path>` |
| "scaffold a new ADR" | `/new-doc adr` |

**Pass criterion**: each phrase fires the corresponding slash without operator typing the slash name. If a phrase doesn't fire its slash, the description's trigger phrases need broadening (CHANGE-REQUEST against the SKILL.md frontmatter).

### B.3 — Multi-primitive sequencing test

**Setup**: fresh session.

**Prompt**:
```
review every doc under docs/
```

**Expected behavior** (planned composite-intent flow for "Holistic docs review"; the harness ships the individual slashes but the composite-intent map is a planned meta-index skill):

1. Claude fires `/audit-docs` autonomously (deterministic checks only).
2. Claude dispatches `Agent(critic, ...)` against `docs/harness/principles.md`.
3. Claude proposes to the operator: "Want `/audit-docs-semantic docs/`? (~$5)" and waits for confirmation.
4. After operator confirms (or declines), Claude synthesizes the prior layers' findings into one structured report.

**Failure modes**:

- Claude fires only `/audit-docs` and stops → the slash descriptions' auto-trigger phrases don't match the composite intent; broaden them.
- Claude fires `/audit-docs-semantic` without operator confirmation → composite discipline violated; the synthesis step shouldn't auto-confirm cost-bearing slashes.
- Claude reads files manually → the `session-start-meta-index.sh` pointer didn't surface at session start; check SessionStart hook output.

### B.4 — SessionStart context relevance

**Setup**: edit a `docs/*.md` file, then start a fresh session.

**Expected stderr at SessionStart** (visible in CC's status / startup output):

- Meta-index pointer (from `session-start-meta-index.sh`): `[harness] Available discipline skills under .claude/skills/: ...`
- Docs-audit nudge: `[harness] audited file roots have changed since <last-audit-path>. Consider running /audit-docs ...`

**Pass criterion**: docs-audit nudge appears AND its message names the actual stale audit path. If it doesn't fire, check `session-start-docs-audit-trigger.sh` is wired in `.claude/settings.json`.

### B.5 — Cost-class spot check

**Setup**: pick three slashes — one unlocked (e.g., `/audit-docs`), one cost-bearing (e.g., `/audit-docs-semantic`), one review-fanout (e.g., `/review-changes`).

**For each**, verify:

1. Frontmatter `disable-model-invocation` matches the cost-class table in [`principles.md`](principles.md) §12.
2. The escape valve form documented for the skill's class actually appears in the SKILL.md body.
3. (For unlocked) auto-trigger phrases appear in the description.

**Failure mode**: skill has drifted from the §12 cost-class rule — file a CHANGE-REQUEST against the SKILL.md.

## When Phase B fails

Phase B failures are CHANGE-REQUEST severity by default. The harness still runs; it just doesn't fire the right primitives at the right time. Address by adjusting:

- Frontmatter description (auto-trigger phrases)
- `disable-model-invocation` flag (per §12)
- The `session-start-meta-index.sh` pointer (slash list and discipline skill list)
- SessionStart hook wiring

If a failure indicates a new primitive is needed (not just a description fix), open a finding against the audit + propose a wave to ship it.
