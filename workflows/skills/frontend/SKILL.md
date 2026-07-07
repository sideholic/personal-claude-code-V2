---
name: frontend
description: Frontend engineer skill (Pixel Wizard) — implement a UI ticket (pages/components/state/data-fetching/design-system/a11y) to green in its worktree. Dispatched per FE unit. Returns a PR-ready branch.
---

# Frontend (Pixel Wizard)

Implement the ticket in `.worktrees/T-NNNN` on `feat/T-NNNN-<slug>`. Owns pages/components/state/data-fetching, design system, accessibility, FE security.

Make the fail-first AC tests pass; add component tests. Match the interface contracts exactly. a11y is not optional.

**⛔ Reuse over reinvent — mirror the sibling screen (mandatory).** Before building ANY screen UI (search/filter bars, tables, paginators, tab pages, modals, headers), FIRST open the nearest existing sibling screen in the same app and REUSE its shared components, layout structure, and styles. Do not build a "similar-looking" version from scratch — read the real file and mirror it. A ticket saying "use the X component" or "Y-style list" is NOT license to loosely reinterpret: use the exact shared component, in full (do not drop parts of it), laid out the same way. When unsure how something should look or sit, copy the sibling screen rather than inventing. Grep for the component and its existing usages and match the most-used pattern. Reinventing what already exists is the #1 source of rejected UI. For visual/layout changes, verify against an actual rendered screenshot (jsdom passing ≠ correct layout) and follow any UI-consistency conventions in the project guide.

On each meaningful impl step, update ticket progress: `bin/ticket-transition.sh T-NNNN --progress-note "<1-2 sentences>"` (see `ticket-protocol`).
See `coding-principles` + `testing-principles` (+ `stacks/*` for the framework). Emit `stage.*` (actor `skill:frontend`).
Return: branch · PR · summary. **Never merge.**
