---
name: android-module-structure
description: Android module structure/modularization (Android module structure) reference rules — app/core/feature split, when to split api|impl, convention plugin and version-catalog conventions. Use to judge them. Expands in detail the Module Baseline and DI sections of `platforms/android/guidance.md`. Reference when creating a new module, deciding whether to split a feature into api|impl, deciding whether to introduce core:domain, touching build.gradle.kts/settings.gradle.kts/libs.versions.toml, and when seeing module-boundary refactor signals such as a god-module or a feature referencing another feature's impl. Use for Android modularization: deciding when to add a module, when to split api|impl, when to introduce a domain layer, convention-plugin and version-catalog conventions.
when_to_use: When creating/splitting/merging Android module boundaries or judging Gradle module build configuration.
paths: **/build.gradle.kts, **/settings.gradle.kts, **/libs.versions.toml, **/*.gradle
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# Android Module Structure

Reference rules expanding the **Module Baseline** and **DI** sections of
`platforms/android/guidance.md` to an executable-judgment level. Read this when
deciding whether to create a new module, whether to split a feature into
`api|impl`, whether to introduce `core:domain`, and how to use convention plugins
and version catalogs. It's an always-on reference document, not a step-by-step
procedure.

## Scope

- In scope: creating/splitting/merging module boundaries, inter-module dependency
  direction, convention plugin and version-catalog conventions.
- Out of scope: rules inside a layer (UiState·ViewModel·Hilt binding details, Intent
  contracts). Those are handled by the Boundaries / Feature Slice / DI sections of
  `guidance.md`.
- The default is module separation for product-sized apps. Small apps start
  collapsed — expand only when a signal to do so arrives.

## Module map

```
app                      # thin shell: manifest, DI wiring, entry Activity only
core/designsystem        # theme, tokens, shared composables
core/model               # domain models, no Android deps (Kotlin/Java module)
core/domain              # use case — only when orchestration actually exists
core/data                # repository, data source, DTO mapping
feature/<name>           # single module by default
feature/<name>/api|impl  # split only when another feature depends on it
build-logic              # convention plugin
```

Dependency direction (never reversed):

```
app -> feature/* -> core/domain(optional) -> core/data -> core/model
feature/*, core/data, core/domain -> core/designsystem/model and other core submodules
```

For the full dependency matrix and the rationale for each rule, see [reference.md](reference.md).

## Core rules (do / don't)

- **DO** keep `app` minimal — only manifest, DI wiring (Hilt), entry Activity, and
  top-level navigation wiring. No screen logic, business logic, or manual object
  construction.
- **DO** have new modules follow the existing convention plugin setup. Don't
  hand-rewrite per-module build config that a convention plugin already covers.
- **DO** manage versions and plugins in one place, `gradle/libs.versions.toml`, and
  have module builds reference only via `libs.*`/`alias(libs.plugins.*)`. No
  hardcoding.
- **DO** make modules that don't need Android resources (`core:model`, pure domain)
  as Kotlin/Java modules rather than Android libraries — lower build overhead.
- **DO** minimize exposure. Hide implementations at module boundaries with
  `internal`/`private`, and default dependencies to `implementation` over `api`
  (reduces transitive exposure and build time).
- **DON'T** preemptively adopt an `api`/`impl` or `domain` split "for later." Expand
  it when a second consumer or platform dependency forces it.
- **DON'T** have a feature reference another feature directly. Inter-feature
  connections go through an Intent contract (external exposure) or shared
  `core:data` — pass a raw ID, not an object.
- **DON'T** reverse the dependency direction (no cycles/reverse references where
  `core` references `feature`, or `data` references `app`).

## Module decision table

| Situation | Decision |
|------|------|
| A new screen/feature appears | `feature/<name>` single module. Don't split `api|impl` yet |
| A second feature depends on something in this feature | Extract only that contract into `feature/<name>/api`, rest stays `impl`. api holds interfaces/models only |
| Implementation must be swapped per build variant/platform | Dependency inversion: `api` module + `impl:xxx` modules, app injects via DI |
| A repository coordinates multiple data sources / reuse rules appear | Add the repository to `core:data`. Hide data sources with `internal` |
| Multi-source orchestration beyond a ViewModel / reused business rules | Introduce a use case in `core:domain` |
| Simple state mapping only, no orchestration | Don't introduce `core:domain` — the ViewModel uses the repository directly |
| Cross-cutting code shared by multiple modules (widgets, theme, formatters, analytics) | A shared `core/<name>` module (designsystem/analytics/network, etc.) |
| Platform-specific entry points such as Android Auto/Wear/TV | A separate app module to isolate platform dependencies |

A new module always starts at the "smallest slice that fits" and is promoted only on
a real signal (second consumer, platform dependency, cycle avoidance), not
speculation.

## Refactor / red-flag signals

- **god-module**: one module keeps growing until it holds code that doesn't often
  interact → split at the low-cohesion boundary.
- A feature referencing another feature's `impl` → revert to an Intent/`api`
  contract.
- A merged god-module where `feature/<name>` boundaries used to be.
- Two features with a cycle/direct dependency to communicate → mediate through
  shared `core:data`, passing a raw ID instead of an object.
- Build config that a convention plugin covers, copy-pasted per module by hand.
- Android deps leaking into a `core:model`/domain module.
- Versions/coordinates hardcoded in a module build (bypassing the version catalog).
- An `api|impl` split with only one consumer, or a `core:domain` with no use case →
  collapse to reduce overhead.

## References

- Detailed material (full dependency matrix, convention plugin examples, version
  catalog snippets): [reference.md](reference.md)
- Team baseline: [../../guidance.md](../../guidance.md)
- Official docs:
  - Modularization overview — https://developer.android.com/topic/modularization
  - Modularization patterns — https://developer.android.com/topic/modularization/patterns
  - Version catalog migration — https://developer.android.com/build/migrate-to-catalogs
  - Now in Android sample — https://github.com/android/nowinandroid
