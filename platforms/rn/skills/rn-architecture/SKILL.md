---
name: rn-architecture
description: React Native architecture · app-architecture skeleton reference rules. Covers the boundary flow (Screen (route) → Container (data + state wiring) → Presentational Components, never reversed), server state vs client state separation, all backend calls through one API client module, native capability behind a project-owned native-module adapter interface, typed navigation params, and the Feature Slice decision table. TypeScript + React Navigation/Expo Router + Turbo Modules/Fabric; shares the web frontend's React boundaries plus mobile-specific rules. Use when designing, reviewing, or refactoring RN architecture, or deciding which slice (local / container / query layer / native adapter) to take. The umbrella skill tying the other five RN skills together.
when_to_use: Designing React Native app architecture, judging component boundaries, placing Container/Presentational/API-client/native-adapter, deciding server vs client state, choosing a feature slice, architecture refactor/review. Also for RN + React Navigation/Expo Router structure, native-module boundary, server-vs-client-state placement requests.
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# rn-architecture — app-architecture skeleton

The spine of a React Native app: component boundaries, the server-vs-client
state split, the single API boundary, and the native-module boundary, pinned as
always-referenced rules. RN shares the web frontend's React boundaries
([`../../../frontend/guidance.md`](../../../frontend/guidance.md)) plus the
mobile-specific rules here. Project `ctx/` overrides this skill, and this skill
overrides the agent's general knowledge. Deeper material lives in
[reference.md](./reference.md).

## Scope

- In scope: component-layer placement, data-flow direction, server/client state
  home, native-module boundary, slice selection, and refactor judgment for new
  RN features. Stack: TypeScript + React Navigation / Expo Router + Turbo
  Modules / Fabric.
- Out of scope: state/fetch/persistence detail, native-adapter detail,
  navigation/lifecycle, performance/UX, security — each delegated to the Related
  skills below.

## Core rules — boundary flow and layer responsibilities

Data flows top→down, one-way, **never reversed**.

```
Screen (route) → Container (data + state wiring) → Presentational Components
                     │
                     ├─ Server state (TanStack Query)  ─┐
                     └─ Client state (UI/session)        │
                                                         ▼
                        API client module → Backend
                        Native Module Adapter → Turbo Module / platform SDK
```

### Do

- **Screen (route)**: the data-fetch + navigation boundary. Owns the four fetch
  states (loading / error / empty / content) → [rn-state-data].
- **Container**: wires data + state, passes plain props down.
- **Presentational component**: props in, callbacks out. No fetching, no store
  access, no navigation coupling, **no native-module calls**.
- **Server state ≠ client state.** Remote data lives in TanStack Query with
  caching + invalidation; client state is UI/session only → [rn-state-data].
- **One API client module** for all backend calls. Typed responses, no `any` at
  the boundary (see [frontend-api-contract](../../../frontend/skills/frontend-api-contract/SKILL.md)).
- **Native capability behind a project-owned adapter interface** wrapping the
  native module. JS feature code never imports a third-party native module
  directly outside the adapter → [rn-native-modules].
- **Typed navigation params** (`ParamList`); deep links validate params →
  [rn-navigation-lifecycle].

### Don't

- A presentational component fetching data, reading a store, navigating, or
  calling a native module → forbidden.
- Remote data copied into a global store and hand-synced → forbidden.
- Raw `fetch` scattered in components instead of the API client module → forbidden.
- A third-party native module imported directly in feature code → forbidden.
- A second state library or styling system next to the existing one → forbidden
  → [rn-performance-ux].
- A lower layer reaching up into a screen/container → forbidden (reversed flow).

## Feature Slice Decision Table

Start at the **smallest** slice that fits. Move up only on a **real signal**, not
speculation.

| Situation | Slice | Signal to move up |
|-----------|-------|-------------------|
| One component's UI state | local `useState`/`useReducer` | state shared across the screen |
| Shared UI state in a screen/feature | lift up / context for stable values | data comes from the server |
| Remote data on a screen | TanStack Query + container | native capability / cross-cutting state appears |
| Native capability | + project-owned native adapter | — |
| Cross-cutting client state (session, theme) | the project's existing store | — (do not add a second store) |

- **Don't build ahead**: no global store, no native module, no extra layer before
  a real requirement forces it (over-engineering).

## Refactor / red-flag signals

- A component importing a native module or `Platform.OS`-branching business logic.
- Remote data copied into a global store; `any` on API responses.
- Unbounded `.map` lists inside `ScrollView`; keys derived from array index on
  reorderable data → [rn-performance-ux].
- Deep-link params used without validation → [rn-navigation-lifecycle].
- Secrets or tokens in AsyncStorage → [rn-security].
- Missing permission-denied/offline handling on a capability path.
- A second styling or state library alongside the existing one.

## Related skills

Umbrella skill. Drill down into each concern's detail below:

- [rn-state-data](../rn-state-data/SKILL.md) — server vs client state · fetch states · persisted state via storage adapter · secure storage for secrets.
- [rn-native-modules](../rn-native-modules/SKILL.md) — native adapter interface · Turbo Modules/Fabric · `Platform.OS` boundary · native-dep justification · permission-denied state.
- [rn-navigation-lifecycle](../rn-navigation-lifecycle/SKILL.md) — typed route params · deep-link validation · AppState · offline/network · permission paths.
- [rn-performance-ux](../rn-performance-ux/SKILL.md) — `FlatList`/`FlashList` · Reanimated worklets · one styling system · accessibility safety guard.
- [rn-security](../rn-security/SKILL.md) — **vibe-coding security guard**: blocks vulnerable patterns in AI-generated code.

## References

- Team guidelines (parent doc): [../../guidance.md](../../guidance.md)
- Web React boundaries (shared): [../../../frontend/guidance.md](../../../frontend/guidance.md)
- Deeper material: [reference.md](./reference.md)
- React Native architecture (New Architecture): https://reactnative.dev/architecture/landing-page
- React Navigation: https://reactnavigation.org/ · TanStack Query: https://tanstack.com/query/latest
