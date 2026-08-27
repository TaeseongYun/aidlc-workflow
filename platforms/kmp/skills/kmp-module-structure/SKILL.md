---
name: kmp-module-structure
description: KMP module/structure rules (source-set layout, DI/Koin scoping, Gradle module split timing). commonMain organized as core/data/features, each feature split into presentation/domain/data only when those layers exist, domain models kept free of platform imports, Koin modules wired at the correct scope (feature vs app), a single Gradle module until a second app or independent consumer forces a split. Use when writing/reviewing build.gradle.kts, settings.gradle.kts, libs.versions.toml, Koin module wiring, or deciding where a file/feature/module belongs.
when_to_use: When laying out source sets, placing a feature or shared code, scoping Koin modules, or deciding whether to split into additional Gradle modules. Also for "where does this file go", feature-first source-set structure, KMP monorepo/module-split questions.
paths: **/build.gradle.kts, **/settings.gradle.kts, **/gradle/libs.versions.toml, **/commonMain/**/*.kt, **/androidMain/**/*.kt, **/iosMain/**/*.kt
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# kmp-module-structure

Rules for source-set layout, Koin DI scope, and Gradle module boundaries. The
Module Baseline from `guidance.md` expanded to an enforceable level. Project
`ctx/` overrides this document. Deeper material (source-set trees, Koin scoping
samples, multi-module timing) lives in [reference.md](./reference.md).

## Scope

- In scope: source-set layout (`commonMain`/`androidMain`/`iosMain`), feature-first
  structure within `commonMain`, Koin module scope, single-module vs multi-module split
  timing.
- Covers: where a file/feature/shared-code belongs, layer folders, Koin wiring scope.
- Doesn't cover: state modeling, Compose recomposition perf, navigation, security —
  follow the Related skills in [kmp-architecture](../kmp-architecture/SKILL.md).

## Core rules

Do:

- **Feature-first within `commonMain`.** Follow the project's existing layout when one
  exists. Absent one, use:

  ```
  shared/src/commonMain/kotlin/
    core/         # shared domain models, utilities, expect declarations, theme
    data/         # Ktor clients, repositories, DTOs, kotlinx.serialization
    features/<name>/
      presentation/  # Composables, ViewModel/ScreenModel, UiState
      domain/        # feature use cases / domain models (when they exist)
      data/          # feature repositories / sources (when they exist)
  ```

- **Create a layer folder only when that layer has content.** A feature with no
  use cases has no `domain/`; don't scaffold empty layers.
- **Domain is platform-free.** `domain/` models import no `androidx.*`, `android.*`,
  iOS platform, or Compose types — they live in `commonMain` as pure Kotlin.
- **Scope Koin modules correctly**: app-wide singletons (config, Ktor client,
  auth) in the root Koin module; feature state in a feature-scoped Koin module
  (or a `KoinComponent` scope). Don't make everything global.
- **Platform code in platform source sets.** `actual` implementations belong in
  `androidMain`/`iosMain`; their `expect` declarations live in `commonMain`.
- **Depend downward across features via shared layers** (`core`/`data`), not
  feature→feature. Cross-feature reuse graduates into `core`.
- **One Gradle module** until a second app or an independent consumer exists.
  Split only then.

Don't:

- Scaffold empty `presentation/domain/data` folders "for later".
- Put a platform import (`android.*`, `UIKit`, `Foundation`, Compose `@Composable`) in a
  `domain/` model.
- Register feature-only state as an app-wide global Koin singleton.
- Import one feature's internals from another feature directly.
- Introduce a Gradle multi-module setup before a second consumer forces it
  (over-engineering).
- Put platform-specific code in `commonMain` without an `expect`/`actual` boundary.

## Decision table

| Situation | Placement |
|---|---|
| Used by one feature only | inside that `features/<name>/` |
| Used by 2+ features, has UI | `core/` (shared Composables/utilities) |
| Used by 2+ features, pure domain | `core/` domain models (platform-free) |
| App-wide client/config/auth | `data/` + app-scoped Koin module |
| Platform-specific capability | `expect` in `commonMain`, `actual` in platform source sets |
| Second app or independent consumer appears | split into a new Gradle module |

## Refactor / red-flag signals

- Empty layer folders with no files.
- A `domain/` file importing `android.*`, `androidx.*`, iOS platform types, or Compose types.
- Feature A importing `features/b/...` internals directly.
- Everything registered as an app-wide global Koin singleton.
- A multi-module Gradle setup with only one consumer.
- Shared code copy-pasted across features instead of lifted into `core`.
- Platform-specific code in `commonMain` (should be behind `expect`/`actual`).

## References

- Kotlin Multiplatform project structure: https://kotlinlang.org/docs/multiplatform-discover-project.html
- Source set hierarchy: https://kotlinlang.org/docs/multiplatform-hierarchy.html
- Koin multiplatform: https://insert-koin.io/docs/reference/koin-mp/kmp
- Team baseline: [../../guidance.md](../../guidance.md)
- Source-set trees, Koin scoping samples, multi-module timing: [reference.md](reference.md)
