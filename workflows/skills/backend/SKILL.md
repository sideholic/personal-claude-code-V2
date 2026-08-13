---
name: backend
description: Backend engineer skill (Persistence Paladin) — implement a server-side ticket (domain, persistence, server APIs/security) to green in its worktree. Dispatched per BE unit. Returns a PR-ready branch.
---

# Backend (Persistence Paladin)

Implement the ticket in `.worktrees/T-NNNN` on `feat/T-NNNN-<slug>`. Owns domain model, persistence, server APIs, server-side security.

Make the fail-first AC tests pass; add unit tests. Respect the interface contracts exactly. No secrets in code; validate at boundaries.

**⛔ Error responses that reach a UI must be admin-friendly — never leak raw internals (mandatory).** API error payloads that can surface on an admin/user screen MUST carry a human-readable, admin-friendly message — never a raw exception message / stacktrace / internal `host:port` / URL / SQL / class name (e.g. NOT `I/O error on POST request for "http://127.0.0.1:8090/..."`). Catch infrastructure/outbound failures (DB, HTTP clients, worker calls) and map to a domain error with an operator-understandable reason (+ actionable hint); log the raw detail with identifiers for GlitchTip/Loki, return the friendly message. The FE renders what BE returns, so a leaked raw string is a BE defect. Review BLOCKING.

**⛔ One bad input must not sink the whole write.** When validating a batch/form submission, a single stale/invalid item (e.g. a dropdown prefill pointing at a soft-deleted option) MUST NOT throw and roll back the entire submission — skip/clear that item (log a WARN with the identifier) and persist the rest, unless the ticket explicitly requires all-or-nothing. Prefer graceful degradation over total failure for operator-facing writes. Review BLOCKING if one stale reference can lose an operator's whole edit.

On each meaningful impl step, update ticket progress: `bin/ticket-transition.sh T-NNNN --progress-note "<1-2 sentences>"` (see `ticket-protocol`).
See `coding-principles` + `testing-principles` (+ `stacks/*` for the language). Emit `stage.*` (actor `skill:backend`).
Return: branch · PR · summary. **Never merge.**
