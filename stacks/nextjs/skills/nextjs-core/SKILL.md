---
name: nextjs-core
description: Next.js (App Router) + TypeScript conventions for frontend code. Layers on coding-principles (read that first); wins on conflict for Next.js/TS. Use when the frontend skill writes or reviews Next.js.
---

# Next.js (App Router)

- **Server Components by default**; `'use client'` only when interactivity/state/browser APIs are needed. Keep the boundary low in the tree.
- TS strict; no `any`. Types shared with the backend match the **interface contracts** exactly.
- Co-locate components; route handlers in `app/`. No fetching in a Client Component when a Server Component can do it.
- Request APIs are async — `await` `params`, `searchParams`, `cookies()`, `headers()`.
- Next 16+: `proxy.ts` (formerly `middleware.ts`) only for redirects/rewrites/headers. **Authn/authz is checked inside every Server Action and route handler** — never rely on Proxy matchers alone.
- **a11y**: semantic HTML, labels, keyboard nav, focus management — not optional.
- Canonical = the repo's scripts: `pnpm lint`, `pnpm test`, `pnpm build`. Typecheck needs generated route types (`PageProps`/`LayoutProps`): `next typegen && tsc --noEmit` — bare `tsc` fails on a clean checkout.
