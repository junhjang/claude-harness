# CONTEXT.md Format

The format `/grill-with-docs` writes when updating CONTEXT.md inline. Single-context (one root `CONTEXT.md`) is the default; multi-context with a shared-kernel doc is the opt-in for larger codebases.

## Single-context structure (default)

For most codebases — including small-to-medium repos and any repo with one bounded context — keep a single root `CONTEXT.md` with the `Language` / `Relationships` sections. No `CONTEXT-MAP.md`, no shared-kernel doc, no per-subsystem split.

```
/
├── CONTEXT.md                      ← root vocabulary (Language / Relationships)
└── docs/
    └── decisions/                  ← ADR home (consuming repos may configure)
        ├── 2026-05-06-007-...md
        └── 2026-05-08-008-...md
```

## Multi-context structure

**Optional — when applicable.** Single-context (one root `CONTEXT.md`) is the default. Use multi-context when the repo has ≥3 bounded subsystems with their own vocabularies. The multi-context layout pairs one `CONTEXT.md` per bounded subsystem with a routing index and shared-kernel doc at the root:

```
/
├── CONTEXT-MAP.md                  ← root routing index (which subsystem hosts what)
├── docs/
│   ├── shared-kernel.md            ← atomic newtypes referenced across subsystems
│   └── decisions/                  ← ADR home (consuming repos may configure)
│       ├── 2026-05-06-007-...md
│       └── 2026-05-08-008-...md
└── <subsystem-1>/CONTEXT.md        ← per-subsystem vocabulary
    <subsystem-2>/CONTEXT.md
    ...
```

When `/grill-with-docs` adds a term (multi-context layout):

1. Decide the **owner context** first. Composite types stay with their owner (per the C-promotion rule in `CONTEXT-MAP.md`).
2. Atomic newtypes (referenced across multiple subsystems, no fields) → `docs/shared-kernel.md`.
3. Composite types (struct/enum with multiple atomic-newtype fields) → the owner subsystem's `CONTEXT.md` until the C-promotion bar is met (e.g., "referenced in ≥3 subsystems with ≥2 cross-subsystem PRs in the last quarter").

## Per-CONTEXT.md structure

```md
---
type: SPEC
status: draft  # canonical set: {draft|accepted|superseded|retired}
owner: <author@example.com>
last-reviewed: <YYYY-MM-DD>
---

# <Subsystem> Context

<2-3 sentence responsibility statement.> Cross-cutting primitive types live in
[`docs/shared-kernel.md`](../docs/shared-kernel.md).

## Language

**Term1**: one-sentence definition. Define what it IS, not what it does.
_Avoid_: synonyms not to use, with reason if non-obvious.

**Term2**: ...
_Avoid_: ...

## Relationships

- bullet list of cross-context flows owned by this subsystem
- (CONTEXT-MAP.md has the system-level view; this CONTEXT.md has the
  flows OWNED by this subsystem)
- See [`CONTEXT-MAP.md`](../CONTEXT-MAP.md) for the system-level view.

## Example dialogue (optional, for ambiguous boundaries)

> Dev: "When X happens, do we Y?"
> Domain: "No — Y only after Z."

## Flagged ambiguities (optional)

- "term" was used to mean both A and B — resolved: ...
```

## Rules

- **Be opinionated.** When multiple words exist for the same concept, pick the canonical one and list synonyms in `_Avoid_:` with reason.
- **Flag conflicts explicitly.** If a term is used ambiguously, surface the conflict in `Flagged ambiguities` with a clear resolution.
- **Keep definitions tight.** One sentence preferred; two acceptable when the second sentence carries an invariant the type encodes.
- **Show relationships.** Cross-context flows go in `Relationships`; per-newtype relationships (e.g., `Foo * Bar → Baz`) go in shared-kernel's `Cross-newtype relationships` section.
- **Only include domain-meaningful terms.** General programming concepts (timeouts, error types, retry policies) don't belong unless they carry domain-specific semantics in this codebase. Before adding a term, ask: is this concept distinctive to this codebase, or general programming?
- **Group by section** as shown above (Language / Relationships / Example dialogue / Flagged ambiguities). Don't introduce sub-headings unless the section grows >20 terms — at which point split the context.
- **Owner-first.** When in doubt about which CONTEXT.md a term belongs in, recall the C-promotion rule: ownership stays with the originating subsystem; promotion to kernel requires evidence.
- **Frontmatter status field** — use the canonical set `{draft|accepted|superseded|retired}`. New CONTEXT.md files start at `status: draft`.

## Inline-update etiquette during a `/grill-with-docs` session

- Update **as soon as a term is resolved**, not after the session — momentum matters; batched updates lose nuance.
- When you add a `_Avoid_:` line, no automated check enforces it — the discipline is operator review during `/grill-with-docs` interviews. If the source already uses a synonym you're forbidding, mention it to the operator so they can rename in the same session.
- When you add a term that mirrors something already in an invariant doc (e.g., `docs/harness/components/<n>/SPEC.md`), the invariant doc stays the source of truth for *how the type behaves*; CONTEXT.md is the source of truth for *what the type is called* and what synonyms to avoid. They are orthogonal — don't migrate rule prose into CONTEXT.md.
- For composite types whose ownership isn't obvious, record **the owner-context decision** in the Flagged ambiguities section: e.g., "`Foo` ownership: subsystem X (emits) over subsystem Y (consumes) — emitter is the canonical home." Future readers and future C-promotion candidate detection benefit from the recorded reasoning.

## Origin

The single-context layout is the mattpocock original. The multi-context extension above is this harness's opt-in for larger codebases — see the "Single-context structure (default)" / "Multi-context structure" sections at the top of this file.
