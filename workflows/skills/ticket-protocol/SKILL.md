---
name: ticket-protocol
description: Schema, IDs, lifecycle, and directory layout for .claude-team tickets. Use whenever any persona/skill creates, claims, transitions, or reads a ticket, review, rescue, backlog, or handoff artifact.
---

# Ticket protocol

State lives in `.claude-team/` (gitignored runtime). Tickets are the **scheduling ledger + dashboard record — NOT a message bus.**

## Layout (directory = status)
`tickets/{queue,in-progress,in-review,done,cancelled}` · `reviews/` · `rescues/` · `backlog/` · `handoff/` · `archive/` · `workers/registry.json` · `events.jsonl`

Moving the file between dirs = the state transition.

## IDs
| prefix | type | counter |
|---|---|---|
| `T-NNNN` | work | `registry.counters.T` |
| `RV-NNNN` | review | `registry.counters.RV` |
| `BL-NNNN` | backlog | `registry.counters.BL` |
| `RR-T-NNNN-R` | review report (round R) | none |
| `RESCUE-<ts>` / `HANDOFF-<ts>` | rescue / handoff | none |

4-digit zero-pad, auto-extends past 9999. Counters are bumped **only** by `bin/ticket-publish.sh` (python `fcntl.flock`, multi-Technoking safe). Filename `<ID>-<kebab-slug>.md`.

## Work ticket frontmatter
- Required: `id, type, title, status, assignee, complexity, created, updated, author`
- Planning: `parent_feature, acceptance_criteria[], files_in_scope[], depends_on[]`
- `status`: `queued → in_progress → in_review → done` (`cancelled` from any)
- `assignee`: skill identity (`design|prd|backend|frontend|qa|review`)
- `files_in_scope[]` + `depends_on[]` = the concurrency planner's input — disjoint scope → parallel; possible overlap → sequence.

Do NOT add v1 harness fields (`attempt_count, last_error_signature, last_update_at, protected_files, owner, claimed_at`) — deleted.

## Emit
On every state write, append the matching event via `bin/events-emit.sh` (Tier1 `ticket.*`; skills emit Tier2 `stage.*` at their boundaries). See `docs/events-contract.md`.

## Rules
Atomic writes (temp + mv); never in-place `sed` on shared files. `done/` is permanent. `RR/RESCUE/HANDOFF/BL` consume no counter and are written directly.
