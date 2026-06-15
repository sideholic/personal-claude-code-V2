---
description: Show the ticket board, in-flight lanes, and recent completions.
---

Render a board from `.claude-team/tickets/*` (queue / in-progress / in-review / done) + recent `.claude-team/events.jsonl`. Group by squad (design/FE/BE/QA/review). Read-only. (The web dashboard is the rich view; this is the CLI fallback.) See `ticket-protocol`, `docs/events-contract.md`.
