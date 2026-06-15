---
name: testing-nextjs
description: Test framework + patterns for Next.js + TS — Vitest, React Testing Library, MSW, Playwright. Layers on testing-principles. Use when tests are written or reviewed in this stack.
---

# Testing (Next.js)

- **Vitest + React Testing Library** (query by role/label, not test-ids). **MSW v2** for network.
- Test behavior the user sees; avoid implementation-detail assertions.
- **Playwright** for E2E (integration / qa-post). One acceptance test per AC, fail-first. Verify-by-stash.
- Canonical: `pnpm test` (unit), `pnpm test:e2e` (Playwright).
