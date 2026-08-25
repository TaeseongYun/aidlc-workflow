# ios-architecture — Reference

Deeper material for `SKILL.md`. Detailed layer responsibilities · protocol
adapter · slice samples. See `SKILL.md` for the rule summary and decision criteria.

## 1. Detailed layer responsibilities

| Layer | Owns | Forbidden | Returns/Exposes |
|-------|------|-----------|-----------------|
| View (SwiftUI) | render state, send actions, `#Preview` | business logic, network/persistence, UIKit reach-through | UI |
| ViewModel/Store | screen state (`@Observable`/`@MainActor`), action→state, route data | SwiftUI/UIKit beyond state modeling, imperative navigation | one state type + route |
| UseCase (optional) | business rules across sources | UI imports, DTO detail | domain result |
| Repository | domain-shaped ops, DTO↔domain mapping | business rules, UI types | domain model |
| Platform Adapter | device frameworks, error mapping | business rules | domain model / adapter result |
| Domain model | invariants, value rules | SwiftUI/UIKit imports | pure Swift |

## 2. Platform framework behind a protocol adapter

```swift
// Protocol: domain language, injected. Testable without the device framework.
protocol LocationProviding {
    func current() async throws -> Coordinate
}

// Live adapter: the only place CoreLocation is imported.
final class CoreLocationAdapter: LocationProviding {
    func current() async throws -> Coordinate {
        // CLLocationManager bridging + error mapping → domain error
    }
}

// Tests inject a fake conforming to LocationProviding — no device framework needed.
```

## 3. Navigation as route data (not imperative)

```swift
// ❌ ViewModel presenting a view / pushing imperatively
func openDetail() { navigationController.pushViewController(...) } // UIKit reach-through in VM

// ✅ ViewModel emits route data; the View layer maps it to navigation
enum Route: Hashable { case detail(id: Order.ID) }
@Observable final class ListViewModel {
    var path: [Route] = []
    func openDetail(_ id: Order.ID) { path.append(.detail(id: id)) } // data, not presentation
}
// View: NavigationStack(path:) maps Route → destination
```

## 4. Repository returns domain, maps DTOs

```swift
struct OrderRepository {
    let api: OrderAPI
    func fetch(_ id: Order.ID) async throws -> Order {
        let dto = try await api.getOrder(id.rawValue) // DTO in the data layer
        return dto.toDomain()                          // domain has no SwiftUI/UIKit deps
    }
}
```

## 5. Module baseline

Thin app target + SPM packages:

```
App/                # entry, DI wiring, scene/lifecycle only
Packages/
  CoreModel/        # domain models, no UI deps
  CoreDomain/       # use cases (only when orchestration exists)
  CoreData*/        # repositories, data sources, API clients
  DesignSystem/     # tokens, shared views, modifiers
  Feature<Name>/    # one package per feature; Interface/Live split only when a 2nd consumer needs it
```

Detail → [ios-module-structure].

## 6. Architecture review checklist

- [ ] Views render state / send actions; no network/persistence/business logic.
- [ ] ViewModel is `@Observable`/`@MainActor`, imports no UI beyond state modeling.
- [ ] Navigation expressed as route data, not imperative presentation.
- [ ] Domain models have no SwiftUI/UIKit deps.
- [ ] Platform frameworks behind injected protocol adapters.
- [ ] Slices promoted on a real signal (no preemptive UseCase/TCA).
- [ ] Each new screen ships a `#Preview`.

## Official references

- SwiftUI model data: https://developer.apple.com/documentation/swiftui/model-data
- Observation: https://developer.apple.com/documentation/observation
- Managing model data (MV): https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
- Swift Package Manager: https://www.swift.org/documentation/package-manager/
- Team baseline: [../../guidance.md](../../guidance.md)
