# android-architecture — reference material (reference)

Deeper appendix to `SKILL.md`. Holds the detailed per-layer responsibility table,
MVI/reducer sample, Modern Android Development (MAD) components, and the official
recommendation priority table. Not the rationale for the rules, but the detail you
reference when applying them.

Related concept links: [android-viewmodel-state](../android-viewmodel-state/SKILL.md),
[android-module-structure](../android-module-structure/SKILL.md).

## 1. Per-layer responsibility table

The official recommended architecture is at least 2 layers (UI, data), with an
optional 3rd (domain). Dependencies flow top → bottom, one-directional:
`UI → domain(optional) → data`. The data layer never depends on a higher layer.

| Layer | Components | Does | Doesn't |
|--------|----------|---------|--------------|
| **UI** | Composable, state holder (`ViewModel`) | Renders `UiState`, receives user events, UI logic (display text from resources, navigation, snackbar) | Business logic, calling repository/DataSource directly, mutating `UiState` directly |
| **Domain** (optional) | UseCase/Interactor | Encapsulate complex business logic, rules reused by multiple ViewModels, combine multiple repositories | Hold mutable state, exist for simple delegation, own lifecycle |
| **Data** | Repository, DataSource | Expose app data, centralize changes, resolve source conflicts, abstract sources, define SSOT | Depend on a higher layer, expose mutable data, name after an implementation detail (`SharedPreferences`) |

### UI layer detail
- **UI State**: an immutable snapshot of what the screen shows. `data class`,
  naming convention `[Feature]UiState` (e.g. `NewsUiState`). Expose related data as
  a single stream.
- **State holder**: screen level is `ViewModel`. Reusable UI components use a plain
  state holder class. A state holder lives as long as its target UI element.
- **Exposure**: `StateFlow` + `stateIn(scope, SharingStarted.WhileSubscribed(5_000),
  initialValue)`. The UI consumes lifecycle-aware via
  `collectAsStateWithLifecycle()`.
- **UI logic vs business logic**: displaying text from resources, navigation, and
  toasts are UI layer. Rules like toggling a bookmark are domain/data. Don't put
  code that needs `Context` in a ViewModel.
- Detailed state/effect design → [android-viewmodel-state](../android-viewmodel-state/SKILL.md).

### Domain layer detail
- **When to add**: only when handling complex logic or when reused across multiple
  ViewModels. Don't create it for simple data delegation (avoid over-engineering).
  Recommended in large apps.
- **Naming**: `present-tense verb + noun(optional) + UseCase` → `FormatDateUseCase`,
  `GetLatestNewsWithAuthorsUseCase`, `LogOutUserUseCase`.
- **Callable**: `operator fun invoke()` (or `suspend operator fun invoke`) to call
  it like a function.
- **Dependencies**: repositories, other UseCases. **No mutable state** — a new
  instance each time it's passed as a dependency. No own lifecycle (scoped to the
  class using it).
- **Threading**: main-safe. Move blocking work to `withContext(defaultDispatcher)`.

### Data layer detail
- **Entry point**: the repository is the only entry point. UI/domain must not
  access a DataSource directly.
- **SSOT**: define a single source of truth per repository. Offline-first means the
  local DataSource.
- **Exposed API**: `suspend fun` for one-shot, `Flow<T>` for ongoing changes.
  Exposed data is immutable.
- **Return domain models**: return domain models trimmed from API/DTOs. Mapping at
  the data layer boundary. Complex apps separate per-layer models (recommended).
- **Naming**: repository `[Data]Repository`, DataSource `[Data][Remote/Local]DataSource`.
  Don't name after an implementation detail (keep swappability). Interface
  implementations use a `Default` prefix.
- **main-safe**: use the main-safe APIs of Room/Retrofit/Ktor. Thread-safe cache
  with `Mutex`.

## 2. MVI / Reducer sample

MVI is the top slice of the decision table — layer it on top of MVVM only when
there's an optimistic-update or complex-concurrency signal. A single `Intent` (user
intent) is folded by a pure `reduce(state, intent)` into a new state. State flows in
one direction via UDF.

