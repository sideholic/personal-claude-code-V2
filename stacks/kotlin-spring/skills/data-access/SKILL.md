---
name: data-access
description: Data access for Kotlin + Spring Boot — JPA/Hibernate + Querydsl, transactions, Flyway migrations. Use when the backend skill writes or reviews repositories, ORM mappings, or DB migrations.
---

# Data access

- **N+1 is BLOCKING.** Fetch joins / `@EntityGraph` / batch size. Verify query count in a test.
- Entities ≠ API DTOs — no entity leakage past the application layer. Writes go through the aggregate root.
- **Default to JPA**; reach for **Querydsl** only when a query is dynamic/complex. No JdbcClient.
- Migrations: **Flyway, forward-only, versioned.** No `ddl-auto: update` in prod.
- Explicit `@Transactional` boundaries; avoid long transactions.
