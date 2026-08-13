---
name: testing-nest
description: Test framework + patterns for NestJS + TS — Vitest, @nestjs/testing, Supertest, Testcontainers. Layers on testing-principles. Use when tests are written or reviewed in this stack.
---

# Testing (NestJS)

- **Vitest** for unit + integration — same toolchain as the FE stack; filter with `pnpm vitest run <pattern>`.
- Unit: `Test.createTestingModule` (@nestjs/testing) with fakes/mocks — no DB, no containers.
- **Testcontainers (MySQL)** for integration — no SQLite substitute for DB-specific behavior. One test class per container run; clean up on exit.
- API-level tests: **Supertest** against the compiled Nest HTTP server.
- One acceptance test per AC, fail-first. Verify-by-stash. Canonical: `pnpm vitest run`.
