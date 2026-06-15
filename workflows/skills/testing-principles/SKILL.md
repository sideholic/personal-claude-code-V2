---
name: testing-principles
description: Stack-agnostic testing bar. Use when writing, reviewing, or planning tests — QA acceptance, unit, integration, E2E. Stack frameworks (stacks/*) override specifics.
---

# Testing principles

- **Fail-first.** One acceptance test per AC, RED before implementation. An untestable AC → escalate; never invent a passing test.
- **Verify-by-stash.** An AC test that passes WITHOUT the production change is invalid → BLOCKING.
- **Behavior, not implementation.** Arrange-Act-Assert. Deterministic — no sleeps, real clock, or live network.
- **Layering.** Unit (impl owns) → integration/E2E (QA, cross-unit seams). Green CI is a merge precondition.
- Stack frameworks/patterns (`stacks/*`) override the specifics.
