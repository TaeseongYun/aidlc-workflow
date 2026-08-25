---
name: flutter-navigation-platform
description: Flutter navigation and platform-channel rules (routing, deep links, MethodChannel adapters). Navigation uses the project's existing router (go_router or Navigator 2.0); route definitions are data; deep links validate parameters before mapping to a route; native functionality goes through platform channels wrapped in a project-owned adapter interface (callable code never touches MethodChannel directly outside the adapter); platform-specific behavior is decided in adapters, not scattered Platform.isX branches. Use when writing/reviewing routers, route/deep-link handling, method-channel code, or platform adapters.
when_to_use: When defining routes, handling deep links, wrapping native capability behind a platform-channel adapter, or removing scattered Platform.isX branches. Also for go_router setup, deep-link parameter validation, MethodChannel wrapping, plugin/platform adapter design.
paths: **/*_router.dart, **/router*.dart, **/*_route*.dart, **/*_channel.dart, **/platform/**/*.dart, **/*_adapter.dart
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# flutter-navigation-platform

Rules for routing, deep links, and platform-channel boundaries. The navigation
and platform-channel items from `guidance.md` expanded to an enforceable level.
Project `ctx/` overrides this document. Deeper material (go_router samples,
deep-link validation, adapter patterns) lives in [reference.md](./reference.md).

## Scope

- In scope: route definitions, deep-link parameter validation, platform-channel
  adapters, `Platform.isX` placement.
- Covers: navigation through the project's router, safe deep links, native
  capability behind an adapter interface.
- Doesn't cover: state modeling, module layout, widget perf, security-vuln
  patterns — follow the Related skills in [flutter-architecture].

## Core rules

Do:

- **Use the project's existing router** (go_router or the project's Navigator 2.0
  setup). Don't mix routing paradigms in one app.
- **Route definitions are data**, centralized. A screen navigates by name/path;
  it doesn't construct ad-hoc `MaterialPageRoute`s scattered around.
- **Validate deep-link parameters before mapping to a route.** External input
  (path params, query, universal/app links) is untrusted: parse, type-check,
  and reject bad values → do not pass raw strings into repositories or trust an
  arbitrary redirect target → [flutter-security].
- **Native capability behind a project-owned adapter interface.** `MethodChannel`
  lives only in the adapter; the rest of the app depends on the interface →
  [flutter-architecture].
- **Decide platform differences in adapters**, not `Platform.isAndroid/isIOS`
  branches scattered through widgets. One `Platform.isX` decision, inside the
  adapter.
- **Map platform errors to domain failures** at the adapter boundary
  (`PlatformException` → typed failure), so widgets/controllers never see raw
  platform exceptions.

Don't:

- Construct routes ad-hoc across widgets instead of the central router.
- Map a deep link to a route (or fetch by its id) without validating parameters.
- Call `MethodChannel`/plugin APIs directly from a widget or controller.
- Sprinkle `Platform.isX` branches through feature widgets.
- Let a raw `PlatformException` propagate to the UI.

## Decision table

| Need | Where it goes |
|---|---|
| Navigate to a screen | project router by name/path (go_router `context.go`/`push`) |
| Pass data to a route | typed route params / extra, validated on receipt |
| Handle an incoming deep/universal link | validate params → map to a route (reject invalid) |
| Call native code (camera, biometrics, share) | project-owned adapter interface; `MethodChannel` inside it |
| Branch on OS behavior | inside the adapter (single `Platform.isX`) |
| Map a native error | `PlatformException` → domain failure at the adapter |

## Refactor / red-flag signals

- Ad-hoc `Navigator.push(MaterialPageRoute(...))` scattered instead of the router.
- A deep link mapped to a route with no parameter validation.
- `MethodChannel` / plugin calls inside a widget or controller.
- `Platform.isAndroid/isIOS` branches in feature widgets.
- Raw `PlatformException` reaching the UI.
- Two routing paradigms active in one app.

## References

- Navigation & routing: https://docs.flutter.dev/ui/navigation
- go_router: https://pub.dev/packages/go_router
- Deep linking: https://docs.flutter.dev/ui/navigation/deep-linking
- Platform channels: https://docs.flutter.dev/platform-integration/platform-channels
- Team baseline: [`../../guidance.md`](../../guidance.md)
- go_router / deep-link validation / adapter samples: [`reference.md`](reference.md)
