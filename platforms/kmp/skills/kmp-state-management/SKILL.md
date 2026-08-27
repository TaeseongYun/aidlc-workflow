---
name: kmp-state-management
description: KMP state-management rules (ViewModel/ScreenModel state modeling). ViewModel/ScreenModel owns screen state as a single immutable/sealed UiState exposed via StateFlow, one-shot effects (snackbar/navigation) separated into a Channel<Effect> or SharedFlow (not persisted in state), loading/content/error modeled explicitly (not parallel nullables), unidirectional data flow (Composable renders state and raises actions up), ViewModel holds no Context/Activity/Compose UI types, repository failures mapped to typed UiState. Single ViewModel/ScreenModel approach — never mix two. Use when writing/reviewing/refactoring ViewModels, ScreenModels, Decompose components, or *State.kt, and when deciding where state lives and how effects are surfaced.
when_to_use: When designing/implementing/reviewing a ViewModel/ScreenModel/state type, splitting state vs effect, choosing the state home, or catching smells like parallel-nullable UiState, Context in a ViewModel, or effects stored in state.
paths: **/*ViewModel.kt, **/*ScreenModel.kt, **/*State.kt, **/*Effect.kt, **/*Action.kt, **/presentation/**/*.kt
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# kmp-state-management

Rules for a ViewModel/ScreenModel's state and effect handling. The State items
from `guidance.md` expanded to an enforceable level. Project `ctx/` overrides
this document. Deeper material (sealed UiState samples, `Channel<Effect>`
wiring, ViewModel/ScreenModel mapping) lives in [reference.md](./reference.md).

## Scope

- In scope: ViewModels (`androidx.lifecycle.ViewModel`, KMP-compatible), Voyager
  `ScreenModel`, Decompose components; screen `UiState` types; effect channels;
  the state-home decision.
- Covers: immutable/sealed `UiState` modeling, effect vs state, UDF, repository-failure
  mapping.
- Doesn't cover: module/DI wiring, Compose recomposition perf, navigation/deep links,
  expect/actual adapters — follow the Related skills in
  [kmp-architecture](../kmp-architecture/SKILL.md).

## Core rules

Do:

- **One `UiState` type per screen**, immutable (sealed class or `data class`).
  The ViewModel emits a new value (`_state.update { ... }`); Composables never
  mutate state directly.
- **Model `Loading`/`Content`/`Error` explicitly** as a sealed hierarchy, not
  as parallel nullables (`isLoading` + `data?` + `error?`).
- **One-shot effects** (snackbar, navigation, toast) go through a
  `Channel<Effect>` (consumed once) or a `SharedFlow` — **not** persisted in
  `UiState`.
- **UDF**: Composable renders `StateFlow<UiState>` and raises `Action`s up to
  the ViewModel; the ViewModel turns actions into state updates and effect
  emissions.
- Map **repository failures to typed `UiState`**. Raw exceptions never reach a
  Composable → [kmp-architecture](../kmp-architecture/SKILL.md).
- Use the state holder the project already has — `ViewModel`, `ScreenModel`, or
  Decompose component, **never mixed**.

Don't:

- Hold a `Context`, `Activity`, `Composable` reference, or any Android/iOS
  platform type inside a ViewModel/ScreenModel.
- Encode a screen's `UiState` as a bag of independent nullables.
- Store a one-shot effect in a state field and reset it to null after consuming.
- Call a repository/client directly from a Composable, or mutate `StateFlow`
  from the UI.
- Scatter multiple `UiState` types across one screen (related state is one type).
- Introduce a second state-management approach into an existing project.

## Decision table

State vs effect — where each type lives:

| Nature of data | Where | Mechanism |
|---|---|---|
| Persistent state the screen renders (list, form, loading/error) | ViewModel `StateFlow<UiState>` | sealed class / `data class` |
| Composable-local, ephemeral (scroll pos, dialog open, field focus) | Composable local | `remember` / `rememberSaveable` |
| A signal expressible as state (login success → show CTA) | state flag, Composable reacts | flag in `UiState` + `collectAsState()` |
| A truly one-shot effect not expressible as state (navigate once, one snackbar) | effect stream | `Channel<Effect>.receiveAsFlow()` / `SharedFlow` |
| Shared/business state across screens | ViewModel scoped at feature/app level (Koin scope) | app-scoped Koin module |

## Refactor / red-flag signals

- ViewModel importing `android.*`, `androidx.compose.*`, holding a `Context` or `Activity`.
- `UiState` as a bundle of mutually independent nullables → replace with sealed class.
- An effect stored in a `UiState` field and reset to null after consumption.
- Composable calling a repository/client directly or mutating `StateFlow`.
- More than one `UiState` type for a single screen.
- Two ViewModel/ScreenModel/Decompose approaches present in the codebase.

## References

- Kotlin StateFlow and SharedFlow: https://kotlinlang.org/docs/flow.html#stateflow-and-sharedflow
- androidx.lifecycle.ViewModel (KMP): https://developer.android.com/topic/libraries/architecture/viewmodel
- Voyager ScreenModel: https://voyager.adriel.cafe/screenmodel
- Turbine (Flow testing): https://github.com/cashapp/turbine
- Team baseline: [../../guidance.md](../../guidance.md)
- Code samples, sealed UiState patterns, Channel/SharedFlow effect wiring: [reference.md](reference.md)
