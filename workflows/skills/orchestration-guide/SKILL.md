---
name: orchestration-guide
description: Master playbook for Technoking — the 6-phase lifecycle, complexity verdict, Stop policy, non-blocking background dispatch, concurrency planner, and escalation rules. Use whenever Technoking accepts a request, dispatches work, runs the review/rescue loop, or merges.
---

# Orchestration guide

Technoking runs in the MAIN loop and **never blocks**: classify → decompose → dispatch (fire-and-forget to background) → relay → converse. All real work runs in background workflows/subagents (all opus). Companions: `ticket-protocol`, `git-flow`, `adversarial-review-bridge`, `general-review-bridge`, `coding-principles`, `testing-principles`, `documentation-criteria`.

## Lifecycle (6 phases)
1. **classify** (king, resident) — intake + complexity verdict. Mint umbrella `T-NNNN`. Route: small→/task; medium/large→spec.
2. **spec** [BG] — prd → design pipeline. Stop: large = PRD-approval **then** Design-approval (two checkpoints); medium = merged once; small = skip.
3. **decompose** (king) — split approved design into units; partition by `files_in_scope[]` → **max non-overlapping set**; sequence overlaps via `depends_on[]`. Stop: large = batch approval.
4. **build** [BG, parallel] — per non-overlapping unit, one worktree + lane (claim transitions queued→in_progress via `bin/ticket-transition.sh`, keeping board + events in sync): `qa-pre`(fail-first RED) → impl(`backend`/`frontend`) → `review`(codex — general for small·medium, adversarial for large; awaited in-lane) + in-lane rescue. No stops.
5. **converge** [BG] — `qa-post` integration/E2E barrier after all lanes APPROVE (large default / medium per-AC / small skip; any auto-large trigger forces ON).
6. **merge** (king) — pre-merge checklist → Technoking-only `--squash` → in_review→done via `bin/ticket-transition.sh` (moves to `done/` + emits events, keeping board in sync), worktree removed, Korean report.

After the last approval (large = phase 3 / medium = phase 2), phases 4–6 are autonomous (user interrupt = implicit consent). **No merge-time Stop.**

## Complexity verdict
| verdict | criteria | 
|---|---|
| small | 1–2 files · single area · no DB/API/auth/external |
| medium | 3–5 files · small DB or 1–2 APIs · existing domain |
| large | 6+ files · BE+FE · large DB · new domain · external |

**auto-large triggers** (force large regardless): auth/permission · DB schema migration · new domain · external payment/legal. Re-evaluate every phase; mid-flight escalation inserts any missed Stop.

## Stop policy (B-pattern)
small = 0 · medium = 1 (phase 2 merged spec) · large = 3 (PRD, Design, batch). Never collapse large's PRD+Design into one (planning §3 invariant). Stop prompts in Korean: 추천 + 대안.

## Dispatch (G0 / G5)
- All skills/subagents run on **opus** at **xhigh** effort (uniform): the king launches at xhigh and background subagents inherit it (`config.yml.effort`). Non-blocking is structural (work → background), not from a lower king effort.
- Everything that does work = `run_in_background` (`Workflow` / `Agent` / Bash). King returns to the user instantly; completion/escalation arrive as notifications.
- Heavy dynamic `Workflow` **only when ≥2 non-overlapping units**. 1 unit or `/task` = single inline BG subagent (no Workflow ceremony).
- The one synchronous await (codex review) lives INSIDE a lane; the king launched that lane in the background, so the king never blocks.

## Escalation (always surface, any tier)
`requirements_change` · `architectural_change` · `untestable_ac` · review 3× BLOCKING · rescue validation fail · `codex_unavailable` (only that lane pauses; main convo + other lanes continue; never merge without a completed codex review). **Auto-rescue** (`error_2x` / `pattern_stuck`) fires WITHOUT user approval, ≤1 per ticket per signature, never rescue-of-a-rescue.

**BLOCKING-round decision** — at the **2nd consecutive BLOCKING round** the lane must NOT auto-loop to round 3; it defers to the king, who picks one: ⓐ **trivial-fix** → allow round 3 (still BLOCKING at round 3 → escalate); ⓑ **`pattern_stuck`** (same BLOCKING repeating) → auto-rescue (unchanged); ⓒ **default** (design/approach is wrong) → **restart from design** = re-enter phase 2 (spec). For `large`, the design-restart re-triggers the **Design Stop only** — PRD stays approved.

## /task (small shortcut)
classify → single inline lane (qa-pre → impl → codex review [general — small] + rescue) → merge. 0 stops. Review/rescue/merge gates still fire.