```kotlin
// State: an immutable snapshot of what the screen shows
data class CartUiState(
    val items: List<CartItem> = emptyList(),
    val isCheckingOut: Boolean = false,
    val error: CartError? = null,
)

// Intent: events raised by the user/system (flow in the opposite direction)
sealed interface CartIntent {
    data class Add(val item: CartItem) : CartIntent
    data class Remove(val id: String) : CartIntent
    data object Checkout : CartIntent
}

// Reducer: a pure function. No side effects, no Android types → easy to test
fun reduce(state: CartUiState, intent: CartIntent): CartUiState = when (intent) {
    is CartIntent.Add    -> state.copy(items = state.items + intent.item)      // optimistic
    is CartIntent.Remove -> state.copy(items = state.items.filterNot { it.id == intent.id })
    CartIntent.Checkout  -> state.copy(isCheckingOut = true)
}

@HiltViewModel
class CartViewModel @Inject constructor(
    private val checkoutCart: CheckoutCartUseCase,   // side effects go to UseCase/Repository
) : ViewModel() {
    private val _state = MutableStateFlow(CartUiState())
    val state: StateFlow<CartUiState> = _state.asStateFlow()

    fun onIntent(intent: CartIntent) {
        _state.update { reduce(it, intent) }          // synchronous state transition
        if (intent is CartIntent.Checkout) launchCheckout()  // async side effect separated
    }

    private fun launchCheckout() = viewModelScope.launch {
        runCatching { checkoutCart(_state.value.items) }
            .onFailure { _state.update { s -> s.copy(isCheckingOut = false, error = CartError.Network) } }
    }
}
```

Key: `reduce` is pure (state transition only) → side effects/network are separated
into UseCase/Repository. One-shot events (toast, navigation) go through a separate
effect stream, not state. For detailed design see
[android-viewmodel-state](../android-viewmodel-state/SKILL.md).

## 3. Modern Android Development (MAD) components

The tech stack the official docs currently recommend. New code defaults to the
latest, highest-performing components.

- **Kotlin** — used by 95%+ of the top 1000 apps. The language default.
- **Jetpack Compose** — declarative UI toolkit. Supports adaptive layouts.
- **Jetpack** — a set of libraries implementing best practices (ViewModel,
  Navigation, Room, WorkManager, Lifecycle, etc.).
- **Coroutines / Flow** — the default for async/streams (strongly recommended).
- **Hilt** — dependency injection (recommended). Compile-time dependency validation.
- **Android Studio** — the official IDE (Compose tooling, Gradle build, emulator).
- **Target the latest SDK** — use the latest APIs/technologies.
- **Architecture & testing best practices** — modular, testable, scalable design.

Aim for adaptive layouts that work across form factors (phone/tablet/foldable/
ChromeOS/car/XR).

## 4. Official recommendation priority table

`Strongly Recommended` vs `Recommended` vs `Optional`.

### Layered architecture
| Recommendation | Priority |
|------|----------|
| Use a clear data layer | Strongly Recommended |
| Use a clear UI layer | Strongly Recommended |
| Expose app data with a repository | Strongly Recommended |
| Use coroutines/flow | Strongly Recommended |
| Use a domain layer | Recommended (large apps) |

### UI layer / ViewModel
| Recommendation | Priority |
|------|----------|
| Follow UDF (unidirectional data flow) | Strongly Recommended |
| Use AAC ViewModel | Strongly Recommended |
| Lifecycle-aware collection with `collectAsStateWithLifecycle` | Strongly Recommended |
| Don't send events from ViewModel→UI | Strongly Recommended |
| Single-Activity app | Strongly Recommended |
| Use Jetpack Compose | Strongly Recommended |
| Keep ViewModel independent of the Android lifecycle | Strongly Recommended |
| Use ViewModel at the screen level | Strongly Recommended |
| Reusable UI components use a plain state holder class | Strongly Recommended |
| Don't use `AndroidViewModel` | Recommended |
| Expose UI State | Recommended |

### Lifecycle / DI / testing / models
| Recommendation | Priority |
|------|----------|
| Use lifecycle-aware effects instead of overriding Activity callbacks | Strongly Recommended |
| Use dependency injection | Strongly Recommended |
| Scope components when needed | Strongly Recommended |
| Use Hilt | Recommended |
| Know what to test | Strongly Recommended |
| Prefer fakes over mocks | Strongly Recommended |
| Test StateFlow | Strongly Recommended |
| Create per-layer models in complex apps | Recommended |

Lifecycle effects/memory detail → [android-lifecycle-memory](../android-lifecycle-memory/SKILL.md).
Background work rules → [android-background-rules](../android-background-rules/SKILL.md).
Security/trust boundary → [android-security](../android-security/SKILL.md).

## References

Official docs (no redirect/404, final URLs preserved):

- App architecture overview: https://developer.android.com/topic/architecture
- UI layer: https://developer.android.com/topic/architecture/ui-layer
- Domain layer: https://developer.android.com/topic/architecture/domain-layer
- Data layer: https://developer.android.com/topic/architecture/data-layer
- Architecture recommendations: https://developer.android.com/topic/architecture/recommendations
- Modern Android Development: https://developer.android.com/modern-android-development

Project docs:

- Team guidelines (parent doc): [../../guidance.md](../../guidance.md)
- Parent skill: [SKILL.md](./SKILL.md)
