# ios-state-concurrency — Reference

Deep-dive for `SKILL.md`. Enum state, route data, `@MainActor`, actors,
`Sendable`, Task lifecycle, Combine bridging. Decision criteria live in `SKILL.md`.

## 1. Model illegal states unrepresentable

```swift
// ❌ Parallel optionals — allows loading && error && content at once
struct HomeState { var isLoading = false; var items: [Item]?; var error: String? }

// ✅ One enum — exactly one phase is possible
enum HomeState {
    case loading
    case loaded([Item])
    case failed(AppError)   // typed error, mapped from the repository
}
```

## 2. @Observable + @MainActor ViewModel

```swift
@MainActor @Observable
final class HomeViewModel {
    private(set) var state: HomeState = .loading   // mutated only on the main actor
    private(set) var route: [HomeRoute] = []       // navigation as data
    private let repo: OrderRepository
    private var loadTask: Task<Void, Never>?

    init(repo: OrderRepository) { self.repo = repo }

    func onAppear() {
        loadTask = Task {                          // owned Task
            do { state = .loaded(try await repo.load()) }
            catch is CancellationError { }
            catch { state = .failed(AppError(error)) }  // typed error case
        }
    }
    func onDisappear() { loadTask?.cancel() }      // screen-scoped → cancel
    func openDetail(_ id: Item.ID) { route.append(.detail(id)) } // route data, not imperative
}
```

```swift
// View maps route data to navigation; the ViewModel never pushes imperatively.
@Bindable var model: ItemListViewModel               // @Observable → @Bindable enables the $ binding
NavigationStack(path: $model.route) { /* ... */ }
```

## 3. Actor for shared mutable state

```swift
// ❌ a shared mutable class passed across tasks → data race
final class ImageCache { var store: [URL: Data] = [:] }

// ✅ actor isolates the mutable state
actor ImageCache {
    private var store: [URL: Data] = [:]
    func data(for url: URL) -> Data? { store[url] }
    func insert(_ data: Data, for url: URL) { store[url] = data }
}
```

## 4. Sendable — deliberate, never `@unchecked` to silence

```swift
// ✅ value type of Sendable fields is Sendable
struct Money: Sendable { let minorUnits: Int; let currency: String }

// ❌ silencing the compiler hides a real race
final class Session: @unchecked Sendable { var token: String? }  // NO
// ✅ isolate it instead (actor, or @MainActor, or make it an immutable value)
```

## 5. Task cancellation in long work

```swift
func sync() async throws {
    for page in 0..<pages {
        try Task.checkCancellation()   // honor cancellation
        try await fetch(page)
    }
}
```

## 6. Bridge Combine / callbacks at the boundary

```swift
// ✅ wrap an old callback API once, expose async/await inward
func value() async throws -> Value {
    try await withCheckedThrowingContinuation { cont in
        legacy.fetch { result in cont.resume(with: result) }
    }
}
// New flows use async/await directly — no new Combine pipelines / completion handlers.
```

## 7. Review checklist

- [ ] One state type per screen; exclusive phases as an `enum` (no parallel optionals).
- [ ] ViewModel `@Observable` + `@MainActor`; state mutated on the main actor.
- [ ] Navigation is route data; no imperative push/present from the ViewModel.
- [ ] No `SwiftUI`/`UIKit` view-type imports in the ViewModel.
- [ ] Screen-scoped `Task`s owned and cancelled on disappear; long work checks cancellation.
- [ ] Shared mutable state actor-isolated or `Sendable`; no `@unchecked Sendable` silencer.
- [ ] New async code uses async/await; Combine/callbacks bridged at the boundary.

## Official references

- Observation framework: https://developer.apple.com/documentation/observation
- Swift Concurrency: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/
- Updating an app to use strict concurrency: https://developer.apple.com/documentation/swift/updating-an-app-to-use-strict-concurrency
- `@MainActor`: https://developer.apple.com/documentation/swift/mainactor
- NavigationStack: https://developer.apple.com/documentation/swiftui/navigationstack
- Team baseline: [../../guidance.md](../../guidance.md)
