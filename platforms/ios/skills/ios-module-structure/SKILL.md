---
name: ios-module-structure
description: iOS module/structure rules (thin app target, SPM packages, composition-root DI). A minimal app target holding only the composition root and lifecycle, feature and core logic in Swift Package Manager packages (CoreModel/CoreDomain/CoreData/DesignSystem/Feature<Name>), Interface/Live target split ONLY when a second consumer needs it, dependency injection via constructor/initializer injection through the composition root (no DI framework for a hand-composed project), a feature importing another feature's Interface (never its Live/impl target), and domain packages free of UI deps. Use when writing/reviewing Package.swift, the app target, DI wiring, or deciding where a module/feature/type belongs.
when_to_use: When laying out the app target and SPM packages, placing a feature or shared code, wiring DI through the composition root, or deciding whether to split Interface/Live. Also for "where does this module go", package boundaries, DI-framework-vs-hand-composition questions.
paths: **/Package.swift, **/Packages/**/*.swift, **/App/**/*.swift, **/*App.swift
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# ios-module-structure

Rules for the app target, SPM package boundaries, and DI. The Module Baseline
from `guidance.md` expanded to an enforceable level. Project `ctx/` overrides
this document. Deeper material (package trees, Interface/Live split, DI samples)
lives in [reference.md](./reference.md).

## Scope

- In scope: app-target scope, SPM package layout, Interface/Live split timing,
  composition-root DI, cross-package dependencies.
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
  App/                # entry, DI wiring, scene/lifecycle
  Packages/
    CoreModel/        # domain models, no UI deps
    CoreDomain/       # use cases (only when orchestration exists)
    CoreData*/        # repositories, data sources, API clients
    DesignSystem/     # tokens, shared views, modifiers
    Feature<Name>/    # one package per feature
  ```

- **Split a feature into Interface/Live targets ONLY when a second consumer needs
  it** (e.g. another feature depends on it, or you need to mock across a package
  boundary). Not preemptively.
- **DI is constructor/initializer injection** through the composition root. Use
  the project's existing container if one exists; **do not introduce a DI
  framework for a project that composes by hand**.
- **Depend on a feature's Interface, never its Live/impl target.** Cross-package
  reuse graduates into a Core package.
- **Domain packages (`CoreModel`) have no UI deps.**

Don't:

- Put feature logic, business rules, or networking in the app target.
- Add `CoreDomain`/UseCase packages before orchestration actually exists.
- Split every feature into Interface/Live "for testability" with one consumer.
- Add a DI framework to a hand-composed project.
- Import another feature's Live/impl target.
- Let a god-package accrete where feature boundaries used to be.

## Decision table

| Situation | Placement |
|---|---|
| App entry / DI wiring / lifecycle | `App/` (thin) |
| Domain models | `CoreModel` (no UI deps) |
| Use cases / orchestration | `CoreDomain` (only when it exists) |
| Repositories / API clients / data sources | `CoreData*` |
| Tokens / shared views / modifiers | `DesignSystem` |
| One feature's screens/VMs | `Feature<Name>` |
| A feature consumed by another / mocked across a boundary | split `Interface` + `Live` |

## Refactor / red-flag signals

- Feature logic or networking living in the app target.
- A feature importing another feature's Live/impl target instead of its Interface.
- Interface/Live split with a single consumer (premature).
- A DI framework bolted onto a hand-composed project.
- `CoreDomain`/UseCase packages with no real orchestration.
- A god-package where feature boundaries used to be.

## References

- Swift Package Manager: https://www.swift.org/documentation/package-manager/
- Organizing your code with local packages: https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages
- Package targets & products: https://developer.apple.com/documentation/packagedescription
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Package trees, Interface/Live split, composition-root samples: [`reference.md`](reference.md)
