---
name: git-flow
description: Branch, worktree, commit, and merge conventions for this plugin. Use whenever a persona creates a branch/worktree, commits, opens a PR, or merges.
---

# Git flow

Branch off `main` (no long-lived develop). One worktree per non-overlapping unit of work.

## Branches
`<type>/T-NNNN-<slug>` — type ∈ `feat|task|fix|rescue|review|spike`. `rescue/T-NNNN` has no slug.

## Worktrees
`.worktrees/T-NNNN/` (gitignored), created on claim, removed on done/cancelled. Parallel **only** when `files_in_scope[]` are disjoint; possible overlap → `depends_on[]` sequence (conservative policy).

## Commits
Conventional Commits. Prefix `<type>(<scope>):` in English; **subject + body in Korean** (user reads `git log`). Footer keys English: `Refs:` / `Closes: T-NNNN` / `Co-Authored-By:`. type ∈ `feat|fix|refactor|test|docs|chore|perf|build|ci`. Subject ≤72 chars. Forbidden subjects: `wip|fixup|temp|update`. Atomic, revertable commits.

## Merge (Technoking only)
`--squash` to `main`. Pre-merge checklist: **codex APPROVE on every PR · all AC checked · green CI · no unresolved BLOCKING.** Workers never merge. PR size soft 400 / hard 800 lines.

## Multi-Technoking (opt-in)
`T-NNNN` comes from the atomic counter (see ticket-protocol). The merge gate is the only other serialization point: wrap the squash merge in `bin/merge-gate.sh` (exclusive `.merge.lock`) so concurrent kings never race on `main`. Launch extra king panes with `bin/king-pane.sh [N]` (unlimited).
