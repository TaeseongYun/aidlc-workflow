---
name: rn-navigation-lifecycle
description: React Native navigation, deep-link, and mobile-lifecycle rules. Navigation uses typed route params (ParamList types); deep links follow incoming URL → linking config → param validation → screen, and deep-link params are never trusted without validation (external URLs are a trust boundary); the mobile lifecycle is handled — app background/foreground via AppState, offline/poor network via query retry + a user-visible state, and permission-denied as a designed state for any capability that asks. Use when defining navigators/routes, wiring linking config, validating deep-link params, or handling AppState/offline/permission paths.
when_to_use: When adding a route/navigator, typing route params, wiring deep links/linking config, validating deep-link input, or handling app background/foreground, offline/poor-network, or permission-denied paths. Also for React Navigation/Expo Router param typing and deep-link trust-boundary validation.
paths: **/navigation/**, **/app/**, **/*Navigator.tsx, **/*Screen.tsx, **/linking.ts, **/linking.config.ts, **/*route*.ts
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# rn-navigation-lifecycle

Rules for routing, deep links, and the mobile lifecycle. The navigation and
lifecycle items of `guidance.md` expanded to an enforceable level. Project
`ctx/` overrides this document. Deeper material lives in [reference.md](./reference.md).

## Scope

- In scope: typed route params, deep-link validation flow, `AppState`
  background/foreground, offline/poor-network handling, permission-denied paths.
- Covers: React Navigation / Expo Router params, deep-link trust boundary,
  mobile lifecycle states.
- Doesn't cover: native-module wrapping → [rn-native-modules], state/persistence
  → [rn-state-data], component boundaries → [rn-architecture], input-security
  detail → [rn-security].

## Core rules

Do:

- **Type route params** with a `ParamList`. Screens read typed params; no
  `any`/untyped `route.params`.
- **Deep links flow: incoming URL → linking config → param validation → screen.**
  External URLs are a **trust boundary** — validate params before use; undefined
  input lands on a defined fallback → [rn-security].
- **Handle background/foreground** (`AppState`): pause/resume work, refresh stale
  data on foreground where it matters.
- **Offline / poor network is a designed state.** Configure query retry and show
  a user-visible offline/error state → [rn-state-data]. Don't leave a permanent spinner.
- **Permission-denied is a designed state** for any capability that asks
  (camera, location, notifications) — an explicit UI path, not an error toast.
- **Navigation is data-driven**: screens navigate by name + typed params;
  presentational components don't own navigation.

Don't:

- Trust deep-link params (ids, redirect targets) without validation.
- Map an incoming URL straight to a screen with no linking config / validation.
- Read `route.params` as untyped/`any`.
- Leave offline/poor-network as an infinite spinner or a silent failure.
- Handle permission denial as a crash/toast instead of a designed state.
- Couple a presentational component to the navigator.

## Decision table

| Need | Approach |
|---|---|
| Navigate to a screen | `navigation.navigate('Name', typedParams)` |
| Pass data to a route | typed `ParamList` params (validated if externally reachable) |
| Handle a deep/universal link | linking config → validate params → screen (reject/fallback on bad input) |
| App returns to foreground | `AppState` listener → refresh stale queries |
| Offline / request fails | query retry + visible offline/error state |
| Capability permission | request in the adapter; surface granted/denied as state |

## Refactor / red-flag signals

- Deep-link params used without validation.
- An incoming URL mapped to a screen with no linking config / validation.
- Untyped `route.params` / `any` on navigation params.
- Offline/poor-network shown as a permanent spinner or silent no-op.
- Missing permission-denied/offline handling on a capability path.
- A presentational component driving navigation directly.

## References

- React Navigation — type checking & params: https://reactnavigation.org/docs/typescript/
- React Navigation — deep linking: https://reactnavigation.org/docs/deep-linking/
- Expo Router: https://docs.expo.dev/router/introduction/
- AppState: https://reactnative.dev/docs/appstate
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Param typing, linking config + validation, AppState/offline samples: [`reference.md`](reference.md)
