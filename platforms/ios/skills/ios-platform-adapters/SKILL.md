---
name: ios-platform-adapters
description: iOS platform-framework adapter and data-layer rules. Platform frameworks (CoreLocation, AVFoundation, StoreKit, UserNotifications, etc.) sit behind project-owned protocol adapters, injected — so callable code is testable without the device framework; permission-denied is a designed state, not an error; repositories return domain models with DTO ↔ domain mapping in the data layer (domain models have no SwiftUI/UIKit deps); small preferences go through a UserDefaults adapter while structured data goes through the repository; secrets go to Keychain, never UserDefaults; native errors map to typed failures at the adapter boundary; tests use a protocol fake, not the device framework. Use when wrapping a platform framework, designing a repository/data source, handling permissions, or choosing UserDefaults vs repository vs Keychain.
when_to_use: When wrapping a system framework behind a protocol adapter, designing a repository/data source or DTO↔domain mapping, wiring a permission flow, choosing UserDefaults vs repository vs Keychain, or catching a direct framework call in feature code / secrets in UserDefaults.
paths: **/*Adapter.swift, **/*Repository.swift, **/*Client.swift, **/*Service.swift, **/DataSources/**/*.swift
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# ios-platform-adapters

Rules for the platform-framework boundary and the data layer. The adapter and
repository items from `guidance.md` expanded to an enforceable level. Project
`ctx/` overrides this document. Deeper material (protocol adapters, permission
state, repository mapping) lives in [reference.md](./reference.md).

## Scope

- In scope: wrapping system frameworks behind protocol adapters, dependency
  injection of adapters, permission-denied handling, repository/data-source
  design, DTO ↔ domain mapping, UserDefaults vs repository vs Keychain.
- Out of scope: ViewModel state/concurrency → [ios-state-concurrency],
  layer placement → [ios-architecture], DI wiring at the root →
  [ios-module-structure], secret-handling vulnerabilities → [ios-security].

## Core rules

Do:

- **Platform frameworks behind a project-owned protocol adapter.**
  CoreLocation / AVFoundation / StoreKit / UserNotifications etc. sit behind a
  protocol the project owns, injected into callers — so features are **testable
  without the device framework**.
- **Permission-denied is a designed state.** Any capability that asks (location,
  camera, notifications) surfaces granted/denied/undetermined as state with an
  explicit UI path — not an error or a crash.
- **Repositories return domain models.** DTO ↔ domain mapping lives in the data
  layer; domain models have **no SwiftUI/UIKit** dependencies.
- **Map native/system errors to typed failures** at the adapter/repository
  boundary — callers get a domain failure, not a raw `NSError`/`CLError`.
- **UserDefaults for small preferences, behind an adapter**; structured data goes
  through the repository. **Keychain for secrets — never UserDefaults** →
  [ios-security].
- **Inject the protocol; test with a fake.** Tests use a protocol conformance,
  not the real framework.

Don't:

- Call a system framework directly from a View/ViewModel/business rule.
- Treat permission denial as an error toast/crash instead of a designed state.
- Return a DTO or a framework type across the repository boundary, or import
  SwiftUI/UIKit into a domain model.
- Let a raw `NSError`/framework error reach the ViewModel/View.
- Put structured data or secrets in `UserDefaults`; scatter `UserDefaults`
  access across the app instead of an adapter.
- Mock the concrete framework in tests instead of the injected protocol.

## Decision table

| Need | Where it goes |
|---|---|
| Use a system framework (location, audio, IAP, notifications) | project-owned protocol adapter, injected |
| Handle a permission | request in the adapter; surface granted/denied/undetermined as state |
| Return data to the domain | repository → domain model (DTO↔domain mapped in the data layer) |
| Map a native error | typed domain failure at the adapter/repository |
| Store a small preference | `UserDefaults` behind an adapter |
| Store structured data | repository / persistence layer |
| Store a secret/token | Keychain (never `UserDefaults`) → [ios-security] |
| Test a feature using a framework | inject a protocol fake |

## Refactor / red-flag signals

- A View/ViewModel/business rule calling CoreLocation/AVFoundation/StoreKit/etc. directly.
- Permission denial handled as an error toast, not a designed state.
- A DTO or framework type crossing the repository boundary; SwiftUI/UIKit in a domain model.
- Raw `NSError`/`CLError` reaching the ViewModel/View.
- Secrets in `UserDefaults`; `UserDefaults` accessed ad-hoc across the app.
- Tests mocking the concrete framework instead of the injected protocol.

## References

- Protocol-oriented / dependency injection: https://developer.apple.com/documentation/swift/adopting-common-protocols
- CoreLocation authorization: https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services
- Keychain services: https://developer.apple.com/documentation/security/keychain-services
- UserDefaults: https://developer.apple.com/documentation/foundation/userdefaults
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Protocol-adapter, permission-state, repository-mapping samples: [`reference.md`](reference.md)
