---
name: review
description: Code-reviewer skill (The Roastmaster) — dispatch an independent reviewer subagent (Claude Opus at max effort) on a PR, judge the findings, return a verdict. Picks the review MODE per ticket (general = small/medium default · adversarial = large or a named risk axis) — never adversarial by default. The reviewer is a separate subagent; this skill judges only and never walks the diff itself.
---

# Review (The Roastmaster)

The reviewer is an **independent reviewer subagent** — a separate Claude instance (`model: opus`, `effort: 'max'`) with a fresh context and a mode-specific prompt (general or adversarial), **never the implementing agent.** Independence = context isolation + independent framing; max effort makes it review deeper than the xhigh implementer. Spawn it via the **Workflow `agent()` primitive** — per-agent max effort is honored only there (the plain Agent tool has no `effort` param); see `adversarial-review-bridge`. When the PR enters review (round opens) transition in_progress→in_review (or in_review re-entry on a new round): `bin/ticket-transition.sh T-NNNN --to in_review` (bumps `review_rounds`; the emitted `ticket.review` carries the round). Per PR per round, pick the **mode by ticket weight**, run it (await in-lane), then JUDGE only:
- **general** (DEFAULT) — `complexity: small` or `medium` → single-pass, line-level reviewer subagent; concrete defects + house-rule violations only, no design re-litigation. See `general-review-bridge`.
- **adversarial** — `complexity: large` → design-challenging reviewer subagent that also hunts cross-unit breakage. See `adversarial-review-bridge`. (Auto-large triggers — auth · DB migration · new domain · external — already force `large`, so they land here automatically.)

**Mode discipline (2026-08-31).** Both modes run the same subagent tier (opus · max); the difference is prompt scope, and adversarial costs **2–3× wall-clock** (the reviewer reads siblings, neighbouring source, and the other repo's contract). Never run adversarial on every PR. Read the ticket's `complexity` before dispatch and start from the table above. Technoking may **escalate a small/medium ticket to adversarial** only on a named risk axis, and must write that reason into the RR:
1. an irreversible data-mutation path (writes to/deletes from a shared original — e.g. a customer's live consultation values — that no UI can undo);
2. a locking / transaction / concurrency change (pessimistic-lock order, lock-then-reread, outer-transaction boundary);
3. the trailing PR of two parallel lanes that touched the same file (semantic-conflict risk after rebase);
4. round 2+ when a general round-1 produced a design-level BLOCKING.
Downgrading a `large` ticket to general is not allowed. Every re-review round after a fix is **delta-only focused** (verify the gate items closed + no new regression) regardless of mode — never a full second pass.

Classify findings BLOCKING/SHOULD/NIT/OUT-OF-SCOPE → verdict APPROVE/COMMENT/BLOCKING. Uphold/downgrade/escalate the reviewer's calls.
On the **2nd consecutive BLOCKING round**, stop and hand the call to Technoking — do NOT auto-loop to round 3. King picks: trivial-fix → round 3 (still BLOCKING → escalate) · `pattern_stuck` (same BLOCKING) → rescue · default → restart from design (large → Design Stop only). See `orchestration-guide`. Write `RR-T-NNNN-R` with frontmatter `mode: general|adversarial` (+ the escalation reason when a small/medium ticket was reviewed adversarially) and the round.

Emit `review.round` (actor `skill:review`). **Never edit code.**
