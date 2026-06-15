---
description: Bootstrap .claude-team directories + registry from templates; verify codex.
---

Materialize `.claude-team/` from `workflows/templates/`: `tickets/{queue,in-progress,in-review,done,cancelled}`, `reviews/`, `rescues/`, `backlog/`, `handoff/`, `archive/`, `workers/registry.json`, `config.yml`, `events.jsonl`.

Verify codex via `/codex:status` (required reviewer). **No tmux panes or daemons in v2** (single non-blocking king + background workflows). The optional multi-king pane launcher is P9.
