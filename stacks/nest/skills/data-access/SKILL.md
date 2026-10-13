---
name: data-access
description: Data access for NestJS + MySQL — Drizzle ORM (default for new repos) or Prisma (repos already on it): schema, queries, transactions, migrations. Use when the backend skill writes or reviews data models, queries, or DB migrations.
---

# Data access

**ORM = the one the repo declares** — Drizzle (`drizzle-orm`, default for new repos) or Prisma (`schema.prisma`, existing repos). Never add a second ORM.

## Common (both ORMs)

- MySQL. **N+1 is BLOCKING** — load relations in one query, never loop-and-query. Verify query count in a test.
- Select what you need — explicit columns on wide tables / list endpoints, no blanket overfetch.
- DB rows ≠ API DTOs — map at the service boundary; never return ORM rows straight from controllers.
- Multi-write use case = one transaction, kept short. Read-then-write races → row lock (`FOR UPDATE`) inside that transaction.
- Raw SQL only where the query API cannot express it, always parameterized — never string-concatenated SQL.
- Migrations: versioned files committed to the repo, **forward-only**, never edit an applied one. Generate locally, apply in CI/deploy.

## Drizzle

- Schema in TypeScript (`mysqlTable`) in one schema module = single source of truth. Row types via `$inferSelect` / `$inferInsert` — no hand-written row types, no `any` around results.
- One `mysql2` pool + `drizzle()` instance, provided by a global `DrizzleModule` under an injection token (`@Inject(DRIZZLE)`). No per-feature clients or pools.
- Queries live in the owning module's repository (infrastructure layer); services call repositories, not query builders scattered around.
- Relations: relational queries (`db.query.<table>.findMany({ with })`) or explicit joins.
- Transactions: `db.transaction(async (tx) => …)`, pass `tx` down to the repositories involved; row locks with `.for('update')`.
- Raw SQL: the `sql` tagged template (parameterized). `sql.raw()` never with external input.
- Migrations: `drizzle-kit generate` → review the SQL → commit; apply with `drizzle-kit migrate` (or the migrator at deploy). `drizzle-kit push` only for throwaway local DBs.
- Stable release only (npm `latest`), not beta/rc tags.

## Prisma

- One `PrismaService` (extends `PrismaClient`, `$connect` on module init) provided by a shared `PrismaModule` — no per-feature clients.
- `schema.prisma` is the single source of truth; rely on the generated client types end-to-end.
- Relations with `include` / nested `select` in one query. Multi-write = `$transaction` (interactive for read-then-write).
- Raw SQL via `$queryRaw` tagged templates only.
- Migrations: `prisma migrate` (`migrate dev` locally, `migrate deploy` in CI/prod). `db push` only for throwaway local experiments.
