---
name: frontend-state-data
description: Frontend state and data rules (server state vs client state, fetch states, state home). Remote data belongs to the query layer / server components with caching + invalidation — never copied into a global store; client state covers UI-only concerns; the state decision table places each kind of state (local, subtree, remote, cross-cutting, form); the four fetch states (loading/error/empty/content) are always modeled and rendered; derived values are computed, not stored; useEffect is not used to re-derive what a query key or a derived value already expresses. Use when deciding where state lives, wiring TanStack Query / server components, rendering fetch states, or catching remote-into-store mirroring and useEffect-derivation smells.
when_to_use: When choosing a state home, separating server vs client state, wiring a query/server component, rendering loading/error/empty/content, or catching smells like remote data mirrored into a store, redundant useEffect derivation, or a second state library.
paths: **/hooks/**/*.ts, **/hooks/**/*.tsx, **/*use*.ts, **/*use*.tsx, **/store/**/*.ts, **/queries/**/*.ts, **/*.query.ts, **/app/**/page.tsx
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# frontend-state-data

Rules for where state lives and how remote data enters the app. The State
Decision Table and server/client-state items from `guidance.md` expanded to an
enforceable level. Project `ctx/` overrides this document. Deeper material
(query samples, derived-state patterns) lives in [reference.md](./reference.md).

## Scope

- In scope: state-home decisions, server vs client state, fetch-state modeling,
  derived state, query/store wiring.
- Covers: TanStack Query / server components, the state decision table, the four
  fetch states, avoiding remote-in-store and redundant effects.
- Doesn't cover: the API client contract → [frontend-api-contract], component
  boundaries → [frontend-architecture], layout/store choice →
  [frontend-module-structure].

## Core rules

Do:

- **Server state ≠ client state.** Remote data lives in the query layer / server
  components (cache + invalidation). Client state is UI-only (open/closed,
  selected tab, theme).
- **Model the four fetch states — loading / error / empty / content — and render
  all four.** The query layer provides them; don't skip empty/error.
- **Derive, don't store.** Values computable from existing state/props are
  computed during render (or `useMemo` on evidence), not duplicated into state
  and synced.
- **Pick the state home from the table** (below). Local first; lift only when
  shared; a store only for genuine cross-cutting client state.
- **Invalidate, don't hand-sync.** After a mutation, invalidate the affected
  query keys; let the query layer refetch.
- Use the state library the project already has — do not add a second one.

Don't:

- Copy remote data into a global store and keep it in sync manually.
- Use `useEffect` to re-derive a value from props/state, or to mirror a query
  result into local state (`You Might Not Need an Effect`).
- Encode a screen's state as a bag of independent booleans/nullables when one
  discriminated union expresses it.
- Skip the empty or error state ("happy path only").
- Reach for a store for state that a single component or a lifted `useState` owns.

## State decision table

| Situation | State home | API |
|---|---|---|
| One component's UI state | local | `useState`/`useReducer` |
| Shared within one subtree | lift up / context for stable values | props / `createContext` |
| Remote data | server components / query layer — **never** a global store | RSC / `useQuery` |
| Cross-cutting client state (session UI, theme, cart) | the project's existing store | Zustand/Redux (one only) |
| Form state | native/controlled inputs; the project's form lib for complex validation | `useState` / RHF etc. |
| Derived value | not stored — computed | render / `useMemo` (on evidence) |

## Refactor / red-flag signals

- Remote data mirrored into a store and manually kept in sync.
- `useEffect` chains re-deriving what a query key or a derived value expresses.
- Local state seeded from props via `useEffect` (should be derived or keyed).
- Missing empty/error rendering; only loading + content handled.
- Independent booleans/nullables encoding one exclusive state.
- A second state-management library next to the existing one.

## References

- You Might Not Need an Effect: https://react.dev/learn/you-might-not-need-an-effect
- Choosing the state structure: https://react.dev/learn/choosing-the-state-structure
- TanStack Query — important defaults & invalidation: https://tanstack.com/query/latest/docs/framework/react/guides/important-defaults
- Next.js data fetching (RSC): https://nextjs.org/docs/app/building-your-application/data-fetching
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Query samples, derived-state patterns, fetch-state rendering: [`reference.md`](reference.md)
