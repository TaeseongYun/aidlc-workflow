---
name: ios-module-structure
description: iOS module/structure rules (thin app target, SPM packages, composition-root DI). A minimal app target holding only the composition root and lifecycle; feature and core logic in Swift Package Manager packages (CoreModel/CoreDomain/CoreData/DesignSystem/Feature<Name>); every feature package ships two targets from day one — Feature<Name>API (navigation identity, route contracts, caller-facing interfaces ONLY) and Feature<Name>Impl (views, view models, implementation); only the app target imports Impl targets, features import other features' API targets only; dependency injection via constructor/initializer injection through the composition root (no DI framework for a hand-composed project); domain packages free of UI deps. Use when writing/reviewing Package.swift, the app target, DI wiring, or deciding where a module/feature/type belongs.
when_to_use: When laying out the app target and SPM packages, placing a feature or shared code, wiring DI through the composition root, or deciding what belongs in a feature's API vs Impl target. Also for "where does this module go", package boundaries, DI-framework-vs-hand-composition questions.
paths: **/Package.swift, **/Packages/**/*.swift, **/App/**/*.swift, **/*App.swift
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# ios-module-structure

Rules for the app target, SPM package boundaries, and DI. The Module Baseline
from `guidance.md` expanded to an enforceable level. Project `ctx/` overrides
this document. Deeper material (package trees, API/Impl target layout, DI
samples) lives in [reference.md](./reference.md).

## Scope

- In scope: app-target scope, SPM package layout, the mandatory API/Impl target
  pair per feature, composition-root DI, cross-package dependencies.
- Covers: where a module/feature/type belongs and how it's wired.
- Doesn't cover: state modeling & concurrency → [ios-state-concurrency],
  platform-framework adapters → [ios-platform-adapters], external surface →
  [ios-navigation-deeplink], security → [ios-security].

## Core rules

Do:

- **Thin app target**: entry point, DI wiring (composition root), scene/lifecycle
  only. No feature logic in the app target.
- **Feature & core logic in SPM packages.** Follow the project's layout; absent
  one:

  ```
  App/                    # entry, DI wiring, scene/lifecycle
  Packages/
    CoreModel/            # domain models, no UI deps
    CoreDomain/           # use cases (only when orchestration exists)
    CoreData*/            # repositories, data sources, API clients
    DesignSystem/         # tokens, shared views, modifiers
    FeatureHome/          # one package per feature, two targets:
      Sources/
        FeatureHomeAPI/   #   navigation identity, route contracts,
                          #   caller-facing interfaces ONLY
        FeatureHomeImpl/  #   views, view models, implementation
  ```

- **Every feature package ships the `API` + `Impl` target pair from day one.**
  No single-target stage, no "split when a second consumer appears" — the pair
  is the standard shape, matching the Android `{feature}:api|impl` convention.
- **`API` holds only the surface a caller needs to navigate into the feature**:
  route/destination identity, the argument types carried across the boundary,
  and caller-facing entry interfaces. No views, no view models, no business
  types — shared types graduate to `CoreModel`.
- **Only the app target (composition root) imports `Impl` targets.** A feature
  imports other features' `API` targets only.
- **DI is constructor/initializer injection** through the composition root. Use
  the project's existing container if one exists; **do not introduce a DI
  framework for a project that composes by hand**.
- **Domain packages (`CoreModel`) have no UI deps.**

Don't:

- Put feature logic, business rules, or networking in the app target.
- Add `CoreDomain`/UseCase packages before orchestration actually exists.
- Import another feature's `Impl` target from a feature.
- Put views, view models, or business types in an `API` target.
- Add a DI framework to a hand-composed project.
- Let a god-package accrete where feature boundaries used to be.

## Decision table

| Situation | Placement |
|---|---|
| App entry / DI wiring / lifecycle | `App/` (thin) |
| Domain models | `CoreModel` (no UI deps) |
| Use cases / orchestration | `CoreDomain` (only when it exists) |
| Repositories / API clients / data sources | `CoreData*` |
| Tokens / shared views / modifiers | `DesignSystem` |
| New feature | `Feature<Name>` package with `Feature<Name>API` + `Feature<Name>Impl` targets |
| Feature B navigates into feature A | B's Impl imports `FeatureAAPI`; App wires the destination |
| A type two features share beyond the navigation payload | `CoreModel` — don't fatten the API target |

## Refactor / red-flag signals

- A feature package without the API/Impl pair (legacy single target) → split on
  next touch: contract into `API`, rest into `Impl`.
- A feature importing another feature's `Impl` target → reroute through `API`.
- Views/view models/business types inside an `API` target → move to `Impl` or Core.
- Feature logic or networking living in the app target.
- A DI framework bolted onto a hand-composed project.
- `CoreDomain`/UseCase packages with no real orchestration.
- A god-package where feature boundaries used to be.

## References

- Swift Package Manager: https://www.swift.org/documentation/package-manager/
- Organizing your code with local packages: https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages
- Package targets & products: https://developer.apple.com/documentation/packagedescription
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Package trees, API/Impl `Package.swift`, composition-root samples: [`reference.md`](reference.md)
