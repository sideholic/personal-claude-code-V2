---
name: testing-kotlin
description: Test framework + patterns for Kotlin + Spring Boot — JUnit 5, Kotest, MockK, Testcontainers, Spring slices. Layers on testing-principles. Use when tests are written or reviewed in this stack.
---

# Testing (Kotlin / Spring)

- JUnit 5 + Kotest assertions; **MockK** for mocks (not Mockito).
- Slices: `@WebMvcTest` (controller), `@DataJpaTest` (repo). Full `@SpringBootTest` only for integration/E2E.
- **Testcontainers** for the real DB in integration tests — no H2 substitute for DB-specific behavior.
- One acceptance test per AC, fail-first. Verify-by-stash. Canonical: `./gradlew test`.
