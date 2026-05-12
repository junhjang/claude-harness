# Python LLM Failure Modes

Tooling (ruff, mypy, pytest) catches code issues. These rules cover **LLM behavior patterns the tools can't catch** — the tendency to silence tools rather than fix the underlying problem.

If you're tempted to do any of the below, stop and ask instead.

---

## 1. Don't silence the type checker with `# type: ignore`

- Fix the underlying type. If genuinely necessary (third-party stub gap, dynamic dispatch), include a specific code and a reason:

```python
# reason: third-party stub returns Any; runtime type is dict[str, Decimal]
result: dict[str, Decimal] = client.fetch_record(key)  # type: ignore[assignment]
```

- Bare `# type: ignore` (no specific code) → not acceptable. No comment → not acceptable.

## 2. Don't catch `Exception` to make code "pass"

- Bare `except:` and `except Exception: pass` hide real failures. A swallowed exception around a side-effecting call is a correctness failure waiting to happen.
- Acceptable patterns:
  - Catch the **specific** exception class you know how to handle (`except httpx.NetworkError`, `except KeyError`).
  - Catch broadly only at top-level supervisors that **log and re-raise or escalate** — never silent.
  - Re-raise via `raise` or `raise NewError(...) from e`.
- If you don't know which exception to catch, **ask**.

## 3. Don't suppress warnings to make code "clean"

- `warnings.filterwarnings("ignore")` and `# noqa` (without a specific code) hide signals. Today's deprecation warning is next quarter's breaking change.
- Narrow suppression only:
  - `# noqa: E501` (specific code) with a comment.
  - `warnings.filterwarnings("ignore", category=SpecificWarning, module="specific_lib")`.

## 4. Don't use `Any` to escape typing

`Any` disables checking entirely — Python's `unsafe`. Before reaching for it:
1. Is there a `TypedDict`, `Protocol`, or `dataclass` that fits?
2. Can you use `object` (forces explicit narrowing)?
3. Third-party API gap? Write a `Protocol` shim.

`Any` is acceptable at boundaries where data is genuinely unstructured (raw JSON before parsing). Past that boundary, it's a smell.

## 5. Don't use `assert` for runtime validation in production code

- `assert` is removed under `-O`. Runtime validation needs explicit raises:

```python
# wrong — disappears under -O
assert count > 0, "count must be positive"

# right
if count <= 0:
    raise ValueError(f"count must be positive, got {count}")
```

- `assert` is fine in tests and for invariants the type system already guarantees.

## 6. Don't mutate default arguments

- `def f(xs: list = []):` — the list is shared across calls. Class of bug that has caused real outages.
- Use `None` sentinel and create inside:

```python
def append_record(records: list[Record] | None = None) -> list[Record]:
    records = records if records is not None else []
```

## 7. Don't use `time.sleep` to wait for async or external state

- `time.sleep` in async code blocks the event loop. In tests, masks race conditions.
- Use `await asyncio.sleep`, real synchronization primitives, or polling with timeout. In tests, prefer deterministic clocks/mocks over wall-clock waits.

---

## Project-specific tips

<!-- TODO: project owner — Python-specific patterns observed in this codebase. -->
