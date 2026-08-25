---
name: android-viewmodel-state
description: Android ViewModel state management rules (Android ViewModel/UiState state management). ViewModel owns screen state as a single UiState and exposes it via StateFlow, one-shot events/effects separated into SharedFlow·Channel, SavedStateHandle for process death, unidirectional data flow (UDF) maintained, ViewModel must not reference Android UI types (View/Activity/Fragment/Compose), lifecycle-aware collection in UI (collectAsStateWithLifecycle). Use when writing/reviewing/refactoring *ViewModel.kt or the ui/ layer, and when deciding where to keep state and how to expose/collect it.
when_to_use: When designing/implementing/reviewing ViewModel/UiState/effect, splitting state vs event, or catching smells like nullable-field overuse or Android-type references.
paths: **/*ViewModel.kt, **/ui/**/*.kt
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# android-viewmodel-state

Rules for a ViewModel's state/event handling. The ViewModel/UiState items from
`guidance.md` expanded to an enforceable level. Project `ctx/` overrides this
document.

## Scope

- In scope: `*ViewModel.kt`, Composable/screen code under `ui/`.
- Covers: UiState modeling, StateFlow exposure, effect streams, SavedStateHandle,
  UDF, lifecycle-aware collection.
- Doesn't cover: module boundaries, DI assembly, Intent contracts, Repository
  mapping — follow `guidance.md` for those.

## Core rules

Do:

- One UiState per screen. `MutableStateFlow` is private; the public exposure is a
  read-only `StateFlow` (`asStateFlow()` or `stateIn(...)`).
- State changes go through `_uiState.update { it.copy(...) }`. UiState is an
  immutable data class.
- Model illegal states as unrepresentable. If loading/content/error are exclusive,
  use a sealed hierarchy. No listing of nullable fields (`isLoading` + `data?` +
  `error?`).
- One-shot events (navigation, one-time snackbar, toast) are separated into a
  `SharedFlow`/`Channel`-based effect stream. Don't carry them in state.
- When possible, model events as state too; effects are only the truly one-shot
  ones that can't be expressed as state. (The official docs recommend "ViewModel
  events should always result in a state update" —
  [events](https://developer.android.com/topic/architecture/ui-layer/events).)
- All coroutines in `viewModelScope`. I/O on an injected dispatcher
  (`@IoDispatcher`); no hardcoded `Dispatchers.IO`.
- The UI collects with `collectAsStateWithLifecycle()` (recommended). Pass state
  down to a stateless Composable and raise actions up via callbacks (UDF).
- Only the minimal state that must survive process death goes in `SavedStateHandle`
  (`getStateFlow(key, default)`).

Don't:

- Reference `View`/`Activity`/`Fragment`/`Context`/Compose types in a ViewModel.
  (`Application`/`SavedStateHandle` allowed.)
- Expose `MutableStateFlow`/`MutableSharedFlow` publicly as-is.
- The workaround of putting an effect in a UiState field and resetting it to null
  after consumption.
- Calling Repository/SDK directly from a Composable, mutating UiState in the UI.
- Scattering multiple UiStates across a single screen (related state is a single
  stream).

## Decision table

State vs event — where each type lives:

| Nature of data | Where | API |
|---|---|---|
| Persistent state the screen renders (list, form values, loading/error) | ViewModel UiState | `StateFlow<UiState>` |
| Input/selection/args that must survive process death | SavedStateHandle | `getStateFlow(key, default)` |
| A "one-time" signal expressible as state (login success→navigation) | UiState flag + UI acks after consuming | `isLoggedIn` + `LaunchedEffect` |
| A truly one-shot effect not expressible as state | effect stream | `SharedFlow`(replay=0)/`Channel` |
| Composition-lifetime UI element state (scroll, dialog open) | UI local | `remember`/`rememberSaveable`, `LazyListState` |
| UI-logic state holder (whether the bottom bar shows, etc.) | plain state holder class | `remember { ... }` |

## Refactor / red-flag signals

- ViewModel importing `android.view`/Compose types.
- public `MutableStateFlow`/`MutableSharedFlow`.
- UiState as a bundle of mutually independent nullables → replace with
  sealed/modeling.
- Pushing an effect into a state field and resetting to null.
- Hardcoded `Dispatchers.IO`, launching outside `viewModelScope`.
- UI collecting with `collect { }` without lifecycle (`launchIn` alone) — use
  `collectAsStateWithLifecycle()` or `repeatOnLifecycle` instead.
- Composable calling Repository/SDK directly or mutating UiState.
- More than one UiState on a single screen.

## References

- [ViewModel](https://developer.android.com/topic/libraries/architecture/viewmodel)
- [SavedStateHandle (ViewModel Saved State)](https://developer.android.com/topic/libraries/architecture/viewmodel/viewmodel-savedstate)
- [UI layer](https://developer.android.com/topic/architecture/ui-layer)
- [State holders](https://developer.android.com/topic/architecture/ui-layer/stateholders)
- [UI events](https://developer.android.com/topic/architecture/ui-layer/events)
- [StateFlow and SharedFlow](https://developer.android.com/kotlin/flow/stateflow-and-sharedflow)
- [State in Compose](https://developer.android.com/jetpack/compose/state)
- Team baseline: [`../../guidance.md`](../../guidance.md)
- Code samples, comparison tables, SavedStateHandle patterns: [`reference.md`](reference.md)
