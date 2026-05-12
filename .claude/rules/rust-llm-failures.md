# Rust LLM Failure Modes

Tooling (clippy, type system, `cargo check`) catches code issues. These rules cover **LLM behavior patterns the tools can't catch** — the tendency to silence tools rather than fix the underlying problem.

If you're tempted to do any of the below, stop and ask instead.

---

## 1. Don't silence clippy with `#[allow(...)]`

- Fix the underlying issue. Clippy lints exist for a reason; suppressing hides that from future readers.
- If the lint genuinely doesn't apply, the `#[allow(...)]` must include a `// reason:` comment:

```rust
// reason: FFI boundary requires raw pointer; safety documented in module header
#[allow(clippy::not_unsafe_ptr_arg_deref)]
```

- No comment → not acceptable.

## 2. Don't `.clone()` to escape the borrow checker

`.clone()` is a deliberate choice with performance and semantic implications, not a shortcut to make the compiler stop complaining.

Before reaching for `.clone()`:
1. Can this be a reference (`&T`)?
2. Can lifetimes be restructured?
3. Can ownership be passed differently?
4. Does `Cow<T>` or `Arc<T>` fit?

"The borrow checker yelled at me" is not a reason.

## 3. Don't `.unwrap()` / `.expect()` outside test code

This is the canonical home for the no-`unwrap`/`expect`-outside-test rule.

- In `src/` (non-test code), errors propagate via `Result<T, E>` and `?`.
- `.unwrap()` / `.expect()` are acceptable only when:
  - In tests (`#[cfg(test)]` or `tests/`).
  - The invariant is provably impossible to violate, AND a comment explains why.
  - Initialization-time code where panic = unrecoverable startup failure (intentional).
- In performance-critical or safety-critical code, an unhandled panic is an outage. If you don't know how to handle an error path, **ask** — don't paper over it.

---

## Project-specific tips

<!-- TODO: project owner — Rust-specific patterns observed in this codebase. -->
