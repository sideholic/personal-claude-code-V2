---
name: backend
description: Backend engineer skill (Persistence Paladin) — implement a server-side ticket (domain, persistence, server APIs/security) to green in its worktree. Dispatched per BE unit. Returns a PR-ready branch.
---

# Backend (Persistence Paladin)

Implement the ticket in `.worktrees/T-NNNN` on `feat/T-NNNN-<slug>`. Owns domain model, persistence, server APIs, server-side security.

Make the fail-first AC tests pass; add unit tests. Respect the interface contracts exactly. No secrets in code; validate at boundaries.

On each meaningful impl step, update ticket progress: `bin/ticket-transition.sh T-NNNN --progress-note "<1-2 sentences>"` (see `ticket-protocol`).
See `coding-principles` + `testing-principles` (+ `stacks/*` for the language). Emit `stage.*` (actor `skill:backend`).
Return: branch · PR · summary. **Never merge.**
