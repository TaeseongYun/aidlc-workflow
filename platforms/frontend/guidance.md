# Frontend (Web) Architecture — Current Guidance

Baseline for web frontend work: TypeScript + React (Next.js App Router when a
framework is present). The boundaries apply to other stacks (Vue/Svelte) with
names swapped. Project `ctx/` overrides this document; this document overrides
the agent's general knowledge.

## Boundaries

```
Route/Page -> Container (data + state wiring) -> Presentational Components
                 |
                 v
        Server state (query layer / server components)  |  Client state (UI-only)
                 |
                 v
        API client module (fetch wrapper) -> Backend
```

- Presentational components take props and emit callbacks; no data fetching,
  no global-store access, no router coupling.
- Data fetching lives at the route/container level: React Server Components /
  route loaders when the framework provides them, otherwise a server-state
  library (TanStack Query). Components below receive data as props.
- **Server state ≠ client state.** Remote data belongs to the query
  layer/server components with caching and invalidation — never copied into a
  global store "for convenience". Client state covers UI-only concerns.
- All backend calls go through one API client module (base URL, auth header,
  error normalization). No raw `fetch` scattered in components.
- API response types are declared (generated from the contract when the
  project has codegen; hand-written and validated otherwise). No `any` at the
  API boundary.

## State Decision Table

| Situation | State home |
|-----------|-----------|
| One component's UI state | `useState`/`useReducer` local |
| Shared within one subtree | lift state up, or context for stable values |
| Remote data | server components / TanStack Query — never a global store |
| Cross-cutting client state (session UI, theme, cart) | the project's existing store (Zustand/Redux); do not add a second one |
| Form state | native form/controlled inputs; the project's existing form lib for complex validation |

## Rules

- Prefer platform over library: semantic HTML, `<input type="date">`, CSS
  (flex/grid, `:has`, transitions) before a JS dependency (ties to
  `core/lazy-implementation.md`).
- Accessibility is a safety guard, not a nice-to-have: interactive elements
  are buttons/links (not divs with onClick), images have alt text, forms have
  labels, focus is managed on dialogs/route changes. Never trimmed for speed.
- Model fetch states explicitly (loading/error/empty/content) — the query
  layer provides them; render all four.
- Validate and encode anything user-provided before render; never
  `dangerouslySetInnerHTML` with unsanitized input. Secrets never reach the
  client bundle (`NEXT_PUBLIC_`/`VITE_` prefixes are public by definition).
- Follow the project's existing styling system (design tokens, Tailwind, or
  CSS modules) — do not introduce a second styling approach.
- Route-level code splitting is the default; heavy widgets load lazily.
- Follow existing test conventions: component tests assert behavior via
  testing-library queries (roles/labels), not implementation details.

## Module Baseline

Follow the project's layout. Absent one:

```
app/ (or pages/)         # routes, layouts, route-level data fetching
components/              # shared presentational components
features/<name>/         # feature-scoped components, hooks, api calls
lib/                     # api client, utilities
styles/ or tokens        # design tokens, global styles
```

## Feature Implementation Checklist

1. API types + client functions for new endpoints (from the approved
   contract).
2. Route/page entry with data fetching and the four fetch states.
3. Presentational components (props in, callbacks out) + stories/previews if
   the project uses them.
4. Client-state wiring only for what is genuinely client state.
5. Form validation + error display for user input paths.
6. Tests: behavior of the main flow, validation errors, empty/error states.

## Refactor Signals

- A presentational component fetching data or reading a global store.
- Remote data mirrored into a store and manually kept in sync.
- `any` on API responses; error handling that swallows failures silently.
- `useEffect` chains re-deriving what a query key or derived value expresses.
- Div-with-onClick interactive elements; unlabeled form fields.
- A second styling system or state library appearing next to the existing one.
- Raw `fetch` calls bypassing the API client module.

## Detailed Skills

This baseline is expanded into seven topic skills under
[`skills/`](skills/README.md). Each is a reference-knowledge skill
(`SKILL.md` + `reference.md`) that auto-loads on matching files (`paths`) and is
also callable as `/frontend-*`. Stack: TypeScript + React (Next.js App Router
when present); the same boundaries apply to Vue/Svelte with names swapped.

- [frontend-architecture](skills/frontend-architecture/SKILL.md) — component boundaries (Route/Page → Container → Presentational), server-vs-client state, one API boundary, Feature Slice decision (umbrella)
- [frontend-state-data](skills/frontend-state-data/SKILL.md) — server vs client state, state decision table, four fetch states, TanStack Query/RSC, no remote-in-store, derive-don't-store
- [frontend-module-structure](skills/frontend-module-structure/SKILL.md) — app/components/features/lib layout, one styling system, one state library, route-level code-splitting & lazy boundaries
- [frontend-api-contract](skills/frontend-api-contract/SKILL.md) — one API client module, typed boundary (no `any`), error normalization, runtime response validation
- [frontend-accessibility](skills/frontend-accessibility/SKILL.md) — **a11y safety guard**: semantic controls (no div-onClick), labels/alt, focus management, keyboard, platform-over-library
- [frontend-security](skills/frontend-security/SKILL.md) — **vibe-coding security guard**: catches AI-generated vulnerabilities (XSS, bundle secrets, token storage, CSRF, open redirect, postMessage, SSRF/injection in server code, prototype pollution, hallucinated deps)
- [frontend-figma-to-code](skills/frontend-figma-to-code/SKILL.md) — Figma → React/Next via the shared `scripts/figma` manifest + DTCG tokens (node→component, token→theme); generated code must still pass the a11y + security floors
