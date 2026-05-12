---
name: review-changes
description: Semantic review of every changed file in the current branch's diff vs main. Dispatches /review-doc per changed .md and code-reviewer per changed .rs/.py/.sh/.yaml/.json config. Writes a state artifact tagged with HEAD sha so the pr-create-gate hook will allow `gh pr create` and `gh pr merge`. Use this before opening or merging any PR.
disable-model-invocation: true
---

# /review-changes

Semantic per-PR review for the current branch. Operator-triggered; subscription-only (uses Claude Code subagent dispatch). Pairs with [`pr-create-gate.sh`](../../hooks/pr-create-gate.sh) hook which blocks `gh pr create` and `gh pr merge` until this skill has run with a non-BLOCK verdict for the current HEAD sha.

## When invoked: `/review-changes`

### 1. Compute the diff scope

```bash
BASE="$(git merge-base origin/main HEAD)"
HEAD_SHA="$(git rev-parse HEAD)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git diff --name-only "$BASE...HEAD"
```

If the branch IS `main`, refuse with: `'/review-changes' is for feature branches; nothing to review on main`.

### 2. Filter to reviewable file kinds

| Kind | Path patterns | Reviewer |
|---|---|---|
| Markdown docs | `docs/**/*.md`, `.claude/**/*.md`, `CLAUDE.md`, `README.md` | `/review-doc <path>` (semantic doc review) |
| Rust source | `**/*.rs` | `code-reviewer` agent against the file's diff |
| Python source | `**/*.py` | `code-reviewer` agent against the file's diff |
| Shell scripts | `.claude/hooks/**/*.sh`, `scripts/**/*.sh` | `code-reviewer` agent against the file's diff |
| YAML / JSON config | `config/**/*.yaml`, `.github/workflows/*.yml`, `.claude/settings.json` | `code-reviewer` agent against the file's diff |

Shell scripts under `.claude/hooks/` are substantive harness components. Including `.sh` here closes the gap where hook changes might otherwise land without semantic review.

#### 2a. `security-reviewer` auto-fan-out

When ANY file in the diff matches a security-sensitive path, additionally dispatch the `security-reviewer` agent **in parallel** to the per-file reviewer above. This implements the cross-cutting policy "PR-by-PR review with the third reviewer firing automatically when the diff touches a security-critical surface."

Configure security-sensitive paths in this skill's project config. Example security-sensitive surfaces — replace per your project:

| Path pattern | Why security-sensitive |
|---|---|
| Auth / credential subsystem | Credential storage, signing logic, key material handling |
| Safety / correctness gates | Pre-action checks, fail-closed paths, circuit breakers |
| External-input parsing / validation | Untrusted input boundaries; deserialization, schema enforcement |

