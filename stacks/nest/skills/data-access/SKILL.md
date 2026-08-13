---
name: data-access
description: Data access for NestJS — Prisma + MySQL, transactions, migrations. Use when the backend skill writes or reviews data models, queries, or DB migrations.
---

# Data access

- **Prisma + MySQL.** One `PrismaService` (extends `PrismaClient`, `$connect` on module init) provided by a shared `PrismaModule` — the official Nest recipe. No per-feature clients.
- `schema.prisma` is the single source of truth; rely on the generated client types end-to-end — no `any` casts around query results.
- **N+1 is BLOCKING.** Fetch relations with `include`/nested `select` in one query (or rely on Prisma's batched relation loading) — never loop-and-query. Verify query count in a test.
- Select what you need: explicit `select` on wide models/list endpoints — no blanket overfetch.
- Prisma models ≠ API DTOs — map at the service boundary; never return Prisma models straight from controllers.
- Multi-write use cases = one `$transaction` (interactive transaction for read-then-write flows); keep it short.
- Raw SQL only where the client cannot express the query, via `$queryRaw` tagged templates (parameterized) — never string-concatenated SQL.
- Migrations: **`prisma migrate`, forward-only, versioned** (`migrate dev` locally, `migrate deploy` in CI/prod). `db push` only for throwaway local experiments.
