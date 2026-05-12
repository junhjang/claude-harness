---
name: zoom-out
description: Go up a layer of abstraction and give a map of relevant modules and callers, using the project's domain glossary vocabulary. Use when the user is unfamiliar with a section of code, asks "what hooks into this", "where is this called from", "한 단계 위에서 보여줘", "이게 어디서 쓰여", or invokes /zoom-out.
---

The user does not know this area of code well. Go up a layer of abstraction. Give a map of all the relevant modules and callers, using the project's domain glossary vocabulary.

Sources of vocabulary, in order: the root `CONTEXT-MAP.md` (if present) and per-subsystem `CONTEXT.md` files; otherwise fall back to `docs/harness/architecture.md` + `docs/harness/components/<x>/SPEC.md` (or `docs/architecture.md` + `docs/components/<x>.md` in forks that use a flatter layout).
