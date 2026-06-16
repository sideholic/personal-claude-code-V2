---
name: general-review-bridge
description: How to invoke the general codex review (`/codex:review`, the built-in reviewer) for light tickets. Lighter sibling of adversarial-review-bridge — same judge-only, same rounds/rescue/codex-unavailable mechanics, only the subcommand differs. Use when the review skill picks general mode (small ticket, no auto-large trigger).
---

# General review bridge

codex is the **sole** reviewer — Claude never walks its own diff. This is the *general* (built-in reviewer) pass for light work; the *adversarial* pass (`adversarial-review-bridge`) challenges design/approach and is reserved for heavier/risky tickets. The `review` skill picks the mode.

## Mode selection (the review skill decides)
- **general** (this skill) — `complexity: small` or `medium`.
- **adversarial** (`adversarial-review-bridge`) — `complexity: large` only. Every auto-large trigger (auth/permission · DB schema migration · new domain · external payment/legal) already forces `large`, so it lands in adversarial automatically.

Either way: every PR gets exactly one codex review per round, and the king-only `--squash` merge gate is unchanged.

## Invoke (per PR, per round)
Run from the PR's worktree; `<base>` = PR base (e.g. `develop`). **Always pass `--model gpt-5.5`** — same ChatGPT-account-mode constraint as adversarial (the runtime default `*-codex` models 400-reject):
```bash
CODEX_ROOT="$(ls -d ~/.claude/plugins/cache/openai-codex/codex/*/ | tail -1)"
node "$CODEX_ROOT/scripts/codex-companion.mjs" review "--base <base> --model gpt-5.5 --wait"
```
`--wait` runs synchronously and prints the full structured review to stdout; detach via Bash `run_in_background: true` so the king isn't blocked (the task output file holds the verbatim review when it finishes). The native reviewer takes `--base`/`--scope` only — **no focus text, no staged/unstaged scope** (need focused or custom framing → use adversarial).

## Everything else = adversarial-review-bridge
Judging (BLOCKING/SHOULD/NIT/OUT-OF-SCOPE → APPROVE/COMMENT/BLOCKING, uphold/downgrade/escalate), `RR-T-NNNN-R` write, the BLOCKING-round decision (2nd consecutive BLOCKING → king's call: round 3 / rescue / restart from design), codex-unavailable (lane-only pause, never merge without a completed codex review), and auto-rescue (`error_2x` / `pattern_stuck`) are **identical** — see `adversarial-review-bridge`. The only differences here are the subcommand (`review` vs `adversarial-review`) and the lack of focus text.
