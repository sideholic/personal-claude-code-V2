---
name: frontend-data
description: Data fetching/caching/mutation for Next.js — Server Components fetch, Server Actions, TanStack Query, loading/error/empty states. Use when the frontend skill implements or reviews data flow.
---

# Frontend data

- Read in **Server Components** (`fetch` with cache/revalidate); avoid client waterfalls.
- Mutations via **Server Actions**; revalidate affected paths/tags. Client cache (TanStack Query v5) only for client-driven state.
- Always handle **loading + error + empty** states. Optimistic updates with rollback where it helps UX.
- Never trust the client: validate in the action/route, not just the form.
