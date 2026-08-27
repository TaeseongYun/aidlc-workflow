# KMP Architecture — Current Guidance

Baseline for KMP (Kotlin Multiplatform) work: Kotlin, coroutines + Flow,
Compose Multiplatform, source sets (`commonMain`/`androidMain`/`iosMain`),
`expect`/`actual` as the platform boundary. Project `ctx/` overrides this
document; this document overrides the agent's general knowledge.

## Boundaries

Dependency flow (never reversed):

```
Composable → Action → ViewModel/ScreenModel (StateFlow) → UseCase (optional) → Repository → DataSource / expect-actual platform adapter
```

- Composables render state and dispatch actions. No business logic, no
  repository or client calls, no platform-specific API access from
  `commonMain` code.
- ViewModels (`androidx.lifecycle.ViewModel`, KMP-compatible) or Voyager
  `ScreenModel` or Decompose components own screen state as a single
  sealed/immutable `UiState` exposed via `StateFlow`. One-shot effects
  (snackbars, navigation) are emitted via `Channel`/`SharedFlow`, not
  persisted in state. Use whichever holder the project already has — never
  mix two.
- Repositories return domain models; DTO ↔ domain mapping lives in the data
  layer. Domain models import no Compose or platform types.
- Platform-specific capability lives behind an `expect` declaration in
  `commonMain` with an `actual` per platform source set (`androidMain`,
  `iosMain`, etc.). `commonMain` code never touches a platform API directly.
  This `expect`/`actual` boundary is the KMP analog of Flutter's
  platform-channel adapter.
- Navigation uses the project's existing solution (Compose Navigation
  multiplatform, Decompose, or Voyager). Never mix two navigation systems.

## State Decision Table

| Situation | State home |
|-----------|-----------|
| Composable-local, ephemeral | `remember` / `rememberSaveable` |
| Screen state + async data | ViewModel/ScreenModel (`StateFlow<UiState>`) per screen |
| Shared/business state across screens | ViewModel scoped at the feature or app level (Koin scope) |
| Remote data | Repository behind the ViewModel — Composables never call clients |

Do not introduce a second state-management approach or a second DI library
into an existing project.

## Module Baseline

Source-set first (KMP); follow the project's layout when one exists:

```
shared/                          # KMP Gradle module (the shared library)
  src/
    commonMain/kotlin/
      core/                      # shared domain models, utilities, expect declarations
      data/                      # Ktor clients, repositories, DTOs, kotlinx.serialization
      features/<name>/
        presentation/            # Composables, ViewModel/ScreenModel, UiState
        domain/                  # feature use cases / domain models (when they exist)
        data/                    # feature repositories / sources (when they exist)
    androidMain/kotlin/          # actual implementations for Android
    iosMain/kotlin/              # actual implementations for iOS
    commonTest/kotlin/
    androidUnitTest/kotlin/
    iosTest/kotlin/
androidApp/                      # Android host application
iosApp/                          # iOS host application (Swift/Xcode)
```

Split into additional Gradle modules only when a second app or independent
consumer exists.

## Rules

- `commonMain` code never calls a platform API directly. Platform capability
  sits behind an `expect`/`actual` boundary.
- `UiState` types are immutable (`data class` or sealed class); model
  `Loading`/`Content`/`Error` explicitly, not as parallel nullables.
- `StateFlow` is the UiState carrier; `Channel<Effect>` or `SharedFlow` for
  one-shot effects.
- Never hold a `Context`, `Activity`, or platform lifecycle object in a
  `ViewModel`/`ScreenModel` directly — pass platform dependencies through the
  `expect`/`actual` boundary.
- Errors from repositories are typed results (`Result<T>` / sealed
  `Failure`) the ViewModel maps to `UiState` — not raw exceptions reaching
  Composables.
- Strings/colors/dimensions from `MaterialTheme` and `stringResource` — no
  hardcoded literals in feature Composables.
- `@Stable` / `@Immutable` on state types; use `derivedStateOf` to avoid
  redundant recompositions.
