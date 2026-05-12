# Harness Principles

**Scope:** permanent commitments that shape every harness in this repo. Append-only — retired commitments are struck through with a date and reason, never deleted, never silently edited.

These principles exist to make the harness predictable, cost-bounded, and safe to run against a production codebase. Each principle below comes with **why** it exists and **how to apply** it. New harnesses must cite the principles they rely on.

For documentation choices (which doc types to write), see [`doc-pattern.md`](doc-pattern.md). For the architectural shape that implements these principles, see [`architecture.md`](architecture.md).

---

## 1. Harness Surface Principle

**Anything the harness modifies automatically must exist as a single declarative artifact, with all derived code generated from it and consistency between artifact and derivatives verified at build or CI time.**

- Why: scattered knowledge (severity in match arms, alert rules in YAML, dashboard config in JSON) cannot be safely modified by automation. The harness needs one file to read and one file to write. Diff size collapses; review becomes mechanical.
- How to apply: designate a single declarative artifact; generate derivatives with a `// GENERATED` header; fail CI on artifact↔derivatives mismatch.
- Anti-pattern this prevents: "the harness scans 200 files and tries to keep them in sync." That fails. Centralize first, then automate.

## 2. LLM Boundary Principle

**LLMs are invoked only between deterministic detection and deterministic validation. Both ends of any harness pipeline must be deterministic.**

- Why: LLMs make probabilistic errors. In any system where a single bad change has high blast radius (production code, security-sensitive paths, irreversible side effects), a probabilistic decision at the boundary — deciding whether an error is fatal, deciding whether a fix is correct — creates unbounded risk. Sandwiching the LLM between deterministic stages caps the consequences of any single LLM mistake.
- How to apply: detection is regex/schema; LLM proposes; validation is deterministic; human reviews the artifact.
- Anti-pattern this prevents: "the LLM judged this as safe and merged it." If the LLM is the last gate, the system is unsafe.

## 3. Severity Is a Code Commitment, Not a Model Output

**Error severity is a property of the error variant, encoded by the code that raises it. No model — statistical or LLM — assigns severity.**

- Why: false-negative cost (mis-classifying a fatal error as noise) is often catastrophic and asymmetric to false-positive cost (extra noise). A 99% accurate classifier still produces 1% catastrophic misses. Deterministic severity removes that risk class entirely. Severity belongs to the variant definition — the harness extends that contract, it does not replace it.
- How to apply: severity is a fixed field on the variant in whatever error system the consuming repo adopts (typed enums, an error-code registry, a typed-exception hierarchy); frequency / recency / anomaly are orthogonal sort signals, never reclassifiers. The pattern is binding; the schema is left to the consuming repo.
- Anti-pattern this prevents: "a million low-severity errors get noticed before the one fatal error." Sorting by frequency in a high-asymmetry system is the bug.

## 4. Model Choice by Difficulty × Importance, Bounded by Budget

**Model selection is a 2-axis decision (task difficulty × consequence severity), not a cost-driven tier. Cost is bounded separately by budget cap and prefilters, not by always-default-to-cheap.**

- Why: P3 already commits us to asymmetric severity. A cost-first model tier puts weak models in front of high-consequence decisions, contradicting P3. Difficulty × importance keeps both budget and accuracy intact: budget is enforced by *frequency* of LLM calls (prefilter, cache, template-first), not by always picking the smallest model.
- How to apply: map (difficulty × consequence) → Haiku/Sonnet/Opus; bound cost by prefilter + cache + per-invocation cap, with a circuit-breaker slash (e.g., a `/kill-cron`-style command in the consuming repo) as the global pause.
- Anti-pattern this prevents:
  - "Haiku triaged the novel error as noise; the fatal variant got buried in the incident store." (P3 hole opened by cost-first tiering)
  - "Always-on Opus cron burns budget proving there is nothing to do." (original P4 still prevents this — preserved via prefilter + budget cap)

## 5. Outalator-Shape Incident Handling

**Logs and alerts feed a deterministic dedup-and-group layer that produces durable incident objects. Tickets are created by humans from incidents — never automatically from raw logs.**

- Why: auto-creating tickets from raw logs produces ticket spam, which destroys ticket discipline, which destroys the value of the ticket queue. Google Outalator and equivalent systems converged on grouping-without-ticketing for this reason. Humans promote a small fraction of incidents to tickets; the rest die quietly.
- How to apply: a dedup key groups signals into incident objects (severity-from-variant, counts, trends, tags) that are deduplicated, severity-sorted, surfaced at session start, and graduated to tickets through an explicit operator gate (not auto-promoted). The Outalator-shape pattern is the rule; the concrete incident-store implementation belongs in the consuming repo.
- Anti-pattern this prevents: "we created 10,000 tickets last week, none were looked at."

## 6. SapFix-Shape Auto-Fix Loop

**Any automated fix flows through: deterministic localization → LLM candidate generation → three deterministic gates (compiles, existing tests pass, new test added) → human review of a PR. The LLM never lands code.**

