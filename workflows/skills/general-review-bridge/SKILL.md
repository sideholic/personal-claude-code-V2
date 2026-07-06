---
name: general-review-bridge
description: How to run the general reviewer subagent (a single-pass Claude Opus review at max effort) for light tickets. Lighter sibling of adversarial-review-bridge — same independent-subagent reviewer, same judge-only, same rounds/rescue/failure mechanics, only the review depth differs. Use when the review skill picks general mode (small ticket, no auto-large trigger).
---

# General review bridge

The reviewer is the same **independent reviewer subagent** as `adversarial-review-bridge` — a separate Claude instance (`model: opus`, `effort: 'max'`) that Claude-the-implementer never is. This is the *general* (single-pass, line-level) review for light work; the *adversarial* pass (`adversarial-review-bridge`) additionally challenges design/approach and reaches for cross-unit breakage, and is reserved for heavier/risky tickets. The `review` skill picks the mode.

## Mode selection (the review skill decides)
- **general** (this skill) — `complexity: small` or `medium`.
- **adversarial** (`adversarial-review-bridge`) — `complexity: large` only. Every auto-large trigger (auth/permission · DB schema migration · new domain · external payment/legal) already forces `large`, so it lands in adversarial automatically.

Either way: every PR gets exactly one review per round, and the king-only `--squash` merge gate is unchanged.

## Invoke (per PR, per round)
Same **Workflow `agent()` primitive** as adversarial — `{ model: 'opus', effort: 'max', schema }`, run from the PR's worktree (`<base>` = PR base, e.g. `develop`). Per-agent max effort is honored **only** through `agent()`; the plain Agent tool has no `effort` param (see `adversarial-review-bridge` for why the review step is always wrapped in a Workflow lane). The only difference from adversarial is the prompt: a **focused, single-pass** review that finds concrete defects but does not re-litigate the design. Prompt skeleton:
```
You are an independent code reviewer (Opus, max effort). You did NOT write this
code. Review the PR diff (git diff <base>...HEAD, run from the worktree) for
correctness bugs, edge cases, and stack house-rule violations. Focused single
pass — flag concrete defects; do not redesign. Return the structured findings
object: verdict / summary / findings[] / confidence.
```

## Everything else = adversarial-review-bridge
Judging (BLOCKING/SHOULD/NIT/OUT-OF-SCOPE → APPROVE/COMMENT/BLOCKING, uphold/downgrade/escalate), `RR-T-NNNN-R` write, the BLOCKING-round decision (2nd consecutive BLOCKING → king's call: round 3 / rescue / restart from design), reviewer-failure handling (retry once → lane-only pause, never merge without a completed review), and auto-rescue (`error_2x` / `pattern_stuck`) are **identical** — see `adversarial-review-bridge`. The only difference here is review depth (single-pass general vs design-challenging adversarial).
