#!/usr/bin/env bash
# SessionStart hook: print a one-line pointer to the available skills so a new
# session knows what discipline skills exist before doing any work.
#
# Pure deterministic — zero LLM, short output. Bootstrap pattern adapted from
# obra/superpowers (hooks/run-hook.cmd session-start), simplified for single-platform.
#
# Why this exists: description-matched skills are individually unreliable to
# auto-trigger. A single bootstrap pointer collapses that to one read at session start.
set -uo pipefail

cat <<'EOF'
[harness] Available discipline skills under .claude/skills/: rust-failure-modes, python-failure-modes, error-taxonomy, configuration, verification-before-completion, doc-pattern. Slash skills: /review-doc, /review-changes, /audit-docs, /audit-docs-semantic, /audit-harness-coverage, /grill-me, /grill-with-docs, /new-doc, /budget-status, /zoom-out, /caveman, /critic-review. Read SKILL.md for any skill before relying on its guarantees.
EOF

exit 0