- Why: this is the only automated-fix architecture publicly documented as production-safe (Meta SapFix, FBLearner pipelines). The structure works because deterministic stages bound the LLM's blast radius and the human is always the merger. Auto-fix follows the SapFix shape — typed agents per stage with deterministic gates; never a single generalist model from ticket to PR.
- How to apply: templates before open-ended LLM; all three gates non-negotiable; output is always a PR; default `forbidden` per variant, explicit opt-in. The pattern is binding; the concrete fix-template library, candidate-generator agent, and orchestrating slash command are left to the consuming repo to commit to once its error system is in place.
- Anti-pattern this prevents: "the harness fixed it itself overnight and broke prod."

## 7. Index Discipline

**`CLAUDE.md` at the repo root is the single index. Every doc in this subtree is reachable from it. No orphan docs.**

- Why: a harness that audits docs needs a deterministic entry point. If docs reference each other only by ad-hoc paths, link rot accumulates and no automation can detect it.
- How to apply: every new doc gets a `CLAUDE.md` line; cross-references use repo-root-relative paths; the docs-auditor verifies reachability both ways.
- Anti-pattern this prevents: docs that exist but no one finds, docs referenced but no longer existing.

---

## 8. External-pattern adoption decisions

**Every external pattern this harness considered has an explicit verdict here. A future patch author can tell whether a missing pattern is intentionally absent or accidentally missing.**

| Pattern | Verdict | Why |
|---|---|---|
| XML body structure for agents (`<Agent_Prompt>` template) | adopted | Strong pattern; clear role / NOT-role separation |
| Frontmatter `name` / `description` / `model` / `disallowedTools` | adopted | Standard Claude Code subagent contract |
| Skill `user-invocable: false` for auto-load-only | adopted | Keeps slash menu clean |
| External-routing `level:` frontmatter field | rejected | Internal to the originating pattern library; no use here |
| Deterministic-first cron pattern (no LLM in cron) | adopted | Implemented across all cron components; semantic review is operator-triggered, not cron-driven. |
| Direct LLM-API usage in cron / hook scripts (vendor SDK, raw API keys) | rejected | Subscription-only by design; no second auth/billing path. PR-time semantic enforcement lives in a local pre-merge hook driven by operator-triggered `/review-changes`. |
| Writer/reviewer separation in agent prompts | adopted | Encoded as `<Constraints>` clause in code-reviewer / security-reviewer / critic / doc-reviewer agents. |
| Hierarchical AGENTS.md generation | deferred | Useful pattern; not yet needed at this scale |
| Autonomous execution loops | rejected | Violates P5 (no autonomous ticket creation) + P6 (human is final merger) |
| Plugin distribution model | rejected | Harness is repo-coupled; abstracting for plugin distribution adds complexity without benefit |
| Multi-provider team orchestration | rejected | SapFix flow is serial by design; parallel agent specialization is a future possibility |
| Skill `pipeline:` / `next-skill:` chaining | deferred | May fit composite audit flows; revisit when chaining is concretely needed |
| Skill `triggers:` keyword auto-activation | deferred | Possible if user-prompt keyword detection becomes useful |

When a pattern's verdict changes, add an ADR explaining the change AND update this table in the same commit. Silently flipping a verdict is a P7 (Index Discipline) violation.

---

## 9. Failure-mode discipline (binding)

**Every patch that introduces a new primitive (skill, agent, hook, cron, slash command, state store) MUST include a failure-mode table.**

The table answers three questions per failure surface:

1. **Failure signature** — what does the failure look like to a downstream observer? (e.g., "the docs-audit cron writes a 0-byte audit file"; "secret-guard hook silently no-ops on a hook script with `set +e`"; "an auto-trigger SessionStart hook fails to surface useful context.")
2. **Detection method** — what catches it? (deterministic check; metric threshold; manual `/audit-X` slash; relies on operator noticing.)
3. **Mitigation or graceful degradation** — what happens between failure and operator noticing? (circuit-breaker flag; refusal output; partial-result with `EARLY-TERMINATED` marker; halt-and-alert.)

Audits that propose new primitives without a failure-mode table are CHANGE-REQUEST when reviewed by the doc-reviewer agent.

This rule binds to **future** patches; existing primitives without a failure-mode table do not need retroactive backfill unless an incident or audit re-opens them.

---

## 10. Token cost exposure

**Every patch that adds an LLM-using primitive must estimate the monthly token cost at baseline call frequency before merge.**

Per-model rates (illustrative; treat the actual numbers as a project-local table updated alongside provider pricing):

| Model | Input $/MTok | Output $/MTok |
|---|---|---|
| Haiku | $1 | $5 |
| Sonnet | $3 | $15 |
| Opus | $15 | $75 |

Worked examples for primitives in this harness:

