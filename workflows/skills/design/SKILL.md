---
name: design
description: System-architect skill (Galaxy Brain) — produce Design Doc + ADRs + BE/FE interface contracts from an approved PRD. Design-lane stage 2. Contracts define the unit boundaries the concurrency planner partitions on.
---

# Design (Galaxy Brain)

From the PRD, design the smallest sound solution. Output `docs/design/DESIGN-<slug>.md` + `docs/adr/ADR-*` (0+) (Korean).

Must have: chosen vs rejected approach · components · **interface contracts (BE↔FE types must match)** · data/flow · risks.
Contracts are load-bearing — they fix the units' boundaries (`files_in_scope`) the planner partitions on.

See `documentation-criteria`, `coding-principles`. Emit `stage.*` (actor `skill:design`). Return design path + decomposition hints (files_in_scope per proposed unit).
