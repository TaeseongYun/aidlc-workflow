# android-viewmodel-state — reference

Deeper material for `SKILL.md`. Code samples, comparison tables, SavedStateHandle
patterns. The rules themselves are in `SKILL.md`; the team baseline is
[`../../guidance.md`](../../guidance.md).

## UiState modeling

### data class (when fields are mutually independent)

```kotlin
data class NewsUiState(
    val isLoading: Boolean = false,
    val items: List<NewsItemUiState> = emptyList(),
    val userMessage: String? = null,   // null after consumption ack
)
```

### sealed hierarchy (when loading/content/error are exclusive)

Make illegal states unrepresentable. A combination like `isLoading=true` with
`error!=null` becomes impossible at compile time.

```kotlin
sealed interface DetailUiState {
    data object Loading : DetailUiState
    data class Content(val item: Item) : DetailUiState
    data class Error(val message: String) : DetailUiState
}
```

A nullable bundle (`data? + error? + isLoading`) is a smell. Use sealed or an
explicit model.

## StateFlow exposure

private mutable, public read-only:

```kotlin
@HiltViewModel
class DetailViewModel @Inject constructor(
    private val repo: ItemRepository,
    @IoDispatcher private val io: CoroutineDispatcher,
) : ViewModel() {

    private val _uiState = MutableStateFlow<DetailUiState>(DetailUiState.Loading)
    val uiState: StateFlow<DetailUiState> = _uiState.asStateFlow()

    fun load(id: String) = viewModelScope.launch {
        _uiState.value = DetailUiState.Loading
        runCatching { withContext(io) { repo.item(id) } }
            .onSuccess { _uiState.value = DetailUiState.Content(it) }
            .onFailure { _uiState.value = DetailUiState.Error(it.message.orEmpty()) }
    }
}
```

When folding a cold flow into state, use `stateIn`:

```kotlin
val uiState: StateFlow<DetailUiState> = repo.stream(id)
    .map { DetailUiState.Content(it) }
    .stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = DetailUiState.Loading,
    )
```

## StateFlow vs SharedFlow

| | StateFlow | SharedFlow |
|---|---|---|
| Holds a value | Always (`.value`), initial value required | No |
| Nature | conflated hot, latest only | hot with configurable replay/buffer |
| New subscriber | receives current value immediately | receives only the replay count (none if 0) |
| Use | screen state (UiState) | one-shot effect/event |
| How to create | `MutableStateFlow(init)` / `stateIn` | `MutableSharedFlow(replay=0, extraBufferCapacity=1)` / `shareIn` |
| Public conversion | `asStateFlow()` | `asSharedFlow()` |

Use `replay = 0` for effects. Keeps past events from re-emitting on resubscription.
Control buffer overflow with `extraBufferCapacity` and `onBufferOverflow`.

## Effect stream (truly one-shot)

Only for what can't be expressed as state. Navigation triggers, one-time toasts, etc.

```kotlin
sealed interface DetailEffect {
    data class NavigateTo(val route: String) : DetailEffect
    data class ShowToast(val message: String) : DetailEffect
}

// ViewModel
private val _effect = MutableSharedFlow<DetailEffect>(
    replay = 0,
    extraBufferCapacity = 1,
    onBufferOverflow = BufferOverflow.DROP_OLDEST,
)
val effect: SharedFlow<DetailEffect> = _effect.asSharedFlow()

fun onSaved() {
    _effect.tryEmit(DetailEffect.NavigateTo("home"))
}
```

`Channel(Channel.BUFFERED).receiveAsFlow()` is also suitable for a single-subscriber
effect.

Note: the official docs warn that when the producer (ViewModel) outlives the
consumer (UI), Channel/Flow events can't guarantee delivery. Handle a signal
expressible as state with a UiState flag + UI ack after consumption, and use effects
as a last resort.
([events](https://developer.android.com/topic/architecture/ui-layer/events))

## Event as state (recommended path)

Login success → navigation as state instead of an effect:

```kotlin
data class LoginUiState(
    val isLoginInProgress: Boolean = false,
    val errorMessage: String? = null,
    val isUserLoggedIn: Boolean = false,
)

// UI: observes state, handles once, reverts via ack
LaunchedEffect(uiState.isUserLoggedIn) {
    if (uiState.isUserLoggedIn) onLoggedIn()
}
```

## UI collection (lifecycle-aware)

Compose recommended:

```kotlin
@Composable
fun DetailRoute(viewModel: DetailViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    DetailScreen(uiState = uiState, onSave = viewModel::onSaved)
}
```

Effect collection:

```kotlin
val lifecycle = LocalLifecycleOwner.current.lifecycle
LaunchedEffect(viewModel, lifecycle) {
    viewModel.effect.flowWithLifecycle(lifecycle).collect { effect ->
        when (effect) {
            is DetailEffect.NavigateTo -> navController.navigate(effect.route)
            is DetailEffect.ShowToast -> /* show */ Unit
        }
    }
}
```

In the View system, collect inside `repeatOnLifecycle(Lifecycle.State.STARTED)`.
Non-lifecycle collection using only `launchIn` is forbidden.

## SavedStateHandle

Only light, transient state that must survive process death (input values,
selections, args). Persist large/complex data locally.

```kotlin
@HiltViewModel
class SearchViewModel @Inject constructor(
    private val savedStateHandle: SavedStateHandle,
) : ViewModel() {

    val query: StateFlow<String> =
        savedStateHandle.getStateFlow("query", "")

    fun setQuery(value: String) {
        savedStateHandle["query"] = value
    }
}
```

Key APIs: `get`/`set`/`contains`/`remove`/`keys`,
`getStateFlow(key, initial)` (read-only StateFlow). With Hilt, just inject
`SavedStateHandle` into the `@HiltViewModel` constructor.

Storable types: whatever fits in a `Bundle` — primitives/arrays, `String`,
`Parcelable`, `Serializable`, etc. For non-Parcelable, use a kotlinx serialization
delegate (`saved { ... }`) or `saveable`.

Survives/doesn't: system-initiated process death and backgrounding survive. Force
stop, recents removal, and reboot do not.

Testing: inject with `SavedStateHandle(mapOf("id" to testId))` to verify initial
values.

## Testing notes

Test ViewModel state transitions with a main-dispatcher rule + a fake repository.
Don't use a mocking framework for value-like types (`guidance.md`).

## References

- [ViewModel](https://developer.android.com/topic/libraries/architecture/viewmodel)
- [SavedStateHandle (ViewModel Saved State)](https://developer.android.com/topic/libraries/architecture/viewmodel/viewmodel-savedstate)
- [UI layer](https://developer.android.com/topic/architecture/ui-layer)
- [State holders](https://developer.android.com/topic/architecture/ui-layer/stateholders)
- [UI events](https://developer.android.com/topic/architecture/ui-layer/events)
- [StateFlow and SharedFlow](https://developer.android.com/kotlin/flow/stateflow-and-sharedflow)
- [State in Compose](https://developer.android.com/jetpack/compose/state)
- Team baseline: [`../../guidance.md`](../../guidance.md)
