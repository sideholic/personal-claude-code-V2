---
name: adversarial-review-bridge
description: How to run the adversarial reviewer subagent (an independent Claude Opus instance at max effort) and the auto-rescue pipeline. Use whenever the review skill reviews a PR or a lane triggers rescue. The reviewer is a separate subagent; a transient agent failure pauses only that lane.
---

# Adversarial review bridge

The reviewer is an **independent reviewer subagent** — a separate Claude instance spun with `model: opus` at **`effort: 'max'`**, never the implementing agent. Independence comes from **context isolation** (fresh context, no access to the implementer's reasoning) and **adversarial framing** (prompted to break the diff); the max effort tier makes it review deeper than the xhigh implementer. Integration is synchronous **inside the build lane** (no daemon, no polling, no inbox).

## ⚠ Spawn via the Workflow `agent()` primitive — required for max effort
Per-agent `effort` is honored **only** through the Workflow `agent()` primitive (`opts.effort`). The plain **Agent tool has no `effort` parameter** — an Agent-tool subagent inherits the session effort, which is *not* guaranteed to be max. So the reviewer must be spawned from **inside a Workflow lane**:
```js
await agent(REVIEW_PROMPT, { model: 'opus', effort: 'max', schema: FINDINGS_SCHEMA, label: `review:${ticket}` })
```
(A single-unit `/task` lane that would otherwise be a bare Agent-tool subagent still wraps the review step in a one-agent Workflow, or runs with the session already at max effort. Never rely on a plain Agent-tool dispatch to deliver max-effort review.)

## Review (per PR, per round)
1. Spawn the reviewer subagent and **await the result in-lane** (the lane is already a background workflow, so the king isn't blocked). In-lane timeout guard (default 30 min) → escalation, not a parked worktree.
   - `agent({ model: 'opus', effort: 'max', schema })` run from the PR's worktree; the validated findings object comes back directly.
   - Prompt template (`<base>` = PR base, e.g. `develop`):
     ```
     You are an independent adversarial code reviewer running as an Opus subagent at
     MAX reasoning effort. You did NOT write this code — your job is to break it.

     Read the diff first:  git diff <base>...HEAD   (run from the worktree)
     Read surrounding source for context as needed.

     Review for: correctness bugs · concurrency / transaction hazards · null / edge
     cases · security · and every stack house rule (see the stack skills + coding-principles).
     Challenge the DESIGN and APPROACH, not just line-level defects. Look past the diff
     for cross-unit breakage the change arms (e.g. now-invalid callers elsewhere).

     Return the structured findings object (schema-enforced):
     verdict <APPROVE|COMMENT|BLOCKING> · summary · findings[] (each: severity + file:line
     + defect + concrete failure scenario) · confidence <high|medium|low>.
     ```
2. The `review` skill JUDGES only: classify findings BLOCKING/SHOULD/NIT/OUT-OF-SCOPE → verdict APPROVE/COMMENT/BLOCKING. Uphold/downgrade/escalate the reviewer's calls.
3. Write `RR-T-NNNN-R` (round R, immutable). Round 1 BLOCKING → fix → re-review. **At the 2nd consecutive BLOCKING, defer to Technoking** (never auto-loop to round 3): trivial-fix → round 3 (still BLOCKING → escalate) · `pattern_stuck` → rescue · default → restart from design (large → Design Stop only). See `orchestration-guide`.

## Reviewer subagent fails
A transient agent/API error is not a global halt (G0). Retry once; on repeated failure only the affected lane pauses and notifies the king — the main conversation and other lanes continue. **Never merge without a completed review.**

## Auto-rescue (no user approval)
Triggers: `error_2x` (the lane's own test runner sees the same failure twice) or `pattern_stuck` (same BLOCKING 2 rounds). The lane detects failure directly — no SHA-1 inbox protocol.
- `error_signature` = first 8 hex of `sha1(<error_class>:<failing_component>)` (component = bean/test/module, not file:line) — used only to de-dup.
- Run the `rescue` skill **≤1 per ticket per signature**, never rescue-of-a-rescue. Failure → escalate to user.

## Pipeline
review → (BLOCKING) fix → re-review … **2nd consecutive BLOCKING → king's call**: round 3 (→ escalate) / `rescue` (error_2x · pattern_stuck → validation via RV ticket + rescue branch → re-review) / restart from design (large → Design Stop only). PASS → continue; FAIL → user.
