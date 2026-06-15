---
name: adversarial-review-bridge
description: How to invoke codex adversarial review (the sole reviewer) and run the auto-rescue pipeline. Use whenever the review skill reviews a PR or a lane triggers rescue. codex is required; its absence pauses only that lane.
---

# Adversarial review bridge

codex is the **sole** code reviewer — Claude never walks its own diff. Integration is synchronous **inside the build lane** (no daemon, no polling, no inbox).

## Review (per PR, per round)
1. Run `/codex:adversarial-review` on the PR and **await the result in-lane** (the lane is already a background workflow, so the king isn't blocked). In-lane timeout guard (default 30 min) → escalation, not a parked worktree.
2. The `review` skill JUDGES only: classify findings BLOCKING/SHOULD/NIT/OUT-OF-SCOPE → verdict APPROVE/COMMENT/BLOCKING. Uphold/downgrade/escalate codex calls.
3. Write `RR-T-NNNN-R` (round R, immutable). BLOCKING → fix → re-review (max 3 rounds → escalate).

## codex unavailable
Not a global halt (G0). Only the affected lane pauses and notifies the king; the main conversation and other lanes continue. **Never merge without a completed codex review.**

## Auto-rescue (no user approval)
Triggers: `error_2x` (the lane's own test runner sees the same failure twice) or `pattern_stuck` (same BLOCKING 2 rounds). The lane detects failure directly — no SHA-1 inbox protocol.
- `error_signature` = first 8 hex of `sha1(<error_class>:<failing_component>)` (component = bean/test/module, not file:line) — used only to de-dup.
- Run the `rescue` skill **≤1 per ticket per signature**, never rescue-of-a-rescue. Failure → escalate to user.

## Pipeline
codex review → (BLOCKING) fix → re-review … OR (error_2x / pattern_stuck) → `rescue` skill → validation (RV ticket, rescue branch) → re-review. PASS → continue; FAIL → user.
