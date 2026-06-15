---
description: Cancel in-progress tickets, stop in-flight background work, and clean up worktrees.
argument-hint: "[T-NNNN | --all]"
---

Cancel the target ticket(s) ($ARGUMENTS): move to `tickets/cancelled/`, stop the matching background workflow/subagent (`TaskStop`), remove its worktree. v2 has no panes/sentinels to kill. Emit `ticket.cancelled`. Report what was aborted.
