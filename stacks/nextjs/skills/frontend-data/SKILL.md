---
name: frontend-data
description: Data fetching/caching/mutation for Next.js — Server Components fetch, Cache Components ('use cache'), Server Actions, TanStack Query, loading/error/empty states. Use when the frontend skill implements or reviews data flow.
---

# Frontend data

- Read in **Server Components**; avoid client waterfalls. With `cacheComponents` enabled, cache with `'use cache'` + `cacheTag` / `cacheLife` (or `fetch` with `next.tags`); without it, `fetch` cache/revalidate options.
- Mutations via **Server Actions**, then invalidate: `updateTag(tag)` for read-your-own-writes (Server Actions only) or `revalidatePath`. In route handlers / webhooks use `revalidateTag(tag, 'max')`. Client cache (TanStack Query v5) only for client-driven state.
- Always handle **loading + error + empty** states. Optimistic updates with rollback where it helps UX.
- Never trust the client: validate in the action/route, not just the form.
