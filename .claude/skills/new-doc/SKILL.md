---
name: new-doc
description: 'Scaffold a new documentation file (PRD / RFC / ADR / SPEC / TDD / AUDIT / POSTMORTEM / README) with the canonical frontmatter and section skeleton from docs/harness/doc-pattern.md.'
argument-hint: "<type> <topic-or-slug>"
---

Scaffold a new documentation file following the doc-pattern matrix in [`docs/harness/doc-pattern.md`](../../../docs/harness/doc-pattern.md). Read that file first if you have not already — it is the source of truth for all doc-type structure rules; this skill only operationalizes it.

**Argument format**: `/new-doc <type> <topic>`
- `<type>`: one of `PRD`, `RFC`, `ADR`, `SPEC`, `TDD`, `AUDIT`, `POSTMORTEM`, `README` (case-insensitive).
- `<topic>`: short slug. Used for both the file path and (often) the doc title.

## Steps when invoked

1. **Parse args.** Normalize `<type>` to uppercase. If the type is not one of the eight, list the valid types and stop.

2. **Determine path.** Apply these defaults; ask the user if any rule is ambiguous in the current context. Default paths shown below; consuming repos may configure different conventions (e.g., `docs/adr/` for ADRs). The skill writes to the path your project has set up.

   | Type        | Default path                                                   |
   |-------------|----------------------------------------------------------------|
   | PRD         | `docs/harness/components/<topic>/PRD.md`                       |
   | RFC         | `docs/harness/components/<topic>/RFC.md`                       |
   | ADR         | `docs/decisions/<YYYY-MM-DD>-NNN-<topic-slug>.md`              |
   | SPEC        | `docs/harness/components/<topic>/SPEC.md`                      |
   | TDD         | `docs/harness/components/<topic>/TDD.md`                       |
   | AUDIT       | `.claude/audits/<YYYY-MM-DD>-<topic>.md`                       |
   | POSTMORTEM  | `docs/postmortems/<YYYY-MM-DD>-<topic>.md`                     |
   | README      | If `<topic>` names a directory, use `<topic>/README.md`. Else ask. |

   For ADR specifically: scan `docs/decisions/` for existing files, take the highest `NNN`, increment by one. Use today's UTC date.

3. **Pre-check.** If the target file already exists, STOP. Report the path and ask whether the user wants to overwrite (default: no).

4. **Generate frontmatter.** Apply this template, filling in fields:
   ```
   ---
   type: <TYPE>
   status: draft
   owner: <git config user.email or 'unowned'>
   last-reviewed: <YYYY-MM-DD>
   ---
   ```
   For ADR, also include empty `supersedes:` and `superseded-by:` keys.

5. **Generate body.** Use the section template for that type from `docs/harness/doc-pattern.md` §4. Write the section *headers* with one-line placeholder beneath each — body text is for the user to fill in.

6. **Write the file.** Create parent directories as needed (`mkdir -p`).

7. **Report.**
   - Echo the created path.
   - Show the first ~10 lines so the user can verify frontmatter.
   - State next-step reminders, applicable to the type:
     - **All**: "Add an index line to `CLAUDE.md` (Principle 7 — Index Discipline)."
     - **ADR**: "If this supersedes an earlier ADR, set `supersedes:` here and update the older ADR's `superseded-by:`."
     - **SPEC**: "If the output of this spec is consumed by automation, plan an AUDIT trigger."
     - **POSTMORTEM**: "Link from any related ticket / incident, then schedule the action items."

## Anti-patterns to avoid

- Creating a doc with **no frontmatter** — frontmatter is required per `doc-pattern.md` §3.
- Accepting a `<type>` not in the canonical eight — push back and refer the user to `doc-pattern.md` §1.
- **Backfilling an RFC** after the decision is made — that is revisionism. Tell the user to write an ADR instead and link the prior context informally.
- Creating a **POSTMORTEM speculatively** — only after an actual incident.
- Silently overwriting an existing file. Always pre-check.
