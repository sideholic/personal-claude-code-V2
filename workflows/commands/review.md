---
description: Run an adversarial reviewer subagent on an existing PR or branch (re-review / second opinion).
argument-hint: <PR# or branch>
---

Run `adversarial-review-bridge` on: $ARGUMENTS

Spawn the independent reviewer subagent (Workflow `agent({ model: 'opus', effort: 'max' })`, adversarial prompt), judge findings (BLOCKING/SHOULD/NIT/OUT-OF-SCOPE → verdict), write the `RR`. Do **not** merge, push, or auto-rescue — report only.
