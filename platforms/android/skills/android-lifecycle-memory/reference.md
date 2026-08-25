# android-lifecycle-memory — Detailed Reference

Deep-dive material for `SKILL.md`: leak-pattern catalog, collection-API
comparison, `onTrimMemory` level table. API names follow the official docs.

## 1. Leak-pattern catalog

If a reference survives past the lifecycle boundary, it leaks. The GC cannot
reclaim reachable objects — breaking the reference is the only way to release
it.

| Pattern | Why it leaks | Fix |
|---|---|---|
| static/companion holding a `Context`/`Activity` | Process lifetime → destroyed Activity stays forever | Hold only `Application`, or remove the reference |
| ViewModel holding a `View`/`Context`/`Fragment` | ViewModel outlives the UI | Remove UI types; only `Application`/`SavedStateHandle` |
| Anonymous `Runnable`/`Handler`/listener | Implicitly references the enclosing `Activity` | static + `WeakReference`, or remove in `onDestroy`/`ON_STOP` |
| Unreleased listener/`BroadcastReceiver`/callback | System keeps holding the reference | Release on the lifecycle event that pairs with registration |
| Non-lifecycle-aware Flow collection | Collection continues in the background, consuming resources and battery | `repeatOnLifecycle`/`collectAsStateWithLifecycle` |
| Long-lived coroutine/`GlobalScope` holding live UI | No cancellation owner | `viewModelScope`/`lifecycleScope` |
| Large bitmaps/caches held into the background | Occupy RAM even when the UI is hidden → LMK risk | Release via `onTrimMemory` |

Quick check: LeakCanary in debug builds (`com.squareup.leakcanary:leakcanary-android:2.14`,
`debugImplementation`) — auto-detects retained instances of destroyed
Activities/Fragments with no code changes. Confirm via
`"LeakCanary is running and ready to detect leaks"` in Logcat.

## 2. Flow collection: repeatOnLifecycle vs collectAsStateWithLifecycle

### View (Activity/Fragment) — `repeatOnLifecycle`

Collects only at `STARTED` and above, cancels the coroutine when dropping
below, and restarts when rising back.

```kotlin
class ConversationActivity : AppCompatActivity() {
    private val viewModel: ConversationViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { render(it) }
            }
        }
    }
}
```

- `repeatOnLifecycle(state) { }` runs the block when the owner reaches `state`
  and cancels it when dropping below. Call it inside `lifecycleScope.launch`.
- For a single Flow, `flow.flowWithLifecycle(lifecycle, STARTED)` also works.
- Forbidden: `lifecycleScope.launchWhenStarted { }` (deprecated family, pauses
  rather than cancels), and a bare `collect` without `repeatOnLifecycle`.

### Compose — `collectAsStateWithLifecycle`

Provided by the `androidx.lifecycle:lifecycle-runtime-compose` artifact.

```kotlin
@Composable
fun ConversationRoute(viewModel: ConversationViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    ConversationScreen(uiState = uiState, onSend = viewModel::sendMessage)
}
```

- The default active floor is `Lifecycle.State.STARTED`; collection stops when
  dropping below. Tunable via `minActiveState = Lifecycle.State.RESUMED`.
- Multiple Flows are each collected in parallel into separate State.
- In Compose, always use this instead of `collectAsState()` (non-lifecycle-aware).

### ViewModel-side exposure

```kotlin
val uiState: StateFlow<UiState> = repository.stream()
    .stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = UiState.Loading,
    )
```

`WhileSubscribed(5_000)` rides out short subscription gaps (such as
configuration changes) for 5 seconds to prevent upstream restarts.

## 3. Compose lifecycle side-effects

Handle paired resources with the lifecycle-aware effects in
`androidx.lifecycle.compose`.

- `LifecycleStartEffect(key) { ...; onStopOrDispose { release } }` — `ON_START`↔`ON_STOP`.
- `LifecycleResumeEffect(key) { ...; onPauseOrDispose { release } }` — `ON_RESUME`↔`ON_PAUSE`.
- `LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { }` — a single event.
- General cleanup: `DisposableEffect(key) { onDispose { release } }`.
- Access the current `LifecycleOwner` via `LocalLifecycleOwner.current`.

## 4. onTrimMemory level table

Implement `ComponentCallbacks2` and release resources in
`onTrimMemory(level: Int)`. Handle `level` with `>=` comparison.

| Constant | Meaning | Response |
|---|---|---|
| `TRIM_MEMORY_UI_HIDDEN` | The app UI moved off-screen | Release bitmap caches, video playback buffers, complex animation resources |
| `TRIM_MEMORY_BACKGROUND` | The process is in the background, a termination candidate | Aggressively release easily reconstructable resources → extends the cached state, reduces cold starts |

> As of Android 14 the system delivers only the two notifications above; the
> remaining `TRIM_MEMORY_*` constants (`RUNNING_MODERATE`/`RUNNING_LOW`/
> `RUNNING_CRITICAL`/`MODERATE`/`COMPLETE`) are deprecated as of Android 15.
> Reference only when maintaining compatibility with earlier API levels.

```kotlin
class MainActivity : AppCompatActivity(), ComponentCallbacks2 {
    override fun onTrimMemory(level: Int) {
        if (level >= ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
            // Release UI-related memory (caches, buffers)
        }
        if (level >= ComponentCallbacks2.TRIM_MEMORY_BACKGROUND) {
            // Release background-processing memory
        }
    }
}
```

Auxiliary: check available memory with `ActivityManager.getMemoryInfo()` before
heavy work, and query the app heap limit (MB) with
`ActivityManager.getMemoryClass()`. Always stop a service when its work
finishes — a running service raises LMK priority and memory pressure.

## 5. References

- Lifecycle-aware components: https://developer.android.com/topic/libraries/architecture/lifecycle
  (current final URL: https://developer.android.com/topic/architecture/ui-layer/lifecycle)
- Lifecycle-aware coroutines: https://developer.android.com/topic/libraries/architecture/coroutines
- Compose side-effects: https://developer.android.com/jetpack/compose/side-effects
  (current final URL: https://developer.android.com/develop/ui/compose/side-effects)
- Memory overview: https://developer.android.com/topic/performance/memory-overview
- App memory management: https://developer.android.com/topic/performance/memory
- `ComponentCallbacks2`: https://developer.android.com/reference/android/content/ComponentCallbacks2
- LeakCanary: https://square.github.io/leakcanary/
- Team guidance: [`../../guidance.md`](../../guidance.md)
