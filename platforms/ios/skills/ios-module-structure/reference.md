# ios-module-structure — Reference

Deep-dive for `SKILL.md`. Package trees, Interface/Live split, composition-root
DI. Decision criteria live in `SKILL.md`.

## 1. Thin app target + SPM packages

```
App/                     # composition root + lifecycle ONLY
  MyApp.swift            # @main; builds the object graph
  AppDependencies.swift  # constructs repositories/adapters, injects them
Packages/
  CoreModel/             # domain models — no UI deps
  CoreDomain/            # use cases — only when orchestration exists
  CoreNetworking/        # API client, DTOs
  CoreData/              # repositories, data sources
  DesignSystem/          # tokens, shared views, modifiers
  FeatureHome/           # one package per feature
  FeatureCheckout/
```

- A `CoreDomain`/UseCase package appears **only when orchestration exists** —
  don't scaffold it empty.

## 2. Composition-root DI (no framework)

```swift
// App/AppDependencies.swift — construct the graph by hand, inject via initializers.
@MainActor struct AppDependencies {
    let orderRepo: OrderRepository
    init() {
        let api = OrderAPI(client: .live)
        self.orderRepo = OrderRepository(api: api)   // constructor injection
    }
    func homeViewModel() -> HomeViewModel { HomeViewModel(repo: orderRepo) }
}

// ❌ Adding Swinject/Resolver to a hand-composed app "for convenience" → over-engineering
```

## 3. Interface / Live split — only on a real signal

```
FeatureProfile/
  Sources/
    ProfileInterface/   # protocol + models another feature can depend on
    ProfileLive/        # the real implementation
```

- Split when **a second consumer** appears: another feature depends on Profile,
  or you must mock Profile across a package boundary in tests. One consumer and
  no cross-boundary mock → keep it a single target.

```swift
// A feature depends on the Interface, never the Live target
import ProfileInterface   // ✅
// import ProfileLive     // ❌ couples to the implementation
```

## 4. Domain package stays UI-free

```swift
// CoreModel — pure Swift, no SwiftUI/UIKit
public struct Order: Sendable, Identifiable { public let id: UUID; public let total: Decimal }
// import SwiftUI  ❌ never in CoreModel
```

## 5. Structure review checklist

- [ ] App target holds only entry, DI wiring, lifecycle.
- [ ] Feature/core logic lives in SPM packages.
- [ ] Interface/Live split only where a second consumer / cross-boundary mock exists.
- [ ] DI is constructor injection via the composition root; no DI framework in a hand-composed app.
- [ ] Features depend on Interfaces, not Live/impl targets.
- [ ] `CoreModel` (domain) has no UI deps.
- [ ] No god-package swallowing feature boundaries.

## Official references

- Swift Package Manager: https://www.swift.org/documentation/package-manager/
- Organizing code with local packages: https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages
- PackageDescription: https://developer.apple.com/documentation/packagedescription
- Team baseline: [../../guidance.md](../../guidance.md)
