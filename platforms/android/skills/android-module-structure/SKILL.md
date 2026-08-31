---
name: android-module-structure
description: Android module structure/modularization reference rules — every feature ships as a {feature}:api + {feature}:impl pair from day one; api exposes ONLY the navigation surface (navigation keys, Intent extras, Intent factories, result contracts) and impl holds everything else; only app may depend on impl modules; grouped Gradle paths (:feature:<name>:api|:impl); convention plugin and version-catalog conventions. Expands the Module Baseline and DI sections of `platforms/android/guidance.md`. Reference when creating a new module, deciding what belongs in api vs impl, deciding whether to introduce core:domain, touching build.gradle.kts/settings.gradle.kts/libs.versions.toml, and when seeing module-boundary refactor signals such as a god-module or a feature referencing another feature's impl.
when_to_use: When creating/splitting/merging Android module boundaries, deciding what goes in a feature's api vs impl module, or judging Gradle module build configuration.
paths: **/build.gradle.kts, **/settings.gradle.kts, **/libs.versions.toml, **/*.gradle
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# Android Module Structure

Reference rules expanding the **Module Baseline** and **DI** sections of
`platforms/android/guidance.md` to an executable-judgment level. Read this when
creating a new module, deciding what belongs in a feature's `api` vs `impl`
module, whether to introduce `core:domain`, and how to use convention plugins
and version catalogs. It's an always-on reference document, not a step-by-step
procedure.

## Scope

- In scope: module boundaries, the mandatory `{feature}:api|impl` pair,
  inter-module dependency direction, convention plugin and version-catalog
  conventions.
- Out of scope: rules inside a layer (UiState·ViewModel·Hilt binding details,
  Intent contract *content*). Those are handled by the Boundaries / Feature
  Slice / DI sections of `guidance.md`.

## Module map

Grouped Gradle paths — features nest under `feature/`, shared code under `core/`:

```
app                      # thin shell: manifest merge, DI wiring, entry Activity only
core/designsystem        # theme, tokens, shared composables
core/model               # domain models, no Android deps (Kotlin/Java module)
core/domain              # use cases — only when orchestration actually exists
core/data                # repositories, data sources, DTO mapping
feature/<name>/api       # :feature:<name>:api  — the feature's public contract
feature/<name>/impl      # :feature:<name>:impl — everything else in the feature
build-logic              # convention plugins
```

**Every feature is born as an `api` + `impl` pair.** There is no single-module
feature stage and no "split later" step — the pair is the standard shape, so
structure stays uniform and no wedge refactor is ever needed.

## The api/impl contract

`{feature}:api` exposes **only the surface another feature needs to navigate
into this feature**:

- Navigation keys / route contracts (the identity of the destination).
- Intent extras as typed data classes (the data carried across the boundary).
- Intent factories — `fun createHomeIntent(context: Context, args: HomeArgs): Intent`
  — so a caller depending only on `api` can launch the feature directly.
- Result contracts (`ActivityResultContract`) when the caller expects a result.

Nothing else. No composables, no ViewModels, no repository interfaces, no
business types. If two features need a shared type beyond the navigation
payload, it graduates to `core:model`; shared behavior graduates to `core:data`.

`{feature}:impl` holds the rest: entry Activity + manifest entry, screens,
ViewModels, UiState, in-feature Compose navigation, Hilt bindings.

## Dependency rules

Direction (never reversed):

```
app ──▶ every :feature:*:impl (DI wiring + manifest merge) and :feature:*:api
:feature:<a>:impl ──▶ :feature:<a>:api, other features' :api, core modules
:feature:<name>:api ──▶ core:model only (plus minimal Android deps for Intent/Context)
core/* ──▶ lower core modules only (see reference.md matrix)
```

- **Only `app` may depend on an `impl` module.** A feature referencing another
  feature's `impl` is a review-blocking violation — cross-feature contact goes
  through `api` (or shared `core:data`, passing a raw ID, not an object).
- `api` is an Android library (it builds `Intent`s) but stays minimal: no
  core:data/domain/designsystem, no third-party UI deps.
- `core:model` stays a leaf with no Android deps.

## Core rules (do / don't)

- **DO** create every new feature as the `api` + `impl` pair, registered as
  `:feature:<name>:api` / `:feature:<name>:impl` in `settings.gradle.kts`.
- **DO** keep `app` minimal — manifest, DI wiring (Hilt), entry Activity, and
  top-level navigation wiring only.
- **DO** have new modules apply the existing convention plugins; don't
  hand-rewrite per-module build config a plugin already covers.
- **DO** manage versions/plugins in `gradle/libs.versions.toml` only, referenced
  via `libs.*` / `alias(libs.plugins.*)`. No hardcoding.
- **DO** make modules without Android deps (`core:model`, pure domain)
  Kotlin/Java modules, not Android libraries.
- **DO** default to `implementation` over `api` in Gradle dependency
  declarations, and hide impl internals with `internal`.
- **DON'T** put UI, ViewModels, repositories, or business types in an `api`
  module — it is a navigation contract, not a shared library.
- **DON'T** depend on another feature's `impl` from anywhere but `app`.
- **DON'T** preemptively introduce `core:domain` — add it when orchestration
  or reused business rules actually exist.
- **DON'T** reverse the dependency direction (`core` → `feature`, `data` → `app`).

## Module decision table

| Situation | Decision |
|------|------|
| A new screen/feature appears | Create the pair: `:feature:<name>:api` + `:feature:<name>:impl` |
| Feature B must navigate into feature A | B's `impl` depends on A's `api`; uses its keys/Intent factory |
| Two features need a shared type beyond the navigation payload | Move it to `core:model` — don't fatten `api` |
| Two features need shared behavior/data | Shared repository in `core:data`; pass raw IDs across features |
| Implementation must be swapped per build variant | `app` selects among `impl` variants via DI (`debugImplementation` etc.) |
| Multi-source orchestration / reused business rules | Introduce a use case in `core:domain` |
| Simple state mapping only | No `core:domain` — ViewModel uses the repository directly |
| Cross-cutting code (theme, analytics, network) | A shared `core/<name>` module |
| Platform entry points (Auto/Wear/TV) | A separate app module isolating platform deps |

## Refactor / red-flag signals

- A feature module without the `api`/`impl` pair (legacy single module) →
  split on next touch: contract into `api`, rest into `impl`.
- Any non-`app` module depending on a `:feature:*:impl` → reroute through `api`.
- UI/ViewModel/repository types inside an `api` module → move to `impl` or core.
- An `api` module accreting business models → graduate them to `core:model`.
- **god-module**: one `impl` growing code that doesn't interact → split at the
  low-cohesion boundary (new feature pair or core module).
- Two features passing objects instead of IDs across the boundary.
- Build config a convention plugin covers, copy-pasted per module by hand.
- Android deps leaking into `core:model`, or versions hardcoded in a module
  build (bypassing the version catalog).
- A `core:domain` with no use case → collapse it.

## References

- Detailed material (full dependency matrix, api/impl build files, convention
  plugin examples, version catalog snippets): [reference.md](reference.md)
- Team baseline: [../../guidance.md](../../guidance.md)
- Official docs:
  - Modularization overview — https://developer.android.com/topic/modularization
  - Modularization patterns — https://developer.android.com/topic/modularization/patterns
  - Version catalog migration — https://developer.android.com/build/migrate-to-catalogs
