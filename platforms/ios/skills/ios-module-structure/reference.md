# ios-module-structure — Reference

Deep-dive for `SKILL.md`. Package trees, the API/Impl target pair,
composition-root DI. Decision criteria live in `SKILL.md`.

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
  FeatureHome/           # one package per feature — see §3
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

## 3. The API/Impl target pair — every feature, from day one

One package per feature, two targets and two products:

```
FeatureHome/
  Package.swift
  Sources/
    FeatureHomeAPI/     # navigation identity, route contracts, caller-facing interfaces
    FeatureHomeImpl/    # views, view models, implementation
```

```swift
// FeatureHome/Package.swift
let package = Package(
    name: "FeatureHome",
    products: [
        .library(name: "FeatureHomeAPI",  targets: ["FeatureHomeAPI"]),
        .library(name: "FeatureHomeImpl", targets: ["FeatureHomeImpl"]),
    ],
    dependencies: [ .package(path: "../CoreModel"), .package(path: "../FeatureProfile") ],
    targets: [
        .target(name: "FeatureHomeAPI",
                dependencies: [.product(name: "CoreModel", package: "CoreModel")]),
        .target(name: "FeatureHomeImpl",
                dependencies: [
                    "FeatureHomeAPI",
                    // navigates into Profile — API product only, never its Impl
                    .product(name: "FeatureProfileAPI", package: "FeatureProfile"),
                ]),
    ]
)
```

### What goes in the API target

Only the surface a caller needs to reach this feature:

```swift
// FeatureHomeAPI/HomeDestination.swift
public struct HomeDestination: Hashable {           // navigation identity + payload
    public let userId: String
    public init(userId: String) { self.userId = userId }
}

public protocol HomeEntry {                          // caller-facing entry interface
    @MainActor func makeHomeView(_ destination: HomeDestination) -> AnyView
}
```

No views, no view models, no repositories. A type two features share beyond the
navigation payload graduates to `CoreModel`.

### Import rules

```swift
import FeatureProfileAPI    // ✅ from another feature's Impl
// import FeatureProfileImpl  ❌ only the App target may import Impl products
```

The App target imports every `Impl`, binds each `API` entry interface to its
implementation in the composition root, and owns top-level navigation wiring.

## 4. Domain package stays UI-free

```swift
// CoreModel — pure Swift, no SwiftUI/UIKit
public struct Order: Sendable, Identifiable { public let id: UUID; public let total: Decimal }
// import SwiftUI  ❌ never in CoreModel
```

## 5. Structure review checklist

- [ ] App target holds only entry, DI wiring, lifecycle.
- [ ] Feature/core logic lives in SPM packages.
- [ ] Every feature package has the `Feature<Name>API` + `Feature<Name>Impl` pair.
- [ ] API targets hold navigation identity/route contracts/entry interfaces only.
- [ ] Features import other features' API products — Impl products only in App.
- [ ] DI is constructor injection via the composition root; no DI framework in a hand-composed app.
- [ ] `CoreModel` (domain) has no UI deps.
- [ ] No god-package swallowing feature boundaries.

## Official references

- Swift Package Manager: https://www.swift.org/documentation/package-manager/
- Organizing code with local packages: https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages
- PackageDescription: https://developer.apple.com/documentation/packagedescription
- Team baseline: [../../guidance.md](../../guidance.md)
