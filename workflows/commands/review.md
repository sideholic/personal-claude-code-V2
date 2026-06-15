---
description: Run a codex adversarial review on an existing PR or branch (re-review / second opinion).
argument-hint: <PR# or branch>
---

Run `adversarial-review-bridge` on: $ARGUMENTS

Dispatch `/codex:adversarial-review`, judge findings (BLOCKING/SHOULD/NIT/OUT-OF-SCOPE → verdict), write the `RR`. Do **not** merge, push, or auto-rescue — report only.