- **`/review-doc` (Sonnet default)** ≈ ~$0.08 / dispatch (12K input + 3K output).
- **`/review-doc` (Opus override on high-blast-radius paths)** ≈ ~$0.40 / dispatch.
- **`/audit-docs-semantic <subtree>`** capped at $5.00 / invocation. Worst case: 50 docs × Sonnet → $4.00; refuses-to-dispatch above cap.
- **`/review-changes`** capped at $1.00 / invocation. Per-PR-diff scope; Sonnet default; Opus on high-blast-radius paths. Typical PR (~5 changed files) → ~$0.30.
- **SapFix-shape auto-fix loop** (Sonnet/Opus per region; consuming-repo implementation) ≈ $0.15–$1.00 / ticket depending on region branch.

**Standing rule**: estimate before merging any patch that adds new LLM-using primitives. Estimate format: `<model> × <calls/period> × <tokens/call> = <$/month>`. Document the estimate in the patch's PR body.

**Auth path rule**: all LLM costs above are billed through the operator's subscription via subagent dispatch. The harness has no direct-SDK / raw-API-key path; cron and hook scripts are deterministic-only.

Daily budget cap: superseded by per-invocation caps (`/audit-docs-semantic` $5.00; `/review-changes` $1.00; Sonnet-gated `/review-doc` / `/review-changes` dispatches). A circuit-breaker slash (consuming-repo `/kill-cron`-style command) remains the global pause when one is wired up.

---

## 11. Audit → canonical doc distillation discipline

**When an audit produces findings, the findings flow to one of three destinations. They do NOT remain as audit-only-references in canonical docs.**

| Destination | When |
|---|---|
| **Apply directly** to the canonical doc | Trivial fix; the canonical doc absorbs the change with no cite needed. |
| **Promote to a new ADR** | The finding establishes a durable architectural commitment. The ADR is the cite-worthy artifact going forward; the audit is the trigger. |
| **Absorb as a rule** in `principles.md` / `doc-pattern.md` / a SPEC / a skill body | The finding establishes a process or convention. The canonical doc states the rule on its own authority. |

Audit cites in canonical docs are restricted to:

- **HTML provenance comments**: `<!-- provenance: <audit-path> F5 -->` (not rendered; grep-only).
- **ADR `Triggered by:` frontmatter lines**: the audit was the trigger; the ADR is the decision.
- **PR bodies + commit messages**: audit IDs are workflow handles, not long-lived doc references.

**Bound to**: `docs/`, `.claude/skills/`, `.claude/agents/`, `.claude/rules/`, `CLAUDE.md`, `README.md`. **Does NOT bind to**: other audit files (audit-to-audit cites are the canonical synthesis pattern).

**Anti-pattern this prevents**: canonical docs that read "Per audit X finding F5" — making audits load-bearing for rules they shouldn't be authoritative for. Audits are work logs; rules are doc content. The two must be separated cleanly.

**Why**: audits are time-stamped review artifacts. Their findings are real but their *role* is to drive change, not to BE the source of truth. When canonical docs cite audits as authority, the docs become brittle — every audit becomes a permanent dependency, dead-link risk grows, and a future maintainer cannot tell which audits are still load-bearing vs historical.

**How to apply**: after each audit ships, the same PR (or a follow-up) absorbs each finding's outcome into the appropriate destination. Audit-cite scrubbing is a canonical-doc-cleanup step, not optional. The doc-reviewer agent's `prompts/cross-cutting.md` flags violations as CHANGE-REQUEST when `/review-doc` or `/review-changes` is dispatched against the offending canonical doc — there is no automated CI gate on this pattern today (operator-triggered review is the layer).

## 12. Cost-class rule for slash skills

A skill sets `disable-model-invocation: true` only when it has real LLM cost (fan-out, multi-agent dispatch), mutates state outside `audits/var/`, creates GitHub artifacts, or is an operator circuit-breaker. Locked skills must document an operator escape valve — drive the procedure inline through chat without the slash. Periodically sweep the catalogue: any locked slash whose justification no longer holds should unlock.

---

## Retired commitments

- **P4 v1 — Cost discipline by tiering (cost-first model selection)** — superseded by P4 v2 (Difficulty × Importance, bounded by budget). Reason: cost-first tiering put weak models at high-consequence detection gates, contradicting P3 asymmetric severity. Original text preserved below for record:
  > Token spend is bounded by tiering: deterministic prefilters do most work, small models triage what remains, large models are reserved for human-triggered synthesis.
  >
  > - Why: an always-on LLM cron daemon spends tokens proving there is nothing to do. The 95% case in any harness is uneventful and should cost ~0. The 5% case justifies an LLM call.
  > - How to apply:
  >   - Default trigger: event-driven (hook, file change, threshold crossing). Scheduled cron only when no event exists.
  >   - First action of any scheduled job: a deterministic "is there work?" check. Exit early if no.
  >   - Triage uses Haiku. Synthesis uses Sonnet/Opus. Frontier model is never the default.
  >   - Costly model invocations are gated by explicit user action (slash command), not autonomous schedule.
  >   - A daily token budget caps spend; exceeding the cap pauses the harness and alerts.
  > - Anti-pattern this prevents: hourly Opus cron that processes empty queues.
