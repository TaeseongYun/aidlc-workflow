# kmp-performance — Reference

Deep-dive for `SKILL.md`. Stability samples, `derivedStateOf`/`remember` patterns,
`LaunchedEffect` discipline, and the profiling workflow. Decision criteria live in `SKILL.md`.

## 1. `@Stable`/`@Immutable` and tight recomposition scope

```kotlin
// ❌ Unstable class — Compose cannot skip recomposition for callers
data class UiState(
    val items: List<Item>,      // List is not stable (mutable subtype exists)
    val isLoading: Boolean,
)

// Every time UiState is emitted by the StateFlow, all composables
// reading it recompose — even if only isLoading changed.

// ✅ @Immutable + ImmutableList — Compose skips recomposition when reference unchanged
import kotlinx.collections.immutable.ImmutableList
import kotlinx.collections.immutable.persistentListOf

@Immutable
data class UiState(
    val items: ImmutableList<Item> = persistentListOf(),
    val isLoading: Boolean = false,
)

// Compose can now skip a composable if the same @Immutable instance is passed
```

```kotlin
// ❌ Whole UiState collected — every field change recomposes every reader
val state by viewModel.uiState.collectAsState()

@Composable
fun CounterDisplay() {
    val state by viewModel.uiState.collectAsState() // all fields observed
    Text("${state.counter}")  // recomposes on ANY field change
}

// ✅ Map the Flow to only the field you need before collecting
@Composable
fun CounterDisplay() {
    val counter by viewModel.uiState
        .map { it.counter }
        .collectAsState(initial = 0)
    Text("$counter") // recomposes ONLY when counter changes
}

// ✅ Or use derivedStateOf when you derive from multiple observed values
@Composable
fun FilteredList(allItems: List<Item>, query: String) {
    val filtered by remember(allItems, query) {
        derivedStateOf { allItems.filter { it.name.contains(query, ignoreCase = true) } }
    }
    LazyColumn { items(filtered) { ItemRow(it) } }
}
```

## 2. Composition-phase purity

```kotlin
// ❌ Side effects / allocation in composition
@Composable
fun DataScreen() {
    val repo = MyRepository()  // new instance every recomposition
    repo.fetch()               // I/O in composition!
    val items = repo.getItems()
    LazyColumn { items(items) { ItemRow(it) } }
}

// ✅ Work in ViewModel / LaunchedEffect; composition reads stable state
// ViewModel (commonMain, shared):
class DataViewModel(private val repo: MyRepository) : ViewModel() {
    val uiState = MutableStateFlow(DataUiState())

    init {
        viewModelScope.launch {
            repo.fetchItems().collect { items ->
                uiState.update { it.copy(items = items.toImmutableList()) }
            }
        }
    }
}

// Composable: reads state, no side effects
@Composable
fun DataScreen(viewModel: DataViewModel = koinViewModel()) {
    val state by viewModel.uiState.collectAsState()
    LazyColumn { items(state.items) { ItemRow(it) } }
}
```

## 3. LaunchedEffect / rememberCoroutineScope — correct key discipline

```kotlin
// ❌ GlobalScope in composition — not cancelled when composable leaves
@Composable
fun PollScreen() {
    GlobalScope.launch {          // never cancelled; leaks after navigation
        while (true) { poll(); delay(5_000) }
    }
}

// ❌ New CoroutineScope in composition — not remembered; new scope every recomposition
@Composable
fun UploadButton(data: ByteArray, onDone: () -> Unit) {
    val scope = CoroutineScope(Dispatchers.IO) // recreated on every recomposition
    Button(onClick = { scope.launch { upload(data); onDone() } }) { Text("Upload") }
}

// ✅ LaunchedEffect for composable-lifetime side effects
@Composable
fun PollScreen(interval: Long = 5_000L) {
    LaunchedEffect(interval) {          // cancelled and relaunched if interval changes
        while (true) { poll(); delay(interval) }
    }
}

// ✅ rememberCoroutineScope for user-triggered coroutines
@Composable
fun UploadButton(data: ByteArray, onDone: () -> Unit) {
    val scope = rememberCoroutineScope()    // scoped to composable; remembered across recompositions
    Button(onClick = { scope.launch { upload(data); onDone() } }) { Text("Upload") }
}
```

### LaunchedEffect key rules

| Key value | When to use |
|---|---|
| `Unit` | Launch once; never relaunch (one-time setup) |
| `someId` | Relaunch whenever `someId` changes (e.g. reload data when `userId` changes) |
| Fast-changing value (scroll offset) | **Never** — relaunches cancel and restart on every change; use `snapshotFlow` instead |

