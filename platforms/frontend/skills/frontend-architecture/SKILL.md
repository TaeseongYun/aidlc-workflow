---
name: frontend-architecture
description: Frontend (web) architecture · component-architecture skeleton reference rules. Covers the boundary flow (Route/Page → Container (data + state wiring) → Presentational Components, never reversed), server state vs client state separation, all backend calls through one API client module, typed API boundary (no any), presentational components taking props and emitting callbacks (no fetching/store/router coupling), and the Feature Slice decision table. TypeScript + React (Next.js App Router when present), same boundaries for Vue/Svelte with names swapped. Use when designing, reviewing, or refactoring frontend architecture, or deciding which slice (local component / container / query layer / feature module) to take. The umbrella skill tying the other five frontend skills together.
when_to_use: Designing web frontend architecture, judging component boundaries, placing Container/Presentational/API-client, deciding server vs client state, choosing a feature slice, architecture refactor/review. Also for React/Next.js/Vue/Svelte app architecture, container-presentational split, server-vs-client-state placement requests.
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# frontend-architecture — component-architecture skeleton

The spine of a web frontend: component boundaries, the server-vs-client state
split, and the single API boundary, pinned as always-referenced rules. Project
`ctx/` overrides this skill, and this skill overrides the agent's general
knowledge. Deeper material (layer responsibilities, container/presentational
samples, feature-slice examples) lives in [reference.md](./reference.md).

## Scope

- In scope: component-layer placement, data-flow direction, server/client state
  home, slice selection, and refactor judgment for new frontend features.
  Primary stack TypeScript + React (Next.js App Router), same boundaries for
  Vue/Svelte.
- Out of scope: state/fetch-state detail, module/styling layout, API client
  contract, accessibility, security vulnerability patterns — each delegated to
  the Related skills below.

## Core rules — boundary flow and layer responsibilities

Data flows top→down, one-way, **never reversed**.

```
Route/Page → Container (data + state wiring) → Presentational Components
                 │
                 ├─ Server state (query layer / server components)  ─┐
                 └─ Client state (UI-only)                            │
                                                                      ▼
                                        API client module (one fetch wrapper) → Backend
```

### Do

- **Route/Page**: the data-fetching boundary. Server Components / route loaders
  when the framework provides them, otherwise a server-state library
  (TanStack Query) at the container. → [frontend-state-data].
- **Container**: wires data + state, passes plain props down. Owns loading /
  error / empty / content handling.
- **Presentational component**: props in, callbacks out. No data fetching, no
  global-store access, no router coupling → reusable and testable.
- **Server state ≠ client state.** Remote data lives in the query layer / server
  components with caching + invalidation. Client state covers UI-only concerns
  → [frontend-state-data].
- **One API client module** for all backend calls (base URL, auth header, error
  normalization). Typed responses, no `any` at the boundary → [frontend-api-contract].

### Don't

- A presentational component fetching data, reading a global store, or touching
  the router → forbidden.
- Remote data copied into a global store "for convenience" and hand-synced → forbidden.
- Raw `fetch` scattered in components instead of the API client module → forbidden.
- `any` on API responses (untyped boundary) → forbidden.
- A second state library or styling system next to the existing one → forbidden
  → [frontend-module-structure].
- A lower layer reaching up into a route/container → forbidden (reversed flow).

## Feature Slice Decision Table

Start at the **smallest** slice that fits. Move up only on a **real signal**, not
speculation.

| Situation | Slice | Signal to move up |
|-----------|-------|-------------------|
| One component's UI state | local `useState`/`useReducer` | state shared across siblings/subtree |
| Shared UI state in a subtree | lift state up / context for stable values | data comes from the server |
| Remote data on a screen | server component / TanStack Query + container | cross-cutting client state appears |
| Cross-cutting client state (session UI, theme, cart) | the project's existing store | — (do not add a second store) |

- **Don't build ahead**: no global store, no extra abstraction layer, no feature
  package before a real requirement forces it (over-engineering).
- Do not create a container that only passes props through without wiring
  data/state.

## Refactor / red-flag signals

- A presentational component fetching data or reading a global store.
- Remote data mirrored into a store and manually kept in sync.
- `any` on API responses; error handling that swallows failures silently.
- `useEffect` chains re-deriving what a query key or derived value expresses.
- Raw `fetch` calls bypassing the API client module.
- A second styling system or state library appearing next to the existing one.
- Div-with-onClick interactive elements; unlabeled form fields → [frontend-accessibility].

## Related skills

Umbrella skill. Drill down into each concern's detail below:

- [frontend-state-data](../frontend-state-data/SKILL.md) — server vs client state · fetch states · TanStack Query/RSC · no remote-in-store.
- [frontend-module-structure](../frontend-module-structure/SKILL.md) — app/components/features/lib layout · single styling system · code-splitting boundaries.
- [frontend-api-contract](../frontend-api-contract/SKILL.md) — one API client module · typed boundary (no any) · error normalization · response validation.
- [frontend-accessibility](../frontend-accessibility/SKILL.md) — a11y safety guard · semantic HTML · focus management · platform-over-library.
- [frontend-security](../frontend-security/SKILL.md) — **vibe-coding security guard**: blocks vulnerable patterns in AI-generated code.

## References

- Team guidelines (parent doc): [../../guidance.md](../../guidance.md)
- Deeper material: [reference.md](./reference.md)
- React — thinking in components: https://react.dev/learn/thinking-in-react
- Next.js App Router: https://nextjs.org/docs/app
- TanStack Query: https://tanstack.com/query/latest
