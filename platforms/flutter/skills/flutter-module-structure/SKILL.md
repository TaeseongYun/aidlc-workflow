---
name: flutter-module-structure
description: Flutter module/structure rules (feature-first layout, DI/provider scoping, package split timing). lib/ organized core/domain/data/features, each feature split into presentation/domain/data only when those layers exist, domain models kept free of Flutter imports, DI/providers wired at the correct scope (feature vs app), a single package until a second app or plugin consumer forces a melos split. Use when writing/reviewing pubspec.yaml, melos.yaml, DI/provider wiring, or deciding where a file/feature/package belongs.
when_to_use: When laying out lib/, placing a feature or shared code, scoping providers/DI, or deciding whether to split into melos packages. Also for "where does this file go", feature-first structure, monorepo/package-split questions.
paths: **/pubspec.yaml, **/melos.yaml, **/lib/main.dart, **/lib/di/**, **/*_providers.dart, **/injection*.dart
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# flutter-module-structure

Rules for project layout, DI scope, and package boundaries. The Module Baseline
from `guidance.md` expanded to an enforceable level. Project `ctx/` overrides
this document. Deeper material (folder trees, scoping samples, melos timing)
lives in [reference.md](./reference.md).

## Scope

- In scope: `lib/` layout, feature-first structure, DI/provider scope, single
  package vs melos split timing.
- Covers: where a file/feature/shared-code belongs, layer folders, DI wiring
  scope.
- Doesn't cover: state modeling, widget perf, navigation, security — follow the
  Related skills in [flutter-architecture].

## Core rules

Do:

- **Feature-first.** Follow the project's existing layout when one exists.
  Absent one, use:

  ```
  lib/
    core/         # theme/tokens, shared widgets, utilities, router
    domain/       # shared domain models (no Flutter imports)
    data/         # API clients, repositories, DTOs
    features/<name>/
      presentation/  # screens, widgets, controllers
      domain/        # feature use cases/models (when they exist)
      data/          # feature repositories/sources (when they exist)
  ```

- **Create a layer folder only when that layer has content.** A feature with no
  use cases has no `domain/`; don't scaffold empty layers.
- **Domain is Flutter-free.** `domain/` models import no `package:flutter/*`.
- **Scope DI/providers correctly**: app-wide singletons (config, HTTP client,
  auth) at app scope; feature state at the feature subtree (`ProviderScope`
  override / `BlocProvider` on the feature route). Don't make everything global.
- **Depend downward across features via shared layers** (`core`/`domain`), not
  feature→feature. Cross-feature reuse graduates into `core`/`domain`.
- **One package** until a second app or a plugin consumer exists. Split with
  melos only then.

Don't:

- Scaffold empty `presentation/domain/data` folders "for later".
- Put a Flutter import in a `domain/` model.
- Register feature-only state as an app-wide global provider.
- Import one feature's internals from another feature directly.
- Introduce melos / a package split before a second consumer forces it
  (over-engineering).

## Decision table

| Situation | Placement |
|---|---|
| Used by one feature only | inside that `features/<name>/` |
| Used by 2+ features, has UI | `core/` (shared widgets/utilities) |
| Used by 2+ features, pure domain | `domain/` (Flutter-free) |
| App-wide client/config/auth | `data/` + app-scoped provider |
| Second app or plugin consumer appears | split into a melos package |

## Refactor / red-flag signals

- Empty layer folders with no files.
- A `domain/` file importing `package:flutter/*`.
- Feature A importing `features/b/...` internals directly.
- Everything registered as an app-wide global provider.
- A melos multi-package setup with only one consumer.
- Shared code copy-pasted across features instead of lifted into `core`/`domain`.

## References

- Flutter architecture — organizing code: https://docs.flutter.dev/app-architecture/case-study
- Package layout conventions: https://dart.dev/tools/pub/package-layout
- melos (monorepo): https://melos.invertase.dev/
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Folder trees, DI scoping samples, melos timing: [`reference.md`](reference.md)
