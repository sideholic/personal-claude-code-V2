---
description: Cancel in-progress tickets, stop in-flight background work, and clean up worktrees.
argument-hint: "[T-NNNN | --all]"
---

Cancel the target ticket(s) ($ARGUMENTS): transition to cancelled via `bin/ticket-transition.sh T-NNNN --to cancelled` (moves to `tickets/cancelled/`, injects `done`, emits `ticket.cancelled`), stop the matching background workflow/subagent (`TaskStop`), remove its worktree. v2 has no panes/sentinels to kill. Report what was aborted.
