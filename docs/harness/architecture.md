# Harness Architecture

**Scope:** the top-level shape of the AI-native development harness — which Claude Code primitives play which role, how they compose into a closed loop, and where each external pattern (SapFix, Outalator, Tricorder) maps in.

For the commitments that constrain this architecture, see [`principles.md`](principles.md). For per-harness specifications, see `components/`.

---

## 1. Five primitives, five roles

The harness is built from five Claude Code primitives, each playing a distinct role. Confusing the roles produces either over-spend or unsafe automation.

| Primitive | Role | Trigger | Cost profile |
|---|---|---|---|
| **Hook** | Reflex — runs on a system event in the active session. | `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, `UserPromptSubmit` | Often deterministic (no LLM). When LLM, scoped tightly. |
| **Cron / scheduled agent** | Heartbeat — runs on a schedule independent of any session (e.g. a daily docs-audit cron). | Time. | LLM only when prefilter says there is work; otherwise early-exit. |
| **Subagent** | Specialist — isolated context, called by another agent or by a slash command. Each agent has a structured `<Agent_Prompt>` body and `disallowedTools` enforcement of P6 ("LLM never lands code"). | Invoked by parent. | Bounded by the calling primitive. |
| **Skill** | Trained intuition — auto-loaded discipline injected when relevant work is detected. | User intent / file patterns matching the skill's scope. | No invocation cost; modifies how the model already running behaves. |
| **Slash command** | Cockpit — explicit human-initiated action. | User types `/<command>`. | Highest-cost work runs here, gated by user intent. |

**Rule:** the more autonomous the primitive (cron > hook > subagent > skill > slash command), the more deterministic its body must be. Autonomous LLM invocations are the most dangerous and most expensive; user-triggered LLM invocations are cheap (rare) and safe (intent is explicit).

## 2. The closed loop

The foundation harness ships the deterministic side of this loop (PostToolUse linters, docs-audit cron, SessionStart context, operator-triggered review slashes). The detection → incident → fix half is a pattern the consuming repo wires up once it has its own error system; the shape of that wiring is fixed by P3 / P5 / P6 even when the implementation is not.

```
[Hook: PostToolUse on code change]
    └─ deterministic linter / consistency check
       └─ on violation → emit signal (no LLM)

[Cron: daily]
    └─ docs auditor
       └─ scan for principle / structure violations
          └─ deterministic checks only → AUDIT-typed file

[Slash command: /review-changes]
    └─ multi-agent review of PR or local diff (Sonnet default; Opus on high-blast-radius)
       └─ verdict gates `gh pr create` / `gh pr merge`

[Hook: SessionStart]
    └─ inject docs-audit nudge and meta-index pointer into session context
```

The consuming repo extends this loop with — at minimum — a deterministic detection layer (logs → grouped incidents), an operator gate (promote incident → ticket), and a typed auto-fix chain (localizer → candidate generator → validator → PR). The patterns are in [`principles.md`](principles.md) §3, §5, §6; the implementations are out of scope for the foundation harness.

Three things to notice:

- **The LLM never appears in the cron/hook stages of the autonomic side.** Detection and grouping are deterministic. Any log scanner the consuming repo adds is shell + SQL, not Sonnet.
- **The user is the gate between detection and fix.** Promotion to ticket and triggering of fix synthesis are slash commands, not autonomous transitions.
- **Skills inject discipline during the fix synthesis itself**, so the LLM operates within the right rules without a separate retrieval step.

## 3. Layered enforcement model

Enforcement of harness invariants is **layered**: each layer catches a different class of violation, at a different latency, with a different blast-radius cost when it fails. The cheaper layers run first; the more expensive layers exist as defense-in-depth and as final review.

| Layer | Where it runs | What it enforces | Cost / latency | Failure mode |
|---|---|---|---|---|
| **Layer 1 — Deterministic guards** | `PreToolUse` hooks; denylists in `.claude/settings.json` | Hard-banned patterns at write time (secrets, `unwrap` in safety-critical paths, `mean` in benches, etc.). Fast regex / static checks. | <100ms ideal, 5s ceiling. Local to the active session. | If a hook is disabled / untriggered / mid-PR edited, the write slips through. Layer 2 catches it. |
| **Layer 2 — Deterministic post-execution checks** | `PostToolUse` hooks; CI gates (`hook-replay`, lint, test, build) | Cross-file consistency, replays of Layer 1 against the PR diff, deterministic registry / spec / artifact integrity. | seconds to minutes; runs after a write or on PR. | If a CI job is misconfigured or skipped, defense-in-depth gone. Layer 3 catches semantic drift; Layer 4 catches the rest. |
| **Layer 3 — LLM-driven adversarial review** | Subagents (`critic`, `code-reviewer`, `security-reviewer`, `doc-reviewer`) dispatched via slash skills (`/review-changes`, `/critic-review`, `/review-doc`) | Principle violations (P1–P12 + retired commitments), per-component invariant breaches on PR diffs, unenforced prose rules in canonical docs. Probabilistic — accepts false-positives, optimised against false-negatives. | per-dispatch cost ($0.08–$2.00 typical); operator-triggered, not autonomous. | If the review verdict is wrong, Layer 4 (the human) is the final reader. The LLM never lands code (P2). |
| **Layer 4 — Human review on the final PR** | GitHub PR review by the operator | Everything Layers 1–3 cannot encode: intent, taste, cross-PR context, off-policy judgment. | Minutes per PR; the final, irreducible gate. | None — this is the last layer. P6 commits the human as the merger. |

**Layering rule:** pick the cheapest layer that catches the failure class; defense-in-depth across layers is the design (Layer 1 hook with Layer 2 CI replay is the canonical pattern).

For the contract every Layer 1/2 hook must satisfy, see [`components/hooks/SPEC.md`](components/hooks/SPEC.md). For the CI workflow that owns Layer 2 + part of Layer 3's dispatch surface, see [`components/ci/SPEC.md`](components/ci/SPEC.md).

## 4. Where each external pattern maps in

Patterns marked *foundation* are wired up in this repo. Patterns marked *pattern only* are committed by `principles.md` but expect the consuming repo to ship the implementation — the foundation harness intentionally leaves the schema choices open.

| Pattern | Source | Where it lives |
|---|---|---|
| **Outalator-shape incident handling** | Google SRE | *Pattern only.* P5 binds the dedup-and-group + operator-gated promotion shape; the incident-store implementation belongs in the consuming repo. |
| **SapFix-shape auto-fix** | Meta | *Pattern only.* P6 binds the localize → candidate → 3-gate → PR flow; the foundation ships the `localizer` / `validator` / `pr-author` subagent contracts as scaffolding, and the consuming repo wires the candidate-generator + orchestrating slash. |
| **Tricorder-shape pre-merge analysis** | Google | *Foundation.* The `PostToolUse` hooks on code changes — `rule-stub-check`, `auto-format` — run deterministic checks scoped to the edited files only. |
| **Kayenta-shape canary** | Netflix / Spinnaker | Out of scope for the harness. The deployment pipeline owns canary; if a consuming repo adds a bench-validator cron, its signal would feed in here. |
| **Getafix-shape learned templates** | Meta | *Pattern only.* When the consuming repo wires the SapFix chain, its candidate generator tries templates before open-ended LLM generation. Template-library shape is described in `principles.md` §6. |

## 5. Layering of decisions

Decisions move from cheap and frequent at the bottom to expensive and rare at the top:

```
                ┌─ human merge of PR              (rare, careful)
       LLM ─────┤
                └─ candidate fix synthesis        (per auto-fix dispatch)
                  ┌─ novel-pattern clustering     (per new incident)
       LLM ───────┤
                  └─ one-line incident summary    (per new incident)
       ─────────────────────────────────────────────────────────────
       script ─── incident dedup, severity sort   (per cron tick)
       script ─── log → store upsert              (per log line)
       script ─── PostToolUse linter              (per file change)
