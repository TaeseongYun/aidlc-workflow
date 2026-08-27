---
name: kmp-navigation-platform
description: KMP navigation and platform-boundary rules (routing, deep links, expect/actual adapters). Navigation uses the project's existing solution (Compose Navigation multiplatform, Decompose, or Voyager); destination definitions are data; deep links validate parameters before mapping to a destination; platform-specific capability lives behind an expect declaration in commonMain with an actual per platform source set; platform differences are decided in actual implementations, not scattered if(platform) branches in commonMain. Use when writing/reviewing navigation graphs, deep-link handling, expect/actual platform adapters, or platform-capability wiring.
when_to_use: When defining destinations, handling deep links, wrapping platform capability behind an expect/actual adapter, or removing scattered platform-check branches from commonMain. Also for Compose Navigation/Decompose/Voyager setup, deep-link parameter validation, expect/actual adapter design.
paths: **/navigation/**/*.kt, **/*NavGraph*.kt, **/*Destination*.kt, **/*Route*.kt, **/androidMain/**/*.kt, **/iosMain/**/*.kt, **/*Adapter.kt, **/*Platform.kt
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# kmp-navigation-platform

Rules for routing, deep links, and the `expect`/`actual` platform boundary.
The navigation and platform-boundary items from `guidance.md` expanded to an
enforceable level. Project `ctx/` overrides this document. Deeper material
(Compose Navigation samples, deep-link validation, expect/actual adapter
patterns) lives in [reference.md](./reference.md).

## Scope

- In scope: destination/route definitions, deep-link parameter validation,
  `expect`/`actual` platform adapters, platform-check placement.
- Covers: navigation through the project's existing solution, safe deep links,
  platform capability behind an `expect`/`actual` boundary.
- Doesn't cover: state modeling, module layout, Compose recomposition perf,
  security-vuln patterns — follow the Related skills in
  [kmp-architecture](../kmp-architecture/SKILL.md).

## Core rules

Do:

- **Use the project's existing navigation solution** (Compose Navigation
  multiplatform, Decompose, or Voyager). Don't mix navigation systems in one
  app.
- **Destination definitions are data**, centralized. A Composable navigates by
  destination type/route; it doesn't construct ad-hoc navigation calls scattered
  around.
- **Validate deep-link parameters before mapping to a destination.** External
  input (path params, query, universal/app links) is untrusted: parse,
  type-check, and reject bad values → do not pass raw strings into repositories
  or trust an arbitrary redirect target → [kmp-security](../kmp-security/SKILL.md).
- **Platform capability behind an `expect`/`actual` boundary.** The `expect`
  declaration lives in `commonMain`; the `actual` lives in `androidMain`,
  `iosMain`, etc. `commonMain` code depends only on the `expect` interface —
  never on a platform type directly.
- **Decide platform differences in `actual` implementations**, not
  `if (platform == "android")` / `getPlatform().name` branches scattered through
  `commonMain`. One decision point, inside the `actual`.
- **Map platform errors to domain failures** at the `actual` boundary
  (platform `Exception` / `NSError` → typed domain failure), so
  Composables/ViewModels never see raw platform exceptions.

Don't:

- Construct navigation calls ad-hoc across Composables instead of the central
  navigation graph.
- Map a deep link to a destination without validating parameters.
- Call platform APIs directly from `commonMain` code (use `expect`/`actual`).
- Sprinkle `getPlatform()` / `Platform.isAndroid` checks through feature
  Composables in `commonMain`.
- Let a raw platform `Exception` propagate to the UI.
- Mix two navigation systems in one app (Compose Navigation + Voyager + Decompose).

## Decision table

| Need | Where it goes |
|---|---|
| Navigate to a screen | project navigation solution by destination type/route |
| Pass data to a destination | typed destination args, validated on receipt |
| Handle an incoming deep/universal link | validate params → map to a destination (reject invalid) |
| Call platform capability (camera, biometrics, secure storage) | `expect` declaration in `commonMain`; `actual` in `androidMain`/`iosMain` |
| Branch on platform behavior | inside the `actual` implementation (single decision point) |
| Map a platform error | platform `Exception`/`NSError` → domain failure at the `actual` boundary |

## Refactor / red-flag signals

- Ad-hoc navigation calls scattered across Composables instead of the navigation graph.
- A deep link mapped to a destination with no parameter validation.
- Platform API calls (Android `Context`, iOS `UIKit`, `Foundation`) directly in `commonMain`.
- `getPlatform().name`/platform-check branches in feature Composables.
- Raw platform exceptions reaching the UI.
- Two navigation systems active in one app.
- An `actual` implementation with business logic that belongs in a UseCase or Repository.

## References

- Compose Multiplatform Navigation: https://www.jetbrains.com/help/kotlin-multiplatform-dev/compose-navigation-routing.html
- Decompose: https://arkivanov.github.io/Decompose/
- Voyager: https://voyager.adriel.cafe/
- KMP `expect`/`actual`: https://kotlinlang.org/docs/multiplatform-expect-actual.html
- Team baseline: [../../guidance.md](../../guidance.md)
- Navigation samples, deep-link validation, expect/actual adapter patterns: [reference.md](reference.md)