If the diff has NO match, `security-reviewer` is NOT dispatched (don't pay for review on diffs that have no security surface). If the diff has even one matching file, `security-reviewer` reviews the WHOLE diff — security concerns span the system.

`security-reviewer` dispatch counts as one additional fan-out slot — concurrency cap stays ≤4 total across all reviewers.

Skip: `*.md` under `scratch/` (gitignored anyway); generated files declared in registries; binary files; vendored third-party scripts. If the filtered list is empty, write an empty-pass state artifact and return — there's nothing to review.

### 3. Pre-flight cost estimate

For each file, predict the dispatching model:

- `.md`: per `/review-doc` heuristic (Sonnet default; Opus on the safety-critical paths configured in `/review-doc`).
- `.rs` / `.py` / `.sh` / `.yaml` / `.json` config: Sonnet default for `code-reviewer`; no Opus override (code-reviewer is uniformly Opus per its current frontmatter — re-evaluate if cost concerns surface).
- **`security-reviewer` (§2a)**: counted as one additional Opus dispatch when any security-sensitive path is in the diff (the agent's frontmatter is `model: claude-opus-4-7` — see `.claude/agents/security-reviewer.md`). Roughly 5–15× Sonnet per token; include in the cost estimate before applying the $1.00 cap.

Sum estimate. **Refuse if estimate > $1.00** (per-PR cap, smaller than `/audit-docs-semantic`'s $5.00 because PR diffs are typically narrower than full subtrees).

### 4. Operator confirmation

Show the file count + per-kind breakdown + estimate. Default: ask. Skip with `--yes`.

### 5. Bounded fan-out dispatch

Concurrency ≤4 (same as `/audit-docs-semantic`). For each file:

- `.md` → invoke `/review-doc <path>` skill
- `.rs` / `.py` / `.sh` / `.yaml` / `.json` config → dispatch `code-reviewer` agent with the file path + the diff slice for that file. For `.sh` files, the agent reads `docs/harness/components/hooks/SPEC.md` as its invariant source (stdin schema / exit codes / matcher narrowing / latency budgets).
- **If §2a security-sensitive path matched**: in parallel, dispatch `security-reviewer` agent with the FULL diff (not just matching files) — security concerns span the system. Counts as one slot in the concurrency cap.

Mid-flight cost tracking; abort remaining if cumulative > cap (emit partial artifact with `EARLY-TERMINATED` marker; verdict defaults to `BLOCK` so the gate refuses).

### 6. Aggregate verdict

Per-file verdict ∈ `{PASS, CHANGE-REQUEST, BLOCK}`. Plus `security-reviewer`'s diff-level verdict (when dispatched per §2a) — uses the same `{PASS, CHANGE-REQUEST, BLOCK}` domain (the agent's own contract may use the GitHub-PR-review verb `REQUEST-CHANGES`; normalize to the harness-canonical `CHANGE-REQUEST` when reading). Aggregate ALL of them:

| Per-file + security outcome counts | Aggregate verdict |
|---|---|
| any `BLOCK` OR any `EARLY-TERMINATED` OR `security-reviewer = BLOCK` | `BLOCK` |
| any `CHANGE-REQUEST` (no BLOCK) OR `security-reviewer = CHANGE-REQUEST` | `CHANGE-REQUEST` |
| all `PASS` (including security-reviewer if it ran) | `PASS` |
| zero files | `PASS` (no-op) |

### 7. Write state artifact

```
var/<env>/review-changes/<head-sha>.json
```

Where `<env>` = `${HARNESS_ENV:-dev}` and `<head-sha>` is the full HEAD sha at review time (`git rev-parse HEAD`). This is keyed by **commit identity, not branch name** — required for multi-session correctness when two Claude Code sessions share one working tree.

The branch name is preserved in the state JSON's `branch` field for human readability and audit-log navigation, but the gate's lookup key is the SHA in the filename. A `git commit --amend` / rebase / new commit changes HEAD sha → state file's filename no longer matches → the gate correctly demands re-review (because the diff content changed).

Schema:

```json
{
  "branch": "feature/foo-bar",
  "head_sha": "abc1234",
  "base_sha": "def5678",
  "reviewed_at": "2026-05-06T09:00:00Z",
  "files_reviewed": 7,
  "verdict": "PASS|CHANGE-REQUEST|BLOCK",
  "blockers": 0,
  "change_requests": 2,
  "nits": 3,
  "ambiguous": 0,
  "per_file": [
    {"path": "docs/harness/components/auth/SPEC.md", "verdict": "CHANGE-REQUEST", "model": "claude-opus-4-7"},
    {"path": "scripts/cron/c1_docs_audit.py", "verdict": "PASS", "model": "claude-opus-4-7"}
  ],
  "security_review": {
    "dispatched": true,
    "trigger_path": "src/auth/lib.rs",
    "verdict": "PASS"
  },
  "early_terminated": false,
  "cumulative_cost_usd": 0.42
}
```

The `security_review` block is present iff §2a auto-fan-out fired. `dispatched: false` (or block omitted) means no security-sensitive path in the diff.

The hook reads `head_sha` and `verdict` from this file.

### 8. Surface to operator

Print: file counts / verdict / cited findings. If verdict is `BLOCK` or `CHANGE-REQUEST`, list the per-file BLOCKERs and CHANGE-REQUESTs explicitly so the operator can address them and re-run.

If verdict is `PASS`, print the gate-allowed line: `state artifact written; gh pr create / gh pr merge will now be allowed`.

## Re-running

If the operator amends the commit (`git commit --amend`), force-pushes, or rebases — the HEAD sha changes and the state artifact no longer matches. The hook will block again until `/review-changes` is re-run.

## Operator escape valve

This skill is `disable-model-invocation: true`. Drive steps 1-8 above turn-by-turn through chat (the Edit/Write/Agent tools the chat session uses are not locked; only the slash is). Hotfix bypass: `BYPASS_REVIEW_CHANGES=1`.

### Failure modes (§9)

| Failure | Detection | Mitigation |
|---|---|---|
| `Skill` tool invocation of `/review-doc` errors mid-flight on one file | Tool returns error result for that file in step 5 | Mark that file's per-file verdict `BLOCK`; continue remaining files; aggregate to `BLOCK` per step 6 |
| `Agent` tool dispatch refuses (permission missing, subagent crash) for one file | Tool returns error in step 5 | Same as above — `BLOCK` that file, continue, aggregate `BLOCK` |
| Operator does not respond to step 4 confirmation | No timeout in chat; the procedure halts indefinitely | Operator-discipline: re-fire the procedure OR resume with explicit "proceed" / `--yes` analog. No artifact written until confirmation; gate stays blocked safely |
| Cumulative cost exceeds $1.00 mid-flight | Mid-flight cost tracker in step 5 | Abort remaining; write artifact with `early_terminated: true` and verdict `BLOCK` per step 6 |
| State JSON write fails (filesystem error, missing parent dir) | `mkdir -p "$ENV_DIR"` succeeds + `jq`/file-write fails | Surface the error to the operator; do NOT pretend success; the gate stays blocked because no artifact exists for HEAD sha |

## Bypass

For hotfixes or for explicitly accepting CHANGE-REQUEST findings:

```bash
BYPASS_REVIEW_CHANGES=1 gh pr create ...
```

The hook accepts the bypass via either (a) `BYPASS_REVIEW_CHANGES=1` in its own environment, OR (b) the same env-var prefix on the command string itself. Both paths log a bypass record to `var/<env>/review-changes/bypass.log` for retrospective review. Path (b) is required because Claude Code's PreToolUse hook is launched by the harness — not by the user's shell — so a shell-prefix env var on a Bash-tool command never reaches the hook's own env.

## Rules

- **Subscription-only.** No `anthropic` SDK calls; no `ANTHROPIC_API_KEY` reads.
- **Per-file scope.** This skill never reviews unchanged files — that is `/audit-docs-semantic`'s territory.
- **Cost cap is mandatory.** $1.00 default; configurable via a future `config/cron/d5.yaml` (deferred until first non-default cap is needed).
- **No auto-block of merge from CI.** The local hook is the only gate; CI deterministic checks remain unchanged.
- **No auto-fix.** Findings are surfaced; operator decides whether to address before re-running.

## Forbidden

- Reviewing files outside the diff scope.
- Concurrency > 4.
- Auto-promoting verdict (operator cannot override the artifact's verdict; they must address findings + re-run).
- Calling `anthropic` SDK directly anywhere in this skill or invoked agents.