- DI via Koin (multiplatform) or Kodein — whichever the project already uses,
  never both.
- Follow existing test conventions: `commonTest` with `kotlin.test` + Turbine
  for Flow assertions + `runTest`; Compose UI tests via `runComposeUiTest`.

## Feature Implementation Checklist

1. Route/destination definition + deep-link parameter validation (if
   externally reachable).
2. `UiState` sealed type + `Action`/`Intent` sealed type (screen contract).
3. Composable screen + child Composables.
4. ViewModel/ScreenModel wiring state ↔ actions ↔ effects via `StateFlow` /
   `Channel`.
5. UseCase/Repository/DataSource as needed; `expect`/`actual` adapter if
   platform capability is involved.
6. Koin module wiring at the correct scope (feature vs. app).
7. Tests: `runTest` for state transitions with fake repositories; `runComposeUiTest`
   for the main UI flow; `expect`/`actual` contract if platform code changed.

## Refactor Signals

- A Composable calling a repository, API client, or platform API directly.
- Platform-specific code in `commonMain` without an `expect`/`actual` boundary.
- `UiState` as a bag of parallel nullable fields.
- One-shot effect stored as a state field (and reset to null after consuming).
- Business rules in a Composable `@Composable` function body.
- Both ViewModel and Decompose/Voyager active in the same codebase.
- Domain models importing Compose or Android/iOS platform types.
- Two DI libraries active in the same codebase.

## Detailed Skills

This baseline is expanded into thirteen topic skills under
[`skills/`](skills/). Each is a reference-knowledge skill
(`SKILL.md` + `reference.md`) that auto-loads on matching files (`paths`) and
is also callable as `/kmp-*`. Stack: KMP, Compose Multiplatform, Ktor,
kotlinx.serialization, Koin, `expect`/`actual`.

- [kmp-architecture](skills/kmp-architecture/SKILL.md) — dependency flow, layer responsibilities, state home, expect/actual boundary, Feature Slice decision (umbrella)
- [kmp-state-management](skills/kmp-state-management/SKILL.md) — sealed/immutable UiState, effects vs state, UDF, StateFlow/Channel, ViewModel/ScreenModel
- [kmp-module-structure](skills/kmp-module-structure/SKILL.md) — source-set layout, DI/Koin scoping, single-module vs multi-module split timing
- [kmp-performance](skills/kmp-performance/SKILL.md) — `@Stable`/`@Immutable`, recomposition scope, `derivedStateOf`, optimize on evidence
- [kmp-navigation-platform](skills/kmp-navigation-platform/SKILL.md) — Compose Navigation/Decompose/Voyager, deep-link validation, expect/actual adapters
- [kmp-security](skills/kmp-security/SKILL.md) — **vibe-coding security guard**: blocks vulnerable patterns in AI-generated code
- [kmp-figma-to-code](skills/kmp-figma-to-code/SKILL.md) — Figma → Compose Multiplatform via DTCG tokens + MaterialTheme; generated code passes kmp-security
- [kmp-design-system](skills/kmp-design-system/SKILL.md) — DTCG tokens → MaterialTheme ColorScheme/Typography, `CompositionLocal`, one theme
- [kmp-accessibility](skills/kmp-accessibility/SKILL.md) — semantics, content descriptions, touch targets, focus order, screen reader support
- [kmp-i18n](skills/kmp-i18n/SKILL.md) — `stringResource`/moko-resources, ICU plurals, locale-aware formatting, RTL
- [kmp-testing](skills/kmp-testing/SKILL.md) — `commonTest`, kotlin.test, Turbine, `runTest`, `runComposeUiTest`
- [kmp-observability](skills/kmp-observability/SKILL.md) — Kermit/Napier, structured logging, expect/actual crash reporting
- [kmp-contract-codegen](skills/kmp-contract-codegen/SKILL.md) — OpenAPI → Ktor client, Apollo Kotlin (GraphQL), drift guard
