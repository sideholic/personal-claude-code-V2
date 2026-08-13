---
name: data-access
description: Data access for NestJS — MikroORM (Unit of Work) + MySQL, transactions, migrations. Use when the backend skill writes or reviews repositories, ORM mappings, or DB migrations.
---

# Data access

- **MikroORM Unit of Work is the default**: load entities, mutate, `flush()` — dirty checking like JPA. No ad-hoc `nativeUpdate`/raw SQL for business writes.
- **N+1 is BLOCKING.** `populate` joins / batch loading; verify query count in a test.
- Entities ≠ API DTOs — no entity leakage past the service layer. Writes go through the aggregate root.
- Dynamic/complex queries via MikroORM **QueryBuilder**; simple reads via repository find. No query strings assembled by hand.
- **Concurrency = pessimistic lock** (`LockMode.PESSIMISTIC_WRITE` → `SELECT … FOR UPDATE`); atomicity = one outer transaction (`em.transactional`) — no nested/split transactions, no upsert-and-catch patterns.
- Migrations: **MikroORM migrations, forward-only, versioned.** No schema-generator sync in prod.
