---
type: SPEC
status: draft
owner: <author@example.com>
last-reviewed: 2026-05-06
---

# CI workflow SPEC

**Scope:** the contract `.github/workflows/ci.yml` satisfies. This SPEC codifies the conventions the active workflow already complies with.

For the architectural role of CI (Layer 2 of the layered enforcement model — "heavier deterministic checks pre-commit defers"), see [`../../architecture.md`](../../architecture.md) §3.

## 1. Workflow structure

**Rust + Python preset.** The job-name and path-filter examples below describe one concrete instance. The binding contract is the *layering* (changes → lint/test/build per language, security always, hook-replay always), not the specific job names. Replace per your stack.

The CI workflow runs on every `pull_request` and `push` to `main`. Job topology:

```
changes (detect what kinds of files changed via dorny/paths-filter@v3)
  ├─ rust-lint   (only if rust-touched OR ci_self-touched)
  ├─ rust-test   (only if rust-touched OR ci_self-touched)
  ├─ rust-build  (only if rust-touched OR ci_self-touched)
  ├─ python-lint (only if python-touched OR ci_self-touched)
  ├─ python-test (only if python-touched OR ci_self-touched)
  ├─ security    (always — cargo-audit + gitleaks)
  ├─ hook-replay (always — defense-in-depth replay of H2/H3 against changed files)
  └─ gate-health (always — pre-merge gate component verification per the subscription-only LLM-gate decision; ADR not in this portfolio cut)
```

Reference: `.github/workflows/ci.yml` (consuming repo).

## 2. Path-detection patterns

Language-specific jobs early-exit on docs-only PRs to save runner minutes. Detection via `dorny/paths-filter@v3` in the `changes` job:

| Filter | Triggers when changes touch |
|---|---|
| `rust` | `**/*.rs`, `**/Cargo.toml`, `**/Cargo.lock`, `**/rustfmt.toml`, `**/rust-toolchain*` |
| `python` | `**/*.py`, `pyproject.toml`, `requirements.txt`, `setup.py` |
| `ci_self` | `.github/workflows/**` (workflow-edit triggers all language jobs as a safety net) |

Conditional execution: every Rust / Python job has `if: needs.changes.outputs.<lang> == 'true' || needs.changes.outputs.ci_self == 'true'`. Workflow-self changes (`ci_self`) trigger the language jobs so a malformed workflow edit cannot silently slip past — the language jobs re-run and surface any breakage.

There is no `docs` filter and no `config` filter. Doc-only PRs (only `docs/**` or `**/*.md` touched, no Rust / Python / workflow changes) skip language-specific jobs entirely; only `security`, `hook-replay`, and `gate-health` run.

## 3. Hook replay (defense-in-depth)

Layer 1 (PreToolUse hooks) catches violations at write time. Layer 2 (CI) re-runs the deterministic hooks against the PR diff as defense-in-depth:

The hook-replay job runs the same scripts CI uses for PreToolUse, against the diff's changed files. If a deterministic `.claude/hooks/*.sh` would have blocked at write time, CI fails.

Future hooks added under `.claude/hooks/` should consider whether CI replay is worth wiring — only deterministic, fast (<5s) hooks are CI-replay candidates. Skill-shaped or session-state-shaped hooks (e.g., `session-start-meta-index`) are not CI-replayable.

### 3.1 Pre-merge gate health (gate-health job)

Distinct from hook-replay (defense-in-depth on file content). The `gate-health` job verifies that the **pre-merge gate's components** (per the subscription-only LLM-gate ADR) remain intact:

| Step | Purpose |
|---|---|
| `bash .claude/hooks/test_pr-create-gate.sh` | Regression test on the `pr-create-gate.sh` matcher and verdict logic — 14 named cases + 1 inline bypass-log-written assertion (15 PASS opportunities total). Catches regex bugs, missing bypass log, stale-sha logic. |

Additional gate-health steps are added as new pre-merge gates land. The consuming repo extends this section when it wires SessionStart-side gates of its own (e.g., a gate-health hook that verifies all required components are present at session start).

## 4. Concurrency control

- **Workflow concurrency**: `concurrency: { group: ci-${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }`. A new push to the same branch cancels in-flight CI for that branch — saves runner minutes when a PR receives multiple pushes in quick succession.
- **Job parallelism**: language-conditional jobs (rust-lint / rust-test / rust-build / python-lint / python-test) run in parallel after `changes` completes. The `security`, `hook-replay`, and `gate-health` jobs run independently of the language jobs (no `needs:` dependency on `changes`).

## 5. Permissions

`permissions:` block at workflow scope:
- `contents: read` — needed for `actions/checkout`.
- `pull-requests: read` — needed for `gitleaks-action` and `dorny/paths-filter` when scoped to PR diff.

No `write` scopes. CI does not mutate repo state.

## 6. Secret scanning

`gitleaks-action@v2` runs in the `security` job on every PR. **It is a hard gate**: when secrets are detected, the action exits non-zero and the job fails, which blocks merge. There is no "warn-only" mode wired here. The `secret-guard.sh` hook (Layer 1) is the first defense at write time; gitleaks is the CI-side (Layer 2) defense-in-depth.

`cargo-audit` runs as a prebuilt binary via `taiki-e/install-action@v2 with: tool: cargo-audit` to avoid 4-minute `cargo install` warmups. Reference: PR #18.

## 7. Adding a new check

Procedure:

1. Determine the layer (per [`../../architecture.md`](../../architecture.md) §3):
   - **Layer 1 (PreToolUse hook)** if the check is fast (<5s) and runs at write time per file.
   - **Layer 2 (CI)** if the check is slower (≥5s) or needs cross-file context.
2. If Layer 2:
   - Add a new job to `ci.yml`.
   - Gate it with the appropriate `paths-filter` output if language-specific.
   - Document permissions if the check needs more than `contents: read`.
   - Add a row to §1 workflow structure.
3. If Layer 1 + the check is also useful as defense-in-depth in CI, wire a hook-replay row in §3.

## 8. Failure-mode discipline

Per [`../../principles.md`](../../principles.md) §9:

- **Failure signature**: a CI check that should have caught the violation passes, OR a check that should not block a docs-only PR runs anyway.
- **Detection method**: PR review notices the green-but-wrong CI; the docs-auditor cron (C2) flags drift between this SPEC and `ci.yml` on the next run.
- **Mitigation**: revert the offending commit; add a regression test under `scripts/cron/` or a smoke test in `ci.yml` itself.

## 9. References

- Workflow: `.github/workflows/ci.yml` (consuming repo)
- Architecture role: [`../../architecture.md`](../../architecture.md) §1, §3
- Hooks SPEC (Layer 2 contract): [`../hooks/SPEC.md`](../hooks/SPEC.md)
- Principles: [`../../principles.md`](../../principles.md) §9 failure-mode discipline
