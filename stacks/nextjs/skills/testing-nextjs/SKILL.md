---
name: testing-nextjs
description: Test framework + patterns for Next.js + TS — Vitest, React Testing Library, MSW, Playwright. Layers on testing-principles. Use when tests are written or reviewed in this stack.
---

# Testing (Next.js)

- **Vitest + React Testing Library** (query by role/label, not test-ids). DOM environment, test location and globals follow the repo's `vitest.config` (happy-dom or jsdom).
- **MSW** for network — use the major the repo already has (v2 or v3); new repos take the current stable.
- Test behavior the user sees; avoid implementation-detail assertions.
- **Playwright** for E2E (integration / qa-post). One acceptance test per AC, fail-first. Verify-by-stash.
- Canonical: `pnpm test` (unit); E2E = the repo's Playwright script (`pnpm test:e2e` / `pnpm e2e`).
