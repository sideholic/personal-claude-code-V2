---
name: rescue
description: One-shot rescue skill — when a build lane fails twice (error_2x) or a reviewer is pattern_stuck, dispatch codex rescue, validate the patch, and re-review. At most once per ticket per signature; never rescue a rescue.
---

# Rescue

Invoked by a lane on `error_2x` / `pattern_stuck` (see `adversarial-review-bridge`). Goal: unstick the lane without the user.

1. **De-dup**: skip if a rescue already ran for this ticket + `error_signature`.
2. **Dispatch** `/codex:rescue` (error_signature in the prompt) on a `rescue/T-NNNN` branch.
3. **Validate** the returned patch: open an `RV-NNNN` validation ticket (no new feature work), run the failing AC tests / build.
4. PASS → re-review (codex) → continue the lane. FAIL → **escalate to user** (never auto-retry a rescue).

Record a `RESCUE-<ts>` artifact. Emit `rescue.triggered` / `rescue.resolved` / `rescue.failed`.
