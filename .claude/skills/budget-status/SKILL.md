---
name: budget-status
description: Report daily LLM token budget — today's consumption per tier (Haiku/Sonnet/Opus), the configured cap, percentage used, time until UTC reset, per-source breakdown, and whether the cron kill flag is set. Run when asked about LLM cost / budget / token consumption / how much spent today, when about to fire an LLM-bearing slash, or when the operator asks if it is safe to run another costly job. Read-only ($0, no LLM calls), reads var/budget/today.json + var/cron.killed flag.
---

Report harness LLM-cost status: today's token consumption per tier (Haiku / Sonnet / Opus), the daily cap, and whether the cron kill flag is set.

**Storage contract**: budget tracking lives at `var/budget/today.json` (gitignored). Schema (when wired):

```json
{
  "date_utc": "2026-05-05",
  "cap_tokens": 5000000,
  "consumed": {
    "haiku":  { "input": 0, "output": 0 },
    "sonnet": { "input": 0, "output": 0 },
    "opus":   { "input": 0, "output": 0 }
  },
  "by_source": {
    "C1_log_scan": 0,
    "C2_docs_audit": 0,
    "user_fix_ticket": 0
  },
  "reset_at_utc": "2026-05-06T00:00:00Z"
}
```

**When the user invokes `/budget-status`:**

1. Check whether the budget store exists:
   ```bash
   ls -la var/budget/today.json 2>/dev/null
   ```

2. **If absent:**
   Report:
   - "Budget store not initialized at `var/budget/today.json`."
   - "No LLM-cost-incurring cron jobs are currently active."
   - "Manual `/audit-*` and `/review-*` invocations are not currently metered — usage cap relies on operator awareness."
   - "Schema target: see body of this skill for the planned format."

3. **If present:** parse and report:
   - Today's consumed tokens per tier (Haiku/Sonnet/Opus, input+output split).
   - Daily cap and percentage used.
   - Time until reset (UTC midnight by default).
   - Per-source breakdown if available.
   - Whether a circuit-breaker file is present (`[ -f var/cron.killed ]`) — if so, prominently flag it.

4. **Threshold warnings** (when the budget store exists):
   - If consumed ≥ 80% of cap → warn user; suggest the consuming repo's circuit-breaker slash (e.g., a `/kill-cron`-style command) if any cron is still running.
   - If consumed ≥ 100% of cap → state that cron jobs should self-disable per the cost-discipline principle in `docs/harness/principles.md`.

**This skill never spends LLM tokens on its own**. All reasoning here is reading files and arithmetic — no external calls.
