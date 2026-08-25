---
name: flutter-architecture
description: Flutter architecture · app-architecture skeleton reference rules. Covers dependency flow (Widget → Action → Controller (Notifier/Bloc) → UseCase (optional) → Repository → DataSource / Platform Channel Adapter, never reversed), layer responsibilities, where screen state lives, domain models importing no Flutter types, native capability behind a project-owned platform-channel adapter, and the Feature Slice decision table. Feature-first structure with Riverpod or Bloc (never both). Use when designing, reviewing, or refactoring Flutter architecture, or deciding which slice (simple screen / UseCase / repository / platform-channel) to take. The umbrella skill tying the other five Flutter skills together.
when_to_use: Designing Flutter app architecture, judging layer boundaries, placing Controller/Repository/Adapter, deciding where state lives, choosing a feature slice, architecture refactor/review. Also for Flutter/Dart app architecture, feature-first/clean architecture, Riverpod-vs-Bloc placement requests.
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# flutter-architecture — app-architecture skeleton

The spine of a Flutter app: dependency flow, layer responsibilities, and where
state lives, pinned as always-referenced rules. Project `ctx/` overrides this
skill, and this skill overrides the agent's general knowledge. Deeper material
(detailed layer responsibilities, adapter samples, feature-slice examples) lives
in [reference.md](./reference.md).

## Scope

- In scope: layer placement, dependency direction, state home, slice selection,
  and refactor judgment for new Flutter features. Feature-first structure,
  Riverpod **or** Bloc (whichever the project already uses — never both).
- Out of scope: state modeling detail, module/DI layout, widget performance,
  navigation/platform-channel detail, security vulnerability patterns — each
  delegated to the Related skills below.

## Core rules — dependency flow and layer responsibilities

Dependency flows top→down, one-way, **never reversed**.

```
Widget → Action → Controller (Notifier/Bloc) → UseCase (optional) → Repository → DataSource / Platform Channel Adapter
```

### Do

- **Widget**: render state and dispatch actions only. No business logic, no
  repository/client calls, no `MethodChannel` access, no `Platform.isX`
  branching → [flutter-widget-performance].
- **Controller** (Riverpod `Notifier`/`AsyncNotifier`, or Bloc): owns screen
  state as a single sealed/immutable type. One-shot effects (snackbar,
  navigation) are emitted as events/listeners, not persisted in state →
  [flutter-state-management].
- **UseCase** (optional): business rules spanning repositories/aggregates. Skip
  it for simple screens; add only on a real signal.
- **Repository**: returns domain models. DTO ↔ domain mapping lives in the data
  layer. Domain models import **no** Flutter types.
- **Platform Channel Adapter**: native capability sits behind a project-owned
  adapter interface. Callable code never touches `MethodChannel` directly
  outside the adapter → [flutter-navigation-platform].

### Don't

- Widget calling a Repository, API client, or `MethodChannel` directly → forbidden.
- Controller holding `BuildContext` or Flutter UI types → forbidden.
- Domain model importing `package:flutter/*` → forbidden.
- Raw exceptions from a repository reaching a widget (map to typed
  results/failures in the controller) → forbidden.
- Both Riverpod and Bloc active in the same codebase → forbidden.
- A lower layer depending on a higher layer → forbidden (reversed dependency).

## Feature Slice Decision Table

Start at the **smallest** slice that fits. Move up only on a **real signal**, not
speculation.

| Situation | Slice | Signal to move up |
|-----------|-------|-------------------|
| Widget-local, ephemeral UI state | `StatefulWidget` / `setState` | State outlives one widget or feeds business logic |
| Screen state + async data | Controller (AsyncNotifier / Bloc) + Repository | Rule spans repositories, or an external/native call appears |
| Business rules across repositories / native capability | + explicit UseCase, platform-channel adapter | Shared business state needed across screens |
| Shared state across screens | Provider/Bloc scoped at feature/app level | — (do not add a second state library or a global store framework) |

- **Don't build ahead**: no UseCase layer, no melos packages, no second state
  library before a real requirement forces it (over-engineering).
- Do not create a UseCase/controller that only delegates.

## Refactor / red-flag signals

- A widget calling a repository, API client, or `MethodChannel` directly.
- `BuildContext` used across an async gap without a `mounted` check.
- Business rules living in widget `build` methods or `initState`.
- Parallel nullable fields encoding what a sealed state should.
- Both Riverpod and Bloc active in the same codebase.
- `Platform.isAndroid/isIOS` branches inside feature widgets instead of an adapter.
- Controllers holding `BuildContext` or Flutter UI types.

## Related skills

Umbrella skill. Drill down into each concern's detail below:

- [flutter-state-management](../flutter-state-management/SKILL.md) — sealed/immutable state · effects vs state · Riverpod/Bloc · async gaps.
- [flutter-module-structure](../flutter-module-structure/SKILL.md) — feature-first layout · DI/provider scoping · melos split timing.
- [flutter-widget-performance](../flutter-widget-performance/SKILL.md) — `const` · rebuild scope · `mounted` · theme/localization literals.
- [flutter-navigation-platform](../flutter-navigation-platform/SKILL.md) — go_router/deep-link validation · platform-channel adapters.
- [flutter-security](../flutter-security/SKILL.md) — **vibe-coding security guard**: blocks vulnerable patterns in AI-generated code.

## References

- Team guidelines (parent doc): [../../guidance.md](../../guidance.md)
- Deeper material: [reference.md](./reference.md)
- Flutter architecture guide: https://docs.flutter.dev/app-architecture
- Riverpod: https://riverpod.dev/ · Bloc: https://bloclibrary.dev/
