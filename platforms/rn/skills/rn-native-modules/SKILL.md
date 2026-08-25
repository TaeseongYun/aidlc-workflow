---
name: rn-native-modules
description: React Native native-module rules (adapter boundary, Turbo Modules/Fabric, platform divergence, permissions). Native capability goes through a project-owned adapter interface wrapping the native module — JS feature code never imports a third-party native module directly outside the adapter; platform divergence lives in the adapter layer or .ios.tsx/.android.tsx files at the component boundary, not Platform.OS branches scattered through business logic; every new native dependency needs real justification (native modules raise upgrade cost — prefer JS-only when performance allows); permission-denied is a designed state, not an error toast; native adapters are mocked at the adapter interface in tests. Use when wrapping native capability, adding a native dependency, handling platform divergence, or catching direct native imports / scattered Platform.OS.
when_to_use: When wrapping a native module behind an adapter, adding/justifying a native dependency, handling iOS/Android divergence, wiring a permission flow, or catching direct native-module imports or Platform.OS branching in business logic.
paths: **/lib/native/**, **/*Adapter.ts, **/*Adapter.tsx, **/*.native.ts, **/*.ios.tsx, **/*.android.tsx, **/modules/**/*.ts
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# rn-native-modules

Rules for the native-module boundary. The native-capability and platform-
divergence items of `guidance.md` expanded to an enforceable level. Project
`ctx/` overrides this document. Deeper material lives in [reference.md](./reference.md).

## Scope

- In scope: wrapping native modules behind an adapter interface, Turbo Modules /
  Fabric, `Platform.OS` divergence, native-dependency justification,
  permission-denied handling, testing via the adapter interface.
- Out of scope: state/persistence → [rn-state-data], navigation/lifecycle →
  [rn-navigation-lifecycle], component boundaries → [rn-architecture], security →
  [rn-security].

## Core rules

Do:

- **Native capability behind a project-owned adapter interface.** The
  third-party native module is imported **only** inside the adapter; feature
  code depends on the interface. This isolates native churn and gives one mock point.
- **Platform divergence at the boundary.** Put OS differences in the adapter, or
  in `.ios.tsx`/`.android.tsx` files at the component boundary — **not**
  `Platform.OS` branches scattered through business logic.
- **Justify every new native dependency.** A native module raises upgrade/build
  cost and CI complexity. Prefer a JS-only solution when performance allows
  (ties to `core/lazy-implementation.md`).
- **Permission-denied is a designed state.** Any capability that asks (camera,
  location, notifications) has an explicit denied path in the UI — not a generic
  error toast.
- **Map native errors to typed results** at the adapter boundary, so feature code
  never handles raw native exceptions.
- **Test against the adapter interface.** Mock the adapter, not the native module.

Don't:

- Import a third-party native module directly in a screen/component/business logic.
- Scatter `Platform.OS === 'ios'` branches through feature code.
- Add a native dependency for what JS (or an existing dep) can do.
- Treat permission denial as an error/crash instead of a designed state.
- Let a raw native exception propagate to the UI.

## Decision table

| Need | Where it goes |
|---|---|
| Call native capability (camera, GPS, biometrics) | project-owned adapter interface; native import inside it |
| iOS vs Android behavior difference | inside the adapter, or `.ios`/`.android` file at the boundary |
| A small platform tweak in one component | `Platform.select`/`.ios.tsx`/`.android.tsx` at that component |
| New capability with no existing module | justify the native dep; prefer JS-only if perf allows |
| Permission required | request in the adapter; surface granted/denied as state |
| Map a native error | typed result/failure at the adapter |
| Test a feature using native capability | mock the adapter interface |

## Refactor / red-flag signals

- A component/business module importing a third-party native module directly.
- `Platform.OS` branches inside business logic instead of the adapter/boundary.
- A native dependency added without justification (JS would have done it).
- Permission denial handled as an error toast, not a designed state.
- Raw native exceptions reaching the UI.
- Tests mocking the native module instead of the adapter interface.

## References

- Native Modules / Turbo Modules: https://reactnative.dev/docs/turbo-native-modules-introduction
- Platform-specific code: https://reactnative.dev/docs/platform-specific-code
- Expo permissions / config plugins: https://docs.expo.dev/guides/permissions/
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Adapter interface, `.ios/.android`, permission-state samples: [`reference.md`](reference.md)
