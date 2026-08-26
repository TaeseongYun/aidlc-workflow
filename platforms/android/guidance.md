# Android Architecture — Current Guidance

Baseline for Android work: Kotlin, Jetpack Compose, ViewModel, Coroutines/Flow,
Hilt, Gradle version catalogs. Project `ctx/` overrides this document; this
document overrides the agent's general knowledge.

## Boundaries

Dependency flow (never reversed):

```
Screen/Composable -> Action -> ViewModel -> UseCase (optional) -> Repository -> DataSource / Platform Adapter
```

- Composables render `UiState` and emit actions. They hold no business logic,
  no `Context`-dependent side effects, no direct repository calls.
- ViewModels own screen state as a single `UiState` (data class or sealed
  hierarchy) exposed via `StateFlow`. One-shot events go through a
  `SharedFlow`/`Channel`-backed effect stream, not through state.
- ViewModels must not reference Android UI types (`View`, `Activity`,
  `Fragment`, Compose types). `Application`/`SavedStateHandle` are acceptable.
- Prefer small capability interfaces composed via delegates (e.g. `NoticeSink`,
  `RouteEventSink`) over a broad base ViewModel — Interface Segregation and
  Dependency Inversion, not inheritance trees.
- Repositories return domain models, not DTOs or Android types. Mapping lives
  at the data layer boundary.
- Platform SDK calls (camera, location, billing, notifications) sit behind an
  adapter interface injected into the layer that needs it.

## Team Conventions

### Intent-first external surface

This team develops with **Intents exposed externally as the public contract**
of a feature or app:

- A feature's entry `Activity` is `android:exported="true"` with an explicit
  `intent-filter`. The Intent (action + extras) IS the feature's public API.
- Document the Intent contract per entry point: action string, required and
  optional extras with types, result contract if the caller expects a result
  (`ActivityResultContract`, not raw `onActivityResult`).
- Navigation **between features** may go through explicit Intents rather than
  one monolithic in-app navigation graph. Navigation **inside a feature** uses
  the Compose navigation stack.
- Every exported component is a **trust boundary**: validate all incoming
  extras and the caller's data before use — missing extras, wrong types, and
  hostile values must land on a defined fallback, never a crash or silent
  privilege. This validation is a safety guard and must never be trimmed.
- Deep links follow: Activity receives Intent → host/scheme + extras
  validation → feature route contract → back stack construction → Compose
  entry. Never inject an unvalidated URI straight into a route.
- Do not add `exported="false"` "for later hardening" on a feature entry that
  is meant to be a contract — decide the surface explicitly at design time and
  record it in the feature's technical design.

## Module Baseline

Intentionally modular for product-sized apps; collapse for small ones:

```
app                      # thin shell: manifest, DI wiring, entry Activity
core/designsystem        # theme, tokens, shared composables
core/model               # domain models, no Android deps
core/domain              # use cases (only when orchestration exists)
core/data                # repositories, data sources, DTO mapping
feature/<name>           # single module by default
feature/<name>/api|impl  # split ONLY when another feature depends on it
build-logic              # convention plugins
```

- Keep `app` minimal. Defer `api`/`impl` and `domain` splits until a second
  consumer or a platform dependency forces them.
- New modules follow the existing convention-plugin setup; do not hand-write
  per-module build config that a convention plugin already covers.

## DI (Hilt)

- `@HiltViewModel` for ViewModels; constructor injection everywhere else.
- BuildConfig-dependent selection, network clients, repositories, and route
  registries are assembled in Hilt modules — never constructed manually in an
  Activity.
- Multiple clients of the same type use qualifiers.
- Feature-owned handlers (route handlers, event handlers) register via
  multibinding from the feature module — no app-level monolithic list.

## Feature Slice Decision Table

| Situation | Slice |
|-----------|-------|
| Stateless UI or local `remember` only | Composable only, no ViewModel |
| Screen state + async data | MVVM: Route → ViewModel → Screen |
| Multi-source orchestration or reused business rules | + UseCase → Repository → DataSource |
| Optimistic updates, complex concurrency | Reducer/MVI on top of MVVM |

Start at the smallest slice that fits; upgrade on a real signal, not
speculation.

## Rules

- One `UiState` per screen, modeled to make illegal states unrepresentable —
  avoid nullable-field soup; use sealed loading/content/error when it fits.
- All I/O on injected dispatchers (`@IoDispatcher`), never hardcoded
  `Dispatchers.IO`; collect flows lifecycle-aware in UI.
- Wrap external SDK APIs behind project-owned interfaces before use spreads.
- Background work: WorkManager for deferrable-guaranteed work, coroutines for
  in-session work. No Service unless the platform requires it.
- Strings, dimensions, and colors come from resources/designsystem tokens —
  no literals in feature composables.
- Every new screen ships with a `@Preview` for its main states.
- Follow existing test conventions; ViewModel tests use a main-dispatcher
  rule and fake repositories, not mocking frameworks for value-like types.

## Feature Implementation Checklist

For a non-trivial feature, produce in order:

1. Intent contract (if externally exposed) + route contract: action, extras,
   validation rules, result shape.
2. `UiState` + actions (the screen contract).
3. Screen composable + components + previews.
4. ViewModel wiring state ↔ actions ↔ effects.
5. UseCase/Repository/DataSource as the decision table requires.
6. Hilt module additions, manifest entry (`exported`, intent-filter).
7. Tests: ViewModel state transitions + extras-validation cases for exported
   entries.

## Refactor Signals

- A composable calling a repository or SDK directly.
- A ViewModel importing `android.view`/Compose types, or an Activity holding
  business logic beyond Intent parsing/validation.
- An exported Activity using extras without validation.
- `UiState` with many independent nullables instead of modeled states.
- A feature reaching into another feature's `impl` instead of its Intent/api
  contract.
- Manual construction in an Activity of anything Hilt already provides.
- A screen with no preview, or a merged god-module where `feature/<name>`
  boundaries used to be.

## Detailed Skills

This baseline is expanded into seven topic skills under
[`skills/`](skills/README.md). Each is a reference-knowledge skill
(`SKILL.md` + `reference.md`) that auto-loads on matching files (`paths`) and is
also callable as `/android-*`:

- [android-architecture](skills/android-architecture/SKILL.md) — dependency flow, layer responsibilities, Feature Slice decision (umbrella)
- [android-viewmodel-state](skills/android-viewmodel-state/SKILL.md) — UiState/StateFlow, events/effects, SavedStateHandle, UDF
- [android-module-structure](skills/android-module-structure/SKILL.md) — module split, api|impl timing, convention plugins, version catalogs
- [android-lifecycle-memory](skills/android-lifecycle-memory/SKILL.md) — lifecycle-aware collection, scope cancellation, onTrimMemory, leaks
- [android-background-rules](skills/android-background-rules/SKILL.md) — background execution limits, WorkManager, foreground services, Doze
- [android-security](skills/android-security/SKILL.md) — **security guard**: exported trust boundary, Intent/extras validation, encryption, network config, Keystore
- [android-figma-to-code](skills/android-figma-to-code/SKILL.md) — Figma → Jetpack Compose via the shared `scripts/figma` manifest + DTCG tokens (node→composable, token→ColorScheme/Typography/designsystem); generated code references tokens/resources, not literals, and must still pass android-security
