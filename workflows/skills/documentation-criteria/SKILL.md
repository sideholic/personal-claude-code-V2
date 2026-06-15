---
name: documentation-criteria
description: What PRD, Design Doc, and ADR must contain and where they live. Use when the prd/design skills author or review user-facing planning docs.
---

# Documentation criteria

User-facing docs in **Korean** (YAML frontmatter English), under `docs/`.

- **PRD** (`docs/prd/PRD-<slug>.md`): problem · goal · in/out-of-scope · **acceptance_criteria (Given/When/Then, testable)** · open questions. Audience = user.
- **Design** (`docs/design/DESIGN-<slug>.md`): chosen vs rejected approach · components · data/flow · **interface contracts (BE↔FE types in sync)** · risks.
- **ADR** (`docs/adr/ADR-NNN-*.md`): one decision — context · decision · consequences. Create only when a choice is hard to reverse.
- **Diagnose** (`docs/diagnose/`): symptom · failure path/root cause · proposed fixes (trade-offs) · recommended route (`/task` or `/feat`). No implementation.

Keep terse. A doc that restates the code is noise.
