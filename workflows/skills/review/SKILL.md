---
name: review
description: Code-reviewer skill (The Roastmaster) — dispatch an independent reviewer subagent (Claude Opus at max effort) on a PR, judge the findings, return a verdict. The reviewer is a separate subagent; this skill judges only and never walks the diff itself.
---

# Review (The Roastmaster)

The reviewer is an **independent reviewer subagent** — a separate Claude instance (`model: opus`, `effort: 'max'`) with a fresh context and an adversarial prompt, **never the implementing agent.** Independence = context isolation + adversarial framing; max effort makes it review deeper than the xhigh implementer. Spawn it via the **Workflow `agent()` primitive** — per-agent max effort is honored only there (the plain Agent tool has no `effort` param); see `adversarial-review-bridge`. When the PR enters review (round opens) transition in_progress→in_review (or in_review re-entry on a new round): `bin/ticket-transition.sh T-NNNN --to in_review` (bumps `review_rounds`; the emitted `ticket.review` carries the round). Per PR per round, pick the **mode by ticket weight**, run it (await in-lane), then JUDGE only:
- **general** — `complexity: small` or `medium` → single-pass reviewer subagent. See `general-review-bridge`.
- **adversarial** — `complexity: large` only → design-challenging reviewer subagent. See `adversarial-review-bridge`. (Auto-large triggers — auth · DB migration · new domain · external — already force `large`, so they land here automatically.)

Classify findings BLOCKING/SHOULD/NIT/OUT-OF-SCOPE → verdict APPROVE/COMMENT/BLOCKING. Uphold/downgrade/escalate the reviewer's calls.
On the **2nd consecutive BLOCKING round**, stop and hand the call to Technoking — do NOT auto-loop to round 3. King picks: trivial-fix → round 3 (still BLOCKING → escalate) · `pattern_stuck` (same BLOCKING) → rescue · default → restart from design (large → Design Stop only). See `orchestration-guide`. Write `RR-T-NNNN-R` (record mode + round).

Emit `review.round` (actor `skill:review`). **Never edit code.**