```kotlin
// ✅ snapshotFlow for reacting to fast-changing state without relaunching LaunchedEffect
@Composable
fun ScrollTracker(listState: LazyListState) {
    LaunchedEffect(listState) {
        snapshotFlow { listState.firstVisibleItemIndex }
            .distinctUntilChanged()
            .collect { index -> analytics.trackScroll(index) }
    }
}
```

## 4. Theme + resources, no literals

```kotlin
// ❌ Literals in a feature composable
Text(
    "Checkout",
    style = TextStyle(fontSize = 18.sp, color = Color(0xFF1A1A1A)),
)
Box(modifier = Modifier.padding(16.dp)) { /* … */ }

// ✅ theme tokens + resource strings
Text(
    stringResource(Res.string.checkout),
    style = MaterialTheme.typography.titleMedium,
)
Box(modifier = Modifier.padding(LocalSpacing.current.md)) { /* … */ }
```

## 5. LazyList — stable item keys + stable types

```kotlin
// ❌ No key — Compose recreates item composables on every list change
LazyColumn {
    items(orders) { order ->
        OrderRow(order)
    }
}

// ❌ Unstable items — Compose cannot diff efficiently
LazyColumn {
    items(
        items = orders,  // List<Order> — unstable
        key = { it.id },
    ) { order ->
        OrderRow(order)
    }
}

// ✅ Stable key + @Immutable data class items
@Immutable
data class Order(val id: String, val total: Double, val placedAt: Instant)

LazyColumn {
    items(
        items = orders,   // ImmutableList<Order>
        key = { it.id },  // stable key → animates removals/insertions correctly
    ) { order ->
        OrderRow(order)
    }
}
```

## 6. remember { } for expensive computation

```kotlin
// ❌ Recomputed on every recomposition
@Composable
fun SortedList(items: List<Item>) {
    val sorted = items.sortedBy { it.name }  // O(n log n) every recomposition
    LazyColumn { items(sorted) { ItemRow(it) } }
}

// ✅ Recomputed only when items reference changes
@Composable
fun SortedList(items: ImmutableList<Item>) {
    val sorted = remember(items) { items.sortedBy { it.name } }
    LazyColumn { items(sorted) { ItemRow(it) } }
}
```

## 7. Optimize on evidence (profiling workflow)

1. Reproduce the jank in **release mode** (`./gradlew assembleRelease`) or at minimum
   `profileable` mode — never profile in debug.
2. On Android: Android Studio → Profiler → CPU → record with "Callstack Sample".
   On iOS: Instruments → Time Profiler.
3. Find the expensive frames / high-frequency recomposition via the
   **Compose layout inspector** (Android Studio) → recomposition counts highlight hot spots.
4. Fix the measured cause:
   - High recomposition count → `@Immutable` state, map Flow to the field, `derivedStateOf`.
   - Scroll jank → `LazyColumn` with stable keys, `@Immutable` items.
   - Object allocation in composition → `remember { … }`.
   - Targeted `RepaintBoundary`-equivalent: move state reads into a child composable so
     only that child recomposes.
5. Re-measure. Don't ship speculative micro-opts.

## 8. Composable review checklist

- [ ] `UiState` / parameter types are `@Immutable` or `@Stable`; `List` replaced with `ImmutableList`.
- [ ] Recomposition scoped to the rendered slice (`map { it.field }.collectAsState()` or `derivedStateOf`); big composables split.
- [ ] Composable functions do no I/O, allocation, or business logic.
- [ ] No `GlobalScope`/bare `CoroutineScope` in composition — only `LaunchedEffect` or `rememberCoroutineScope`.
- [ ] `LaunchedEffect` keys are correct: `Unit` for one-shot, the changing value for reactive launches.
- [ ] `LazyList` items have stable `key = { item.id }` and `@Immutable` types.
- [ ] Expensive computation wrapped in `remember(deps) { … }`.
- [ ] Strings/colors/dimensions from theme + resources, not literals.
- [ ] Any perf change backed by a profiler measurement.

## Official references

- Compose performance: https://developer.android.com/develop/ui/compose/performance
- Compose stability: https://developer.android.com/develop/ui/compose/performance/stability
- `@Stable`/`@Immutable` guide: https://developer.android.com/develop/ui/compose/performance/stability/strongskipping
- `derivedStateOf`: https://developer.android.com/develop/ui/compose/side-effects#derivedstateof
- `LaunchedEffect` / side-effects: https://developer.android.com/develop/ui/compose/side-effects
- `snapshotFlow`: https://developer.android.com/develop/ui/compose/side-effects#snapshotFlow
- `kotlinx.collections.immutable`: https://github.com/Kotlin/kotlinx.collections.immutable
- Compose layout inspector: https://developer.android.com/develop/ui/compose/tooling/layout-inspector
- Team baseline: [../../guidance.md](../../guidance.md)
