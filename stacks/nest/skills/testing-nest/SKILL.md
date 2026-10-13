---
name: testing-nest
description: Test framework + patterns for NestJS + TS — Vitest or Jest (whichever the repo declares), @nestjs/testing, Supertest, Testcontainers. Layers on testing-principles. Use when tests are written or reviewed in this stack.
---

# Testing (NestJS)

- **Runner = the one in the repo's `package.json`** — Vitest (NestJS 12+ scaffold default) or Jest (older scaffold). Never add the other or mix APIs (`vi.fn()` vs `jest.fn()`).
- Filter, don't run the full suite for one class: Vitest `pnpm exec vitest run <pattern>` · Jest `pnpm exec jest <pattern>`.
- Unit: `Test.createTestingModule` (@nestjs/testing) with mocked providers (`useValue`/`useFactory`) — no DB, no containers. Specs co-located as `*.spec.ts`.
- e2e/API: **Supertest** against `createNestApplication()` — `test/*.e2e-spec.ts`, run by the repo's separate e2e config (`pnpm test:e2e`).
- **Testcontainers (`@testcontainers/mysql`)** for integration against real MySQL — apply the repo's migrations (Drizzle/Prisma) to the container first; no SQLite substitute for MySQL-specific behavior. Clean up containers on exit.
- One acceptance test per AC, fail-first. Verify-by-stash. Canonical: `pnpm test` (unit), `pnpm test:e2e` (Supertest e2e).
