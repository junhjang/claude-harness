---
name: python-failure-modes
description: 'Rules for writing or editing Python code. Forbids bare "# type: ignore", "except Exception: pass", mutable default args, time.sleep in async code, Any past data boundaries. Auto-loads on .py file edits.'
paths: ["**/*.py"]
user-invocable: false
---

Apply these rules when touching `.py` files. Full rationale: [`.claude/rules/python-llm-failures.md`](../../rules/python-llm-failures.md).

1. **No bare `# type: ignore`.** Use `# type: ignore[specific-code]` with a `# reason:` comment.
2. **No `except Exception: pass` or bare `except:`.** Catch the specific exception you handle, or escalate. Top-level supervisors log and re-raise — never silent.
3. **No global warning suppression.** Narrow only — `# noqa: <code>` with comment, or `filterwarnings(category=, module=)`.
4. **No `Any` past boundaries.** Use `TypedDict`, `Protocol`, or `dataclass`. `Any` is acceptable only at unstructured-data ingress (raw JSON before parsing).
5. **No `assert` for runtime validation in prod code.** Use `if … raise ValueError(...)`. `assert` disappears under `-O`.
6. **No mutable default args** (`def f(xs=[]): ...`). Use `None` sentinel and create inside the function.
7. **No `time.sleep` to wait for async/external state.** Use `await asyncio.sleep`, real sync primitives, or deterministic mocks in tests.

If tempted to break any rule, stop and ask the user.
