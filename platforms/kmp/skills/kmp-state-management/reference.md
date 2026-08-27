# kmp-state-management — Reference

Deep-dive for `SKILL.md`. Sealed `UiState`, `Channel<Effect>` wiring,
ViewModel/ScreenModel mapping. Decision criteria live in `SKILL.md`.

## 1. Model illegal states unrepresentable

```kotlin
// ❌ Parallel nullables — allows isLoading && error && data all at once
data class HomeState(
    val isLoading: Boolean = false,
    val items: List<Item>? = null,
    val error: String? = null,
)

// ✅ Sealed hierarchy — exactly one case is possible at runtime
sealed interface HomeUiState {
    data object Loading : HomeUiState
    data class Error(val failure: HomeFailure) : HomeUiState
    data class Content(val items: List<Item>) : HomeUiState
}
```

- For pure async fetches with no extra fields, Kotlin's `Result<T>` or a thin
  sealed wrapper gives the same guarantee with less boilerplate.

## 2. ViewModel — state + effect (androidx.lifecycle, KMP-compatible)

```kotlin
// UiState via StateFlow; effects via Channel consumed as a Flow.
class HomeViewModel(private val repo: HomeRepository) : ViewModel() {

    private val _state = MutableStateFlow<HomeUiState>(HomeUiState.Loading)
    val state: StateFlow<HomeUiState> = _state.asStateFlow()

    private val _effects = Channel<HomeEffect>(Channel.BUFFERED)
    val effects: Flow<HomeEffect> = _effects.receiveAsFlow()

    init { load() }

    fun onAction(action: HomeAction) {
        when (action) {
            is HomeAction.Refresh -> load()
            is HomeAction.ItemClicked -> viewModelScope.launch {
                _effects.send(HomeEffect.NavigateToDetail(action.id))
            }
        }
    }

    private fun load() {
        viewModelScope.launch {
            _state.value = HomeUiState.Loading
            repo.fetchItems()
                .onSuccess { _state.value = HomeUiState.Content(it) }
                .onFailure { _state.value = HomeUiState.Error(HomeFailure.from(it)) }
        }
    }
}

// Composable side: collect state and effects
@Composable
fun HomeScreen(viewModel: HomeViewModel = koinViewModel()) {
    val state by viewModel.state.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is HomeEffect.NavigateToDetail -> navController.navigate(DetailDestination(effect.id))
                is HomeEffect.ShowSnack -> snackbarHostState.showSnackbar(effect.message)
            }
        }
    }

    HomeContent(state = state, onAction = viewModel::onAction)
}
```

## 3. Voyager ScreenModel — state + effect equivalent

```kotlin
// ScreenModel: same pattern, different holder — pick one, never both.
class HomeScreenModel(private val repo: HomeRepository) : ScreenModel {

    private val _state = MutableStateFlow<HomeUiState>(HomeUiState.Loading)
    val state: StateFlow<HomeUiState> = _state.asStateFlow()

    private val _effects = Channel<HomeEffect>(Channel.BUFFERED)
    val effects: Flow<HomeEffect> = _effects.receiveAsFlow()

    init {
        coroutineScope.launch { load() }
    }

    fun onAction(action: HomeAction) { /* same as ViewModel above */ }
    private suspend fun load() { /* same as ViewModel above */ }
}

// Screen:
class HomeScreen : Screen {
    @Composable
    override fun Content() {
        val screenModel = rememberScreenModel<HomeScreenModel>()
        val state by screenModel.state.collectAsState()
        // LaunchedEffect for effects — same as ViewModel pattern above
        HomeContent(state = state, onAction = screenModel::onAction)
    }
}
```

## 4. ViewModel vs ScreenModel vs Decompose (pick one project-wide)

| Concept | androidx ViewModel | Voyager ScreenModel | Decompose |
|--------|-------------------|---------------------|-----------|
| State carrier | `StateFlow<UiState>` | `StateFlow<UiState>` | `Value<UiState>` (StateKeeper) |
| Effect stream | `Channel<Effect>.receiveAsFlow()` | `Channel<Effect>.receiveAsFlow()` | `SharedFlow` / callbacks |
| Scope | `viewModelScope` | `coroutineScope` (ScreenModel) | `coroutineScope` (ComponentContext) |
| DI | `koinViewModel()` | `rememberScreenModel()` | component factory (Koin) |
| Survivability | process death via `SavedStateHandle` | Voyager back-stack retention | Decompose `StateKeeper` |

Never mix two of these in one project.

## 5. Async safety — no leaked coroutines

```kotlin
// ❌ Fire-and-forget without scope — leaks if ViewModel is cleared
fun onRefresh() {
    GlobalScope.launch { repo.fetch() } // forbidden
}

// ✅ Use viewModelScope (or coroutineScope for ScreenModel) — cancelled on clear
fun onRefresh() {
    viewModelScope.launch {
        _state.value = HomeUiState.Loading
        // ...
    }
}
```

- Unlike Flutter's `mounted` check, KMP ViewModels cancel their scope
  automatically on `onCleared()`. The risk to guard is `GlobalScope` or
  unstructured coroutines escaping the scope.

## 6. State review checklist

- [ ] One immutable/sealed `UiState` type per screen.
- [ ] `Loading`/`Content`/`Error` modeled explicitly (sealed class), no parallel nullables.
- [ ] One-shot effects via `Channel<Effect>.receiveAsFlow()` or `SharedFlow`, not stored in `UiState`.
- [ ] ViewModel/ScreenModel imports no `android.*`, `androidx.compose.*`, holds no `Context`/`Activity`.
- [ ] Repository failures mapped to typed `UiState`; no raw exceptions to Composables.
- [ ] Coroutines launched in `viewModelScope`/`coroutineScope`, not `GlobalScope`.
- [ ] Exactly one state holder approach in the project (ViewModel or ScreenModel or Decompose).

## Official references

- Kotlin StateFlow/SharedFlow: https://kotlinlang.org/docs/flow.html#stateflow-and-sharedflow
- Kotlin Channel: https://kotlinlang.org/docs/channels.html
- androidx.lifecycle.ViewModel (KMP): https://developer.android.com/topic/libraries/architecture/viewmodel
- Voyager ScreenModel: https://voyager.adriel.cafe/screenmodel
- Turbine (Flow testing): https://github.com/cashapp/turbine
- Team baseline: [../../guidance.md](../../guidance.md)
