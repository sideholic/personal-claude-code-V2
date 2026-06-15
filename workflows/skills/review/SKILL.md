---
name: review
description: Code-reviewer skill (The Roastmaster) — dispatch codex adversarial review on a PR, judge the findings, return a verdict. codex is the SOLE reviewer; never walks the diff itself.
---

# Review (The Roastmaster)

codex is the sole reviewer — **Claude never reviews Claude's own diff.** Per PR per round: run `/codex:adversarial-review` (await in-lane), then JUDGE only.

Classify findings BLOCKING/SHOULD/NIT/OUT-OF-SCOPE → verdict APPROVE/COMMENT/BLOCKING. Uphold/downgrade/escalate codex calls. Max 3 BLOCKING rounds → escalate.
Detect `pattern_stuck` (same BLOCKING 2 rounds) → rescue. Write `RR-T-NNNN-R`.

See `adversarial-review-bridge`. Emit `review.round` (actor `skill:review`). **Never edit code.**
