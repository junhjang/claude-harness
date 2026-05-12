---
name: error-taxonomy
description: 'Adding a new error variant or error enum, wiring an error path between components, or adding a retry loop. Enforces 3-layer taxonomy (boundary/core/coordination), retry policy table, escalation contract.'
user-invocable: false
---

Apply when adding an error variant, defining a new error enum, wiring an error path, or adding a retry loop.

1. **Three layers.** Boundary (parsers, network ingress, deserializers — never retry the same bytes), core (domain logic, state machines, validators — policy varies by sub-category), coordination (config, startup, supervisors — process-abort on fatal).
2. **Unrecoverable core errors escalate; never auto-correct.** A drift between in-memory state and persisted state, an illegal state transition, or a violated invariant must halt the affected subsystem and surface to the operator. Silent auto-correction hides bugs.
3. **Preserve cause across boundaries.** Use `From` impls or `#[source]`. Never stringify lower-layer errors. Never `.map_err(|_| MyError::Whatever)` that loses the underlying variant. No catch-all `Other(String)` variants in long-lived enums.
4. **Structured variants only.** Carry typed fields (`field: &'static str`, `offset: usize`, expected/got, request id, etc.). No `String`-typed variants in performance-critical paths.
5. **Forbidden retries.** Same input that already failed deterministic parsing; encode/decode errors on unsupported shapes; any illegal-transition error; anything after the subsystem has tripped its circuit breaker. Explicit retry policy or no retry — implicit "user kicks the process" is forbidden.
6. **Vocabulary-mapping errors escalate** (unknown enum value, unknown discriminator) — upstream contracts don't add cases silently; if you see one, that's a contract drift and needs operator attention, not a fallback default.

If unclear which layer a new error belongs to, ask before defining.
