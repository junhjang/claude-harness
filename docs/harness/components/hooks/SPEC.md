---
type: SPEC
status: accepted
owner: <author@example.com>
last-reviewed: 2026-05-06
---

# Hooks SPEC

**Scope:** the contract every hook script under `.claude/hooks/` must satisfy. This SPEC codifies the conventions the active hook scripts already comply with.

For the architectural role of hooks (Layer 1/2 of the layered enforcement model), see [`../../architecture.md`](../../architecture.md) §3.

## 1. Stdin JSON schema

Claude Code invokes the hook with a JSON document on stdin. The exact shape varies by event type but the wrapper is consistent:

```json
{
  "session_id": "<uuid>",
  "transcript_path": "<absolute-path>",
  "cwd": "<absolute-path>",
  "tool_name": "Read|Write|Edit|Bash|...",
  "tool_input": {
    "file_path": "<relative-or-absolute-path>",
    "content": "<file-contents>",
    "new_string": "<new-content-for-edit>",
    "old_string": "<old-content-for-edit>",
    "command": "<bash-command>"
  }
}
```

Field availability by event:

| Field | PreToolUse | PostToolUse | SessionStart | UserPromptSubmit | Stop |
|---|---|---|---|---|---|
| `session_id` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `tool_name` | ✓ | ✓ | — | — | — |
| `tool_input.file_path` | ✓ (Write/Edit) | ✓ (Write/Edit) | — | — | — |
| `tool_input.content` | ✓ (Write only) | ✓ (Write only) | — | — | — |
| `tool_input.new_string` / `old_string` | ✓ (Edit only) | ✓ (Edit only) | — | — | — |
| `tool_input.command` | ✓ (Bash only) | ✓ (Bash only) | — | — | — |

**Parsing convention**: every hook reads stdin once and uses `jq -r` to extract fields with `// ""` defaults so missing fields do not crash the hook.

```bash
input=$(cat)
fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
content=$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // ""')
```

The `// .tool_input.new_string` fallback handles both `Write` and `Edit` events with one extraction.

## 2. Exit code semantics

Claude Code interprets the hook's exit code as follows:

| Exit | Behavior | When to use |
|---|---|---|
| `0` | Allow the tool call. Hook output (stdout) is ignored unless explicitly emitted via `additionalContext` JSON. | Hook checked, no violation — proceed silently. |
| `1` | Allow with warning. Stderr is shown to the model and operator. | Soft-warn; e.g., a smell that the model should know about but does not block. |
| `2` | **Block the tool call.** Stderr is shown to the model and the operator. | Hard violation — secret detected, banned pattern, principle violated. |
| Other | Treated as failure; the tool call is blocked but Claude Code logs the unexpected exit. | Avoid. Use `0`/`1`/`2` exclusively. |
| `timeout` (script does not exit within configured timeout) | Tool call is blocked. The hook's behavior beyond the timeout is undefined — assume nothing. | Configure timeouts conservatively (see §4). |

**Rule**: every hook should `set -uo pipefail` (no `-e`, because `2` is intentional non-zero). `pipefail` ensures `jq` failure surfaces.

## 3. Matcher narrowing rules

Hooks register against a `matcher` string (tool name or regex alternation). The narrowing rule:

| Rule scope | Matcher shape |
|---|---|
| Type-specific (e.g., "Rust files only") | Narrow matcher (e.g., `Write|Edit`) + early-exit by file extension inside the script. |
| Operation-specific (e.g., "any Bash command") | Specific tool name (e.g., `Bash`). |
| Repo-wide (e.g., "always check secrets") | Broad matcher (e.g., `Read|Write|Edit|NotebookEdit`). |
| Multi-tool with shared filter | Pipe alternation in the matcher; let the script narrow further. |

**Heuristic**: matcher narrowness should match invocation cost. A 5ms script can run on every `Write|Edit`; a 5s script must be narrower (`Write` + file-extension early-exit).

Examples:
- A repo-wide guard (e.g., secret scanner) — broad matcher (`Bash|Read|Write|Edit|NotebookEdit`); cheap regex check.
- A language-and-subsystem-scoped guard (e.g., disallow a forbidden pattern in a specific subsystem) — narrow matcher (`Write|Edit`) + file-extension check + subsystem-path check.
- A test-discipline check — narrowest (`Write` only); uses path heuristics to find sibling test files.

Anti-pattern: registering against `*` and gating everything inside the script. The narrower the matcher, the faster the no-op path.

## 4. Latency budgets per layer

Hooks are the Layer 1 / Layer 2 deterministic surface of the layered enforcement model (`architecture.md` §3). Layer 1/2's commitment: **fast feedback during authoring**. Per-hook timeout budgets:

| Hook category | Timeout (seconds) | Why |
|---|---|---|
| Pattern checkers (regex, single-pass) — secret scanners, forbidden-call guards, banned-pattern lint | 5 | Should complete in <100ms; 5s is the safety ceiling. |
| Cross-file consistency — registry / surface-consistency checks | 10 | May read `config/` + generated artifacts. |
| Pre-commit fast — linter / formatter on the changed module | 60 | Bounded to one module; full lint is Layer 3 (CI). |
| TDD check — does a test file exist for this source? | 30 | Walks the source tree once; deterministic. |
| Post-edit format — auto-formatter on the just-edited file | 30 | Tool latency, not script latency. |
| SessionStart bootstrap — meta-index injection, audit-trigger nudge | 5 | Cheap reads only. |

`.claude/settings.json` is the source of truth for actual timeout values. The table above is the **budget contract** — a hook that needs >timeout is a redesign signal (split into cheaper layers, not a bigger budget).

## 5. Failure-mode discipline (binding)

Per [`../../principles.md`](../../principles.md) §9 (failure-mode discipline binding), every hook script must surface the following in its top comment block:

1. **Failure signature**: what does a wrong-positive or wrong-negative look like to the operator?
2. **Detection method**: how does the operator notice the hook failed?
3. **Mitigation or graceful degradation**: what happens if `jq` is missing / stdin is malformed / timeout fires?

Existing hooks comply implicitly (they `set -uo pipefail` and `exit 0` on missing inputs); future hooks should make this explicit in the comment block.

## 6. Disabled hooks

Hooks that are temporarily disabled live as `<name>.sh.disabled`. The `.disabled` extension prevents Claude Code from invoking the script. Per [`../cron-c1-docs-audit/SPEC.md`](../cron-c1-docs-audit/SPEC.md) §3.1 D9, disabled hooks must be referenced in some doc explaining why they are disabled — orphaned `.disabled` files are CHANGE-REQUEST.

To restore a disabled hook: rename back to `.sh` and re-add to `.claude/settings.json`.

## 7. Adding a new hook

Procedure:

1. Identify the matcher narrowness (per §3).
2. Identify the latency budget (per §4).
3. Write the script under `.claude/hooks/<name>.sh` with the canonical stdin parser (§1).
4. Document the failure mode in the script's top comment (§5).
5. Add the hook to `.claude/settings.json` with the chosen timeout.
6. Update `docs/harness/components/README.md` if the hook crosses the documentation threshold (e.g., enforces a new principle or component invariant).
7. Add a smoke test under `scripts/cron/test_*.py` or a test-harness equivalent for non-trivial hooks.

The `tdd-check.sh` hook itself enforces step 7 transitively for source files; for hook scripts, a test is convention rather than enforced.

## 8. References

- Active hooks: `.claude/hooks/*.sh`
- Settings: `.claude/settings.json`
- Architecture role: [`../../architecture.md`](../../architecture.md) §1, §3
- Failure-mode discipline: [`../../principles.md`](../../principles.md) §9
