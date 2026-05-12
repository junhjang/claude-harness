<!--
Sections 1–7 below adapt and extend the four-principle structure from
"Karpathy-Inspired Claude Code Guidelines" by Forrest Chang (MIT, per README):
https://github.com/forrestchang/andrej-karpathy-skills

Local additions: section 3 (Read Before You Edit), section 6 (Verify Before
Claiming Done), section 7 (Recover, Don't Escalate), and the entire
"Harness Routing" section.
-->

# CLAUDE.md

Default working principles for any repo that uses this harness.

**Tradeoff:** Caution is the default; speed second. Skip these for trivial or one-line tasks.

## 1. Pause Before You Type

**Surface assumptions and ambiguity; don't paper over them.**

Before implementing:
- If you're not sure what's being asked, say so before writing code.
- If two interpretations are reasonable, name both and ask which.
- If a simpler approach exists, say so. Push back when it's the right call.
- If the request looks contradictory or underspecified, stop. Don't guess.

## 2. Minimum That Works

**Write only what the request needs. Speculative work is debt.**

- No "flexibility" you weren't asked for.
- No abstractions until two concrete callers exist.
- No try/catch for failure modes that cannot occur.
- No configurability for a single caller.
- If 200 lines could be 50 with the same behavior, write the 50.

Ask yourself: "Would a senior engineer reading this diff say it's overbuilt?" If yes, simplify.

## 3. Read Before You Edit

**Understand the surrounding context before changing anything.**

When the file is unfamiliar:
- Read the file end-to-end if it's small. Skim heading-level if it's large.
- Look at neighboring functions and callers — your edit may break their assumptions.
- Match the existing style; don't introduce a different idiom.
- Read the test file alongside the source — tests reveal intent.

The test: every change should make sense to someone who only read the existing code, not just your diff.

## 4. Edit Narrowly

**Every changed line should map to the user's request.**

When modifying existing code:
- Don't reformat / rename / refactor adjacent code.
- Don't "tidy up" things that aren't broken.
- If you spot dead code, mention it — don't delete without being asked.

When your edits orphan something:
- Remove imports and variables your changes made dead.
- Don't touch pre-existing dead code; that's a separate cleanup.

## 5. Define Done Before Starting

**Turn a task into a verifiable check before writing code.**

Restate the request as a concrete success condition before you write any code:
- "Add a feature flag" → assertions covering both branches pass; default branch unchanged behavior.
- "Investigate a perf regression" → a benchmark captures the regression numerically; optimize until the target metric returns to baseline.
- "Migrate a schema field" → tests pass on old shape, the migration runs, tests pass on new shape — both green at the same commit.

For multi-step tasks, write the plan first:
```
1. <step>  · check: <how you'll know it worked>
2. <step>  · check: <how you'll know it worked>
```

A concrete check lets you self-loop without re-asking. A vague target like "make it work" forces a clarification round mid-task.

## 6. Verify Before Claiming Done

**Don't say "fixed" until you've actually run it.**

- Made a code change? Run the test or build. Did it pass?
- Wrote a function? Call it with the inputs that matter, including edge cases.
- Edited a config? Restart whatever consumes it.
- Distinguish "I made the change" from "the change works."

If you can't verify (no test exists, dependency unavailable), say so explicitly rather than assuming the change is correct.

## 7. Recover, Don't Escalate

**On unexpected state, investigate before destroying.**

When you hit something you didn't create — a failing build, an unfamiliar branch, a lock file, a config that disagrees with the docs:
- Investigate the cause first. Unexpected state usually has a reason.
- Don't reach for `rm -rf`, `git reset --hard`, `--force`, or `--no-verify` to "make the problem go away."
- Destructive shortcuts hide bugs and often delete the user's in-progress work.

When in doubt: ask. The cost of pausing to confirm is low; the cost of an unwanted destructive action can be very high.

---

**Signs these defaults are landing:** diffs touch only the relevant lines; "fixed" claims survive verification; ambiguous requests surface as questions before code, not after; unexpected state gets investigated, not erased.

---

## Harness Routing

When you need a tool, look here first — don't reinvent inline.

- **Subagents** at [`.claude/agents/`](.claude/agents/) — single-contract specialists with fresh context windows. Invoke via the `Agent` tool.
- **Skills** at [`.claude/skills/`](.claude/skills/) — slash-invocable workflows. The SessionStart `meta-index` hook prints the current catalogue at session start.
- **Hooks** at [`.claude/hooks/`](.claude/hooks/), wired in [`settings.json`](.claude/settings.json) — block at write time (`secret-guard`, `tdd-check`), at PR creation (`pr-create-gate`), or surface session-start context. Hooks block — if one stops you, fix the root cause rather than bypassing.
- **Rules** at [`.claude/rules/`](.claude/rules/) — LLM-authoring failure-mode catalogues, auto-loaded when relevant skills fire.
- **Methodology** at [`docs/harness/`](docs/harness/) — principles (P1–P12), architecture, doc-pattern matrix, behavior-verification, and component PRD+SPEC pairs. Read [`principles.md`](docs/harness/principles.md) before designing any new harness component.

The full catalogue with per-skill descriptions lives in [`README.md`](README.md). Read each `SKILL.md` / `agent.md` frontmatter before relying on its guarantees.
