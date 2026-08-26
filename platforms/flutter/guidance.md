# Flutter Architecture — Current Guidance

Baseline for Flutter work: Dart, feature-first structure, Riverpod or Bloc for
state (use whichever the project already has — never both). Project `ctx/`
overrides this document; this document overrides the agent's general
knowledge.

## Boundaries

Dependency flow (never reversed):

```
Widget -> Action -> Controller (Notifier/Bloc) -> UseCase (optional) -> Repository -> DataSource / Platform Channel Adapter
```

- Widgets render state and dispatch actions. No business logic, no repository
  or client calls, no platform-channel access from widgets.
- Controllers (Riverpod `Notifier`/`AsyncNotifier`, or Bloc) own screen state
  as a single sealed/immutable state type. One-shot effects (snackbars,
  navigation) are emitted as events/listeners, not persisted in state.
- Repositories return domain models; DTO ↔ domain mapping lives in the data
  layer. Domain models import no Flutter types.
- Native functionality goes through platform channels wrapped in a
  project-owned adapter interface — callable code never touches
  `MethodChannel` directly outside the adapter.
- Navigation uses the project's existing router (go_router or Navigator 2.0
  setup). Route definitions are data; deep links validate parameters before
  mapping to a route.

## State Decision Table

| Situation | State home |
|-----------|-----------|
| Widget-local, ephemeral | `StatefulWidget` / `setState` |
| Screen state + async data | Controller (AsyncNotifier / Bloc) per screen |
| Shared/business state across screens | Provider/Bloc scoped at the feature or app level |
| Remote data | Repository behind the controller — widgets never call clients |

Do not introduce a second state-management library into an existing project.

## Module Baseline

Feature-first; follow the project's layout when one exists:

```
lib/
  core/                  # theme/tokens, shared widgets, utilities, router
  domain/                # shared domain models (no Flutter imports)
  data/                  # API clients, repositories, DTOs
  features/<name>/
    presentation/        # screens, widgets, controllers
    domain/              # feature use cases/models (when they exist)
    data/                # feature repositories/sources (when they exist)
```

Split into packages (melos) only when a second app or plugin consumer exists.

## Rules

- State types are immutable (sealed classes / freezed if the project uses it);
  model loading/content/error explicitly, not as parallel nullables.
- `const` constructors wherever possible; rebuild scope kept tight (select/
  buildWhen) — but optimize on evidence, not speculation.
- Async gaps: never use `BuildContext` after an `await` without a `mounted`
  check.
- Errors from repositories are typed results/failures the controller maps to
  state — not raw exceptions reaching widgets.
- Strings/colors/dimensions from the theme and localization setup — no
  literals in feature widgets.
- Platform-specific behavior is decided in adapters, not by `Platform.isX`
  branches scattered through widgets.
- Follow existing test conventions: controller/bloc tests for state
  transitions with fake repositories; widget tests for the main flow; golden
  tests only if the project already has them.

## Feature Implementation Checklist

1. Route definition + deep-link parameter validation (if reachable
   externally).
2. State type + actions (screen contract).
3. Screen + widgets.
4. Controller wiring state ↔ actions ↔ effects.
5. UseCase/Repository/DataSource as needed; platform-channel adapter if
   native capability is involved.
6. DI/provider wiring at the correct scope.
7. Tests: state transitions, main-flow widget test, adapter contract if
   native code changed.

## Refactor Signals

- A widget calling a repository, API client, or `MethodChannel` directly.
- `BuildContext` used across an async gap without a mounted check.
- Business rules living in widget `build` methods or `initState`.
- Parallel nullable fields encoding what a sealed state should.
- Both Riverpod and Bloc active in the same codebase.
- `Platform.isAndroid/isIOS` branches inside feature widgets instead of an
  adapter.
- Controllers holding `BuildContext` or Flutter UI types.

## Detailed Skills

This baseline is expanded into seven topic skills under
[`skills/`](skills/README.md). Each is a reference-knowledge skill
(`SKILL.md` + `reference.md`) that auto-loads on matching files (`paths`) and is
also callable as `/flutter-*`. Stack: feature-first Flutter/Dart, Riverpod or
Bloc (whichever the project already uses — never both).

- [flutter-architecture](skills/flutter-architecture/SKILL.md) — dependency flow, layer responsibilities, state home, platform-channel boundary, Feature Slice decision (umbrella)
- [flutter-state-management](skills/flutter-state-management/SKILL.md) — sealed/immutable state, effects vs state, UDF, async-gap (`mounted`) safety, Riverpod/Bloc (never both)
- [flutter-module-structure](skills/flutter-module-structure/SKILL.md) — feature-first `lib/` layout, DI/provider scoping, single-package vs melos split timing
- [flutter-widget-performance](skills/flutter-widget-performance/SKILL.md) — `const`, rebuild scope (`select`/`buildWhen`), `mounted` after await, theme/localization (no literals), optimize on evidence
- [flutter-navigation-platform](skills/flutter-navigation-platform/SKILL.md) — go_router/Navigator 2.0, deep-link parameter validation, platform-channel adapters, `Platform.isX` in adapters
- [flutter-security](skills/flutter-security/SKILL.md) — **vibe-coding security guard**: catches AI-generated vulnerabilities (embedded secrets, insecure storage, TLS bypass, deep-link/channel input, WebView, sqflite injection, log leakage, weak crypto, insecure manifests, hallucinated deps)
- [flutter-figma-to-code](skills/flutter-figma-to-code/SKILL.md) — Figma → Flutter widgets via the shared `scripts/figma` manifest + DTCG tokens (node→widget, token→ThemeExtension/textTheme, `const`); generated code must still pass flutter-security
