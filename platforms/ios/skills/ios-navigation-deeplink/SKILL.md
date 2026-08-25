---
name: ios-navigation-deeplink
description: iOS navigation and external-surface rules (URL schemes, Universal Links, deep-link validation). URL schemes and Universal Links are the app's external contract (analogue of Android exported Intents) — each entry documents its URL pattern, typed parameters, and validation rules; the deep-link flow is App/Scene receives URL → host/path/parameter validation → feature route contract → navigation state → SwiftUI entry; an unvalidated URL is never mapped straight onto navigation state; incoming URLs, user activities, and extension payloads are trust boundaries validated before use with undefined input landing on a defined fallback; navigation intent is expressed as route data. Use when handling URL schemes / Universal Links / user activities, defining the external surface, or validating deep-link parameters.
when_to_use: When handling an incoming URL / Universal Link / user activity / extension payload, documenting the external contract, validating deep-link parameters, or mapping a link to a navigation route. Also for URL-scheme design, Universal Link setup, deep-link trust-boundary validation.
paths: **/*App.swift, **/*Scene*.swift, **/*Router*.swift, **/*Route*.swift, **/*Coordinator*.swift, **/*DeepLink*.swift, **/Info.plist
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# ios-navigation-deeplink

Rules for navigation intent and the external URL surface. The External Surface
section of `guidance.md` expanded to an enforceable level. Project `ctx/`
overrides this document. Deeper material (validation flow, route contract,
fallback patterns) lives in [reference.md](./reference.md).

## Scope

- In scope: URL schemes / Universal Links / user activities / extension payloads,
  parameter validation, mapping to a navigation route.
- Covers: the external contract and safe deep-link handling.
- Doesn't cover: route-data modeling in the ViewModel → [ios-state-concurrency],
  layer boundaries → [ios-architecture], security-vuln patterns → [ios-security].

## Core rules

Do:

- **Treat URL schemes and Universal Links as the external contract.** Document
  each entry: URL pattern, parameters **with types**, and validation rules
  (analogue of Android's exported Intents).
- **Follow the deep-link flow:** App/Scene receives URL → host/path/parameter
  **validation** → feature route contract → navigation state construction →
  SwiftUI entry.
- **Validate before use.** Incoming URLs, `NSUserActivity`, and extension
  payloads are **trust boundaries**: parse and type-check; **undefined input
  lands on a defined fallback** (home / not-found), never a crash or a guessed route.
- **Express navigation as route data** (an `enum` route), constructed only after
  validation → [ios-state-concurrency].
- **Keep the entry list explicit.** New external entries update Info.plist /
  entitlements and the documented contract.

Don't:

- Map an unvalidated URL straight onto navigation state.
- Force-unwrap deep-link parameters (`URLComponents...!`) — data crossing a trust
  boundary is optional-by-nature → [ios-security].
- Trust a link to name an internal route/screen directly without validation.
- Scatter URL parsing across views; centralize it at the App/Scene boundary.
- Add an external URL entry without documenting its pattern/params/validation.

## Deep-link handling flow

| Step | What happens | On bad input |
|---|---|---|
| 1. Receive | App/Scene gets the URL / user activity / payload | — |
| 2. Match | host/path matched against known patterns | unknown → fallback route |
| 3. Validate | parameters parsed & type-checked (ids, enums) | invalid → fallback route |
| 4. Route | build the typed `Route` from validated params | — |
| 5. Navigate | push the route onto navigation state → SwiftUI | — |

## Refactor / red-flag signals

- An unvalidated URL mapped straight onto navigation state.
- Force-unwraps on deep-link parameters.
- URL parsing scattered across views instead of centralized at App/Scene.
- A new external entry with no documented pattern/params/validation.
- No defined fallback for undefined/invalid input.
- A link trusted to select an internal route without validation.

## References

- Defining a custom URL scheme: https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app
- Supporting Universal Links: https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app
- Handling `NSUserActivity` / Handoff: https://developer.apple.com/documentation/foundation/nsuseractivity
- NavigationStack (path): https://developer.apple.com/documentation/swiftui/navigationstack
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Validation flow, route contract, fallback samples: [`reference.md`](reference.md)
