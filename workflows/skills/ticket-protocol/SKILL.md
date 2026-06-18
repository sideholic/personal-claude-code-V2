---
name: ticket-protocol
description: Schema, IDs, lifecycle, and directory layout for .claude-team tickets. Use whenever any persona/skill creates, claims, transitions, or reads a ticket, review, rescue, backlog, or handoff artifact.
---

# Ticket protocol

State lives in `.claude-team/` (gitignored runtime). Tickets are the **scheduling ledger + dashboard record — NOT a message bus.**

## Layout (directory = status)
`tickets/{queue,in-progress,in-review,done,cancelled}` · `reviews/` · `rescues/` · `backlog/` · `handoff/` · `archive/` · `workers/registry.json` · `events.jsonl`

## Transitions
All state changes go through `bin/ticket-transition.sh` (`_lib/transition_ticket.py`): atomic move between dirs + `status` set + timestamp/counter injection + event emit — never move files or edit status by hand. The helper injects `started` (queue→in_progress), `done` (→done/→cancelled), bumps `last_activity_at`/`rescue_count`/`review_rounds`, and emits the matching event.
Status: `queued → in_progress → in_review → done` (`cancelled` from any).

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
Two writer classes — keep the boundary strict.

**Agent-written** (in the draft before publish, or as transition-helper args):
- `id` (auto by publish — leave blank in draft), `type, title, status` (publish/transition set)
- `assignee` — skill identity (`design|prd|backend|frontend|qa|review`)
- `complexity`
- `parent_feature` — REQUIRED, never null/absent; literal `standalone` when no parent feature
- `priority` — `high|medium|low`, queue ordering key
- `acceptance_criteria[], files_in_scope[], depends_on[]`
- `progress_note` — 1–2 sentence current-status note; update on EACH transition (or note-only without a transition)

**Script-written** (authoritative — AGENTS MUST NEVER write or hand-edit these in a draft):
- `created` — ISO8601+TZ, FORCED by publish (overwrites any draft value)
- `updated` — FORCED on every script write
- `started` — injected on queue→in_progress
- `done` — injected on →done / →cancelled
- `last_activity_at` — bumped on every transition / progress_note update
- `rescue_count` — default 0; +1 per rescue trigger
- `review_rounds` — default 0; +1 per in_review (re)entry
- `author` — publish sets (`technoking`)

Hard rule: timestamp & counter fields (`created, updated, started, done, last_activity_at, rescue_count, review_rounds`) are SCRIPT-OWNED — never write them in a draft; the publish/transition scripts are the sole writers.

`files_in_scope[]` + `depends_on[]` = the concurrency planner's input — disjoint scope → parallel; possible overlap → sequence.

### progress_note
- WHEN: on every transition, and whenever meaningful progress is made.
- HOW: 1–2 sentences, present tense — what's done / what's next / any blocker.
- Feeds the dashboard's in-progress card and the `last_activity_at` staleness signal.

Do NOT add v1 harness fields (`attempt_count, last_error_signature, protected_files, owner`) — deleted. NOTE: `rescue_count`/`review_rounds`/`last_activity_at` are deliberately RE-INTRODUCED here as SCRIPT-OWNED — distinct from the deleted v1 `attempt_count`/`claimed_at`/`last_update_at`, which were agent-managed and unsafe. Script ownership is what keeps the new fields from repeating that mistake.

## Emit
`bin/ticket-transition.sh` emits the Tier1 `ticket.claimed|review|done|cancelled` events as part of each transition; `bin/ticket-publish.sh` emits `ticket.published`. Skills emit Tier2 `stage.*` at their boundaries via `bin/events-emit.sh`. See `docs/events-contract.md`.

## Rules
Atomic writes (temp + mv); never in-place `sed` on shared files. `done/` is permanent. `RR/RESCUE/HANDOFF/BL` consume no counter and are written directly.
