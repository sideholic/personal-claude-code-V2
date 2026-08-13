---
name: frontend
description: Frontend engineer skill (Pixel Wizard) — implement a UI ticket (pages/components/state/data-fetching/design-system/a11y) to green in its worktree. Dispatched per FE unit. Returns a PR-ready branch.
---

# Frontend (Pixel Wizard)

Implement the ticket in `.worktrees/T-NNNN` on `feat/T-NNNN-<slug>`. Owns pages/components/state/data-fetching, design system, accessibility, FE security.

Make the fail-first AC tests pass; add component tests. Match the interface contracts exactly. a11y is not optional.

**⛔ Reuse over reinvent — mirror the sibling screen (mandatory).** Before building ANY screen UI (search/filter bars, tables, paginators, tab pages, modals, headers), FIRST open the nearest existing sibling screen in the same app and REUSE its shared components, layout structure, and styles. Do not build a "similar-looking" version from scratch — read the real file and mirror it. A ticket saying "use the X component" or "Y-style list" is NOT license to loosely reinterpret: use the exact shared component, in full (do not drop parts of it), laid out the same way. When unsure how something should look or sit, copy the sibling screen rather than inventing. Grep for the component and its existing usages and match the most-used pattern. Reinventing what already exists is the #1 source of rejected UI. For visual/layout changes, verify against an actual rendered screenshot (jsdom passing ≠ correct layout) and follow any UI-consistency conventions in the project guide.

**⛔ Admin-friendly error copy — never surface raw dev errors (mandatory).** Any UI that shows an error (toasts, inline field errors, failure/empty states, popovers) MUST display admin-friendly Korean copy — never a raw exception / stacktrace / internal `host:port` / URL / SQL / HTTP-client message verbatim (e.g. NOT `I/O error on POST request for "http://127.0.0.1:8090/..."`). Even when the API error response carries a technical string, map it to a message the operator understands (+ an actionable next step when possible) and keep raw detail out of view (console/logs only). Never render `error.message` blindly — always have a friendly fallback for unknown errors (e.g. "일시적인 문제가 발생했어요. 잠시 후 다시 시도해 주세요."). Review BLOCKING if a raw error string can reach the admin screen.

On each meaningful impl step, update ticket progress: `bin/ticket-transition.sh T-NNNN --progress-note "<1-2 sentences>"` (see `ticket-protocol`).
See `coding-principles` + `testing-principles` (+ `stacks/*` for the framework). Emit `stage.*` (actor `skill:frontend`).
Return: branch · PR · summary. **Never merge.**
