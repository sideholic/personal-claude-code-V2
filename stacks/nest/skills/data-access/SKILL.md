---
name: data-access
description: Data access for NestJS — TypeORM (@nestjs/typeorm) + MySQL, transactions, migrations. Use when the backend skill writes or reviews repositories, ORM mappings, or DB migrations.
---

# Data access

- **TypeORM via `@nestjs/typeorm` + MySQL (mysql2 driver).** Repositories injected with `@InjectRepository`; transactions through `DataSource`/`EntityManager`.
- **N+1 is BLOCKING.** Load relations explicitly (`relations` option / QueryBuilder joins); verify query count in a test.
- Entities ≠ API DTOs — no entity leakage past the service layer.
- Simple reads via repository find options; dynamic/complex queries via **QueryBuilder**. No hand-assembled SQL strings; raw SQL only where QueryBuilder cannot express it, always parameterized.
- Multi-write use cases wrap in a single `dataSource.transaction(...)` at the application layer; keep transactions short. Concurrent writes on the same row use `setLock('pessimistic_write')` inside that transaction.
- Migrations: **TypeORM migrations, forward-only, versioned.** `synchronize: false` everywhere except throwaway local dev.
