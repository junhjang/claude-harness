---
name: doc-pattern
description: 'Creating a new doc file under docs/ — PRD, RFC, ADR, SPEC, TDD, AUDIT, POSTMORTEM, README. Selects the right doc type based on trigger rules, applies frontmatter, decides single-file vs folder layout.'
paths: ["docs/**"]
user-invocable: false
---

Apply when creating a new doc under `docs/`. Full rationale: [`docs/harness/doc-pattern.md`](../../../docs/harness/doc-pattern.md).

1. **8 doc types, each answers one question.**
   - PRD: why exists / who uses
   - RFC: alternatives explored
   - ADR: what was committed
   - SPEC: input/output contract
   - TDD: internal mechanics (only if non-trivial)
   - AUDIT: does it still work (output of automation)
   - POSTMORTEM: post-incident only, never speculative
   - README: how to run / observe / stop

2. **Triggers — write only when fired.** PRD + README always. RFC: irreversible decision OR multiple credible alternatives. ADR: per RFC conclusion or small committed decision. SPEC: output consumed by another system. TDD: code unreadable in <30min. AUDIT: output is automation input. POSTMORTEM: actual incident only. Empty docs are worse than missing docs.

3. **Frontmatter required:**
   ```
   type: PRD | RFC | ADR | SPEC | TDD | AUDIT | POSTMORTEM | README
   status: draft | accepted | superseded | retired
   owner: <author>
   last-reviewed: YYYY-MM-DD
   ```
   ADRs may add `supersedes` / `superseded-by`.

4. **Single file → folder promotion** when 2nd ADR is needed or RFC accumulates more than one screen. `git mv components/X.md components/X/SPEC.md`. Update CLAUDE.md to point at the folder.

5. **Status discipline.** ADR never edited — supersede with new ADR + `superseded-by` link. PRD answers "why", SPEC answers "what" — don't mix in one doc. README is operator-facing and links to SPEC, never paraphrases it.

If unsure which type, ask before writing.
