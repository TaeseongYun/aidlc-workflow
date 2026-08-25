# iOS Architecture — Current Guidance

Baseline for iOS work: Swift, SwiftUI, Swift Concurrency (async/await, actors),
the Observation framework (`@Observable`), Swift Package Manager modules.
Project `ctx/` overrides this document; this document overrides the agent's
general knowledge.

## Boundaries

Dependency flow (never reversed):

```
View (SwiftUI) -> Action -> ViewModel/Store -> UseCase (optional) -> Repository -> DataSource / Platform Adapter
```

- Views render state and send actions. No business logic, no direct network or
  persistence calls, no UIKit reach-through unless wrapped.
- ViewModels are `@Observable` (or `ObservableObject` on older targets) and
  `@MainActor`-bound for state mutation. Async work runs in `Task`s owned by
  the ViewModel; cancel on disappear where the work is screen-scoped.
- ViewModels must not import SwiftUI/UIKit types beyond what state modeling
  requires. Navigation intent is expressed as data (route enum), not by
  presenting views directly.
- Repositories return domain models; DTO ↔ domain mapping lives in the data
  layer. Domain models have no SwiftUI/UIKit dependencies.
- Platform frameworks (CoreLocation, AVFoundation, StoreKit, UserNotifications)
  sit behind project-owned protocol adapters, injected — testable without the
  device framework.
- Shared mutable state crossing concurrency domains is actor-isolated or
  `Sendable`; do not sprinkle `@unchecked Sendable` to silence the compiler.

## External Surface

- URL schemes and Universal Links are the external contract (analogue of
  Android's exported Intents). Document each entry: URL pattern, parameters
  with types, and validation rules.
- Deep link flow: App/Scene receives URL → host/path/parameter validation →
  feature route contract → navigation state construction → SwiftUI entry.
  Never map an unvalidated URL straight onto navigation state.
- Incoming URLs, user activities, and extension payloads are trust boundaries:
  validate before use; undefined input lands on a defined fallback.

## Module Baseline

Thin app target + SPM packages:

```
App/                     # app target: entry, DI wiring, scene/lifecycle
Packages/
  CoreModel/             # domain models, no UI deps
  CoreDomain/            # use cases (only when orchestration exists)
  CoreData*/             # repositories, data sources, API clients
  DesignSystem/          # tokens, shared views, modifiers
  Feature<Name>/         # one package per feature; split Interface/Live
                         # targets ONLY when a second consumer needs it
```

- Keep the app target minimal: composition root and lifecycle only.
- Dependency injection is constructor/initializer injection through the
  composition root. Use the project's existing container if one exists; do not
  introduce a DI framework for a project that composes by hand.

## Feature Slice Decision Table

| Situation | Slice |
|-----------|-------|
| Stateless view or local `@State` only | View only, no ViewModel |
| Screen state + async data | MVVM: Route → ViewModel → View |
| Multi-source orchestration or reused business rules | + UseCase → Repository → DataSource |
| Optimistic updates, complex effect management | Reducer-style store (TCA-like) — only if the project already uses one |

Start at the smallest slice that fits; do not introduce TCA into a plain-MVVM
codebase for one screen.

## Rules

- One state type per screen, modeled so illegal combinations are
  unrepresentable (enum for loading/content/error over parallel optionals).
- async/await over Combine for new code; wrap remaining Combine at the
  boundary. No completion-handler APIs in new code unless bridging.
- All user-facing strings via the project's localization mechanism; layout via
  design-system tokens.
- Persist small preferences in `UserDefaults` behind an adapter; anything
  structured goes through the repository layer.
- Keychain for secrets — never `UserDefaults`.
- Every new screen ships with `#Preview` for its main states.
- Follow existing test conventions; ViewModel tests drive actions and assert
  state transitions with fake repositories.

## Feature Implementation Checklist

1. External contract if reachable via URL/Universal Link: pattern, params,
   validation.
2. State type + actions (screen contract).
3. View + components + previews.
4. ViewModel wiring state ↔ actions ↔ navigation route data.
5. UseCase/Repository/DataSource as the decision table requires.
6. Composition-root wiring; Info.plist/entitlements entries if the surface
   changed.
7. Tests: state transitions + URL-validation cases for external entries.

## Refactor Signals

- A View performing network/persistence calls or holding business rules.
- State mutation off the main actor, or `@unchecked Sendable` used as a
  compiler silencer.
- Navigation performed imperatively from a ViewModel instead of via route
  data.
- Parallel optionals encoding what an enum state should.
- A feature importing another feature's Live/impl target instead of its
  interface.
- Secrets in `UserDefaults`; force-unwraps on data crossing a trust boundary.
- A screen with no preview; a god-package where feature boundaries used to be.

## Detailed Skills

This baseline is expanded into six topic skills under
[`skills/`](skills/README.md). Each is a reference-knowledge skill
(`SKILL.md` + `reference.md`) that auto-loads on matching files (`paths`) and is
also callable as `/ios-*`. Stack: Swift + SwiftUI + Swift Concurrency + the
Observation framework (`@Observable`), SPM modules.

- [ios-architecture](skills/ios-architecture/SKILL.md) — dependency flow, layer responsibilities, `@MainActor`/actor isolation, navigation-as-data, Feature Slice decision (umbrella)
- [ios-state-concurrency](skills/ios-state-concurrency/SKILL.md) — one state type per screen (enum, not parallel optionals), `@Observable`/`@MainActor`, Task ownership/cancellation, `Sendable`/actor isolation (no `@unchecked` silencer), async/await over Combine
- [ios-module-structure](skills/ios-module-structure/SKILL.md) — thin app target + SPM packages, Interface/Live split timing, composition-root DI (no DI framework)
- [ios-platform-adapters](skills/ios-platform-adapters/SKILL.md) — system frameworks behind injected protocol adapters, permission-denied as a designed state, repository DTO↔domain mapping, UserDefaults/Keychain placement
- [ios-navigation-deeplink](skills/ios-navigation-deeplink/SKILL.md) — URL schemes / Universal Links external contract, deep-link parameter validation, trust-boundary fallback, route data
- [ios-security](skills/ios-security/SKILL.md) — **vibe-coding security guard**: catches AI-generated vulnerabilities (Keychain vs UserDefaults, embedded secrets, ATS/TLS bypass, deep-link input, WKWebView, log/pasteboard leaks, weak crypto, Data Protection, hallucinated SPM deps)
