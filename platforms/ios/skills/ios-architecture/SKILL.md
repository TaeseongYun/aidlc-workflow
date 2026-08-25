---
name: ios-architecture
description: iOS architecture · app-architecture skeleton reference rules. Covers dependency flow (View (SwiftUI) → Action → ViewModel/Store → UseCase (optional) → Repository → DataSource / Platform Adapter, never reversed), layer responsibilities, ViewModels not importing SwiftUI/UIKit beyond state modeling, navigation expressed as route data (not imperative presentation), domain models free of UI deps, platform frameworks (CoreLocation/AVFoundation/StoreKit/UserNotifications) behind project-owned protocol adapters, and the Feature Slice decision table (View-only / MVVM / +UseCase / reducer-store). Swift, SwiftUI, Swift Concurrency, Observation (@Observable), SPM modules. Use when designing, reviewing, or refactoring iOS architecture, or deciding which slice a screen needs. The umbrella skill tying the other five iOS skills together.
when_to_use: Designing iOS app architecture, judging layer boundaries, placing ViewModel/Repository/Adapter, deciding navigation-as-data, choosing a feature slice, architecture refactor/review. Also for SwiftUI/MVVM architecture, clean/layered architecture, platform-framework wrapping requests.
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# ios-architecture — app-architecture skeleton

The spine of an iOS app: dependency flow, layer responsibilities, and
navigation-as-data, pinned as always-referenced rules. Project `ctx/` overrides
this skill, and this skill overrides the agent's general knowledge. Deeper
material (layer responsibilities, adapter samples, slice examples) lives in
[reference.md](./reference.md).

## Scope

- In scope: layer placement, dependency direction, navigation intent, slice
  selection, and refactor judgment for new iOS features. Swift + SwiftUI +
  Swift Concurrency + Observation, SPM modules.
- Out of scope: ViewModel state modeling detail, module/DI layout, concurrency
  isolation, deep-link/external surface detail, security vulnerability patterns
  — each delegated to the Related skills below.

## Core rules — dependency flow and layer responsibilities

Dependency flows top→down, one-way, **never reversed**.

```
View (SwiftUI) → Action → ViewModel/Store → UseCase (optional) → Repository → DataSource / Platform Adapter
```

### Do

- **View**: render state and send actions only. No business logic, no network/
  persistence calls, no UIKit reach-through unless wrapped → [ios-state-concurrency].
- **ViewModel/Store**: `@Observable`, `@MainActor`-bound for state mutation.
  Owns screen state as one type; expresses navigation as **route data**, not by
  presenting views → [ios-state-concurrency].
- **UseCase** (optional): business rules across sources/aggregates. Add only on
  a real signal.
- **Repository**: returns domain models. DTO ↔ domain mapping in the data layer.
  Domain models have **no** SwiftUI/UIKit dependencies.
- **Platform Adapter**: CoreLocation/AVFoundation/StoreKit/UserNotifications sit
  behind project-owned **protocol** adapters, injected — testable without the
  device framework → [ios-platform-adapters].

### Don't

- A View performing network/persistence calls or holding business rules → forbidden.
- ViewModel importing SwiftUI/UIKit beyond what state modeling requires → forbidden.
- Navigation performed imperatively from a ViewModel instead of via route data → forbidden.
- Domain models depending on SwiftUI/UIKit → forbidden.
- Touching a platform framework directly outside its protocol adapter → forbidden.
- A lower layer depending on a higher layer → forbidden (reversed dependency).

## Feature Slice Decision Table

Start at the **smallest** slice that fits. Move up only on a **real signal**, not
speculation.

| Situation | Slice | Signal to move up |
|-----------|-------|-------------------|
| Stateless view or local `@State` only | View only, no ViewModel | State outlives the view or drives async work |
| Screen state + async data | MVVM: Route → ViewModel → View | Rule spans sources / reused business logic |
| Multi-source orchestration / reused rules | + UseCase → Repository → DataSource | Optimistic updates / complex effects |
| Optimistic updates, complex effect mgmt | reducer-style store (TCA-like) | — (only if the project already uses one) |

- **Don't build ahead**: do not introduce TCA into a plain-MVVM codebase for one
  screen, or add a UseCase layer before a real requirement forces it.
- Do not create a ViewModel that only forwards to a repository.

## Refactor / red-flag signals

- A View performing network/persistence calls or holding business rules.
- State mutation off the main actor, or `@unchecked Sendable` as a compiler silencer.
- Navigation performed imperatively from a ViewModel instead of via route data.
- Parallel optionals encoding what an enum state should.
- A feature importing another feature's Live/impl target instead of its interface.
- Secrets in `UserDefaults`; force-unwraps on data crossing a trust boundary.
- A screen with no preview; a god-package where feature boundaries used to be.

## Related skills

Umbrella skill. Drill down into each concern's detail below:

- [ios-state-concurrency](../ios-state-concurrency/SKILL.md) — `@Observable`/`@MainActor` ViewModel · one state type (enum) · navigation route data · actor isolation · `Sendable` · Task cancellation · async/await over Combine.
- [ios-module-structure](../ios-module-structure/SKILL.md) — thin app target + SPM packages · Interface/Live split · composition-root DI.
- [ios-platform-adapters](../ios-platform-adapters/SKILL.md) — system frameworks behind protocol adapters · permission-denied state · repository DTO↔domain mapping · UserDefaults/Keychain placement.
- [ios-navigation-deeplink](../ios-navigation-deeplink/SKILL.md) — URL schemes / Universal Links external contract · deep-link validation.
- [ios-security](../ios-security/SKILL.md) — **vibe-coding security guard**: blocks vulnerable patterns in AI-generated code.

## References

- Team guidelines (parent doc): [../../guidance.md](../../guidance.md)
- Deeper material: [reference.md](./reference.md)
- Architecting SwiftUI apps: https://developer.apple.com/documentation/swiftui/model-data
- Observation: https://developer.apple.com/documentation/observation
- Swift Package Manager: https://www.swift.org/documentation/package-manager/
