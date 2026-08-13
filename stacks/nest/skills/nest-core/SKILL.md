---
name: nest-core
description: NestJS + TypeScript conventions for backend code. Layers on coding-principles (read that first); wins on conflict for NestJS/TS. Use when the backend skill writes or reviews NestJS.
---

# NestJS (modular monolith)

- **Module boundaries are architecture**: one Nest module per business domain. Cross-module access only through the module's exported service interface — never import another module's internals (entities, repositories, internal services).
- **Layers inside a module**: controller → service (application) → domain ← infrastructure. Controllers thin (validate → delegate → map) — logic lives in domain/services.
- TS strict; no `any`. Boundary DTOs validated with class-validator + global `ValidationPipe` (whitelist); entities never leak past the service layer.
- Constructor injection only; providers stateless. Domain error hierarchy (no bare `throw new Error`) mapped to HTTP by one exception filter.
- Config = typed `@nestjs/config` schema validated at boot — no bare `process.env` reads outside the config module.
- Canonical: build `pnpm build`, test `pnpm test` (Jest).
