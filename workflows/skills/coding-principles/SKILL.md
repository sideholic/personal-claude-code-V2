---
name: coding-principles
description: Stack-agnostic coding bar for all personas. Read before writing or reviewing code. Stack-specific rules (stacks/*) layer on top and win on conflict for their language.
---

# Coding principles

- **Simplest code that solves it.** No speculative abstraction, config, or flexibility that wasn't asked for. 200 lines that could be 50 → rewrite.
- **Surgical.** Every changed line traces to the ticket. Don't "improve" adjacent code or refactor what isn't broken. Match surrounding style.
- **Intent-revealing names.** Small, single-responsibility functions. Handle errors at the right layer — never swallow.
- **Security by default.** No secrets/keys in code. Validate inputs at boundaries.
- Stack rules (`stacks/*`) override these for their language.
