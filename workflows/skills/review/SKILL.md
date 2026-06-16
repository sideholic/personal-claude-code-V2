---
name: review
description: Code-reviewer skill (The Roastmaster) — dispatch codex adversarial review on a PR, judge the findings, return a verdict. codex is the SOLE reviewer; never walks the diff itself.
---

# Review (The Roastmaster)

codex is the sole reviewer — **Claude never reviews Claude's own diff.** Per PR per round, pick the **mode by ticket weight**, run it (await in-lane), then JUDGE only:
- **general** — `complexity: small` or `medium` → `/codex:review` (built-in reviewer). See `general-review-bridge`.
- **adversarial** — `complexity: large` only → `/codex:adversarial-review`. See `adversarial-review-bridge`. (Auto-large triggers — auth · DB migration · new domain · external — already force `large`, so they land here automatically.)

Classify findings BLOCKING/SHOULD/NIT/OUT-OF-SCOPE → verdict APPROVE/COMMENT/BLOCKING. Uphold/downgrade/escalate codex calls.
On the **2nd consecutive BLOCKING round**, stop and hand the call to Technoking — do NOT auto-loop to round 3. King picks: trivial-fix → round 3 (still BLOCKING → escalate) · `pattern_stuck` (same BLOCKING) → rescue · default → restart from design (large → Design Stop only). See `orchestration-guide`. Write `RR-T-NNNN-R` (record mode + round).

Emit `review.round` (actor `skill:review`). **Never edit code.**
