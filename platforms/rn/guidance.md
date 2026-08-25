# React Native Architecture — Current Guidance

Baseline for React Native work: TypeScript, React Navigation (or Expo Router),
Turbo Modules/Fabric for native capability. Shares the web frontend's React
boundaries (see `../frontend/guidance.md`) plus mobile-specific rules
below. Project `ctx/` overrides this document; this document overrides the
agent's general knowledge.

## Boundaries

```
Screen (route) -> Container (data + state wiring) -> Presentational Components
                     |
                     v
      Server state (TanStack Query)  |  Client state (UI/session)
                     |
                     v
      API client module -> Backend
      Native Module Adapter -> Turbo Module / platform SDK
```

- Presentational components: props in, callbacks out; no fetching, no store
  access, no navigation coupling, no native-module calls.
- Remote data lives in the server-state layer (TanStack Query) with explicit
  loading/error/empty/content states — never mirrored into a global store.
- All backend calls go through one API client module; API response types are
  declared, no `any` at the boundary.
- **Native capability goes through a project-owned adapter interface** wrapping
  the native module. JS feature code never imports a third-party native
  module directly outside the adapter — this keeps native churn (and mocking
  in tests) in one place.
- Navigation: typed route params (`ParamList` types). Deep links follow:
  incoming URL → linking config → param validation → screen. Never trust
  deep-link params without validation — external URLs are a trust boundary.

## State Decision Table

| Situation | State home |
|-----------|-----------|
| One component's UI state | `useState`/`useReducer` local |
| Shared within a screen/feature | lift up, or context for stable values |
| Remote data | TanStack Query — never a global store |
| Cross-cutting client state (session, theme) | the project's existing store (Zustand/Redux); do not add a second |
| Persisted client state | storage adapter (MMKV/AsyncStorage) behind the store — secrets go to Keychain/Keystore via a secure-storage module, never AsyncStorage |

## Rules

- Lists use `FlatList`/`FlashList` with stable keys — never `map` inside a
  `ScrollView` for unbounded data.
- Animations/gestures use Reanimated worklets and the project's existing
  gesture setup; do not drive animation state through React renders.
- Platform divergence lives in the adapter layer or `.ios.tsx`/`.android.tsx`
  files at the component boundary — not `Platform.OS` branches scattered
  through business logic.
- Handle the mobile lifecycle: app background/foreground (`AppState`),
  offline/poor network (query retry + user-visible state), and permission
  denial paths for any capability that asks (camera, location, notifications).
  Permission-denied is a designed state, not an error toast.
- Accessibility is a safety guard: `accessibilityRole`/`accessibilityLabel`
  on interactive elements, touch targets ≥ 44pt.
- Follow the project's styling convention (StyleSheet, styled-components, or
  NativeWind) — do not introduce a second one.
- New native dependency = real justification (ties to
  `core/lazy-implementation.md`): every native module raises upgrade cost;
  prefer JS-only solutions when performance allows.
- Follow existing test conventions: component behavior via testing-library,
  native adapters mocked at the adapter interface.

## Module Baseline

Follow the project's layout. Absent one:

```
src/
  app/ or navigation/    # navigators, linking config, route params
  components/            # shared presentational components
  features/<name>/       # feature screens, hooks, api calls
  lib/                   # api client, storage adapter, native adapters
  theme/                 # tokens, styling setup
ios/ android/            # native projects — touched only via modules/config
```

## Feature Implementation Checklist

1. Route + typed params + linking config with param validation (if deep-link
   reachable).
2. API types + client functions for new endpoints (approved contract only).
3. Screen with the four fetch states; presentational components below.
4. Client-state wiring only for genuine client state; persistence via the
   storage adapter.
5. Native adapter (and native module config) if platform capability is
   involved — including the permission-denied path.
6. Tests: main-flow behavior, param validation, permission/offline states
   where relevant.

## Refactor Signals

- A component importing a native module or `Platform.OS`-branching business
  logic.
- Remote data copied into a global store; `any` on API responses.
- Unbounded `.map` lists inside `ScrollView`; keys derived from array index
  on reorderable data.
- Deep-link params used without validation.
- Secrets or tokens in AsyncStorage.
- Missing permission-denied/offline handling on a capability path.
- A second styling or state library alongside the existing one.

## Detailed Skills

This baseline is expanded into six topic skills under
[`skills/`](skills/README.md). Each is a reference-knowledge skill
(`SKILL.md` + `reference.md`) that auto-loads on matching files (`paths`) and is
also callable as `/rn-*`. RN shares the web frontend's React boundaries
([`../frontend/guidance.md`](../frontend/guidance.md)); these skills are the
mobile delta on top. Stack: TypeScript + React Navigation / Expo Router +
Turbo Modules / Fabric.

- [rn-architecture](skills/rn-architecture/SKILL.md) — Screen → Container → Presentational, server-vs-client state, one API boundary, native-module boundary, Feature Slice decision (umbrella)
- [rn-state-data](skills/rn-state-data/SKILL.md) — server vs client state, four fetch states, persisted state via a storage adapter, secure storage for secrets (never AsyncStorage)
- [rn-native-modules](skills/rn-native-modules/SKILL.md) — native adapter interface over Turbo Modules/Fabric, `Platform.OS` boundary, native-dependency justification, permission-denied state
- [rn-navigation-lifecycle](skills/rn-navigation-lifecycle/SKILL.md) — typed route params, deep-link validation, AppState background/foreground, offline/network, permission paths
- [rn-performance-ux](skills/rn-performance-ux/SKILL.md) — `FlatList`/`FlashList` + stable keys, Reanimated worklets, one styling system, **accessibility safety guard** (roles/labels, ≥44pt)
- [rn-security](skills/rn-security/SKILL.md) — **vibe-coding security guard**: catches AI-generated vulnerabilities (bundle secrets, insecure storage, TLS bypass, deep-link input, WebView, log leakage, weak crypto, insecure manifests, hallucinated deps)
