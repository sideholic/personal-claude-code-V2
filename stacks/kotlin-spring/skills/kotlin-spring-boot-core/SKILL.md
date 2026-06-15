---
name: kotlin-spring-boot-core
description: Kotlin + Spring Boot conventions for backend code. Layers on coding-principles (read that first); wins on conflict for Kotlin/Spring. Use when the backend skill writes or reviews Kotlin.
---

# Kotlin + Spring Boot

- **Layers**: api → application → domain ← infrastructure. Domain has no framework deps; dependencies point inward.
- **Rich domain**: logic in the domain model, not anemic services. Controllers thin (validate → delegate → map).
- `val` over `var`; data/value classes; null-safety (no `!!`). Sealed `DomainException` hierarchy — no bare `RuntimeException`.
- Constructor injection only. `@Transactional` at the application layer, `readOnly` where possible.
- Canonical: build `./gradlew build`, test `./gradlew test`.