```

The volume of work flows upward (1000s of log lines → ~20 incidents/day → ~5 tickets/week → ~1 PR/week). Cost flows the same direction. The architecture works because the funnel narrows quickly.

## 6. State that crosses session boundaries

The harness pattern calls for durable state stores; none of them is the LLM's context window. The foundation cut writes only audit artifacts (under `.claude/audits/`) and run records (under `var/<env>/`). The richer state stores listed below are described as patterns — concrete implementations are out of scope for this generic harness, and live in the consuming repo per the rules in [`principles.md`](principles.md).

| Store | Holds | Role |
|---|---|---|
| **Registries** (e.g., a typed error registry) | The Surface — single source of truth per domain (P1). | Codegen, validators, harness fix proposals read it; humans normally write it. |
| **Incident store** | Deduped incidents, counts, trends, tags, severity (P5). | Dashboard, slash commands, SessionStart hook read it; deterministic cron + `PostToolUse` hooks write it. |
| **Fix template library** | Accepted-PR-derived templates for SapFix-shape generation (P6). | Candidate generator reads it; an explicit operator slash promotes templates after a PR merges. |

Pattern: the harness may need state stores like these. Concrete implementations are out of scope for this generic harness — see [`principles.md`](principles.md) §3 / §5 / §6 for the patterns these stores adopt. Sessions are stateless against any such storage. Restarting the harness or starting a new Claude Code session loses no state.

## 7. Failure modes of the architecture itself

| Failure | Symptom | Mitigation |
|---|---|---|
| Cron fires on empty queue, spends tokens. | Per-invocation cap creeps toward ceiling. | Early-exit prefilter ([principle 4](principles.md#4-model-choice-by-difficulty--importance-bounded-by-budget)). Per-invocation caps (`/audit-docs-semantic` $5.00; `/review-changes` $1.00; etc.) refuse-to-dispatch above cap; a consuming-repo circuit-breaker slash is the global pause ([principle 10](principles.md#10-token-cost-exposure)). |
| LLM proposes a fix that passes the three gates but is semantically wrong. | Bad PR opened. | Human review is the final gate ([principle 6](principles.md#6-sapfix-shape-auto-fix-loop)). Templates only accumulate from merged PRs, not opened ones. |
| Auto-ticket creation slips into the design. | Ticket queue floods. | Architectural ban ([principle 5](principles.md#5-outalator-shape-incident-handling)) enforced by `/critic-review` and PR reviewer. |
| Docs and harness behavior diverge. | Reviewers cannot trust the SPEC. | Docs auditor flags drift; AUDIT files updated automatically. |

## 8. What this architecture is not

- **Not a fully-autonomous agent.** It does not self-improve without human approval at the merge step.
- **Not real-time.** All harness work is off any latency-sensitive runtime path. The slowest stage (LLM synthesis) takes minutes, not microseconds.
- **Not a replacement for SRE process.** The harness handles development-time mechanical work. Production incidents still flow through whatever incident process the operator runs; the harness produces inputs to that process, not the process itself.
