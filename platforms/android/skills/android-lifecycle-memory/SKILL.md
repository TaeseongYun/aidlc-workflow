---
name: android-lifecycle-memory
description: Memory-leak-prevention reference tied to the Android lifecycle. Use lifecycle-aware components, collect Flows with repeatOnLifecycle / collectAsStateWithLifecycle, cancel coroutines via viewModelScope / lifecycleScope, and respond to memory pressure with onTrimMemory. Reference when an Activity/Fragment/Composable holds a Context/View past the lifecycle, uses non-lifecycle-aware collection, or a static/companion captures a Context. Always apply when writing or reviewing Kotlin, Compose, ViewModel, or Coroutines/Flow code.
when_to_use: When a lifecycle/memory decision is needed in an Activity/Fragment/ViewModel/Composable — collecting a Flow, choosing a coroutine scope, referencing a Context/View, or handling onTrimMemory.
paths: **/*Activity.kt, **/*Fragment.kt, **/ui/**/*.kt
user-invocable: true
allowed-tools: Read, Grep, Glob
---

# android-lifecycle-memory

Eliminate references that outlive the lifecycle boundary, and release resources
when the UI is not visible. Bind collection, cancellation, and release to the
lifecycle to prevent leaks structurally. This is the detailed expansion of the
`../../guidance.md` rules "collect flows lifecycle-aware in UI",
"All I/O on injected dispatchers", and "ViewModels must not reference Android UI
types".

## Scope

- Applies to: `**/*Activity.kt`, `**/*Fragment.kt`, `**/ui/**/*.kt`.
- Covers: where Flows are collected, coroutine scope choice, `Context`/`View`
  reference lifetime, `onTrimMemory` response, static/companion retention.
- Out of scope: DI wiring, module boundaries, Intent contracts → `../../guidance.md`.

## Core rules

- **Collect on the UI lifecycle-aware.** In Compose use
  `collectAsStateWithLifecycle()`; in View collect inside a
  `repeatOnLifecycle(STARTED)` block. No bare `collect`/`collectAsState()`/
  `launchWhenStarted` — they keep running in the background and burn
  resources and battery.
- **Delegate cancellation to a scope.** Run coroutines in the owner's scope:
  `viewModelScope` in a ViewModel, `lifecycleScope` in the UI. No manual `Job`
  cancellation or `GlobalScope`.
- **ViewModels must not hold Android UI types.** No references to `View`,
  `Activity`, `Fragment`, `Context` (non-`Application`), or Compose types.
  Only `Application` and `SavedStateHandle` are allowed. The ViewModel outlives
  the UI even after the screen leaves, so holding it is a leak.
- **I/O on injected dispatchers.** Inject and use `@IoDispatcher`; no hardcoded
  `Dispatchers.IO` (breaks test and cancellation control).
- **Unregister callbacks/listeners on the lifecycle that registered them.**
  Pair `ON_START`↔`ON_STOP` and `ON_RESUME`↔`ON_PAUSE`. In Compose, unregister
  with `LifecycleStartEffect`/`LifecycleResumeEffect` (their
  `onStopOrDispose`/`onPauseOrDispose`) or `DisposableEffect`.
- **static/companion/object must not hold a `Context`, `View`, or `Fragment`.**
  They have process lifetime, so this leaks forever. If unavoidable, only
  `Application`.
- **Keep `Handler`, `Runnable`, and listeners in a leak-safe form.** Prevent an
  outer/anonymous class from implicitly referencing the enclosing `Activity`.
- **Respond to `onTrimMemory(level)` by releasing UI resources.** At
  `TRIM_MEMORY_UI_HIDDEN` and above, release bitmap caches, playback buffers,
  and animation resources (see the table below and `reference.md`).
- **Add LeakCanary to debug builds.**
  `debugImplementation 'com.squareup.leakcanary:leakcanary-android:2.14'` —
  auto-detects retained instances of destroyed Activities/Fragments.

## Scope → collection/cancellation mechanism

| Owner / lifecycle | Correct collection/execution | Cancellation point |
|---|---|---|
| ViewModel (screen state / async data) | `viewModelScope.launch`, `stateIn(viewModelScope, WhileSubscribed(5_000), ...)` | ViewModel `onCleared()` |
| Compose Composable | `flow.collectAsStateWithLifecycle()` (collects at `STARTED` by default, tune with `minActiveState`) | leaving composition / lifecycle drop |
| Compose side-effect | `LaunchedEffect(key)`, `rememberCoroutineScope()` | key change / leaving composition |
| Activity/Fragment (View-based) | `lifecycleScope.launch { repeatOnLifecycle(Lifecycle.State.STARTED) { flow.collect { } } }` | cancels when dropping below `STARTED`, restarts when rising back |
| Paired resource (listener / camera) | `LifecycleStartEffect`/`LifecycleResumeEffect`, or `DefaultLifecycleObserver` | release on the paired event (`ON_STOP`/`ON_PAUSE`) |

`Lifecycle.State`: `INITIALIZED` → `CREATED` → `STARTED` → `RESUMED` →
`DESTROYED`. `repeatOnLifecycle` and `collectAsStateWithLifecycle` use
`STARTED` as the active floor by default.

## Refactor / red-flag signals

- `Context`, `View`, `Activity`, or `Fragment` retained as a reference past the
  lifecycle (ViewModel field, static, callback closure).
- Non-lifecycle-aware collection: `lifecycleScope.launch { collect }` without
  `repeatOnLifecycle`, Compose `collectAsState()`, `launchWhenStarted`/`launchWhenResumed`.
- static/companion/`object` holding a `Context`, `View`, or listener.
- A ViewModel importing `android.view`, `android.widget`, or Compose types.
- Hardcoded `Dispatchers.IO`/`Dispatchers.Main`, `GlobalScope`, or manual `Job` cancellation.
- A listener, `BroadcastReceiver`, or callback that is registered but never
  unregistered (no pair).
- `onTrimMemory`/`onLowMemory` not implemented while large bitmaps or caches are
  held in the UI.
- An anonymous `Handler`/`Runnable`/inner class implicitly referencing the `Activity`.

## References

- Detailed catalog (leak patterns, `repeatOnLifecycle` vs
  `collectAsStateWithLifecycle` samples, `onTrimMemory` level table):
  [`reference.md`](reference.md)
- Team architecture guidance: [`../../guidance.md`](../../guidance.md)
- Lifecycle-aware components: https://developer.android.com/topic/libraries/architecture/lifecycle
- Lifecycle-aware coroutines (`viewModelScope`/`lifecycleScope`/`repeatOnLifecycle`): https://developer.android.com/topic/libraries/architecture/coroutines
- Compose side-effects: https://developer.android.com/jetpack/compose/side-effects
- Memory overview (GC / leaks / LMK): https://developer.android.com/topic/performance/memory-overview
- App memory management (`onTrimMemory`): https://developer.android.com/topic/performance/memory
- `ComponentCallbacks2` / `onTrimMemory` constants: https://developer.android.com/reference/android/content/ComponentCallbacks2
- LeakCanary: https://square.github.io/leakcanary/
