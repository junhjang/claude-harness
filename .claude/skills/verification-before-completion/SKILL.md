---
name: verification-before-completion
description: 'Self-check before declaring "done" / "ready" / "ship it" on a change. Auto-loads on any code or config edit. User-invocable via /verify. Test-existence is one check among many; this skill enforces sufficiency.'
paths: ["**/*"]
---

Before saying "done" / "ready for review" / "ship it" on a change, run the verification checklist. Test-existence hooks enforce *that a test exists*; this skill enforces *that the test exercises the path that changed*.

## Steps

1. **Scope check** — list every subtree your diff touched (`git diff --name-only`).

2. **Per-change checklist** — for each touched area, verify:

   - **The change is covered by a test that exercises the new path** — not just compiles, not just an unrelated assertion in the same module.
   - **Error paths in the diff have at least one negative test** — happy path alone is insufficient when the change introduces new failure modes.
   - **State-mutating code** — if the change touches mutable state, list the invariants that must hold after the mutation and verify a test asserts each.
   - **External-boundary code** (parsers, deserializers, network ingress) — at least one round-trip or fixture-based test; if property-based, the seed is fixed and recorded.
   - **Performance-critical code** — allocation count unchanged (or the change is justified); no `unwrap()`/`expect()`/`panic!` introduced in non-test paths.
   - **Configuration** — schema validates at startup; new fields either fail loud on absence or have an explicit safe default.

3. **Test pass status** — list which tests ran and which subset relates to the change. "All green" alone is insufficient; identify the specific tests that exercise the modified path.

4. **Unverified items** — explicitly call out any item in step 2 that was NOT verified, with a one-line reason. "Skipped because already covered upstream" is acceptable; "didn't get to it" is not.

5. **Known-broken** — anything left in a known-broken state? Link to a follow-up issue.

Do NOT claim "done" if any item in steps 2–5 is missing.
