---
name: ios-state-concurrency
description: iOS ViewModel state + Swift Concurrency rules (@Observable/@MainActor state modeling with actors, Sendable, Task lifecycle). One state type per screen modeled so illegal combinations are unrepresentable (enum for loading/content/error over parallel optionals); ViewModel is @Observable (ObservableObject on older targets) and @MainActor-bound for state mutation; navigation expressed as route data (enum), not imperative presentation; ViewModel imports no SwiftUI/UIKit beyond state modeling; async work runs in Tasks the ViewModel owns and cancels on disappear where screen-scoped; shared mutable state crossing concurrency domains is actor-isolated or Sendable, never @unchecked Sendable as a compiler silencer; async/await over Combine for new code with remaining Combine wrapped at the boundary, no new completion-handler APIs unless bridging. Use when writing/reviewing a ViewModel/Store/actor, modeling state, or handling isolation/Task/Sendable, and when a parallel-optional, off-main-actor mutation, or data-race smell appears.
when_to_use: When designing/implementing/reviewing a ViewModel/Store state type, modeling loading/content/error, splitting state vs navigation route data, writing async/await/actors/Sendable/Task code, deciding actor isolation, migrating Combine/completion handlers, or fixing an off-main-actor / data-race / Sendable warning.
paths: **/*ViewModel.swift, **/*Store.swift, **/*State.swift, **/*Actor.swift, **/ViewModels/**/*.swift
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# ios-state-concurrency

Rules for a ViewModel's state modeling and the Swift Concurrency it runs on. The
state and concurrency items from `guidance.md` expanded to an enforceable level.
Project `ctx/` overrides this document. Deeper material (enum-state samples,
actor/Sendable patterns, Combine bridging) lives in [reference.md](./reference.md).

## Scope

- In scope: `*ViewModel.swift`/`*Store.swift`/`*Actor.swift` state types, state
  modeling, navigation route data, `@MainActor` isolation, actors, `Sendable`,
  Task ownership/cancellation, async/await adoption.
- Covers: one-state-per-screen, illegal-states-unrepresentable,
  navigation-as-data, safe concurrency for state mutation and shared data.
- Doesn't cover: layer placement → [ios-architecture], module/DI →
  [ios-module-structure], deep-link contract → [ios-navigation-deeplink],
  platform-framework adapters → [ios-platform-adapters].

## Core rules

Do:

- **One state type per screen**, modeled so illegal combinations are
  unrepresentable — an `enum` for loading/content/error, not parallel optionals
  (`isLoading` + `data?` + `error?`).
- ViewModel is **`@Observable`** (or `ObservableObject` on older targets) and
  **`@MainActor`**-bound for state mutation. UI-observed state is updated on the
  main actor.
- **Navigation is route data**: the ViewModel sets/append an `enum Route` value;
  the View maps it to a `NavigationStack`. No imperative pushing/presenting.
- ViewModel imports **no SwiftUI/UIKit** beyond what state modeling requires;
  actions are method calls, state is read-only outward.
- **Own your Tasks.** Screen-scoped async work runs in a `Task` the ViewModel
  holds and **cancels on disappear**; long work checks `Task.isCancelled` /
  `try Task.checkCancellation()`.
- **Shared mutable state crossing concurrency domains is actor-isolated or
  `Sendable`.** Use an `actor` for shared mutable state (caches, coordinators);
  make value types `Sendable` deliberately.
- **async/await over Combine** for new code; wrap remaining Combine at the
  boundary (`AsyncSequence`/continuation). No new completion-handler APIs unless
  bridging.
- Map repository failures to a **typed error case** in state; raw errors don't
  reach the View → [ios-platform-adapters].

Don't:

- Encode screen state as a bag of independent optionals/booleans.
- Present/push views imperatively from the ViewModel.
- Import `SwiftUI`/`UIKit` for view types or hold a `UIViewController` in a ViewModel.
- Mutate `@Observable`/UI state off the main actor.
- Use **`@unchecked Sendable`** to silence the compiler — fix isolation instead.
- Detach a `Task { }` for screen-scoped work and leave it uncancelled.
- Add Combine pipelines / new completion-handler APIs where async/await fits.

## Decision table

| Nature of data / need | Where / Use |
|---|---|
| Persistent screen state (list, form, loading/error) | ViewModel state — one `enum`/`struct` |
| Exclusive phases (loading/content/error/empty) | `enum` case per phase |
| Navigation intent (open detail, present sheet) | route data (`enum Route`) |
| View-local, ephemeral (focus, scroll, toggle) | View `@State` |
| Mutate UI-observed state | `@MainActor` (ViewModel/Store) |
| Shared mutable state across tasks | an `actor` |
| Pass a value across actors | make it `Sendable` (value type of Sendable fields) |
| Screen-scoped async work | `Task` owned by the ViewModel, cancelled on disappear |
| Consume an old Combine/callback API | bridge at the boundary → async/await |
| "The compiler complains about Sendable" | fix isolation — **not** `@unchecked Sendable` |

## Refactor / red-flag signals

- Parallel optionals encoding what an enum state should.
- Navigation performed imperatively from a ViewModel.
- `import SwiftUI`/`UIKit` in a ViewModel for view types.
- State mutation off the main actor (missing `@MainActor`).
- `@unchecked Sendable` used as a compiler silencer.
- A screen-scoped `Task` never cancelled; long async work with no cancellation checks.
- Shared mutable reference type passed across tasks without an actor.
- New Combine pipelines / completion-handler APIs where async/await fits.

## References

- Observation: https://developer.apple.com/documentation/observation
- Managing model data (MV pattern): https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
- Swift Concurrency: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/
- `@MainActor`: https://developer.apple.com/documentation/swift/mainactor · Sendable: https://developer.apple.com/documentation/swift/sendable
- NavigationStack (path): https://developer.apple.com/documentation/swiftui/navigationstack
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Enum-state samples, actor/Sendable patterns, Combine bridging: [`reference.md`](reference.md)
