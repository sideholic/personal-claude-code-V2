---
name: testing-nest
description: Test framework + patterns for NestJS + TS — Jest, @nestjs/testing, Supertest, Testcontainers. Layers on testing-principles. Use when tests are written or reviewed in this stack.
---

# Testing (NestJS)

- **Jest** (Nest CLI default). Filter with `pnpm exec jest <pattern>` — don't run the full suite for one class.
- Unit: `Test.createTestingModule` (@nestjs/testing) with mocked providers (`useValue`/`useFactory`) — no DB, no containers.
- e2e/API: **Supertest** against `createNestApplication()` — Nest convention `test/*.e2e-spec.ts`.
- **Testcontainers (`@testcontainers/mysql`)** for integration against real MySQL — no SQLite substitute for MySQL-specific behavior. Clean up containers on exit.
- One acceptance test per AC, fail-first. Verify-by-stash. Canonical: `pnpm test` (unit), `pnpm test:e2e` (Supertest e2e).
