---
description: Archive stale tickets and reviews; remove orphan worktrees; delete merged local/remote branches; reclaim disk.
---

Run for every repo the project owns (monofolder → each subrepo; single-repo project → itself).

**Tickets** — move archive-eligible `cancelled`/old tickets to `archive/{YYYY-MM}/` (`done/` is permanent). See `ticket-protocol`.

**Worktrees** — remove `.worktrees/` entries with no open ticket, then `git worktree prune`.

**Branches** — delete only what is *provably* merged. Never touch `main`, `develop`, the checked-out branch, or a branch whose ticket is still open.

1. `git fetch --prune origin` — drops remote-tracking refs whose remote branch is gone (local bookkeeping only, always safe).
2. **Local**: take `git branch --merged <base>` (base = the project's PR base, e.g. `develop`), subtract the protected set, delete with `git branch -d`. **Never `-D`** — if `-d` refuses, the branch has unmerged commits: leave it and report it.
3. **Remote**: for each surviving `origin/<feature-branch>`, require merge proof — `gh pr list --head <branch> --state merged` returns a PR — before `git push origin --delete <branch>`. No merge proof → leave it, even if it looks abandoned.

**Report** — what was archived / removed / deleted, and what was **skipped with the reason** (unmerged, ticket still open, no merged PR found). List the branch deletions before performing them so the set is visible in the transcript.
